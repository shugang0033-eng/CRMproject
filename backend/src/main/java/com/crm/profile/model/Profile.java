package com.crm.profile.model;

import java.time.LocalDate;
import java.time.LocalDateTime;

public record Profile(Long id, String account, String employeeNo, String name, String dept,
                      Long deptId, String role, String roleCode, String phone, String email,
                      String avatar, LocalDate hireDate, String status, LocalDateTime lastLoginAt,
                      String lastLoginIp, LocalDateTime passwordUpdatedAt, boolean mustChangePassword) {}
