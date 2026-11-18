package com.crm.product.service;

import com.crm.product.mapper.ProductMapper;
import com.crm.product.model.ProductForm;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

@Service
public class ProductCsvService {
    private static final String HEADER = "物料编码,产品名称,品类,品牌,规格,最小单位,每箱数量,标准价(元/箱),经销价(元/箱),起订量,生产周期(天),生产方式,状态";
    private static final Pattern FIELD = Pattern.compile("(?:^|,)(?:\"((?:[^\"]|\"\")*)\"|([^,\"]*))(?=,|$)");
    private final ProductMapper db;
    private final ProductService products;

    public ProductCsvService(ProductMapper db, ProductService products) {
        this.db = db;
        this.products = products;
    }

    @Transactional
    public Object upload(String csv) {
        String[] lines = csv.replaceFirst("^\uFEFF", "").split("\\R");
        if (!fields(lines[0]).equals(fields(HEADER))) throw new ImportError(1);
        int created = 0;
        int updated = 0;
        for (int i = 1; i < lines.length; i++) {
            if (lines[i].isBlank()) continue;
            try {
                var f = fields(lines[i]);
                if (f.size() != 13) throw new IllegalArgumentException();
                var category = ProductService.required(db.rows("SELECT id FROM crm_product_categories WHERE name=?",f.get(2)));
                var existing = db.rows("SELECT id FROM crm_products WHERE code=?",f.get(0));
                Long id = existing.isEmpty() ? null : ((Number)existing.get(0).get("id")).longValue();
                int factor = Integer.parseInt(f.get(6));
                var units = List.of(new ProductForm.Unit(f.get(5),1),new ProductForm.Unit("箱",factor));
                var prices = new ProductForm.Prices(new BigDecimal(f.get(7)),
                        f.get(8).isBlank() ? null : new BigDecimal(f.get(8)),null,null);
                products.save(id,new ProductForm(f.get(0),f.get(1),((Number)category.get("id")).longValue(),
                        f.get(3),Map.of("description",f.get(4)),units,"箱",prices,null,Integer.parseInt(f.get(9)),
                        Integer.parseInt(f.get(10)),f.get(11),false,null,f.get(12),null),true,false);
                if (id == null) created++; else updated++;
            } catch (IllegalArgumentException | org.springframework.dao.DataAccessException |
                     org.springframework.web.server.ResponseStatusException e) {
                throw new ImportError(i + 1);
            }
        }
        return Map.of("created",created,"updated",updated,"failed",0,"errors",List.of());
    }

    public String export(String keyword,Long category,String brand,String status,String mode) {
        var csv = new StringBuilder("\uFEFF物料编码,产品名称,品牌,报价单位,标准价,经销价,可发量,状态\r\n");
        for (var row : products.list(keyword,category,brand,status,mode,false)) {
            var price = (ProductForm.Prices)row.get("prices");
            var values = java.util.Arrays.asList(row.get("code"),row.get("name"),row.get("brand"),row.get("saleUnit"),
                    price.standard(),price.dealer(),row.get("stock"),row.get("status"));
            csv.append(values.stream().map(this::escape).collect(java.util.stream.Collectors.joining(","))).append("\r\n");
        }
        return csv.toString();
    }

    private String escape(Object value) {
        String text = value == null ? "" : value.toString();
        if (text.matches("(?s)^[=+@\\-\\t\\r].*")) text = "'" + text;
        return "\"" + text.replace("\""," \"".trim() + "\"") + "\"";
    }

    private List<String> fields(String line) {
        var values = new ArrayList<String>();
        var matcher = FIELD.matcher(line);
        int end = 0;
        while (matcher.find()) {
            if (matcher.start() != end) return List.of();
            values.add(matcher.group(1) == null ? matcher.group(2) : matcher.group(1).replace("\"\"","\""));
            end = matcher.end();
        }
        return end == line.length() ? values : List.of();
    }

    public static class ImportError extends RuntimeException {
        public final int row;

        public ImportError(int row) {
            this.row = row;
        }
    }
}
