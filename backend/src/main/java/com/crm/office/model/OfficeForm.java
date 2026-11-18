package com.crm.office.model;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record OfficeForm(String requestId,String type,BigDecimal amount,String purpose,LocalDate dueDate,
    LocalDate start,LocalDate end,String reason,Long handoverId,String projectName,LocalDate applyDate,
    String remark,List<Item> items,Trip trip,Deduct deduct,List<Attachment> attachments) {
    public record Item(LocalDate date,String type,BigDecimal amount,String note,int bills) {}
    public record Trip(String from,String to,LocalDate start,LocalDate end) {}
    public record Deduct(long loanId,BigDecimal amount) {}
    public record Attachment(String name,String fileId) {}
}
