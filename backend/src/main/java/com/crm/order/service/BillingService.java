package com.crm.order.service;

import com.crm.common.DocCode;

import org.springframework.jdbc.core.JdbcTemplate;
import com.crm.customer.service.CustomerLifecycle;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import java.math.*;
import java.time.*;
import java.util.*;

@Service
public class BillingService {
    private final JdbcTemplate db;
    private final CustomerLifecycle lifecycle;
    private final OrderWriteService access;

    public BillingService(JdbcTemplate db, OrderWriteService access, CustomerLifecycle lifecycle) {
        this.db = db;
        this.lifecycle = lifecycle;
        this.access = access;
    }

    private Map<String,Object> document(Long employee,String table,long id,String permission,boolean lock) {
        var grants=access.require(employee,permission);
        var row=access.one("SELECT d.*,c.owner_id AS customer_owner FROM crm_"+table+
            " d JOIN crm_customers c ON c.id=d.customer_id WHERE d.id=?"+(lock?" FOR UPDATE":""),id);
        access.checkOwner(employee,grants,id(row,"customer_owner"));
        return row;
    }

    private void customer(Long employee,long customer,String permission) {
        var grants=access.require(employee,permission);
        var row=access.one("SELECT owner_id FROM crm_customers WHERE id=? AND owner_id IS NOT NULL AND merged_into_id IS NULL FOR UPDATE",customer);
        access.checkOwner(employee,grants,id(row,"owner_id"));
    }

    public Map<String,Object> statement(Long employee,long id) {
        var row=document(employee,"statements",id,"statement.view",false);
        var lines=db.queryForList("SELECT * FROM crm_statement_lines WHERE statement_id=? ORDER BY id",id);
        return Map.of("statement",row,"lines",lines,"orders",lines.stream().filter(l -> "shipment".equals(l.get("kind"))).toList(),
            "receipts",lines.stream().filter(l -> "receipt".equals(l.get("kind"))).toList(),
            "invoices",db.queryForList("SELECT id,code,amount,status FROM crm_invoices WHERE statement_id=?",id));
    }

    @Transactional
    public Object generate(Long employee,long customer,String period) {
        customer(employee,customer,"statement.create");
        YearMonth month;
        try { month=YearMonth.parse(period); }
        catch (java.time.format.DateTimeParseException e) { throw error(HttpStatus.BAD_REQUEST); }
        if(month.isAfter(YearMonth.now())) throw error(HttpStatus.BAD_REQUEST);
        var start=month.atDay(1);
        var end=month.plusMonths(1).atDay(1);
        BigDecimal open=db.queryForList("""
            SELECT close_amount FROM crm_statements WHERE customer_id=? AND period<? AND status<>'已作废'
            ORDER BY period DESC LIMIT 1
            """,BigDecimal.class,customer,period).stream().findFirst().orElse(BigDecimal.ZERO);
        var shipments=db.queryForList("""
            SELECT o.id AS order_id,o.code,s.amount,DATE(s.signed_at) AS date FROM crm_shipments s
            JOIN crm_orders o ON o.id=s.order_id WHERE o.customer_id=? AND s.status='已签收'
              AND s.signed_at>=? AND s.signed_at<? AND o.status NOT IN ('草稿','已取消')
            """,customer,start,end);
        var returns=db.queryForList("""
            SELECT order_id,code,-amount AS amount,DATE(confirmed_at) AS date FROM crm_returns
            WHERE customer_id=? AND status IN ('已入库','已退款') AND confirmed_at>=? AND confirmed_at<?
            """,customer,start,end);
        var receipts=db.queryForList("SELECT code,amount,pay_date AS date FROM crm_receipts WHERE customer_id=? AND pay_date>=? AND pay_date<?",
            customer,start,end);
        BigDecimal shipped=sum(shipments).add(sum(returns));
        BigDecimal received=sum(receipts);
        BigDecimal close=open.add(shipped).subtract(received);
        long count=shipments.stream().map(r -> r.get("order_id")).distinct().count();
        String code=DocCode.next(db,"DZ","crm_statements");
        db.update("""
            INSERT INTO crm_statements(code,customer_id,period,start_date,end_date,open_amount,shipped_amount,
                received_amount,close_amount,order_count,created_by) VALUES(?,?,?,?,?,?,?,?,?,?,?)
            """,code,customer,period,start,month.atEndOfMonth(),open,shipped,received,close,count,employee);
        long id=findId("statements",code);
        snapshot(id,"shipment",shipments);
        snapshot(id,"return",returns);
        snapshot(id,"receipt",receipts);
        return Map.of("id",id,"code",code,"open",open,"shipped",shipped,"received",received,"close",close,
            "orders",count,"status","待确认");
    }

    private void snapshot(long id,String kind,List<Map<String,Object>> rows) {
        for(var r:rows) db.update("INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount) VALUES(?,?,?,?,?,?)",
            id,kind,r.get("order_id"),r.get("code"),r.get("date"),r.get("amount"));
    }

    @Transactional
    public Object confirm(Long employee,long id) {
        state(document(employee,"statements",id,"statement.confirm",true),"待确认");
        db.update("UPDATE crm_statements SET status='已确认',confirmed_at=NOW() WHERE id=?",id);
        return access.one("SELECT confirmed_at AS confirmedAt FROM crm_statements WHERE id=?",id);
    }

    @Transactional
    public Object invoice(Long employee,Invoice f) {
        positive(f.amount());
        if(f.taxRate()==null || f.taxRate().signum()<0 || f.taxRate().compareTo(BigDecimal.ONE)>0
                || !Set.of("增值税专用","增值税普通").contains(f.type())) throw error(HttpStatus.BAD_REQUEST);
        var statement=document(employee,"statements",f.statementId(),"invoice.create",true);
        if(!Set.of("已确认","已开票","已回款").contains(statement.get("status"))) throw error(HttpStatus.CONFLICT);
        long customer=id(statement,"customer_id");
        if(f.customerId()!=null && f.customerId()!=customer) throw error(HttpStatus.BAD_REQUEST);
        BigDecimal used=db.queryForObject("SELECT COALESCE(SUM(amount),0) FROM crm_invoices WHERE statement_id=? AND status<>'已驳回'",
            BigDecimal.class,f.statementId());
        if (money(statement,"close_amount").subtract(used).compareTo(f.amount())<0) throw error(HttpStatus.BAD_REQUEST);
        String code=DocCode.next(db,"FP","crm_invoices");
        BigDecimal tax=f.amount().multiply(f.taxRate()).divide(BigDecimal.ONE.add(f.taxRate()),2,RoundingMode.HALF_UP);
        db.update("""
            INSERT INTO crm_invoices(code,customer_id,statement_id,amount,tax_rate,tax_amount,type,apply_date,created_by)
            VALUES(?,?,?,?,?,?,?,CURDATE(),?)
            """,code,customer,f.statementId(),f.amount(),f.taxRate(),tax,f.type(),employee);
        return Map.of("id",findId("invoices",code),"code",code,"amount",f.amount(),"taxAmount",tax,"status","待开票");
    }

    @Transactional
    public Object issue(Long employee,long id,String no) {
        var row=document(employee,"invoices",id,"invoice.create",true);
        state(row,"待开票");
        if(no==null || no.isBlank() || no.length()>40) throw error(HttpStatus.BAD_REQUEST);
        db.update("UPDATE crm_invoices SET status='已开票',no=?,issue_date=CURDATE() WHERE id=?",no.strip(),id);
        db.update("UPDATE crm_statements SET status='已开票' WHERE id=? AND status='已确认'",row.get("statement_id"));
        return access.one("SELECT no,issue_date AS issueDate,status FROM crm_invoices WHERE id=?",id);
    }

    @Transactional
    public Object red(Long employee,long id,String reason) {
        var row=document(employee,"invoices",id,"invoice.redflush",true);
        state(row,"已开票");
        if(allocated("target_type='invoice' AND target_id=?",id).signum()>0) throw error(HttpStatus.CONFLICT);
        if(LocalDate.parse(row.get("issue_date").toString()).getYear()!=LocalDate.now().getYear()) throw error(HttpStatus.BAD_REQUEST);
        if(reason==null || reason.isBlank()) throw error(HttpStatus.BAD_REQUEST);
        String code=DocCode.next(db,"FP","crm_invoices");
        db.update("""
            INSERT INTO crm_invoices(code,customer_id,contract_id,statement_id,amount,tax_rate,tax_amount,type,
                apply_date,issue_date,status,red_flush_of,red_flush_reason,created_by)
            SELECT ?,customer_id,contract_id,statement_id,-amount,tax_rate,-tax_amount,type,CURDATE(),CURDATE(),'已红冲',id,?,?
            FROM crm_invoices WHERE id=?
            """,code,reason,employee,id);
        db.update("UPDATE crm_invoices SET status='已红冲' WHERE id=?",id);
        return Map.of("id",findId("invoices",code),"code",code,"redFlushOf",id,"amount",money(row,"amount").negate(),"status","已红冲");
    }

    @Transactional
    public Object receipt(Long employee,Receipt f) {
        customer(employee,f.customerId(),"payment.create");
        positive(f.amount());
        if(f.requestId()!=null) {
            var prior=db.queryForList("SELECT id,code,customer_id,created_by FROM crm_receipts WHERE request_id=?",f.requestId());
            if(!prior.isEmpty()) {
                var r=prior.get(0);
                if(id(r,"customer_id")!=f.customerId() || id(r,"created_by")!=employee) throw error(HttpStatus.CONFLICT);
                return Map.of("id",r.get("id"),"code",r.get("code"));
            }
        }
        String code=DocCode.next(db,"SK","crm_receipts");
        db.update("INSERT INTO crm_receipts(code,customer_id,amount,pay_date,method,bank,remark,request_id,created_by) VALUES(?,?,?,?,?,?,?,?,?)",
            code,f.customerId(),f.amount(),f.payDate(),f.method(),text(f.bank()),text(f.remark()),f.requestId(),employee);
        lifecycle.refresh(f.customerId());
        return Map.of("id",findId("receipts",code),"code",code);
    }

    public Object receiptDetail(Long employee,long id) {
        var receipt=document(employee,"receipts",id,"payment.view",false);
        var history=db.queryForList("""
            SELECT a.id,a.target_type AS targetType,a.target_id AS targetId,COALESCE(i.code,o.code,c.code,s.code) AS target,
                   a.amount,a.created_at AS at,a.revoked_at AS revokedAt,a.revoke_reason AS revokeReason,a.revoked_by AS revokedBy FROM crm_receipt_allocations a
            LEFT JOIN crm_invoices i ON a.target_type='invoice' AND i.id=a.target_id
            LEFT JOIN crm_orders o ON a.target_type='order' AND o.id=a.target_id
            LEFT JOIN crm_contracts c ON a.target_type='contract' AND c.id=a.target_id
            LEFT JOIN crm_statements s ON a.target_type='statement' AND s.id=a.target_id
            WHERE a.receipt_id=?
            ORDER BY a.id
            """,id);
        var active=history.stream().filter(a -> a.get("revokedAt")==null).toList();
        var revoked=history.stream().filter(a -> a.get("revokedAt")!=null).toList();
        return Map.of("receipt",receipt,"allocations",active,"revokedAllocations",revoked,"availableInvoices",db.queryForList("""
            SELECT i.id,i.code,i.amount,i.amount-COALESCE((SELECT SUM(a.amount) FROM crm_receipt_allocations a
              WHERE a.target_type='invoice' AND a.target_id=i.id AND a.revoked_at IS NULL),0) AS available
            FROM crm_invoices i WHERE i.customer_id=? AND i.status='已开票' AND i.amount>0 HAVING available>0
            """,receipt.get("customer_id")));
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public void allocate(Long employee,long receipt,List<Allocation> allocations,String requestId) {
        var r=document(employee,"receipts",receipt,"payment.confirm",true);
        if(allocations==null || allocations.isEmpty()) throw error(HttpStatus.BAD_REQUEST);
        if (requestId != null && !requestId.isBlank()) {
            if (requestId.length()>64) throw error(HttpStatus.BAD_REQUEST);
            if (db.queryForObject("SELECT COUNT(*) FROM crm_receipt_allocation_requests WHERE receipt_id=? AND request_id=?",
                                  Integer.class,receipt,requestId)>0) return;
            db.update("INSERT INTO crm_receipt_allocation_requests(receipt_id,request_id) VALUES(?,?)",receipt,requestId);
        }
        if (allocations.stream().anyMatch(a -> !"invoice".equals(a.targetType()))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"核销只支持发票，请选择已开票的发票");
        }
        BigDecimal left=money(r,"amount").subtract(allocated("receipt_id=?",receipt));
        if(left.signum()<=0) throw error(HttpStatus.CONFLICT);
        for(var a:allocations.stream().sorted(Comparator.comparingLong(Allocation::targetId)).toList()) {
            positive(a.amount());
            var target=access.one("SELECT customer_id,amount,status FROM crm_invoices WHERE id=? FOR UPDATE",a.targetId());
            if (id(target,"customer_id")!=id(r,"customer_id") || !"已开票".equals(target.get("status"))
                || money(target,"amount").signum()<=0) throw error(HttpStatus.BAD_REQUEST);
            if(left.compareTo(a.amount())<0) throw error(HttpStatus.UNPROCESSABLE_ENTITY);
            if(money(target,"amount").subtract(allocated("target_type=? AND target_id=?",a.targetType(),a.targetId())).compareTo(a.amount())<0)
                throw error(HttpStatus.BAD_REQUEST);
            db.update("INSERT INTO crm_receipt_allocations(receipt_id,target_type,target_id,amount,created_by) VALUES(?,?,?,?,?)",
                receipt,a.targetType(),a.targetId(),a.amount(),employee);
            left=left.subtract(a.amount());
        }
    }

    @Transactional
    public void revoke(Long employee,long receipt,long allocation,String reason) {
        document(employee,"receipts",receipt,"payment.revoke",true);
        String note=text(reason).trim();
        if (note.length()<2 || note.length()>200) throw error(HttpStatus.BAD_REQUEST);
        if(db.update("UPDATE crm_receipt_allocations SET revoked_at=NOW(),revoke_reason=?,revoked_by=? WHERE id=? AND receipt_id=? AND revoked_at IS NULL",
            note,employee,allocation,receipt)==0) throw error(HttpStatus.CONFLICT);
    }

    private BigDecimal allocated(String where,Object... args) {
        return db.queryForObject("SELECT COALESCE(SUM(amount),0) FROM crm_receipt_allocations WHERE revoked_at IS NULL AND "+where,BigDecimal.class,args);
    }
    private long findId(String table,String code){return db.queryForObject("SELECT id FROM crm_"+table+" WHERE code=?",Long.class,code);}
    static long id(Map<String,Object> row,String key){return ((Number)row.get(key)).longValue();}
    static BigDecimal money(Map<String,Object> row,String key){return (BigDecimal)row.get(key);}
    static String text(String s){return s==null?"":s;}
    static void positive(BigDecimal amount){if(amount==null||amount.signum()<=0||amount.scale()>2)throw error(HttpStatus.BAD_REQUEST);}
    static void state(Map<String,Object> row,String state){if(!state.equals(row.get("status")))throw error(HttpStatus.CONFLICT);}
    static ResponseStatusException error(HttpStatus status){return new ResponseStatusException(status);}
    private BigDecimal sum(List<Map<String,Object>> rows){return rows.stream().map(r -> money(r,"amount")).reduce(BigDecimal.ZERO,BigDecimal::add);}

    public record Invoice(long statementId,Long customerId,BigDecimal amount,BigDecimal taxRate,String type) {}
    public record Receipt(long customerId,BigDecimal amount,LocalDate payDate,String method,String bank,String remark,String requestId) {}
    public record Allocation(String targetType,long targetId,BigDecimal amount) {}
}






