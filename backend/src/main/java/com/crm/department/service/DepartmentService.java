package com.crm.department.service;

import com.crm.department.mapper.DepartmentMapper;
import com.crm.department.model.DepartmentForm;
import com.crm.department.model.DepartmentNode;
import com.crm.department.model.LeaderOption;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class DepartmentService {
    private final DepartmentMapper mapper;

    public DepartmentService(DepartmentMapper mapper) {
        this.mapper = mapper;
    }

    public List<DepartmentNode> tree() {
        List<DepartmentNode> departments = mapper.findAll();
        Map<Long, DepartmentNode> byId = new HashMap<>();
        departments.forEach(department -> byId.put(department.id(), department));

        List<DepartmentNode> roots = new ArrayList<>();
        for (DepartmentNode department : departments) {
            if (department.parentId() == null) {
                roots.add(department);
            } else {
                byId.get(department.parentId()).children().add(department);
            }
        }
        return roots;
    }

    public List<LeaderOption> leaderOptions() {
        return mapper.findLeaderOptions();
    }

    @Transactional
    public long create(DepartmentForm form) {
        validate(form);
        if (form.parentId() != null && !mapper.exists(form.parentId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Parent department does not exist");
        }

        Map<String, Object> department = new HashMap<>();
        department.put("name", form.name().strip());
        department.put("parentId", form.parentId());
        department.put("sortOrder", form.sortOrder() == null ? 0 : form.sortOrder());
        mapper.insert(department);
        long id = ((Number) department.get("id")).longValue();
        if (form.leaderId() != null) {
            mapper.insertLeader(id, form.leaderId());
        }
        return id;
    }

    @Transactional
    public void update(long id, DepartmentForm form) {
        if (!mapper.exists(id)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Department does not exist");
        }
        validate(form);
        mapper.update(id, form.name().strip(), form.sortOrder());
        mapper.clearLeader(id);
        if (form.leaderId() != null) {
            mapper.insertLeader(id, form.leaderId());
        }
    }

    public void delete(long id) {
        try {
            if (mapper.delete(id) == 0) {
                throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Department does not exist");
            }
        } catch (DataIntegrityViolationException e) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Department has children or employee records");
        }
    }

    private void validate(DepartmentForm form) {
        if (form.name() == null || form.name().isBlank() || form.name().strip().length() > 100) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Department name must be 1 to 100 characters");
        }
        if (form.leaderId() != null && !mapper.canLead(form.leaderId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Choose an active employee as leader");
        }
    }
}


