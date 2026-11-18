package com.crm.product.model;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

public record ProductForm(String code, String name, Long categoryId, String brand,
                          Map<String, Object> specs, List<Unit> units, String saleUnit,
                          Prices prices, List<Tier> tiers, int moq, int productionDays,
                          String mode, boolean customizable, String stock, String status, String remark) {
    public record Unit(String name, int factor) {}
    public record Tier(int min, BigDecimal price) {}
    public record Prices(BigDecimal standard, BigDecimal dealer, BigDecimal cost, List<Tier> tiers) {}
}
