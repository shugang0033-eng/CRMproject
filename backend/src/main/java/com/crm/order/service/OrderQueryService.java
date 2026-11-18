package com.crm.order.service;

import com.crm.auth.service.AuthService;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

@Service
public class OrderQueryService {
    private static final Map<String,String> PERMISSIONS = Map.of(
        "orders","order.view", "contracts","contract.view", "invoices","invoice.view",
        "receipts","payment.view", "statements","statement.view",
        "shipments","order.view", "returns","order.view");

    private final JdbcTemplate db;
    private final AuthService auth;

    public OrderQueryService(JdbcTemplate db, AuthService auth) {
        this.db = db;
        this.auth = auth;
    }

    public Map<String,Object> list(Long employee, String resource, String status, String type, Long customer,
                       Long owner, String period, Long order, Long contract, String keyword, int page, int size) {
        return query(employee,resource,status,type,customer,owner,period,order,contract,keyword,page,size);
    }

    @SuppressWarnings("unchecked")
    public List<Map<String,Object>> pending(Long employee,String resource,String status) {
        return (List<Map<String,Object>>)query(employee,resource,status,null,null,null,null,null,null,null,1,null).get("rows");
    }

    private Map<String,Object> query(Long employee,String resource,String status,String type,Long customer,
                                    Long owner,String period,Long order,Long contract,String keyword,int page,Integer size) {
        if (employee == null) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        String permission = PERMISSIONS.get(resource);
        if (permission == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        var grants = auth.current(employee).permissions();
        if (!grants.contains(permission)) throw new ResponseStatusException(HttpStatus.FORBIDDEN);
        if (size != null && (page < 1 || size < 1 || size > 500)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST);

        String date = switch (resource) {
            case "orders" -> "o.order_date";
            case "contracts" -> "o.sign_date";
            case "invoices" -> "o.apply_date";
            case "receipts" -> "o.pay_date";
            case "statements" -> "o.start_date";
            case "returns" -> "o.return_date";
            default -> "o.ship_date";
        };
        boolean delivery = List.of("shipments","returns").contains(resource);
        boolean directOwner = List.of("orders","contracts").contains(resource);
        String ownerColumn = directOwner ? "o.owner_id" : delivery ? "sale.owner_id" : "c.owner_id";
        String statusColumn = resource.equals("receipts") ? """
            CASE WHEN COALESCE((SELECT SUM(a.amount) FROM crm_receipt_allocations a
                WHERE a.receipt_id=o.id AND a.revoked_at IS NULL),0)>=o.amount THEN '已核销'
                WHEN EXISTS(SELECT 1 FROM crm_receipt_allocations a WHERE a.receipt_id=o.id AND a.revoked_at IS NULL)
                THEN '部分核销' ELSE '待核销' END
            """ : "o.status";
        String typeColumn = directOwner || resource.equals("invoices") ? "o.type" : "NULL";
        String from = " FROM crm_" + resource + " o "
            + (delivery ? " JOIN crm_orders sale ON sale.id=o.order_id JOIN crm_customers c ON c.id=sale.customer_id " :
                            " JOIN crm_customers c ON c.id=o.customer_id ")
            + " LEFT JOIN crm_employees e ON e.id=" + ownerColumn
            + " WHERE (? OR " + ownerColumn + "=? OR (? AND e.department_id IN (SELECT id FROM departments)))"
            + " AND (? IS NULL OR c.id=?) AND (? IS NULL OR " + ownerColumn + "=?)"
            + " AND (? IS NULL OR DATE_FORMAT(" + date + ",'%Y-%m')=?)"
            + " AND (? IS NULL OR " + statusColumn + "=?) AND (? IS NULL OR " + typeColumn + "=?)"
            + (delivery ? " AND (? IS NULL OR o.order_id=?)" : " AND ? IS NULL AND ? IS NULL")
            + (resource.equals("orders") ? " AND (? IS NULL OR o.contract_id=?)" : " AND (? IS NULL OR ? IS NOT NULL)")
            + (directOwner ? " AND o.deleted_at IS NULL" : "");
        String tree = """
            WITH RECURSIVE departments AS (
                SELECT department_id AS id FROM crm_employees WHERE id=?
                UNION ALL SELECT d.id FROM crm_departments d JOIN departments t ON d.parent_id=t.id
            )
            """;
        Object[] args = {employee, grants.contains("data.scope.all"), employee, grants.contains("data.scope.dept"),
                         customer,customer,owner,owner,period,period,status,status,type,type,order,order,contract,contract};
        if (resource.equals("returns") && keyword != null && !keyword.isBlank()) {
            from += """
                AND (LOCATE(?,o.code)>0 OR LOCATE(?,sale.code)>0 OR LOCATE(?,c.name)>0 OR EXISTS (
                    SELECT 1 FROM crm_return_items ri JOIN crm_products p ON p.id=ri.product_id
                    WHERE ri.return_id=o.id AND LOCATE(?,p.name)>0))
                """;
            var filters = new java.util.ArrayList<>(java.util.Arrays.asList(args));
            filters.addAll(java.util.Collections.nCopies(4,keyword.trim()));
            args = filters.toArray();
        }
        var paging = new java.util.ArrayList<>(java.util.Arrays.asList(args));
        if (size != null) {
            paging.add(size);
            paging.add((page-1L)*size);
        }
        String extra = switch (resource) {
            case "receipts" -> "," + statusColumn + " AS status, (SELECT COALESCE(SUM(a.amount),0) FROM crm_receipt_allocations a WHERE a.receipt_id=o.id AND a.revoked_at IS NULL) AS allocatedAmount";
            case "contracts" -> ",(SELECT COALESCE(SUM(s.amount),0) FROM crm_orders s WHERE s.contract_id=o.id AND s.deleted_at IS NULL AND s.status<>'已取消') AS orderedAmount";
            case "invoices" -> """
                ,(SELECT code FROM crm_statements WHERE id=o.statement_id) AS statementCode,
                (SELECT code FROM crm_contracts WHERE id=o.contract_id) AS contractCode,
                (SELECT COALESCE(SUM(a.amount),0) FROM crm_receipt_allocations a
                  WHERE a.target_type='invoice' AND a.target_id=o.id AND a.revoked_at IS NULL) AS settledAmount
                """;
            case "orders" -> """
                ,o.contract_id AS contractId,
                (SELECT SUM(qty) FROM crm_order_items WHERE order_id=o.id) AS quantity,
                (SELECT SUM(shipped_qty-returned_qty) FROM crm_order_items WHERE order_id=o.id) AS shipped
                """;
            case "returns" -> ",sale.code AS orderCode";
            default -> "";
        };
        var rows = db.queryForList(tree + "SELECT o.*,c.name AS customer,e.name AS owner,"+date+" AS date"+extra
            + from + " ORDER BY o.id DESC" + (size == null ? "" : " LIMIT ? OFFSET ?"), paging.toArray());
        long total = size == null ? rows.size() : db.queryForObject(tree+"SELECT COUNT(*) "+from,Long.class,args);
        return Map.of("rows",rows,"total",total);
    }
}



