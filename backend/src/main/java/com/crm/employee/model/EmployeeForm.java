package com.crm.employee.model;

import java.time.LocalDate;

public record EmployeeForm(String username, String name, Long departmentId,
                           String phone, String email, LocalDate hireDate, String status) {
}
