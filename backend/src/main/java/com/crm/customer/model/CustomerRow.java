package com.crm.customer.model;

public record CustomerRow(Long id, String name, String industry, String level,
                          Long ownerId, String owner, long contacts) {}
