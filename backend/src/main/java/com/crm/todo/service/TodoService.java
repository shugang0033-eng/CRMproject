package com.crm.todo.service;

import com.crm.auth.service.AuthService;
import com.crm.customer.service.CustomerBoardService;
import com.crm.lead.service.LeadService;
import com.crm.office.service.OfficeService;
import com.crm.order.service.OrderQueryService;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class TodoService {
    private final AuthService auth;
    private final OfficeService office;
    private final OrderQueryService orders;
    private final CustomerBoardService follow;
    private final LeadService leads;

    public TodoService(AuthService auth,OfficeService office,OrderQueryService orders,
                       CustomerBoardService follow,LeadService leads) {
        this.auth=auth;
        this.office=office;
        this.orders=orders;
        this.follow=follow;
        this.leads=leads;
    }

    public Map<String,Object> list(Long employee) {
        var p=auth.current(employee).permissions();
        LocalDate today=LocalDate.now();
        var rows=new ArrayList<Item>();
        if (p.contains("approval.view")) {
            for (var r : office.approvalRows(employee,Map.of("box","pending"))) {
                Object id=r.get("docId");
                String kind=value(r,"kind");
                rows.add(item(today,"approval:"+kind+":"+id,"审批","check-circle",value(r,"title"),value(r,"purpose","reason"),
                    value(r,"apply_date","created_at"),null,2,"/finance/approvals",id,
                    Map.of("type","decide","kind",kind,"docId",id,"applicant",value(r,"applicant"))));
            }
        }
        if (p.contains("contract.view")) {
            for (var r : orders.pending(employee,"contracts","待审批")) {
                rows.add(document(today,r,"contract","合同","file","created_at",2,"/orders/contracts",null));
            }
        }
        if (p.contains("order.view")) {
            for (String status : List.of("待发货","部分发货")) {
                for (var r : orders.pending(employee,"orders",status)) {
                    rows.add(document(today,r,"order","发货","box","date",1,"/orders/"+r.get("id"),null));
                }
            }
            for (var r : orders.pending(employee,"returns","待审核")) {
                var action=p.contains("order.approve") ? Map.of("type","confirmReturn","id",r.get("id"),
                    "code",value(r,"code"),"amount",value(r,"amount")) : null;
                rows.add(document(today,r,"return","退货","refresh","date",1,"/orders/returns",action));
            }
        }
        if (p.contains("statement.view")) {
            for (var r : orders.pending(employee,"statements","待确认")) {
                var action=p.contains("statement.confirm") ? Map.of("type","confirmStatement",
                    "id",r.get("id"),"code",value(r,"code")) : null;
                rows.add(document(today,r,"statement","对账","receipt","end_date",3,"/orders/statements",action));
            }
        }
        if (p.contains("followup.board")) {
            for (var r : follow.pendingTasks(employee)) {
                Object id=r.get("id");
                rows.add(item(today,"follow:"+id,"跟进","users",value(r,"customer")+" · "+value(r,"owner"),
                    value(r,"content"),null,value(r,"due"),0,"/customers/"+r.get("customerId"),id,
                    Map.of("type","finishTask","id",id,"customer",value(r,"customer"))));
            }
        }
        if (p.contains("lead.view")) {
            for (var r : leads.list(employee,false)) {
                if (!"pending".equals(r.status()) && !"待联系".equals(r.status())) continue;
                rows.add(item(today,"lead:"+r.id(),"线索","target",r.company(),
                    Objects.toString(r.contact(),"")+" · "+Objects.toString(r.source(),""),
                    Objects.toString(r.createdAt(),""),null,1,"/leads",r.id(),null));
            }
        }
        rows.sort(Comparator.comparing(Item::due).thenComparing(Item::waitDays,Comparator.reverseOrder()).thenComparing(Item::key));
        var counts=rows.stream().collect(Collectors.groupingBy(Item::bucket,Collectors.counting()));
        var byKind=rows.stream().collect(Collectors.groupingBy(Item::kind,Collectors.counting()));
        return Map.of("rows",rows,"total",rows.size(),"overdue",counts.getOrDefault("overdue",0L),
            "today",counts.getOrDefault("today",0L),"week",counts.getOrDefault("week",0L),"byKind",byKind);
    }

    private Item document(LocalDate today,Map<String,Object> r,String prefix,String kind,String icon,
                          String date,int sla,String path,Map<String,?> action) {
        return item(today,prefix+":"+r.get("id"),kind,icon,value(r,"code")+" · "+value(r,"customer"),
            value(r,"reason","owner"),value(r,date,"date"),null,sla,path,r.get("id"),action);
    }

    private Item item(LocalDate today,String key,String kind,String icon,String title,String desc,
                      String since,String deadline,int sla,String path,Object id,Map<String,?> action) {
        LocalDate date=since==null || since.isBlank() ? today : LocalDate.parse(since.substring(0,10));
        LocalDate due=deadline==null || deadline.isBlank() ? date.plusDays(sla) : LocalDate.parse(deadline.substring(0,10));
        long diff=ChronoUnit.DAYS.between(today,due);
        String bucket=diff<0 ? "overdue" : diff==0 ? "today" : diff<=7 ? "week" : "later";
        String dueText=diff<0 ? "已逾期 "+(-diff)+" 天" : diff==0 ? "今天到期" : "还有 "+diff+" 天";
        String tone=diff<0 ? "danger" : diff<=1 ? "warning" : "info";
        return new Item(key,kind,icon,title,desc,due,diff,dueText,bucket,tone,ChronoUnit.DAYS.between(date,today),path,id,action);
    }

    private String value(Map<String,Object> r,String... keys) {
        for (String key : keys) {
            if (r.get(key)!=null) return r.get(key).toString();
        }
        return "";
    }

    public record Item(String key,String kind,String icon,String title,String desc,LocalDate due,long diff,
                       String dueText,String bucket,String tone,long waitDays,String path,Object dbId,Map<String,?> action) {}
}