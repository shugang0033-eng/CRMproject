package com.crm.office.controller;

import com.crm.analytics.AnalyticsWorkbook;
import com.crm.office.model.OfficeForm;
import com.crm.office.service.OfficeService;
import com.crm.office.service.OfficeService.Kind;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.*;
import org.springframework.dao.DuplicateKeyException;

import java.io.IOException;
import java.math.BigDecimal;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class OfficeController {
    private final OfficeService office;

    public OfficeController(OfficeService office) {
        this.office=office;
    }

    @GetMapping("/{kind:expenses|loans|leaves}")
    public Object list(@SessionAttribute(required=false) Long employeeId,@PathVariable String kind,
                       @RequestParam Map<String,String> query) {
        return office.list(employeeId,Kind.of(kind),query);
    }

    @GetMapping("/{kind:expenses|loans|leaves}/{id}")
    public Object detail(@SessionAttribute(required=false) Long employeeId,@PathVariable String kind,@PathVariable long id) {
        return office.detail(employeeId,Kind.of(kind),id);
    }

    @PostMapping("/{kind:expenses|loans|leaves}")
    public Object create(@SessionAttribute(required=false) Long employeeId,@PathVariable String kind,@RequestBody OfficeForm form) {
        return office.create(employeeId,Kind.of(kind),form);
    }

    @PostMapping("/{kind:expenses|loans|leaves}/{id}/approve")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void approve(@SessionAttribute(required=false) Long employeeId,@PathVariable String kind,
                        @PathVariable long id,@RequestBody Decision decision) {
        office.decide(employeeId,Kind.of(kind),id,decision.result(),decision.note());
    }

    @PostMapping("/expenses/{id}/withdraw")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void withdraw(@SessionAttribute(required=false) Long employeeId,@PathVariable long id) {
        office.withdraw(employeeId,Kind.EXPENSE,id);
    }

    @PostMapping("/leaves/{id}/revoke")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void revoke(@SessionAttribute(required=false) Long employeeId,@PathVariable long id) {
        office.withdraw(employeeId,Kind.LEAVE,id);
    }

    @GetMapping("/loans/open")
    public Object open(@SessionAttribute(required=false) Long employeeId,@RequestParam(required=false) Long applicantId) {
        return office.open(employeeId,applicantId);
    }

    @PostMapping("/loans/{id}/write-off")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void writeOff(@SessionAttribute(required=false) Long employeeId,@PathVariable long id,@RequestBody WriteOff form) {
        office.writeOff(employeeId,id,form.amount(),form.source(),form.note(),form.requestId());
    }

    @GetMapping("/leaves/quota")
    public Object quota(@SessionAttribute(required=false) Long employeeId,@RequestParam(required=false) Long applicantId,
                        @RequestParam(required=false) Integer year) {
        return office.quota(employeeId,applicantId,year);
    }

    @GetMapping("/approvals")
    public Object approvals(@SessionAttribute(required=false) Long employeeId,@RequestParam Map<String,String> query) {
        return office.approvals(employeeId,query);
    }

    @PostMapping("/approvals/decide")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void decide(@SessionAttribute(required=false) Long employeeId,@RequestBody Decision form) {
        office.decide(employeeId,Kind.of(form.kind()),form.docId(),form.result(),form.note());
    }

    @GetMapping("/approvals/{kind}/{id}/history")
    public Object history(@SessionAttribute(required=false) Long employeeId,@PathVariable String kind,@PathVariable long id) {
        return office.history(employeeId,Kind.of(kind),id);
    }

    @GetMapping("/{kind:expenses|loans}/export")
    public ResponseEntity<byte[]> export(@SessionAttribute(required=false) Long employeeId,
            @PathVariable String kind,@RequestParam Map<String,String> query) throws IOException {
        query.put("page","1");
        query.put("pageSize","500");
        return ResponseEntity.ok().header("Content-Disposition","attachment; filename="+kind+".xlsx")
            .header("Content-Type","application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
            .body(AnalyticsWorkbook.write(office.list(employeeId,Kind.of(kind),query)));
    }

    @ExceptionHandler(OfficeService.LeaveError.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Object leaveError(OfficeService.LeaveError error) {
        return Map.of("code",error.code,"field",error.field,"message",error.getMessage());
    }

    @ExceptionHandler(DuplicateKeyException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public void duplicate() {}

    public record Decision(String kind,long docId,String result,String note) {}
    public record WriteOff(BigDecimal amount,String source,String note,String requestId) {}
}

