package com.crm.order.controller;

import com.crm.analytics.AnalyticsWorkbook;
import com.crm.order.service.BillingService;
import com.crm.order.service.FulfillmentService;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.util.List;

@RestController
@RequestMapping("/api")
public class OrderFlowController {
    private final BillingService billing;
    private final FulfillmentService fulfillment;

    public OrderFlowController(BillingService billing,FulfillmentService fulfillment) {
        this.billing=billing;
        this.fulfillment=fulfillment;
    }

    @GetMapping("/statements/{id}")
    public Object statement(@SessionAttribute(required=false) Long employeeId,@PathVariable long id) {
        return billing.statement(employeeId,id);
    }

    @PostMapping("/statements")
    @ResponseStatus(HttpStatus.CREATED)
    public Object generate(@SessionAttribute(required=false) Long employeeId,@RequestBody Statement form) {
        return billing.generate(employeeId,form.customerId(),form.period());
    }

    @PostMapping("/statements/{id}/confirm")
    public Object confirm(@SessionAttribute(required=false) Long employeeId,@PathVariable long id) {
        return billing.confirm(employeeId,id);
    }

    @GetMapping("/statements/{id}/export")
    public ResponseEntity<byte[]> export(@SessionAttribute(required=false) Long employeeId,@PathVariable long id) throws IOException {
        return ResponseEntity.ok().contentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
            .header(HttpHeaders.CONTENT_DISPOSITION,"attachment; filename=statement-"+id+".xlsx")
            .body(AnalyticsWorkbook.write(billing.statement(employeeId,id)));
    }

    @PostMapping("/invoices")
    @ResponseStatus(HttpStatus.CREATED)
    public Object invoice(@SessionAttribute(required=false) Long employeeId,@RequestBody BillingService.Invoice form) {
        return billing.invoice(employeeId,form);
    }

    @PostMapping("/invoices/{id}/issue")
    public Object issue(@SessionAttribute(required=false) Long employeeId,@PathVariable long id,@RequestBody Issue form) {
        return billing.issue(employeeId,id,form.no());
    }

    @PostMapping("/invoices/{id}/red-flush")
    @ResponseStatus(HttpStatus.CREATED)
    public Object red(@SessionAttribute(required=false) Long employeeId,@PathVariable long id,@RequestBody Reason form) {
        return billing.red(employeeId,id,form.reason());
    }

    @GetMapping("/receipts/{id}")
    public Object receiptDetail(@SessionAttribute(required=false) Long employeeId,@PathVariable long id) {
        return billing.receiptDetail(employeeId,id);
    }

    @PostMapping("/receipts")
    @ResponseStatus(HttpStatus.CREATED)
    public Object receipt(@SessionAttribute(required=false) Long employeeId,@RequestBody BillingService.Receipt form) {
        return billing.receipt(employeeId,form);
    }

    @PostMapping("/receipts/{id}/allocate")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void allocate(@SessionAttribute(required=false) Long employeeId,@PathVariable long id,@RequestBody AllocationBatch form) {
        billing.allocate(employeeId,id,form.allocations(),form.requestId());
    }

    @PostMapping("/receipts/{id}/revoke-allocation")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void revoke(@SessionAttribute(required=false) Long employeeId,@PathVariable long id,@RequestBody Revoke form) {
        billing.revoke(employeeId,id,form.allocationId(),form.reason());
    }

    @PostMapping("/orders/{id}/shipments")
    @ResponseStatus(HttpStatus.CREATED)
    public Object ship(@SessionAttribute(required=false) Long employeeId,@PathVariable long id,@RequestBody FulfillmentService.Shipment form) {
        return fulfillment.ship(employeeId,id,form);
    }

    @PostMapping("/shipments/{id}/sign")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void sign(@SessionAttribute(required=false) Long employeeId,@PathVariable long id) {
        fulfillment.sign(employeeId,id);
    }

    @GetMapping("/shipments/{id}/tracking")
    public Object tracking(@SessionAttribute(required=false) Long employeeId,@PathVariable long id) {
        return fulfillment.tracking(employeeId,id);
    }

    @PostMapping("/returns")
    @ResponseStatus(HttpStatus.CREATED)
    public Object requestReturn(@SessionAttribute(required=false) Long employeeId,@RequestBody FulfillmentService.ReturnForm form) {
        return fulfillment.requestReturn(employeeId,form);
    }

    @PostMapping("/returns/{id}/confirm")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void confirmReturn(@SessionAttribute(required=false) Long employeeId,@PathVariable long id,@RequestBody ReturnDecision form) {
        fulfillment.confirmReturn(employeeId,id,form.result(),form.restock(),form.reason());
    }

    @ExceptionHandler(DuplicateKeyException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public void duplicate() {}

    public record Statement(long customerId,String period) {}
    public record Issue(String no) {}
    public record Reason(String reason) {}
    public record AllocationBatch(List<BillingService.Allocation> allocations,String requestId) {}
    public record Revoke(long allocationId,String reason) {}
    public record ReturnDecision(String result,boolean restock,String reason) {}
}
