package com.crm.role.model;

import java.util.List;

public record Role(Long id, String name, String code, String description,
                   boolean builtin, long members, List<String> permissionCodes) {
    public Role(Long id, String name, String code, String description, boolean builtin, long members) {
        this(id, name, code, description, builtin, members, List.of());
    }
}

