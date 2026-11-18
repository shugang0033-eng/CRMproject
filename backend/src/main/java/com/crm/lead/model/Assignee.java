package com.crm.lead.model;

public record Assignee(Long id, String name, String department, String role, long activeLeads, Integer capacity) {}
