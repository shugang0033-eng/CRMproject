package com.crm.order.controller;

import com.crm.order.service.OrderQueryService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class OrderQueryController {
    private final OrderQueryService orders;

    public OrderQueryController(OrderQueryService orders) {
        this.orders = orders;
    }

    @GetMapping("/orders/export")
    public org.springframework.http.ResponseEntity<byte[]> export(@SessionAttribute Long employeeId,
            @RequestParam(required=false) String status,@RequestParam(required=false) String type,
            @RequestParam(required=false) Long customerId,@RequestParam(required=false) Long ownerId,
            @RequestParam(required=false) String period) throws java.io.IOException {
        var first=orders.list(employeeId,"orders",status,type,customerId,ownerId,period,null,null,null,1,500);
        var rows=new java.util.ArrayList<java.util.Map<String,Object>>();
        rows.addAll((java.util.List<java.util.Map<String,Object>>)first.get("rows"));
        long total=((Number)first.get("total")).longValue();
        for(int page=2;rows.size()<total;page++) {
            var next=orders.list(employeeId,"orders",status,type,customerId,ownerId,period,null,null,null,page,500);
            rows.addAll((java.util.List<java.util.Map<String,Object>>)next.get("rows"));
        }
        return org.springframework.http.ResponseEntity.ok()
            .header("Content-Type","application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
            .header("Content-Disposition","attachment; filename=orders.xlsx")
            .body(com.crm.analytics.AnalyticsWorkbook.write(java.util.Map.of("orders",rows)));
    }

    @GetMapping("/{resource:orders|contracts|invoices|receipts|statements|shipments|returns}")
    public Object list(@SessionAttribute(required=false) Long employeeId,@PathVariable String resource,
                       @RequestParam(required=false) String status,@RequestParam(required=false) String type,
                       @RequestParam(required=false) Long customerId,@RequestParam(required=false) Long ownerId,
                       @RequestParam(required=false) String period,@RequestParam(required=false) Long orderId,
                       @RequestParam(required=false) Long contractId,@RequestParam(required=false) String keyword,
                       @RequestParam(defaultValue="1") int page,@RequestParam(defaultValue="20") int pageSize) {
        return orders.list(employeeId,resource,status,type,customerId,ownerId,period,orderId,contractId,keyword,page,pageSize);
    }
}

