package com.crm.order.controller;

import com.crm.order.service.ContractService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/contracts")
public class ContractController {
    private final ContractService contracts;

    public ContractController(ContractService contracts) {
        this.contracts = contracts;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Object create(@SessionAttribute(required=false) Long employeeId,@RequestBody ContractService.Form form) {
        return contracts.create(employeeId,form);
    }

    @GetMapping("/{id}")
    public Object detail(@SessionAttribute(required=false) Long employeeId,@PathVariable long id) {
        return contracts.detail(employeeId,id);
    }

    @PostMapping("/{id}/approve")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void approve(@SessionAttribute(required=false) Long employeeId,@PathVariable long id,@RequestBody Decision form) {
        contracts.approve(employeeId,id,form.result(),form.note());
    }

    public record Decision(String result,String note) {}
}
