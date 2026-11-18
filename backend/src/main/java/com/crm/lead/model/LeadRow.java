package com.crm.lead.model;

import java.time.LocalDateTime;

public record LeadRow(String id, String company, String contact, String phone, String source,
                      String industry, String level, String status, Long ownerId, String owner,
                      String region, String reason, LocalDateTime createdAt, boolean inPool) {}

