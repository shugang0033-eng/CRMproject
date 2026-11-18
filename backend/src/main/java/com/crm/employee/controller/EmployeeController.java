package com.crm.employee.controller;

import com.crm.auth.service.AuthService;
import org.springframework.web.server.ResponseStatusException;
import com.crm.employee.model.Employee;
import com.crm.employee.model.EmployeeForm;
import com.crm.employee.service.EmployeeService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/employees")
public class EmployeeController {
    private final EmployeeService service;

    private final AuthService auth;

    public EmployeeController(EmployeeService service, AuthService auth) {
        this.auth = auth;
        this.service = service;
    }

    @GetMapping
    public List<Employee> list(@RequestParam(required = false) String keyword,
                               @RequestParam(required = false) Long departmentId,
                               @RequestParam(required = false) String status) {
        return service.list(keyword, departmentId, status);
    }

    @GetMapping("/{id}")
    public Employee detail(@PathVariable long id) {
        return service.detail(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Long> create(@RequestBody EmployeeForm form) {
        return Map.of("id", service.create(form));
    }

    @PutMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void update(@SessionAttribute(required=false) Long employeeId,@PathVariable long id,@RequestBody EmployeeForm form) {
        requireManager(employeeId);
        service.update(id, form);
    }

    @PatchMapping("/{id}/department")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void moveDepartment(@SessionAttribute(required=false) Long employeeId,@PathVariable long id,
                               @RequestBody Map<String,Long> form) {
        requireManager(employeeId);
        service.moveDepartment(id,form.get("departmentId"));
    }

    private void requireManager(Long employeeId) {
        if (employeeId == null) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        if (!auth.current(employeeId).permissions().contains("employee.manage")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN);
        }
    }

    @PatchMapping("/{id}/status")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void setStatus(@PathVariable long id, @RequestBody Map<String, String> form) {
        service.setStatus(id, form.get("status"));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable long id) {
        service.delete(id);
    }
}
