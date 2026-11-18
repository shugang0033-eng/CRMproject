package com.crm.role.model;

import java.util.List;

public record RoleForm(String name, String code, String desc, List<String> perms) {}
