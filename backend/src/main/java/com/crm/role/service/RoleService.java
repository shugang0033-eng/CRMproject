package com.crm.role.service;

import com.crm.role.mapper.RoleMapper;
import com.crm.role.model.Role;
import com.crm.role.model.RoleForm;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.ArrayList;

@Service
public class RoleService {
    private final RoleMapper mapper;

    public RoleService(RoleMapper mapper) {
        this.mapper = mapper;
    }

    @Transactional(readOnly = true)
    public List<Role> list() {
        List<Role> roles = mapper.findAll();
        Map<Long, List<String>> codesByRole = new HashMap<>();
        for (var permission : mapper.findPermissions()) {
            codesByRole.computeIfAbsent(permission.roleId(), id -> new ArrayList<>()).add(permission.code());
        }
        return roles.stream().map(role -> new Role(role.id(), role.name(), role.code(), role.description(),
                role.builtin(), role.members(), codesByRole.getOrDefault(role.id(), List.of()))).toList();
    }

    @Transactional
    public void save(Long id, RoleForm form) {
        if (form.name() == null || form.name().isBlank() || form.name().length() > 100
                || form.perms() == null || form.perms().isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Name and permissions are required");
        }
        if (id == null) {
            if (form.code() == null || !form.code().matches("[A-Za-z0-9_-]{1,64}")) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid role code");
            }
            try {
                mapper.insert(form);
            } catch (DuplicateKeyException e) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "Role code already exists");
            }
            id = mapper.findId(form.code());
        } else if (mapper.update(id, form) == 0) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Role not found");
        }

        mapper.clearPermissions(id);
        for (String code : form.perms().stream().distinct().toList()) {
            if (mapper.addPermission(id, code) == 0) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unknown permission");
            }
        }
    }

    @Transactional
    public void delete(long id) {
        Boolean builtin = mapper.lockBuiltinFlag(id);
        if (builtin == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Role not found");
        }
        if (builtin || mapper.hasMembers(id)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Role is built-in or still has members");
        }
        mapper.delete(id);
    }

    public List<Long> employeeRoles(long id) {
        return mapper.employeeRoles(id);
    }

    @Transactional
    public void assign(long id, List<Long> roleIds) {
        if (roleIds == null || roleIds.contains(null)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Provide roleIds");
        }
        if (mapper.lockEmployee(id) == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Employee not found");
        }
        mapper.clearEmployeeRoles(id);
        for (long roleId : roleIds.stream().distinct().toList()) {
            if (mapper.addEmployeeRole(id, roleId) == 0) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unknown role");
            }
        }
    }
}


