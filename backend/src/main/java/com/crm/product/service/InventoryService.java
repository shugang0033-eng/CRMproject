package com.crm.product.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class InventoryService {
    private static final String STOCK = """
        WITH occupied AS (
            SELECT i.product_id, SUM(GREATEST(i.qty-i.shipped_qty,0)
                   * COALESCE(NULLIF(i.unit_factor,0),u.factor,1)) AS qty
            FROM crm_order_items i JOIN crm_orders o ON o.id=i.order_id
            LEFT JOIN crm_product_units u ON u.product_id=i.product_id AND u.unit_name=i.unit
            WHERE o.deleted_at IS NULL AND o.status IN ('待发货','部分发货')
            GROUP BY i.product_id
        ), balances AS (
            SELECT p.id AS productId,p.code,p.name,p.sale_unit AS saleUnit,p.moq,
                   p.production_days AS productionDays,COALESCE(u.factor,1) AS factor,
                   COALESCE(i.available,0)-COALESCE(o.qty,0) AS freeUnits,
                   COALESCE(o.qty,0) AS reservedUnits,
                   CASE p.stock_status WHEN 'enough' THEN '充足' WHEN 'low' THEN '少量' ELSE '需排产' END AS stock
            FROM crm_products p
            LEFT JOIN crm_product_inventory i ON i.product_id=p.id
            LEFT JOIN occupied o ON o.product_id=p.id
            LEFT JOIN crm_product_units u ON u.product_id=p.id AND u.unit_name=p.sale_unit
        )
        """;
    private final JdbcTemplate db;

    public InventoryService(JdbcTemplate db) {
        this.db = db;
    }

    public Map<String,Object> list(String keyword,String stock,int page,int size) {
        String filter = " FROM balances WHERE (LOCATE(?,name)>0 OR LOCATE(?,code)>0) AND (?='' OR stock=?)";
        var total = db.queryForObject(STOCK+"SELECT COUNT(*)"+filter,Long.class,keyword,keyword,stock,stock);
        var rows = db.queryForList(STOCK+"""
            SELECT productId,code,name,saleUnit,moq,productionDays,stock,
                   ROUND(GREATEST(freeUnits,0)/factor,2) AS available,
                   ROUND(reservedUnits/factor,2) AS occupied,0 AS inTransit
            """+filter+" ORDER BY productId LIMIT ? OFFSET ?",keyword,keyword,stock,stock,size,(page-1L)*size);
        return Map.of("rows",rows,"total",total);
    }

    public Map<String,Object> balance(long productId) {
        return db.queryForMap(STOCK+"SELECT name,stock,freeUnits FROM balances WHERE productId=?",productId);
    }
}