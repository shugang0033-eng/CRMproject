package com.crm.analytics;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/analytics")
public class AnalyticsController {
    private final AnalyticsService service;

    public AnalyticsController(AnalyticsService service) {
        this.service = service;
    }

    @GetMapping("/{type}")
    public Object report(@SessionAttribute(required=false) Long employeeId,@PathVariable String type,
            @RequestParam(defaultValue="year") String period,@RequestParam(required=false) Long deptId,
            @RequestParam(required=false) Long ownerId) {
        return service.report(employeeId,type,period,deptId,ownerId);
    }

    @GetMapping("/filters")
    public Object filters(@SessionAttribute(required=false) Long employeeId) {
        return service.filters(employeeId);
    }

    @GetMapping("/export")
    public ResponseEntity<byte[]> export(@SessionAttribute(required=false) Long employeeId,@RequestParam String type,
            @RequestParam(defaultValue="year") String period,@RequestParam(required=false) Long deptId,
            @RequestParam(required=false) Long ownerId) throws java.io.IOException {
        var data = service.report(employeeId,type,period,deptId,ownerId);
        return ResponseEntity.ok()
            .header("Content-Type","application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
            .header("Content-Disposition","attachment; filename="+type+".xlsx")
            .body(AnalyticsWorkbook.write(data));
    }
}
