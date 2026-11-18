package com.crm.department.model;

public record DepartmentForm(String name, Long parentId, Long leaderId, Integer sortOrder) {
}
