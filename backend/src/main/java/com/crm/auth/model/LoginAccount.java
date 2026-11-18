package com.crm.auth.model;

public record LoginAccount(Long id, String account, String name, String dept, String passwordHash) {}
