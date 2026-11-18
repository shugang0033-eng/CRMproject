package com.crm.product.mapper;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;

@Repository
public class ProductMapper {
    private final JdbcTemplate jdbc;
    private final ObjectMapper json;

    public ProductMapper(JdbcTemplate jdbc, ObjectMapper json) {
        this.jdbc = jdbc;
        this.json = json;
    }

    public List<Map<String, Object>> rows(String sql, Object... args) {
        return jdbc.queryForList(sql, args);
    }

    public int write(String sql, Object... args) {
        return jdbc.update(sql, args);
    }

    public String encode(Object data) {
        try {
            return json.writeValueAsString(data);
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException(e);
        }
    }

    public Object decode(Object data) {
        if (data == null) return null;
        try {
            return json.readValue(data.toString(), Object.class);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException(e);
        }
    }
}
