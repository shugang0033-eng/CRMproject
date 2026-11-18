package com.crm.employee.service;

import com.crm.department.mapper.DepartmentMapper;
import com.crm.auth.service.EmployeePasswords;
import com.crm.employee.mapper.EmployeeMapper;
import com.crm.employee.model.Employee;
import com.crm.employee.model.EmployeeForm;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class EmployeeService {
    private final EmployeeMapper mapper;
    private final DepartmentMapper departments;
    private final EmployeePasswords passwords;

    public EmployeeService(EmployeeMapper mapper, DepartmentMapper departments, EmployeePasswords passwords) {
        this.mapper = mapper;
        this.departments = departments;
        this.passwords = passwords;
    }

    public List<Employee> list(String keyword, Long departmentId, String status) {
        return mapper.findAll(keyword, departmentId, status);
    }

    public Employee detail(long id) {
        Employee employee = mapper.findById(id);
        if (employee == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "员工不存在");
        }
        return employee;
    }

    public long create(EmployeeForm form) {
        validate(form);
        Map<String, Object> employee = new HashMap<>();
        employee.put("form", form);
        employee.put("passwordHash", passwords.initialHash());
        employee.put("employeeNo", "E" + UUID.randomUUID().toString().replace("-", "").substring(0, 16));
        try {
            mapper.insert(employee);
        } catch (DuplicateKeyException e) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "登录账号或工号已存在");
        }
        return ((Number) employee.get("id")).longValue();
    }

    public void update(long id, EmployeeForm form) {
        validate(form);
        try {
            checkUpdated(mapper.update(id, form));
        } catch (DuplicateKeyException e) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "登录账号已存在");
        }
    }

    public void moveDepartment(long id,Long departmentId) {
        if (departmentId == null || !departments.exists(departmentId)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"请选择已有部门");
        }
        checkUpdated(mapper.updateDepartment(id,departmentId));
    }

    public void setStatus(long id, String status) {
        if (!"active".equals(status) && !"disabled".equals(status)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "请选择有效的员工状态");
        }
        checkUpdated(mapper.updateStatus(id, status));
    }

    public void delete(long id) {
        checkUpdated(mapper.softDelete(id));
    }

    private void validate(EmployeeForm form) {
        if (form.username() == null || !form.username().matches("[A-Za-z0-9]{1,64}")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "登录账号须为 1 至 64 位字母或数字");
        }
        if (form.name() == null || form.name().isBlank() || form.name().length() > 100) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "请输入 1 至 100 字的姓名");
        }
        if (form.phone() != null && !form.phone().isBlank() && !form.phone().matches("1[3-9][0-9]{9}")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"请输入有效的11位手机号");
        }
        if (form.email() != null && !form.email().isBlank()
                && (form.email().length()>254 || !form.email().matches("[A-Za-z0-9_%+.-]+@[A-Za-z0-9-]+(?:[.][A-Za-z0-9-]+)*[.][A-Za-z]{2,}"))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"请输入有效的邮箱地址");
        }
        if (form.departmentId() == null || !departments.exists(form.departmentId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "请选择已有部门");
        }
        if (form.status() != null && !"active".equals(form.status()) && !"disabled".equals(form.status())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "请选择有效的员工状态");
        }
    }

    private void checkUpdated(int rows) {
        if (rows == 0) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "员工不存在");
        }
    }
}

