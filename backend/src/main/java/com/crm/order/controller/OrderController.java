package com.crm.order.controller;

import com.crm.order.service.OrderWriteService;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.HttpStatus;

import java.util.List;

@RestController
@RequestMapping("/api/orders")
public class OrderController {
    private final OrderWriteService orders;

    public OrderController(OrderWriteService orders) {
        this.orders = orders;
    }

    @GetMapping("/{id}")
    public Object detail(@SessionAttribute(required=false) Long employeeId, @PathVariable long id) {
        return orders.detail(employeeId, id);
    }

    @GetMapping("/credit")
    public Object credit(@SessionAttribute(required=false) Long employeeId,@RequestParam long customerId,
                         @RequestParam(defaultValue="0") java.math.BigDecimal amount) {
        return orders.credit(employeeId,customerId,amount);
    }

    @PostMapping("/quote")
    public Object quote(@SessionAttribute(required=false) Long employeeId,@RequestBody OrderWriteService.Form form) {
        return orders.quote(employeeId,form);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Object create(@SessionAttribute(required=false) Long employeeId, @RequestBody OrderWriteService.Form form) {
        return orders.create(employeeId, form);
    }

    @PostMapping("/{id}/approve")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void approve(@SessionAttribute(required=false) Long employeeId, @PathVariable long id, @RequestBody Decision form) {
        orders.approve(employeeId, id, form.result());
    }

    public record Decision(String result) {}
}

