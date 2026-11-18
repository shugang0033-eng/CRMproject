package com.crm.auth.model;

import java.util.List;

public record SessionUser(Long id, String account, String name, String dept,
                          String role, List<String> permissions) {}
