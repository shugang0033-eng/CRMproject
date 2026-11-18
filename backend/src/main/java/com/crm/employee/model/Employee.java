package com.crm.employee.model;

import java.time.LocalDate;

public record Employee(Long id, String employeeNo, String username, String name,
                       Long departmentId, String departmentName, String phone, String email,
                       LocalDate hireDate, String status, String roleNames) {
}
