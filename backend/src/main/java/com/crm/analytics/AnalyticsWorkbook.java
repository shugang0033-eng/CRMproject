package com.crm.analytics;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.zip.*;

public final class AnalyticsWorkbook {
    public static byte[] write(Map<String,Object> data) throws IOException {
        var bytes = new ByteArrayOutputStream();
        var sheet = new StringBuilder("<worksheet xmlns='http://schemas.openxmlformats.org/spreadsheetml/2006/main'><sheetData>");
        append(sheet, "", data);
        sheet.append("</sheetData></worksheet>");
        try (var zip = new ZipOutputStream(bytes)) {
            entry(zip,"[Content_Types].xml","""
                <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
                <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
                <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
                <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
                </Types>
                """);
            entry(zip,"_rels/.rels",relationship("officeDocument","xl/workbook.xml"));
            entry(zip,"xl/_rels/workbook.xml.rels",relationship("worksheet","worksheets/sheet1.xml"));
            entry(zip,"xl/workbook.xml","""
                <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
                  <sheets><sheet name="Report" sheetId="1" r:id="rId1"/></sheets>
                </workbook>
                """);
            entry(zip,"xl/worksheets/sheet1.xml",sheet.toString());
        }
        return bytes.toByteArray();
    }

    private static String relationship(String type,String target) {
        return "<Relationships xmlns='http://schemas.openxmlformats.org/package/2006/relationships'>"
            + "<Relationship Id='rId1' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/"
            + type + "' Target='" + target + "'/></Relationships>";
    }

    private static void append(StringBuilder sheet,String path,Object value) {
        if (value instanceof Map<?,?> map) {
            map.forEach((key,item) -> append(sheet,path.isEmpty() ? key.toString() : path+"."+key,item));
        } else if (value instanceof Iterable<?> rows) {
            int i=0;
            for (Object row : rows) append(sheet,path+"["+(++i)+"]",row);
        } else {
            sheet.append("<row>").append(cell(path));
            if (value instanceof Number) sheet.append("<c><v>").append(value).append("</v></c>");
            else sheet.append(cell(value == null ? "" : value.toString()));
            sheet.append("</row>");
        }
    }

    private static String cell(String value) {
        return "<c t='inlineStr'><is><t xml:space='preserve'>"
            + value.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")
            + "</t></is></c>";
    }

    private static void entry(ZipOutputStream zip,String path,String data) throws IOException {
        zip.putNextEntry(new ZipEntry(path));
        zip.write(data.getBytes(StandardCharsets.UTF_8));
        zip.closeEntry();
    }
}

