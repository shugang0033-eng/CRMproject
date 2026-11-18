package com.crm.lead.model;

public record LeadConflict(String leadId, String leadName, String type, String code,
                           String name, String owner, Long ownerId, String status, String detail) {}
