package com.crm.product.service;

import com.crm.product.mapper.ProductMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

import static com.crm.product.service.ProductService.*;

@Service
public class CatalogService {
    private final ProductMapper db;

    public CatalogService(ProductMapper db) {
        this.db = db;
    }

    public Object categories() {
        var rows = db.rows("""
            SELECT c.id,c.name,c.icon,c.description AS `desc`,IF(c.status='active','启用','停用') AS status,
                   (SELECT COUNT(*) FROM crm_products p WHERE p.category_id=c.id) AS productCount
            FROM crm_product_categories c ORDER BY c.sort,c.id
            """);
        rows.forEach(row -> {
            var attrs = db.rows("SELECT attr_key AS `key`,label,type,unit,options_json AS options FROM crm_product_category_attrs WHERE category_id=? ORDER BY sort,id",row.get("id"));
            attrs.forEach(a -> a.put("options",db.decode(a.get("options"))));
            row.put("attrs",attrs);
        });
        return rows;
    }

    @Transactional
    public void category(Long id, Category form) {
        String state = List.of("停用","disabled").contains(form.status()) ? "disabled" : "active";
        if (id == null) {
            db.write("INSERT INTO crm_product_categories(name,icon,description,status) VALUES(?,?,?,?)",form.name(),form.icon(),form.desc(),state);
            id = ((Number) required(db.rows("SELECT id FROM crm_product_categories WHERE name=?",form.name())).get("id")).longValue();
        } else {
            changed(db.write("UPDATE crm_product_categories SET name=?,icon=?,description=?,status=? WHERE id=?",form.name(),form.icon(),form.desc(),state,id));
        }
        db.write("DELETE FROM crm_product_category_attrs WHERE category_id=?",id);
        int sort = 0;
        for (var attr : form.attrs()) {
            db.write("INSERT INTO crm_product_category_attrs(category_id,attr_key,label,type,unit,options_json,sort) VALUES(?,?,?,?,?,?,?)",
                    id,attr.key(),attr.label(),attr.type(),attr.unit(),db.encode(attr.options()),sort++);
        }
    }

    @Transactional
    public void deleteCategory(long id) {
        db.write("DELETE FROM crm_product_category_attrs WHERE category_id=?",id);
        changed(db.write("DELETE FROM crm_product_categories WHERE id=?",id));
    }

    public Object bundles() {
        var rows = db.rows("SELECT id,code,name,bundle_price AS bundlePrice,IF(status='on','在售','停售') AS status,remark FROM crm_product_bundles ORDER BY id DESC");
        rows.forEach(row -> row.put("items",db.rows("SELECT product_id AS productId,qty,unit_name AS unit FROM crm_product_bundle_items WHERE bundle_id=?",row.get("id"))));
        return rows;
    }

    @Transactional
    public void bundle(Long id, Bundle form) {
        if (form.bundlePrice() == null || form.bundlePrice().signum() <= 0 || form.items() == null || form.items().isEmpty()) bad();
        if (id == null) {
            db.write("INSERT INTO crm_product_bundles(code,name,bundle_price,status,remark) VALUES(?,?,?,?,?)",
                    form.code(),form.name(),form.bundlePrice(),status(form.status()),form.remark());
            id = ((Number)required(db.rows("SELECT id FROM crm_product_bundles WHERE code=?",form.code())).get("id")).longValue();
        } else {
            changed(db.write("UPDATE crm_product_bundles SET code=?,name=?,bundle_price=?,status=?,remark=? WHERE id=?",
                    form.code(),form.name(),form.bundlePrice(),status(form.status()),form.remark(),id));
        }
        db.write("DELETE FROM crm_product_bundle_items WHERE bundle_id=?",id);
        for (var item : form.items()) {
            if (item.qty() < 1) bad();
            changed(db.write("""
                INSERT INTO crm_product_bundle_items(bundle_id,product_id,qty,unit_name)
                SELECT ?,product_id,?,unit_name FROM crm_product_units WHERE product_id=? AND unit_name=?
                """,id,item.qty(),item.productId(),item.unit()));
        }
    }

    public void bundleStatus(long id,String value) {
        changed(db.write("UPDATE crm_product_bundles SET status=? WHERE id=?",status(value),id));
    }

    public Object customerPrices() {
        var rows = db.rows("""
            SELECT p.customer_id AS customerId,c.name AS customer,c.level,e.name AS owner,p.discount,
                   p.product_ids AS productIds,DATE(p.updated_at) AS updatedAt
            FROM crm_customer_prices p JOIN crm_customers c ON c.id=p.customer_id
            JOIN crm_employees e ON e.id=c.owner_id ORDER BY p.updated_at DESC
            """);
        rows.forEach(row -> row.put("productIds",db.decode(row.get("productIds"))));
        return rows;
    }

    public void customerPrice(long customer,long employee,Agreement form) {
        required(db.rows("SELECT id FROM crm_customers WHERE id=?",customer));
        if (form.discount() == null || form.discount().signum() <= 0 || form.discount().compareTo(BigDecimal.ONE) > 0) bad();
        db.write("""
            INSERT INTO crm_customer_prices(customer_id,discount,product_ids,updated_by) VALUES(?,?,?,?)
            ON DUPLICATE KEY UPDATE discount=VALUES(discount),product_ids=VALUES(product_ids),updated_by=VALUES(updated_by)
            """,customer,form.discount(),form.productIds() == null || form.productIds().isEmpty() ? null : db.encode(form.productIds()),employee);
    }

    public record Category(String name,String icon,String desc,String status,List<Attribute> attrs) {}
    public record Attribute(String key,String label,String type,String unit,List<String> options) {}
    public record Bundle(String code,String name,BigDecimal bundlePrice,String status,String remark,List<Item> items) {}
    public record Item(long productId,int qty,String unit) {}
    public record Agreement(BigDecimal discount,List<Long> productIds) {}
}
