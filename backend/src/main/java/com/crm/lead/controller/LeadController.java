package com.crm.lead.controller;

import com.crm.lead.model.Assignee;
import com.crm.lead.model.LeadMove;
import com.crm.lead.model.LeadForm;
import com.crm.lead.model.LeadRow;
import com.crm.lead.service.LeadService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/leads")
public class LeadController {
    private final LeadService service;

    public LeadController(LeadService service) {
        this.service = service;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String,String> create(@SessionAttribute(required = false) Long employeeId, @RequestBody LeadForm form) {
        return Map.of("id", service.create(employeeId, form));
    }

    @GetMapping
    public List<LeadRow> list(@SessionAttribute(required = false) Long employeeId,
                              @RequestParam(defaultValue = "false") boolean pool) {
        return service.list(employeeId, pool);
    }

    @GetMapping("/assignees")
    public List<Assignee> assignees(@SessionAttribute(required = false) Long employeeId,
                                    @RequestParam(defaultValue = "") String keyword) {
        return service.assignees(employeeId, keyword);
    }

    @PostMapping("/{id}/transfer")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void transfer(@SessionAttribute(required = false) Long employeeId, @PathVariable String id,
                         @RequestBody LeadMove form) {
        service.move(employeeId, List.of(id), form, false);
    }

    @PostMapping("/transfer")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void transferBatch(@SessionAttribute(required = false) Long employeeId, @RequestBody LeadMove form) {
        service.move(employeeId, form.ids(), form, false);
    }

    @PostMapping("/conflicts")
    public Map<String, ?> conflicts(@SessionAttribute(required = false) Long employeeId,
                                    @RequestBody LeadMove form) {
        return Map.of("items", service.conflicts(employeeId, form));
    }

    @PostMapping("/assign")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void assign(@SessionAttribute(required = false) Long employeeId, @RequestBody LeadMove form) {
        service.move(employeeId, form.ids(), form, true);
    }
}


