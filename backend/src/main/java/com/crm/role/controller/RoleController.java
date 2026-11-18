package com.crm.role.controller;

import com.crm.role.model.Role;
import com.crm.role.model.RoleForm;
import com.crm.role.service.RoleService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api")
public class RoleController {
    private final RoleService service;

    public RoleController(RoleService service) {
        this.service = service;
    }

    @GetMapping("/roles")
    public List<Role> list() {
        return service.list();
    }

    @PostMapping("/roles")
    @ResponseStatus(HttpStatus.CREATED)
    public void create(@RequestBody RoleForm form) {
        service.save(null, form);
    }

    @PutMapping("/roles/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void update(@PathVariable long id, @RequestBody RoleForm form) {
        service.save(id, form);
    }

    @DeleteMapping("/roles/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable long id) {
        service.delete(id);
    }

    @GetMapping("/employees/{id}/roles")
    public List<Long> employeeRoles(@PathVariable long id) {
        return service.employeeRoles(id);
    }

    @PutMapping("/employees/{id}/roles")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void assign(@PathVariable long id, @RequestBody Assignment form) {
        service.assign(id, form.roleIds());
    }

    public record Assignment(List<Long> roleIds) {}
}

