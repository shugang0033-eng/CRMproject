package com.crm.order.service;

import com.crm.common.DocCode;

import com.crm.auth.service.AuthService;
import org.springframework.jdbc.core.JdbcTemplate;
import com.crm.customer.service.CustomerLifecycle;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.*;

@Service
public class OrderWriteService {
    private final JdbcTemplate db;
    private final CustomerLifecycle lifecycle;
    private final AuthService auth;

    private final com.crm.product.service.InventoryService inventory;

    public OrderWriteService(JdbcTemplate db, AuthService auth, CustomerLifecycle lifecycle,
                             com.crm.product.service.InventoryService inventory) {
        this.db = db;
        this.lifecycle = lifecycle;
        this.inventory = inventory;
        this.auth = auth;
    }

    public Object detail(Long employee, long id) {
        var grants = require(employee, "order.view");
        var order = one("""
            SELECT o.*,c.name AS customer,e.name AS owner FROM crm_orders o
            JOIN crm_customers c ON c.id=o.customer_id JOIN crm_employees e ON e.id=o.owner_id
            WHERE o.id=? AND o.deleted_at IS NULL
            """, id);
        checkOwner(employee, grants, ((Number) order.get("owner_id")).longValue());
        order.put("customerCredit", customerCredit(BillingService.id(order,"customer_id"), BigDecimal.ZERO));
        return Map.of("order",order,"items",db.queryForList("""
            SELECT i.id,i.product_id AS productId,p.name,i.unit,i.qty,i.price,i.amount,
                   i.shipped_qty AS shippedQty,i.returned_qty AS returnedQty,i.price_source AS priceSource
            FROM crm_order_items i JOIN crm_products p ON p.id=i.product_id WHERE i.order_id=? ORDER BY i.id
            """,id),"shipments",db.queryForList("SELECT * FROM crm_shipments WHERE order_id=?",id),
            "returns",db.queryForList("SELECT * FROM crm_returns WHERE order_id=?",id),
            "invoices",grants.contains("invoice.view") ? db.queryForList("""
                SELECT DISTINCT i.id,i.code,i.no,i.amount,i.status FROM crm_invoices i
                JOIN crm_statement_lines sl ON sl.statement_id=i.statement_id WHERE sl.order_id=?
                """,id) : List.of(),
            "receipts",grants.contains("payment.view") ? db.queryForList("""
                SELECT r.id,r.code,r.amount,r.pay_date AS payDate,SUM(a.amount) AS allocated
                FROM crm_receipts r JOIN crm_receipt_allocations a ON a.receipt_id=r.id
                WHERE a.revoked_at IS NULL AND ((a.target_type='order' AND a.target_id=?)
                  OR (a.target_type='invoice' AND EXISTS(SELECT 1 FROM crm_invoices i JOIN crm_statement_lines sl
                   ON sl.statement_id=i.statement_id WHERE i.id=a.target_id AND sl.order_id=?)))
                GROUP BY r.id,r.code,r.amount,r.pay_date
                """,id,id) : List.of());
    }

    @Transactional
    public Object create(Long employee, Form form) {
        var grants = require(employee, "order.create");
        if (form.items()==null || form.items().isEmpty() || form.customerId()==null
                || form.type()==null || !Set.of("合同订单","备货订单").contains(form.type())) bad();
        var customer = one("""
            SELECT owner_id,credit_limit,credit_used FROM crm_customers
            WHERE id=? AND merged_into_id IS NULL AND owner_id IS NOT NULL FOR UPDATE
            """,form.customerId());
        long owner = ((Number)customer.get("owner_id")).longValue();
        checkOwner(employee,grants,owner);
        if (form.requestId()!=null && !form.requestId().isBlank()) {
            var existing = db.queryForList("SELECT id,code,status,created_by,customer_id FROM crm_orders WHERE request_id=?",form.requestId());
            if (!existing.isEmpty()) {
                var old = existing.get(0);
                if (((Number)old.get("created_by")).longValue()!=employee
                    || ((Number)old.get("customer_id")).longValue()!=form.customerId()) conflict();
                return Map.of("id",old.get("id"),"code",old.get("code"),"status",old.get("status"));
            }
        }
        boolean contract = "合同订单".equals(form.type());
        if (contract != (form.contractId()!=null)) bad();
        if (contract) one("""
            SELECT id FROM crm_contracts WHERE id=? AND customer_id=? AND status='执行中' AND deleted_at IS NULL FOR UPDATE
            """,form.contractId(),form.customerId());
        var priced = new ArrayList<Priced>();
        var keys = new HashSet<String>();
        BigDecimal amount = BigDecimal.ZERO;
        boolean lowPrice = false;
        for (Line line : form.items()) {
            if (line.qty()<1 || !keys.add(line.productId()+":"+line.unit())) bad();
            var quote=resolve(line,form.customerId(),form.contractId());
            BigDecimal quoted=quote.price();
            BigDecimal floor=quote.floor();
            String source=quote.source();
            BigDecimal unitPrice=line.price()==null ? quoted : line.price();
            if (unitPrice.signum()<=0 || unitPrice.scale()>2) bad();
            if (unitPrice.compareTo(quoted)!=0) source="手工价";
            lowPrice |= unitPrice.compareTo(floor)<0;
            BigDecimal total=unitPrice.multiply(BigDecimal.valueOf(line.qty()));
            amount=amount.add(total);
            priced.add(new Priced(line,unitPrice,floor,total,source,quote.factor()));
        }
        var reserved=db.queryForObject("""
            SELECT COALESCE(SUM(amount),0) FROM crm_orders WHERE customer_id=? AND deleted_at IS NULL
            AND status IN ('待审批','待发货','部分发货')
            """,BigDecimal.class,form.customerId());
        boolean over=((BigDecimal)customer.get("credit_limit")).subtract((BigDecimal)customer.get("credit_used"))
                .subtract(reserved).compareTo(amount)<0;
        var warnings = new ArrayList<Warning>();
        if (over) warnings.add(new Warning("CREDIT_EXCEEDED","超过可用信用额度，需审批"));
        if (lowPrice) warnings.add(new Warning("BELOW_COST","成交价低于底价，需审批"));
        var requested = new java.util.LinkedHashMap<Long,Long>();
        for (var item : priced) {
            requested.merge(item.line().productId(),(long)item.line().qty()*item.factor(),Long::sum);
        }
        for (var entry : requested.entrySet()) {
            var balance = inventory.balance(entry.getKey());
            if ("需排产".equals(balance.get("stock"))) {
                warnings.add(new Warning("MADE_TO_ORDER",balance.get("name")+"需要排产"));
            } else if (((Number)balance.get("freeUnits")).doubleValue() < entry.getValue()) {
                warnings.add(new Warning("STOCK_SHORT",balance.get("name")+"可用库存不足"));
            }
        }
        String status=over || lowPrice ? "待审批" : "待发货";
        String code=DocCode.next(db,"SO","crm_orders");
        db.update("""
            INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
                                   credit_check,amount,remark,request_id,created_by)
            VALUES(?,?,?,?,CURDATE(),?,?,?,?,?,?,?,?)
            """,code,form.customerId(),form.contractId(),form.type(),form.expectDate(),owner,status,
                over ? "超限" : lowPrice ? "待审批" : "通过",amount,Objects.toString(form.remark(),""),form.requestId(),employee);
        long id=((Number)one("SELECT id FROM crm_orders WHERE code=?",code).get("id")).longValue();
        for (var item : priced) {
            db.update("""
                INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,unit_factor)
                VALUES(?,?,?,?,?,?,?,?,?)
                """,id,item.line().productId(),item.line().unit(),item.line().qty(),item.price(),item.source(),item.floor(),item.total(),item.factor());
        }
        lifecycle.refresh(form.customerId());
        return Map.of("id",id,"code",code,"status",status,"warnings",warnings);
    }

    @Transactional
    public void approve(Long employee,long id,String result) {
        var grants=require(employee,"order.approve");
        if (!"pass".equals(result) && !"reject".equals(result)) bad();
        var order=one("SELECT owner_id,status FROM crm_orders WHERE id=? AND deleted_at IS NULL FOR UPDATE",id);
        checkOwner(employee,grants,((Number)order.get("owner_id")).longValue());
        if (!"待审批".equals(order.get("status"))) conflict();
        db.update("UPDATE crm_orders SET status=?,credit_check=? WHERE id=?",
            "pass".equals(result) ? "待发货" : "已取消",
            "pass".equals(result) ? "通过" : "待审批",id);
        lifecycle.refresh(db.queryForObject("SELECT customer_id FROM crm_orders WHERE id=?",Long.class,id));
    }

    List<String> require(Long employee,String permission) {
        if (employee==null) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        var grants=auth.current(employee).permissions();
        if (!grants.contains(permission)) forbidden();
        return grants;
    }

    void checkOwner(long employee,List<String> grants,long owner) {
        if (employee==owner || grants.contains("data.scope.all")) return;
        if (grants.contains("data.scope.dept") && Boolean.TRUE.equals(db.queryForObject("""
            WITH RECURSIVE tree AS (SELECT department_id AS id FROM crm_employees WHERE id=?
                UNION ALL SELECT d.id FROM crm_departments d JOIN tree t ON d.parent_id=t.id)
            SELECT EXISTS(SELECT 1 FROM crm_employees WHERE id=? AND department_id IN (SELECT id FROM tree))
            """,Boolean.class,employee,owner))) return;
        forbidden();
    }

    Map<String,Object> one(String sql,Object... args) {
        var rows=db.queryForList(sql,args);
        if (rows.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        return rows.get(0);
    }

    public Object credit(Long employee,long customer,BigDecimal amount) {
        var grants=require(employee,"order.create");
        var row=one("SELECT owner_id FROM crm_customers WHERE id=? AND owner_id IS NOT NULL AND merged_into_id IS NULL",customer);
        checkOwner(employee,grants,BillingService.id(row,"owner_id"));
        return customerCredit(customer, amount);
    }

    private Object customerCredit(long customer, BigDecimal amount) {
        var row=one("SELECT credit_limit,credit_used,payment_term FROM crm_customers WHERE id=?",customer);
        var limit=BillingService.money(row,"credit_limit");
        var used=BillingService.money(row,"credit_used");
        var reserved=db.queryForObject("""
            SELECT COALESCE(SUM(amount),0) FROM crm_orders WHERE customer_id=? AND deleted_at IS NULL
            AND status IN ('待审批','待发货','部分发货')
            """,BigDecimal.class,customer);
        var available=limit.subtract(used).subtract(reserved);
        return Map.of("limit",limit,"used",used,"reserved",reserved,"available",available,"enough",available.compareTo(amount)>=0,"term",row.get("payment_term"));
    }

    public Object quote(Long employee,Form form) {
        var grants=require(employee,"order.create");
        if(form.customerId()==null || form.items()==null || form.items().isEmpty()) bad();
        credit(employee,form.customerId(),BigDecimal.ZERO);
        if(form.contractId()!=null) one("""
            SELECT id FROM crm_contracts WHERE id=? AND customer_id=? AND status='执行中' AND deleted_at IS NULL
            """,form.contractId(),form.customerId());
        return form.items().stream().map(line -> {
            if(line.qty()<1) bad();
            var q=resolve(line,form.customerId(),form.contractId());
            var row=new LinkedHashMap<String,Object>();
            row.put("productId",line.productId());
            row.put("unit",line.unit());
            row.put("price",q.price());
            row.put("priceSource",q.source());
            if(grants.contains("product.cost")) {
                row.put("floor",q.floor());
                row.put("margin",q.price().signum()>0 ? q.price().subtract(q.floor()).divide(q.price(),4,RoundingMode.HALF_UP) : null);
            }
            return row;
        }).toList();
    }

    private Quote resolve(Line line,long customerId,Long contractId) {
            var price = one("""
                SELECT u.factor, ROUND(p.base_price*u.factor,2) AS standard, ROUND(COALESCE(p.cost_price,0)*u.factor,2) AS floor,
                    ROUND(p.dealer_price*u.factor,2) AS dealer,
                    (SELECT ROUND(t.unit_price*u.factor,2) FROM crm_product_tiers t
                     WHERE t.product_id=p.id AND t.min_qty*s.factor<=?*u.factor ORDER BY t.min_qty DESC LIMIT 1) AS tier,
                    (SELECT ROUND(p.base_price*u.factor*a.discount,2) FROM crm_customer_prices a
                     WHERE a.customer_id=? AND (a.product_ids IS NULL OR JSON_CONTAINS(a.product_ids,CAST(p.id AS JSON)))) AS agreement
                FROM crm_products p JOIN crm_product_units u ON u.product_id=p.id AND u.unit_name=?
                JOIN crm_product_units s ON s.product_id=p.id AND s.unit_name=p.sale_unit
                WHERE p.id=? AND p.status='on'
                """,line.qty(),customerId,line.unit(),line.productId());
            BigDecimal floor = (BigDecimal)price.get("floor");
            String source = "标准价";
            BigDecimal quoted = (BigDecimal)price.get("standard");
            for (String key: List.of("dealer","tier","agreement")) {
                if (price.get(key) instanceof BigDecimal candidate && candidate.signum()>0 && (source.equals("标准价") || candidate.compareTo(quoted)<0)) {
                    quoted=candidate;
                    source=switch (key) {case "dealer" -> "经销价"; case "tier" -> "阶梯价"; default -> "客户协议价";};
                }
            }
            if (contractId != null) {
                var term = one("""
                    SELECT ci.price,ci.qty-COALESCE((SELECT SUM(i.qty) FROM crm_order_items i JOIN crm_orders o ON o.id=i.order_id
                    WHERE o.contract_id=ci.contract_id AND o.status<>'已取消' AND o.deleted_at IS NULL
                      AND i.product_id=ci.product_id AND i.unit=ci.unit),0) AS remaining
                    FROM crm_contract_items ci WHERE ci.contract_id=? AND ci.product_id=? AND ci.unit=?
                    """,contractId,line.productId(),line.unit());
                if (((BigDecimal)term.get("remaining")).compareTo(BigDecimal.valueOf(line.qty()))<0) conflict();
                quoted=(BigDecimal)term.get("price");
                source="合同协议价";
            }
        return new Quote(quoted,floor,source,((Number)price.get("factor")).intValue());
    }

    private static void bad() { throw new ResponseStatusException(HttpStatus.BAD_REQUEST); }
    private static void conflict() { throw new ResponseStatusException(HttpStatus.CONFLICT); }
    private static void forbidden() { throw new ResponseStatusException(HttpStatus.FORBIDDEN); }

    public record Form(Long customerId,Long contractId,String type,LocalDate expectDate,String remark,String requestId,List<Line> items) {}
    public record Line(long productId,String unit,int qty,BigDecimal price) {}
    private record Priced(Line line,BigDecimal price,BigDecimal floor,BigDecimal total,String source,int factor) {}
    private record Warning(String code,String message) {}
    private record Quote(BigDecimal price,BigDecimal floor,String source,int factor) {}
}







