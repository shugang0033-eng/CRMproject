package com.crm.common;

import org.springframework.jdbc.core.JdbcTemplate;
import java.time.Year;
import java.util.Locale;

public final class DocCode {
    private DocCode() {}

    // Call within the transaction that inserts the document.
    public static String next(JdbcTemplate db, String prefix, String table) {
        return next(db, prefix, table, "code");
    }

    public static String next(JdbcTemplate db, String prefix, String table, String column) {
        int year = Year.now().getValue();
        String stem = prefix + "-" + year + "-";
        long existing = db.queryForObject(
            "SELECT COALESCE(MAX(CAST(SUBSTRING(" + column + ", ?) AS UNSIGNED)),0) FROM " + table
            + " WHERE " + column + " LIKE ? AND SUBSTRING(" + column + ", ?) REGEXP '^[0-9]+$'",
            Long.class, stem.length()+1, stem+"%", stem.length()+1);
        db.update("""
            INSERT INTO crm_doc_sequences(prefix,year,serial) VALUES(?,?,?)
            ON DUPLICATE KEY UPDATE serial=GREATEST(serial+1,VALUES(serial))
            """,prefix,year,existing+1);
        long number=db.queryForObject("SELECT serial FROM crm_doc_sequences WHERE prefix=? AND year=?",Long.class,prefix,year);
        return stem + String.format(Locale.ROOT,"%04d",number);
    }
}


