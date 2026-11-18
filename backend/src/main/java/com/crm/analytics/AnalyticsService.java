package com.crm.analytics;

import com.crm.auth.service.AuthService;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.*;

@Service
public class AnalyticsService {
    static final Map<String,String> PERMISSIONS = Map.of(
        "summary","overview","funnel","funnel","customers","customers","performance","performance",
        "payments","payments","products","products","sources","sources");
    private final JdbcTemplate db;
    private final AuthService auth;

    public AnalyticsService(JdbcTemplate db, AuthService auth) {
        this.db = db;
        this.auth = auth;
    }

    public Map<String,Object> report(Long employee, String type, String period, Long dept, Long owner) {
        if (employee == null) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        String permission = PERMISSIONS.get(type);
        if (permission == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        var permissions = auth.current(employee).permissions();
        if (!permissions.contains("data." + permission)) forbidden();
        var people = scope(employee, permissions, dept, owner);
        LocalDate today = LocalDate.now();
        LocalDate start = switch (period) {
            case "month" -> today.withDayOfMonth(1);
            case "quarter" -> today.withMonth((today.getMonthValue()-1)/3*3+1).withDayOfMonth(1);
            case "year" -> today.withDayOfYear(1);
            case "last12" -> today.withDayOfMonth(1).minusMonths(11);
            default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
        };
        boolean company = permissions.contains("data.scope.all") && dept == null && owner == null;
        String ids = people.isEmpty() ? "NULL" : String.join(",",people.stream().map(String::valueOf).toList());
        String leadScope = company ? "1=1" : "owner_id IN (" + ids + ")";
        String customerScope = company ? "1=1" : "owner_id IN (" + ids + ")";
        LocalDate end = today.plusDays(1);
        var leads = Set.of("summary","funnel","sources").contains(type)
                ? db.queryForList("SELECT source,status,DATE(created_at) AS day FROM crm_leads WHERE " + leadScope
                    + " AND created_at >= ? AND created_at < ?",type.equals("summary") ? start.withDayOfMonth(1).isBefore(today.withDayOfMonth(1).minusMonths(11))
                    ? start : today.withDayOfMonth(1).minusMonths(11) : start,end)
                : List.<Map<String,Object>>of();
        var selected = leads.stream().filter(row -> !date(row).isBefore(start)).toList();
        var missing = new ArrayList<String>();
        var result = new LinkedHashMap<String,Object>();
        var reports=new AnalyticsDetails(db,start,end,ids,company);
        switch (type) {
            case "summary" -> {
                var kpis = new LinkedHashMap<String,Object>();
                for (String key : List.of("ytdSigned","ytdReceived","annualTarget","completion","timeProgress","signedDelta",
                        "receivedDelta","customersDelta","ytdDeals","avgDeal","monthSigned","monthSignedDelta","monthDeals")) kpis.put(key,null);
                kpis.put("ytdLeads",selected.size());
                kpis.put("winRate",percent(countStage(selected,4),selected.size()));
                var customers = db.queryForList("SELECT DATE(created_at) AS day FROM crm_customers WHERE "
                        + customerScope + " AND created_at >= ? AND created_at < ?",today.withDayOfMonth(1).minusMonths(11),end);
                kpis.put("ytdCustomers",customers.stream().filter(row -> !date(row).isBefore(start)).count());
                var money = overviewMoney(start,end,today,period,ids,company,dept,owner,permissions.contains("data.scope.dept") || permissions.contains("data.scope.all"));
                kpis.putAll(money.kpis());
                result.put("depts",money.departments());
                result.putAll(Map.of("kpis",kpis,"monthly",months(today).stream().map(m -> Map.of(
                    "month",m.toString(),"label",label(m),"leads",inMonth(leads,m).size(),
                    "customers",inMonth(customers,m).size(),"signed",sumMonth(money.shipments(),m),"received",sumMonth(money.receipts(),m),"deals",0)).toList(),"alerts",List.of()));

            }
            case "funnel" -> {
                var stages = new ArrayList<Map<String,Object>>();
                var keys = List.of("new","contacted","quoted","negotiating","won");
                var labels = List.of("线索接入","已联系","已报价","谈判中","成交");
                long previous = selected.size();
                for (int i=0;i<keys.size();i++) {
                    long count = i==0 ? selected.size() : countStage(selected,i);
                    var stage = new LinkedHashMap<String,Object>();
                    stage.put("key",keys.get(i)); stage.put("label",labels.get(i)); stage.put("count",count);
                    stage.put("fromPrev",percent(count,previous)); stage.put("avgDays",0);
                    stages.add(stage);
                    previous = count;
                }
                result.put("stages",stages);
                result.put("invalid",selected.stream().filter(r -> "invalid".equals(r.get("status"))).count());
                result.put("overallRate",percent(countStage(selected,4),selected.size()));
                result.put("overallRateDelta",null);
                result.put("lossReasons",List.of());
                result.put("bySource",channels(selected).stream().map(source -> {
                    var rows = selected.stream().filter(r -> source.equals(r.get("source"))).toList();
                    return Map.of("source",source,"count",rows.size(),"contacted",countStage(rows,1),"quoted",countStage(rows,2),
                        "negotiating",countStage(rows,3),"won",countStage(rows,4),"rate",percent(countStage(rows,4),rows.size()));
                }).toList());
                result.put("trend",months(today).stream().map(m -> {
                    var rows = inMonth(selected,m);
                    var point = new LinkedHashMap<String,Object>();
                    point.put("label",label(m)); point.put("value",percent(countStage(rows,4),rows.size()));
                    return point;
                }).toList());
                missing.add("漏斗按当前阶段推算，阶段历史和无效原因尚未接入");
            }
            case "customers" -> {
                result.putAll(reports.customers());
                missing.add("历史客户状态快照尚未记录");
            }
            case "performance" -> {
                var money=overviewMoney(start,end,today,period,ids,company,dept,owner,
                    permissions.contains("data.scope.dept") || permissions.contains("data.scope.all"));
                result.putAll(reports.performance(money.departments()));
            }
            case "payments" -> {
                result.putAll(reports.payments());
                missing.add("账龄到期日按开票日加客户账期计算");
            }
            case "products" -> result.putAll(reports.products(permissions.contains("product.cost")));
            case "sources" -> {
                var costs = company && start.getDayOfMonth() == 1 ? db.queryForList("""
                    SELECT channel,SUM(amount) AS cost FROM crm_channel_costs
                    WHERE period_month BETWEEN ? AND ? GROUP BY channel
                    """,YearMonth.from(start).toString(),YearMonth.from(today).toString()) : List.<Map<String,Object>>of();
                var sales=reports.sales();
                var sources = new TreeSet<>(channels(selected));
                sales.forEach(row -> sources.add(row.get("source").toString()));
                costs.forEach(row -> sources.add(row.get("channel").toString()));
                result.put("rows",sources.stream().map(source -> {
                    var rows = selected.stream().filter(r -> source.equals(r.get("source"))).toList();
                    long won = countStage(rows,4);
                    var row = new LinkedHashMap<String,Object>();
                    var cost = costs.stream().filter(c -> source.equals(c.get("channel"))).findFirst()
                        .map(c -> (Number)c.get("cost")).orElse(null);
                    row.put("source",source); row.put("leads",rows.size()); row.put("won",won);
                    row.put("rate",percent(won,rows.size())); row.put("cost",cost);
                    row.put("cac",cost == null || won == 0 ? null : Math.round(cost.doubleValue()/won));
                    double shipped=sales.stream().filter(r -> source.equals(r.get("source"))).mapToDouble(AnalyticsService::amount).sum();
                    row.put("amount",shipped);
                    row.put("roi",cost==null || cost.doubleValue()==0 ? null : Math.round(shipped/cost.doubleValue()*10)/10.0);
                    row.put("avgDeal",won==0 ? null : shipped/won);
                    row.put("cycle",null);
                    return row;
                }).toList());
                result.put("trend",months(today).stream().map(m -> {
                    var row = new LinkedHashMap<String,Object>();
                    row.put("label",label(m));
                    for (String source : sources) row.put(source,inMonth(selected,m).stream().filter(r -> source.equals(r.get("source"))).count());
                    return row;
                }).toList());
                if(!company) missing.add("渠道费用和 ROI 仅在全公司范围显示");
            }
        }
        result.put("unavailable",missing);
        return result;
    }

    private OverviewMoney overviewMoney(LocalDate start,LocalDate end,LocalDate today,String period,
                                        String ids,boolean company,Long dept,Long owner,boolean team) {
        LocalDate chartStart=today.withDayOfMonth(1).minusMonths(11);
        String orderScope=company ? "1=1" : "o.owner_id IN ("+ids+")";
        String customerScope=company ? "1=1" : "c.owner_id IN ("+ids+")";
        var shipments=db.queryForList("""
            SELECT movement.day,d.id AS deptId,d.name AS dept,SUM(movement.amount) AS amount
            FROM (
                SELECT order_id,ship_date AS day,amount FROM crm_shipments WHERE status IN ('已发出','运输中','已签收')
                UNION ALL
                SELECT order_id,DATE(COALESCE(confirmed_at,return_date)),-amount FROM crm_returns
                WHERE status IN ('已入库','已退款')
            ) movement
            JOIN crm_orders o ON o.id=movement.order_id
            LEFT JOIN crm_employees e ON e.id=o.owner_id
            LEFT JOIN crm_departments d ON d.id=e.department_id
            WHERE o.deleted_at IS NULL AND o.status<>'已取消' AND movement.day>=? AND movement.day<?
              AND
            """+orderScope+" GROUP BY movement.day,d.id,d.name",chartStart,end);
        var receipts=db.queryForList("""
            SELECT DATE(a.created_at) AS day,SUM(a.amount) AS amount
            FROM crm_receipt_allocations a
            JOIN crm_receipts r ON r.id=a.receipt_id JOIN crm_customers c ON c.id=r.customer_id
            WHERE a.revoked_at IS NULL AND a.created_at>=? AND a.created_at<? AND
            """+customerScope+" GROUP BY DATE(a.created_at)",chartStart,end);
        double shipped=sumSince(shipments,start);
        double received=sumSince(receipts,start);
        String quarter=today.getYear()+"-Q"+((today.getMonthValue()-1)/3+1);
        var departments=db.queryForList("SELECT id,parent_id FROM crm_departments");
        var parents=new HashMap<Long,Long>();
        for(var d:departments) {
            if(d.get("parent_id") instanceof Number parent) parents.put(((Number)d.get("id")).longValue(),parent.longValue());
        }
        var targets=new HashMap<Long,Double>();
        double target=0;
        double scale=switch(period) { case "month" -> 1.0/3; case "quarter" -> 1; default -> 4; };
        if(owner==null && team) {
            var allowed=company ? departments : db.queryForList(
                "SELECT DISTINCT department_id AS id FROM crm_employees WHERE id IN ("+ids+") AND department_id IS NOT NULL");
            var visible=new HashSet<Long>();
            for(var d:allowed) visible.add(((Number)d.get("id")).longValue());
            
            for(var t:db.queryForList("""
                SELECT scope_id,amount FROM crm_targets WHERE scope='dept' AND metric='signed' AND period=?
                """,quarter)) {
                long id=((Number)t.get("scope_id")).longValue();
                if(visible.contains(id)) targets.put(id,((Number)t.get("amount")).doubleValue()*scale);
            }
            for(var entry:targets.entrySet()) {
                Long parent=parents.get(entry.getKey());
                while(parent!=null && !targets.containsKey(parent)) parent=parents.get(parent);
                if(parent==null) target+=entry.getValue();
            }
        } else {
            target=db.queryForObject("""
                SELECT COALESCE(SUM(amount),0) FROM crm_targets
                WHERE scope='employee' AND metric='signed' AND period BETWEEN ? AND ? AND scope_id IN (
                """+ids+")",Double.class,YearMonth.from(start).toString(),YearMonth.from(today).toString());
        }
        LocalDate periodEnd=switch(period) {
            case "month" -> start.plusMonths(1);
            case "quarter" -> start.plusMonths(3);
            case "year" -> start.plusYears(1);
            default -> end;
        };
        var kpis=new LinkedHashMap<String,Object>();
        kpis.put("ytdSigned",shipped);
        kpis.put("ytdReceived",received);
        kpis.put("annualTarget",target>0 ? target : null);
        kpis.put("completion",target>0 ? ratio(shipped,target) : null);
        kpis.put("timeProgress",ratio(java.time.temporal.ChronoUnit.DAYS.between(start,end),
                                     java.time.temporal.ChronoUnit.DAYS.between(start,periodEnd)));
        var amounts=new HashMap<Long,Double>();
        var names=new HashMap<Long,String>();
        for(var row:shipments) {
            if(date(row).isBefore(start) || !(row.get("deptId") instanceof Number id)) continue;
            amounts.merge(id.longValue(),amount(row),Double::sum);
            names.put(id.longValue(),row.get("dept").toString());
        }
        var contribution=amounts.entrySet().stream().sorted(Map.Entry.<Long,Double>comparingByValue().reversed())
            .map(entry -> {
                var row=new LinkedHashMap<String,Object>();
                Double goal=targets.get(entry.getKey());
                row.put("dept",names.get(entry.getKey()));
                row.put("signed",entry.getValue());
                row.put("target",goal);
                row.put("completion",goal==null || goal==0 ? null : ratio(entry.getValue(),goal));
                return (Map<String,Object>)row;
            }).toList();
        return new OverviewMoney(kpis,shipments,receipts,contribution);
    }

    private static double amount(Map<String,Object> row) { return ((Number)row.get("amount")).doubleValue(); }
    private static double sumSince(List<Map<String,Object>> rows,LocalDate start) {
        return rows.stream().filter(row -> !date(row).isBefore(start)).mapToDouble(AnalyticsService::amount).sum();
    }
    private static double sumMonth(List<Map<String,Object>> rows,YearMonth month) {
        return inMonth(rows,month).stream().mapToDouble(AnalyticsService::amount).sum();
    }
    private static long ratio(double part,double total) { return Math.round(part*100/total); }

    private record OverviewMoney(Map<String,Object> kpis,List<Map<String,Object>> shipments,
                                 List<Map<String,Object>> receipts,List<Map<String,Object>> departments) {}

    public Map<String,Object> filters(Long employee) {
        if (employee == null) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        var permissions = auth.current(employee).permissions();
        if (PERMISSIONS.values().stream().noneMatch(p -> permissions.contains("data."+p))) forbidden();
        var ids = scope(employee,permissions,null,null);
        String list = ids.isEmpty() ? "NULL" : String.join(",",ids.stream().map(String::valueOf).toList());
        return Map.of("owners",db.queryForList("SELECT id,name,department_id AS deptId FROM crm_employees WHERE id IN ("+list+") ORDER BY name,id"),
            "depts",permissions.contains("data.scope.all") ? db.queryForList("SELECT id,name FROM crm_departments ORDER BY id")
                : db.queryForList("SELECT DISTINCT d.id,d.name FROM crm_departments d JOIN crm_employees e ON e.department_id=d.id WHERE e.id IN ("+list+") ORDER BY d.id"));
    }

    private List<Long> scope(long employee,List<String> permissions,Long dept,Long owner) {
        long home = db.queryForObject("SELECT department_id FROM crm_employees WHERE id=?",Long.class,employee);
        if (permissions.contains("data.scope.all")) {
            if (dept == null) return db.queryForList("SELECT id FROM crm_employees WHERE (? IS NULL OR id=?)",Long.class,owner,owner);
        } else if (!permissions.contains("data.scope.dept")) {
            if ((owner != null && owner != employee) || (dept != null && dept != home)) forbidden();
            return List.of(employee);
        } else {
            var allowed = departments(home);
            if (dept != null && !allowed.contains(dept)) forbidden();
            if (owner != null && db.queryForList("SELECT department_id FROM crm_employees WHERE id=?",Long.class,owner)
                    .stream().noneMatch(allowed::contains)) forbidden();
        }
        var depts = departments(dept == null ? home : dept);
        return db.queryForList("SELECT id FROM crm_employees WHERE (? IS NULL OR id=?)",owner,owner)
            .stream().map(r -> ((Number)r.get("id")).longValue())
            .filter(id -> depts.contains(db.queryForObject("SELECT department_id FROM crm_employees WHERE id=?",Long.class,id))).toList();
    }

    private List<Long> departments(long root) {
        return db.queryForList("""
            WITH RECURSIVE tree AS (SELECT id FROM crm_departments WHERE id=?
              UNION ALL SELECT d.id FROM crm_departments d JOIN tree t ON d.parent_id=t.id)
            SELECT id FROM tree
            """,Long.class,root);
    }

    private static void forbidden() { throw new ResponseStatusException(HttpStatus.FORBIDDEN); }
    private static LocalDate date(Map<String,Object> row) { return LocalDate.parse(row.get("day").toString()); }
    private static List<YearMonth> months(LocalDate today) {
        return java.util.stream.IntStream.rangeClosed(0,11).mapToObj(i -> YearMonth.from(today).minusMonths(11-i)).toList();
    }
    private static String label(YearMonth m) { return m.getMonthValue()+"月"; }
    private static List<Map<String,Object>> inMonth(List<Map<String,Object>> rows,YearMonth month) {
        return rows.stream().filter(r -> YearMonth.from(date(r)).equals(month)).toList();
    }
    private static List<String> channels(List<Map<String,Object>> rows) {
        return rows.stream().map(r -> r.get("source").toString()).distinct().sorted().toList();
    }
    private static long countStage(List<Map<String,Object>> rows,int stage) {
        var ranks = List.of("pending","contacted","quoted","negotiating","won");
        return rows.stream().filter(r -> ranks.indexOf("converted".equals(r.get("status")) ? "won" : r.get("status")) >= stage).count();
    }
    private static Double percent(long number,long total) {
        return total == 0 ? null : Math.round(number*1000.0/total)/10.0;
    }
}
