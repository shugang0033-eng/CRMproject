package com.crm.order.service;

import com.crm.common.DocCode;
import org.springframework.jdbc.core.JdbcTemplate;
import com.crm.customer.service.CustomerLifecycle;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.http.HttpStatus;
import java.math.*;
import java.time.LocalDate;
import java.util.*;

import static com.crm.order.service.BillingService.*;

@Service
public class ContractService {
    private final JdbcTemplate db;
    private final CustomerLifecycle lifecycle;
    private final OrderWriteService access;

    public ContractService(JdbcTemplate db, OrderWriteService access, CustomerLifecycle lifecycle) {
        this.db = db;
        this.lifecycle = lifecycle;
        this.access = access;
    }

    @Transactional
    public Object create(Long employee, Form form) {
        var grants = access.require(employee, "contract.create");
        if (form.name() == null || form.name().isBlank() || form.name().length() > 120
                || !List.of("年框", "季度", "单次").contains(text(form.type()))
                || form.discount() == null || form.discount().scale() > 3
                || form.discount().compareTo(new BigDecimal("0.500")) < 0 || form.discount().compareTo(BigDecimal.ONE) > 0
                || form.termDays() < 0 || form.termDays() > 180 || form.items() == null || form.items().isEmpty()
                || (form.startDate() != null && form.endDate() != null && form.endDate().isBefore(form.startDate()))) bad();
        var customers = db.queryForList("""
            SELECT owner_id FROM crm_customers WHERE id=? AND owner_id IS NOT NULL
            AND merged_into_id IS NULL FOR UPDATE
            """, form.customerId());
        if (customers.isEmpty()) bad();
        access.checkOwner(employee, grants, id(customers.get(0), "owner_id"));
        if (db.queryForObject("""
            SELECT COUNT(*) FROM crm_contracts WHERE customer_id=? AND name=?
            AND deleted_at IS NULL AND status<>'已作废'
            """, Long.class, form.customerId(), form.name().strip()) > 0) bad();

        var keys = new HashSet<List<Object>>();
        var warnings = new ArrayList<Map<String,String>>();
        BigDecimal amount = BigDecimal.ZERO;
        for (var item : form.items()) {
            positive(item.price());
            if (item.qty() == null || item.qty().compareTo(BigDecimal.ONE) < 0 || item.qty().scale() > 2
                    || item.unit() == null || !keys.add(List.of(item.productId(), item.unit()))) bad();
            var units = db.queryForList("""
                SELECT p.cost_price*u.factor AS floor FROM crm_product_units u JOIN crm_products p ON p.id=u.product_id
                WHERE u.product_id=? AND u.unit_name=?
                """, item.productId(), item.unit());
            if (units.isEmpty()) bad();
            if (grants.contains("product.cost") && units.get(0).get("floor") instanceof BigDecimal floor
                    && item.price().compareTo(floor) < 0) {
                warnings.add(Map.of("code","BELOW_COST","message","商品 "+item.productId()+" 的协议价低于成本价"));
            }
            amount = amount.add(item.qty().multiply(item.price()).setScale(2, RoundingMode.HALF_UP));
        }

        String code = DocCode.next(db, "HT", "crm_contracts");
        db.update("""
            INSERT INTO crm_contracts(code,name,customer_id,type,amount,discount,term_days,payment_term,
                sign_date,start_date,end_date,owner_id,status,remark,created_by)
            VALUES(?,?,?,?,?,?,?,?,COALESCE(?,CURDATE()),?,?,?,'待审批',?,?)
            """, code, form.name().strip(), form.customerId(), form.type(), amount, form.discount(),
            form.termDays(), text(form.paymentTerm()), form.signDate(), form.startDate(), form.endDate(),
            employee, text(form.remark()), employee);
        long id = db.queryForObject("SELECT id FROM crm_contracts WHERE code=?", Long.class, code);
        for (var item : form.items()) {
            db.update("INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price) VALUES(?,?,?,?,?)",
                    id,item.productId(),item.unit(),item.qty(),item.price());
        }
        log(id, employee, "提交", "");
        return Map.of("id",id,"code",code,"status","待审批","warnings",warnings);
    }

    @Transactional
    public void approve(Long employee, long id, String result, String note) {
        var grants = access.require(employee, "contract.approve");
        var row = access.one("SELECT owner_id,status FROM crm_contracts WHERE id=? AND deleted_at IS NULL FOR UPDATE",id);
        long owner = id(row,"owner_id");
        access.checkOwner(employee,grants,owner);
        if (owner == employee) throw error(HttpStatus.FORBIDDEN);
        state(row,"待审批");
        boolean pass = "pass".equals(result);
        String reason = text(note).strip();
        if ((!pass && (!"reject".equals(result) || reason.length()<2)) || reason.length()>300) bad();
        db.update("UPDATE crm_contracts SET status=? WHERE id=?",pass?"执行中":"草稿",id);
        log(id,employee,pass?"同意":"驳回",reason);
        lifecycle.refresh(db.queryForObject("SELECT customer_id FROM crm_contracts WHERE id=?",Long.class,id));
    }

    public Map<String,Object> detail(Long employee, long id) {
        var grants = access.require(employee,"contract.view");
        var contract = access.one("""
            SELECT ct.*,c.name AS customer,e.name AS owner FROM crm_contracts ct
            JOIN crm_customers c ON c.id=ct.customer_id JOIN crm_employees e ON e.id=ct.owner_id
            WHERE ct.id=? AND ct.deleted_at IS NULL
            """,id);
        access.checkOwner(employee,grants,id(contract,"owner_id"));
        var items = db.queryForList("""
            SELECT i.id,i.product_id AS productId,p.name,i.unit,i.qty,i.price,ROUND(i.qty*i.price,2) AS amount
            FROM crm_contract_items i JOIN crm_products p ON p.id=i.product_id WHERE i.contract_id=? ORDER BY i.id
            """,id);
        var orders = db.queryForList("""
            SELECT id,code,order_date,amount,status FROM crm_orders
            WHERE contract_id=? AND deleted_at IS NULL AND status<>'已取消' ORDER BY order_date DESC,id DESC
            """,id);
        var approvals = db.queryForList("""
            SELECT e.name AS reviewer,l.action,l.note,l.created_at AS at FROM crm_approval_logs l
            JOIN crm_employees e ON e.id=l.operator_id WHERE l.kind='合同' AND l.doc_id=? ORDER BY l.id
            """,id);
        approvals.forEach(row -> row.put("by",row.remove("reviewer")));
        var ordered = orders.stream().map(row -> money(row,"amount")).reduce(BigDecimal.ZERO,BigDecimal::add);
        return Map.of("contract",contract,"items",items,"orders",orders,"approvals",approvals,
                "summary",Map.of("orderedAmount",ordered,"orderCount",orders.size(),
                        "remainingAmount",money(contract,"amount").subtract(ordered)));
    }

    private void log(long id,long employee,String action,String note) {
        db.update("INSERT INTO crm_approval_logs(kind,doc_id,operator_id,action,note) VALUES('合同',?,?,?,?)",
                id,employee,action,note);
    }

    private static void bad() { throw error(HttpStatus.BAD_REQUEST); }

    public record Form(String name,long customerId,String type,BigDecimal discount,int termDays,
                       String paymentTerm,LocalDate signDate,LocalDate startDate,LocalDate endDate,String remark,List<Item> items) {}
    public record Item(long productId,String unit,BigDecimal qty,BigDecimal price) {}
}

