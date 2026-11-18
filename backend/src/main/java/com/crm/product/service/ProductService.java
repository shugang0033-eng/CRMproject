package com.crm.product.service;

import com.crm.product.mapper.ProductMapper;
import com.crm.product.model.ProductForm;
import com.crm.product.model.ProductForm.Prices;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Map;

@Service
public class ProductService {
    private final ProductMapper db;

    public ProductService(ProductMapper db) {
        this.db = db;
    }

    public List<Map<String, Object>> list(String keyword, Long category, String brand, String status, String mode, boolean cost) {
        return db.rows("""
            SELECT id FROM crm_products WHERE (? IS NULL OR LOCATE(?, CONCAT(code, ' ', name)) > 0)
              AND (? IS NULL OR category_id = ?) AND (? IS NULL OR brand = ?)
              AND (? IS NULL OR status = ?) AND (? IS NULL OR produce_mode = ?) ORDER BY id DESC
            """, keyword, keyword, category, category, brand, brand, status == null ? null : status(status), status == null ? null : status(status), mode == null ? null : mode(mode), mode == null ? null : mode(mode))
            .stream().map(row -> detail(((Number) row.get("id")).longValue(), cost)).toList();
    }

    public Map<String, Object> detail(long id, boolean cost) {
        var p = required(db.rows("""
            SELECT id,code,name,category_id AS categoryId,brand,specs_json AS specs,sale_unit AS saleUnit,
                   moq,production_days AS productionDays,customizable,remark,DATE(updated_at) AS updatedAt,
                   IF(produce_mode='self','自产','外采') AS mode,
                   CASE stock_status WHEN 'enough' THEN '充足' WHEN 'low' THEN '少量' ELSE '需排产' END AS stock,
                   IF(status='on','在售','停售') AS status,base_price,dealer_price,cost_price
            FROM crm_products WHERE id=?
            """, id));
        p.put("specs", db.decode(p.get("specs")));
        var units = db.rows("SELECT unit_name AS name,factor FROM crm_product_units WHERE product_id=? ORDER BY factor,id", id);
        p.put("units", units);
        int factor = units.stream().filter(u -> u.get("name").equals(p.get("saleUnit")))
                .mapToInt(u -> ((Number) u.get("factor")).intValue()).findFirst().orElseThrow();
        var standard = quote((BigDecimal)p.remove("base_price"), factor);
        var dealer = quote((BigDecimal)p.remove("dealer_price"), factor);
        var storedCost = (BigDecimal)p.remove("cost_price");
        var visibleCost = cost ? quote(storedCost, factor) : null;
        p.put("prices", new Prices(standard, dealer, visibleCost, null));
        p.put("margin", visibleCost == null ? null : standard.subtract(visibleCost)
                .multiply(BigDecimal.valueOf(100)).divide(standard, 2, RoundingMode.HALF_UP));
        var tiers = db.rows("SELECT min_qty AS min,unit_price AS price FROM crm_product_tiers WHERE product_id=? ORDER BY min_qty", id);
        tiers.forEach(t -> t.put("price", quote((BigDecimal)t.get("price"), factor)));
        p.put("tiers", tiers);
        return p;
    }

    @Transactional
    public long save(Long id, ProductForm form, boolean editPrice, boolean editCost) {
        if (form.code() == null || form.code().isBlank() || form.name() == null || form.name().isBlank()
                || form.units() == null || form.units().stream().anyMatch(u -> u.factor() < 1)
                || form.units().stream().noneMatch(u -> u.factor() == 1)) bad();
        int factor = form.units().stream().filter(u -> u.name().equals(form.saleUnit()))
                .mapToInt(ProductForm.Unit::factor).findFirst().orElse(0);
        if (factor == 0) bad();
        required(db.rows("SELECT id FROM crm_product_categories WHERE id=?", form.categoryId()));

        if (id == null) {
            validatePrice(form.prices());
            db.write("INSERT INTO crm_products(code,name,category_id,sale_unit,base_price) VALUES(?,?,?,?,?)",
                    form.code(),form.name(),form.categoryId(),form.saleUnit(),base(form.prices().standard(),factor));
            id = ((Number)required(db.rows("SELECT id FROM crm_products WHERE code=?",form.code())).get("id")).longValue();
            editPrice = true;
        } else lock(id);

        db.write("""
            UPDATE crm_products SET code=?,name=?,category_id=?,brand=?,specs_json=?,sale_unit=?,moq=?,
            production_days=?,produce_mode=?,customizable=?,stock_status=?,status=?,remark=? WHERE id=?
            """, form.code(),form.name(),form.categoryId(),form.brand(),
                db.encode(form.specs() == null ? Map.of() : form.specs()),form.saleUnit(),Math.max(1,form.moq()),
                form.productionDays(),mode(form.mode()),form.customizable(),stock(form.stock()),status(form.status()),form.remark(),id);
        db.write("DELETE FROM crm_product_units WHERE product_id=?",id);
        for (var unit : form.units()) {
            db.write("INSERT INTO crm_product_units(product_id,unit_name,factor,is_sale) VALUES(?,?,?,?)",
                    id,unit.name(),unit.factor(),unit.name().equals(form.saleUnit()));
        }
        if (editPrice && form.prices() != null) {
            var price = form.prices();
            savePrice(id,new Prices(price.standard(),price.dealer(),price.cost(),form.tiers()),editCost);
        }
        return id;
    }

    @Transactional
    public void savePrice(long id, Prices prices, boolean cost) {
        lock(id);
        validatePrice(prices);
        int factor = ((Number)required(db.rows("SELECT factor FROM crm_product_units WHERE product_id=? AND is_sale=1",id)).get("factor")).intValue();
        db.write("UPDATE crm_products SET base_price=?,dealer_price=? WHERE id=?",base(prices.standard(),factor),base(prices.dealer(),factor),id);
        if (cost) db.write("UPDATE crm_products SET cost_price=? WHERE id=?",base(prices.cost(),factor),id);
        if (prices.tiers() == null) return;
        db.write("DELETE FROM crm_product_tiers WHERE product_id=?",id);
        for (var tier : prices.tiers()) {
            if (tier.min() < 1 || tier.price() == null || tier.price().signum() <= 0) bad();
            db.write("INSERT INTO crm_product_tiers(product_id,min_qty,unit_price) VALUES(?,?,?)",id,tier.min(),base(tier.price(),factor));
        }
    }

    @Transactional
    public void batch(List<Long> ids, String kind, String mode, BigDecimal value, boolean cost) {
        if (!List.of("standard","dealer","cost").contains(kind) || !List.of("amount","percent").contains(mode)
                || value == null || ids == null || ids.isEmpty()) bad();
        if ("cost".equals(kind) && !cost) throw new ResponseStatusException(HttpStatus.FORBIDDEN);
        for (long id : ids.stream().distinct().sorted().toList()) {
            lock(id);
            var prices = (Prices)detail(id,true).get("prices");
            BigDecimal current = switch (kind) {
                case "dealer" -> prices.dealer();
                case "cost" -> prices.cost();
                default -> prices.standard();
            };
            if (current == null) bad();
            BigDecimal next = mode.equals("percent") ? current.add(current.multiply(value).movePointLeft(2)) : current.add(value);
            savePrice(id,new Prices(kind.equals("standard") ? next : prices.standard(),
                    kind.equals("dealer") ? next : prices.dealer(),kind.equals("cost") ? next : prices.cost(),null),cost);
        }
    }

    @Transactional
    public void delete(long id) {
        lock(id);
        db.write("DELETE FROM crm_product_tiers WHERE product_id=?",id);
        db.write("DELETE FROM crm_product_units WHERE product_id=?",id);
        db.write("DELETE FROM crm_products WHERE id=?",id);
    }

    public void status(long id,String value) {
        changed(db.write("UPDATE crm_products SET status=? WHERE id=?",status(value),id));
    }

    public void stock(long id,String value) {
        changed(db.write("UPDATE crm_products SET stock_status=? WHERE id=?",stock(value),id));
    }

    private void lock(long id) {
        required(db.rows("SELECT id FROM crm_products WHERE id=? FOR UPDATE",id));
    }

    private static void validatePrice(Prices p) {
        if (p == null || p.standard() == null || p.standard().signum() <= 0
                || (p.dealer() != null && p.dealer().signum() < 0)
                || (p.cost() != null && p.cost().signum() < 0)) bad();
    }

    private static BigDecimal quote(BigDecimal price,int factor) {
        return price == null ? null : price.multiply(BigDecimal.valueOf(factor)).setScale(2,RoundingMode.HALF_UP);
    }

    private static BigDecimal base(BigDecimal price,int factor) {
        return price == null ? null : price.divide(BigDecimal.valueOf(factor),8,RoundingMode.HALF_UP);
    }

    static String status(String value) {
        return switch (value == null ? "on" : value) {
            case "on","在售" -> "on";
            case "off","停售" -> "off";
            default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
        };
    }

    static String stock(String value) {
        return switch (value == null ? "enough" : value) {
            case "enough","充足" -> "enough";
            case "low","偏紧","紧张","少量" -> "low";
            case "made_to_order","按单生产","接单生产","需排产" -> "made_to_order";
            default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
        };
    }

    static String mode(String value) {
        return switch (value == null ? "self" : value) {
            case "self","自产" -> "self";
            case "outsource","外协","外采","外包" -> "outsource";
            default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
        };
    }

    static Map<String,Object> required(List<Map<String,Object>> rows) {
        if (rows.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        return rows.get(0);
    }

    static void changed(int rows) {
        if (rows == 0) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
    }

    static void bad() {
        throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
    }
}


