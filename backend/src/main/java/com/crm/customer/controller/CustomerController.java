package com.crm.customer.controller;

import com.crm.customer.model.CustomerRow;
import com.crm.customer.model.CustomerContact;
import com.crm.customer.service.CustomerService;
import com.crm.customer.service.CustomerDetailService;
import com.crm.customer.service.CustomerBoardService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api")
public class CustomerController {
    private final CustomerService service;
    private final CustomerDetailService details;
    private final CustomerBoardService board;

    public CustomerController(CustomerService service, CustomerDetailService details, CustomerBoardService board) {
        this.service = service;
        this.details = details;
        this.board = board;
    }

    @PostMapping("/customers")
    @ResponseStatus(HttpStatus.CREATED)
    public Object create(@SessionAttribute(required=false) Long employeeId,@RequestBody CustomerDetailService.Create form) {
        return details.create(employeeId,form);
    }

    @ExceptionHandler(CustomerDetailService.DuplicateCustomer.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public Object duplicateCustomer(CustomerDetailService.DuplicateCustomer error) {
        return java.util.Map.of("duplicates",error.duplicates);
    }

    @GetMapping("/customers")
    public Object list(@SessionAttribute(required = false) Long employeeId) {
        return service.list(employeeId);
    }

    @GetMapping({"/contacts", "/customers/contacts"})
    public List<CustomerContact> contacts(@SessionAttribute(required = false) Long employeeId) {
        return service.contacts(employeeId);
    }

    @PostMapping("/leads/{id}/convert")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void convert(@SessionAttribute(required = false) Long employeeId, @PathVariable String id) {
        service.convert(employeeId, id);
    }

    @PostMapping("/customers/transfer")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void transfer(@SessionAttribute(required = false) Long employeeId, @RequestBody Transfer form) {
        service.transfer(employeeId, form.ids(), form.ownerId(), form.reason());
    }

    @GetMapping("/customers/{id}")
    public Object detail(@SessionAttribute(required=false) Long employeeId,@PathVariable long id) {
        return details.detail(employeeId,id);
    }

    @PatchMapping("/customers/{id}")
    public Object update(@SessionAttribute(required=false) Long employeeId,@PathVariable long id,
                         @RequestBody java.util.Map<String,com.fasterxml.jackson.databind.JsonNode> fields) {
        return details.update(employeeId,id,fields);
    }

    @GetMapping("/customers/{id}/timeline")
    public Object timeline(@SessionAttribute(required=false) Long employeeId,@PathVariable long id,
                           @RequestParam(required=false) String before,@RequestParam(defaultValue="50") int limit) {
        return details.timeline(employeeId,id,before,limit);
    }

    @GetMapping("/customers/{id}/orders")
    public Object orders(@SessionAttribute(required=false) Long employeeId,@PathVariable long id) {
        return details.orders(employeeId,id);
    }

    @PostMapping("/customers/{id}/followups")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void follow(@SessionAttribute(required=false) Long employeeId,@PathVariable long id,
                       @RequestBody CustomerDetailService.Follow form) {
        details.follow(employeeId,id,form);
    }

    @PostMapping("/customers/{id}/contacts")
    @ResponseStatus(HttpStatus.CREATED)
    public void addContact(@SessionAttribute(required=false) Long employeeId,@PathVariable long id,
                           @RequestBody CustomerDetailService.Contact form) {
        details.addContact(employeeId,id,form);
    }

    @PatchMapping("/customers/{id}/contacts/{contactId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void editContact(@SessionAttribute(required=false) Long employeeId,@PathVariable long id,
                            @PathVariable long contactId,@RequestBody CustomerDetailService.Contact form) {
        details.editContact(employeeId,id,contactId,form);
    }

    @PostMapping("/customers/merge")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void merge(@SessionAttribute(required=false) Long employeeId,@RequestBody Merge form) {
        details.merge(employeeId,form.fromId(),form.toId(),form.note());
    }

    @PostMapping("/customers/duplicates/check")
    public Object duplicates(@SessionAttribute(required=false) Long employeeId,@RequestBody Duplicate form) {
        return details.duplicates(employeeId,form.name(),form.phone());
    }

    @GetMapping("/customers/pool")
    public Object pool(@SessionAttribute(required=false) Long employeeId) {
        return board.pool(employeeId);
    }

    @PostMapping("/customers/{id}/claim")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void claim(@SessionAttribute(required=false) Long employeeId,@PathVariable long id) {
        board.claim(employeeId,id);
    }

    @GetMapping("/customers/follow-board")
    public Object board(@SessionAttribute(required=false) Long employeeId,@RequestParam(defaultValue="week") String range,
                        @RequestParam(required=false) Long deptId,@RequestParam(required=false) Long ownerId) {
        return board.board(employeeId,range,deptId,ownerId);
    }

    @PatchMapping("/customers/follow-tasks/{taskId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void task(@SessionAttribute(required=false) Long employeeId,@PathVariable long taskId,
                     @RequestBody CustomerBoardService.Task form) {
        board.update(employeeId,taskId,form);
    }

    public record Merge(long fromId,long toId,String note) {}
    public record Duplicate(String name,String phone) {}
    public record Transfer(List<Long> ids, Long ownerId, String reason) {}
}






