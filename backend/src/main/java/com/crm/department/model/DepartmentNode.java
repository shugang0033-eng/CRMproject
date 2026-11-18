package com.crm.department.model;

import java.util.ArrayList;
import java.util.List;

public record DepartmentNode(Long id, Long parentId, String name, int sortOrder,
                             Long leaderId, String leader, long count, List<DepartmentNode> children) {
    public DepartmentNode(Long id, Long parentId, String name, int sortOrder,
                          Long leaderId, String leader, long count) {
        this(id, parentId, name, sortOrder, leaderId, leader, count, new ArrayList<>());
    }
}
