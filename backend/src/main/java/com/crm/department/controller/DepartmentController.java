package com.crm.department.controller;

import com.crm.department.model.DepartmentForm;
import com.crm.department.model.DepartmentNode;
import com.crm.department.model.LeaderOption;
import com.crm.department.service.DepartmentService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/departments")
public class DepartmentController {
    private final DepartmentService service;

    public DepartmentController(DepartmentService service) {
        this.service = service;
    }

    @GetMapping
    public List<DepartmentNode> tree() {
        return service.tree();
    }

    @GetMapping("/leader-options")
    public List<LeaderOption> leaderOptions() {
        return service.leaderOptions();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Long> create(@RequestBody DepartmentForm form) {
        return Map.of("id", service.create(form));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable long id) {
        service.delete(id);
    }

    @PutMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void update(@PathVariable long id, @RequestBody DepartmentForm form) {
        service.update(id, form);
    }
}

