package com.crm.analytics;

import org.springframework.jdbc.core.JdbcTemplate;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.*;

final class AnalyticsDetails {
    private final JdbcTemplate db;
    private final LocalDate start;
    private final LocalDate end;
    private final String ids;
    private final boolean company;

    AnalyticsDetails(JdbcTemplate db,LocalDate start,LocalDate end,String ids,boolean company) {
        this.db=db;
        this.start=start;
        this.end=end;
        this.ids=ids;
        this.company=company;
    }

    private String scope(String column) {
        return company ? "1=1" : column+" IN ("+ids+")";
    }

    Map<String,Object> customers() {
        var customers=db.queryForList("""
            SELECT c.id,c.name,c.level,c.status,e.name AS owner,t.hasDeal
            FROM crm_customers c LEFT JOIN crm_customer_trade t ON t.id=c.id
            LEFT JOIN crm_employees e ON e.id=c.owner_id
            WHERE c.merged_into_id IS NULL AND
            """+scope("c.owner_id"));
        var contracts=db.queryForList("""
            SELECT k.customer_id,k.sign_date AS day,k.amount
            FROM crm_contracts k JOIN crm_customers c ON c.id=k.customer_id
            WHERE k.deleted_at IS NULL AND k.status IN ('执行中','已完成') AND c.merged_into_id IS NULL
              AND k.sign_date>=? AND k.sign_date<? AND
            """+scope("c.owner_id")+" ORDER BY k.customer_id,k.sign_date,k.id",end.minusMonths(12),end);
        var byCustomer=group(contracts,"customer_id");
        var results=db.queryForList("""
            SELECT f.type,f.result FROM crm_customer_followups f JOIN crm_customers c ON c.id=f.customer_id
            WHERE c.merged_into_id IS NULL AND f.created_at>=? AND f.created_at<? AND
            """+scope("c.owner_id"),start,end);
        long overdue=db.queryForObject("""
            SELECT COUNT(*) FROM crm_customers c WHERE c.merged_into_id IS NULL AND
              (SELECT f.next_date FROM crm_customer_followups f WHERE f.customer_id=c.id
               ORDER BY f.created_at DESC,f.id DESC LIMIT 1) < ? AND
            """+scope("c.owner_id"),Long.class,end.minusDays(1));
        var sleeping=db.queryForList("""
            SELECT c.id,c.name,c.level,e.name AS owner,MAX(k.sign_date) AS lastOrder,
                   DATEDIFF(?,MAX(k.sign_date)) AS days,SUM(k.amount) AS amount
            FROM crm_customers c JOIN crm_contracts k ON k.customer_id=c.id
            LEFT JOIN crm_employees e ON e.id=c.owner_id
            WHERE c.merged_into_id IS NULL AND k.deleted_at IS NULL AND k.status IN ('执行中','已完成')
              AND k.sign_date<? AND
            """+scope("c.owner_id")+" GROUP BY c.id,e.name HAVING days>60 ORDER BY days DESC",end.minusDays(1),end);
        var cycles=new LinkedHashMap<String,Long>();
        var customerCycles=new HashMap<Object,Long>();
        long intervalCount=0, intervalDays=0;
        for(var entry:byCustomer.entrySet()) {
            var rows=entry.getValue();
            if(rows.size()<2) continue;
            long span=java.time.temporal.ChronoUnit.DAYS.between(day(rows.get(0)),day(rows.get(rows.size()-1)));
            long avg=Math.round((double)span/(rows.size()-1));
            intervalDays+=span;
            intervalCount+=rows.size()-1;
            customerCycles.put(entry.getKey(),avg);
            String bucket=avg<=20 ? "20 天以内" : avg<=40 ? "21–40 天" : avg<=60 ? "41–60 天" : "60 天以上";
            cycles.merge(bucket,1L,Long::sum);
        }
        sleeping.forEach(r -> r.put("cycle",customerCycles.get(r.get("id"))));
        Map<String,Object> data=new LinkedHashMap<>();
        data.put("total",customers.size());
        data.put("following",customers.stream().filter(r -> number(r,"hasDeal")==0).count());
        data.put("sleeping",sleeping.size());
        data.put("sleepingList",sleeping);
        data.put("repeatRate",rate(customerCycles.size(),byCustomer.size()));
        data.put("avgCycle",intervalCount==0 ? null : Math.round((double)intervalDays/intervalCount));
        data.put("cycleBuckets",cycles.entrySet().stream().map(e -> Map.of("label",e.getKey(),"count",e.getValue(),
            "ratio",rate(e.getValue(),customerCycles.size()))).toList());
        data.put("follow",Map.of("total",results.size(),"overdue",overdue,
            "resultDist",distribution(results,"result"),"typeDist",distribution(results,"type")));
        data.put("statusFlow",List.of());
        return data;
    }

    private static List<Map<String,Object>> distribution(List<Map<String,Object>> rows,String key) {
        return group(rows,key).entrySet().stream().map(e -> Map.<String,Object>of("label",e.getKey(),
            "count",e.getValue().size(),"ratio",rate(e.getValue().size(),rows.size()))).toList();
    }

    Map<String,Object> payments() {
        LocalDate today=end.minusDays(1);
        var invoices=db.queryForList("""
            SELECT i.code AS contract,c.name AS customer,COALESCE(e.name,'未分配') AS owner,
                   COALESCE(d.name,'未分配') AS dept,c.payment_term AS method,
                   DATE_ADD(i.issue_date,INTERVAL c.payment_term DAY) AS dueDate,i.issue_date AS day,
                   i.amount AS billed, GREATEST(i.amount-COALESCE(SUM(a.amount),0),0) AS amount
            FROM crm_invoices i JOIN crm_customers c ON c.id=i.customer_id
            LEFT JOIN crm_employees e ON e.id=c.owner_id LEFT JOIN crm_departments d ON d.id=e.department_id
            LEFT JOIN crm_receipt_allocations a ON a.target_type='invoice' AND a.target_id=i.id AND a.revoked_at IS NULL
            WHERE i.status='已开票' AND i.amount>0 AND i.issue_date<? AND
            """+scope("c.owner_id")+" GROUP BY i.id,c.id,e.id,d.id",end);
        var receipts=db.queryForList("""
            SELECT DATE(a.created_at) AS day,a.amount FROM crm_receipt_allocations a
            JOIN crm_receipts r ON r.id=a.receipt_id JOIN crm_customers c ON c.id=r.customer_id
            WHERE a.revoked_at IS NULL AND a.created_at>=? AND a.created_at<? AND
            """+scope("c.owner_id"),end.minusMonths(12).withDayOfMonth(1),end);
        var overdue=new ArrayList<Map<String,Object>>();
        double[] aging=new double[5];
        for(var row:invoices) {
            int days=(int)java.time.temporal.ChronoUnit.DAYS.between(LocalDate.parse(row.get("dueDate").toString()),today);
            double amount=number(row,"amount");
            int bucket=days<=0 ? 0 : days<=30 ? 1 : days<=60 ? 2 : days<=90 ? 3 : 4;
            aging[bucket]+=amount;
            row.put("days",days);
            row.put("method","账期 "+row.get("method")+" 天");
            if(days>0 && amount>0) overdue.add(row);
        }
        overdue.sort(Comparator.comparingDouble((Map<String,Object> r) -> number(r,"days")).reversed());
        double balance=Arrays.stream(aging).sum();
        double received=receipts.stream().filter(r -> !day(r).isBefore(start)).mapToDouble(r -> number(r,"amount")).sum();
        var buckets=new ArrayList<Map<String,Object>>();
        var labels=List.of("未到期","1–30 天","31–60 天","61–90 天","90 天以上");
        for(int i=0;i<aging.length;i++) buckets.add(Map.of("label",labels.get(i),"amount",aging[i],
            "ratio",balance==0 ? 0 : rate(aging[i],balance),"tone",i==0?"success":i<3?"warning":"danger"));
        var owners=group(invoices,"owner").values().stream().map(rows -> {
            double billed=sum(rows,"billed"), open=sum(rows,"amount");
            return Map.of("owner",rows.get(0).get("owner"),"dept",rows.get(0).get("dept"),
                "receivable",open,"received",billed-open,"rate",rate(billed-open,billed));
        }).toList();
        var monthly=months(today).stream().map(m -> Map.of("label",m.getMonthValue()+"月",
            "signed",monthly(invoices,m,"billed"),"received",monthly(receipts,m,"amount"))).toList();
        var data=new LinkedHashMap<String,Object>();
        data.put("receivable",balance);
        data.put("received",received);
        data.put("overdue",balance-aging[0]);
        data.put("rate",rate(sum(invoices,"billed")-balance,sum(invoices,"billed")));
        data.put("aging",buckets);
        data.put("overdueList",overdue);
        data.put("byOwner",owners);
        data.put("monthly",monthly);
        return data;
    }

    Map<String,Object> products(boolean canCost) {
        var movements=db.queryForList("""
            SELECT x.day,p.id,p.code,p.name,COALESCE(c.name,'未分类') AS category,
                   x.qty*COALESCE(NULLIF(i.unit_factor,0),u.factor,1) AS qty,
                   x.qty*i.price AS amount,
                   x.qty*COALESCE(NULLIF(i.unit_factor,0),u.factor,1)*p.cost_price/COALESCE(s.factor,1) AS cost
            FROM (
                SELECT h.ship_date AS day,si.order_item_id,si.qty
                FROM crm_shipment_items si JOIN crm_shipments h ON h.id=si.shipment_id
                WHERE h.status IN ('已发出','运输中','已签收')
                UNION ALL
                SELECT DATE(COALESCE(r.confirmed_at,r.return_date)),ri.order_item_id,-ri.qty
                FROM crm_return_items ri JOIN crm_returns r ON r.id=ri.return_id
                WHERE r.status IN ('已入库','已退款')
            ) x JOIN crm_order_items i ON i.id=x.order_item_id JOIN crm_orders o ON o.id=i.order_id
            JOIN crm_products p ON p.id=i.product_id LEFT JOIN crm_product_categories c ON c.id=p.category_id
            LEFT JOIN crm_product_units u ON u.product_id=p.id AND u.unit_name=i.unit
            LEFT JOIN crm_product_units s ON s.product_id=p.id AND s.unit_name=p.sale_unit
            WHERE o.deleted_at IS NULL AND o.status<>'已取消' AND x.day>=? AND x.day<? AND
            """+scope("o.owner_id"),end.minusMonths(12).withDayOfMonth(1),end);
        var selected=movements.stream().filter(r -> !day(r).isBefore(start)).toList();
        double total=sum(selected,"amount");
        var categories=group(selected,"category").values().stream().map(rows -> {
            double sales=sum(rows,"amount");
            Double gross=!canCost || rows.stream().anyMatch(r->r.get("cost")==null) ? null : sales-sum(rows,"cost");
            var row=new LinkedHashMap<String,Object>();
            row.put("name",rows.get(0).get("category")); row.put("sales",sales); row.put("qty",sum(rows,"qty"));
            row.put("gross",gross); row.put("margin",gross==null ? null : rate(gross,sales)); row.put("ratio",rate(sales,total));
            return (Map<String,Object>)row;
        }).toList();
        var sku=group(selected,"id").values().stream().map(rows -> {
            var row=new LinkedHashMap<String,Object>();
            var first=rows.get(0);
            for(String key:List.of("code","name","category")) row.put(key,first.get(key));
            double amount=sum(rows,"amount");
            row.put("amount",amount); row.put("qty",sum(rows,"qty"));
            row.put("margin",!canCost || rows.stream().anyMatch(r -> r.get("cost")==null) ? null : rate(amount-sum(rows,"cost"),amount));
            return (Map<String,Object>)row;
        }).sorted(Comparator.comparingDouble((Map<String,Object> r)->number(r,"amount")).reversed()).limit(10).toList();
        List<Map<String,Object>> slow=company ? db.queryForList("""
            SELECT p.code,p.name,COALESCE(c.name,'未分类') AS category,i.available AS stock,
                   p.cost_price/COALESCE(u.factor,1) AS cost,i.available*p.cost_price/COALESCE(u.factor,1) AS amount,
                   DATEDIFF(?,COALESCE(MAX(s.ship_date),DATE(p.created_at))) AS days
            FROM crm_products p JOIN crm_product_inventory i ON i.product_id=p.id
            LEFT JOIN crm_product_categories c ON c.id=p.category_id
            LEFT JOIN crm_product_units u ON u.product_id=p.id AND u.unit_name=p.sale_unit
            LEFT JOIN crm_shipment_items si ON si.product_id=p.id
            LEFT JOIN crm_shipments s ON s.id=si.shipment_id AND s.status IN ('已发出','运输中','已签收') AND s.ship_date<?
            WHERE i.available>0 GROUP BY p.id,c.id,i.available,u.factor HAVING days>=60 ORDER BY days DESC
            """,end.minusDays(1),end) : List.of();
        if (!canCost) slow.forEach(r -> { r.remove("cost"); r.remove("amount"); });
        var trend=months(end.minusDays(1)).stream().map(m -> {
            var row=new LinkedHashMap<String,Object>();
            row.put("label",m.getMonthValue()+"月");
            group(movements,"category").forEach((key,rows)->row.put(key.toString(),monthly(rows,m,"amount")/10000));
            return row;
        }).toList();
        return Map.of("categories",categories,"topSku",sku,"slowMoving",slow,"trend",trend);
    }

    List<Map<String,Object>> sales() {
        return db.queryForList("""
            SELECT x.day,o.id AS orderId,o.owner_id,e.name,COALESCE(d.name,'未分配') AS dept,
                   COALESCE(l.source,c.source,'未标记') AS source,x.amount
            FROM (
                SELECT order_id,ship_date AS day,amount FROM crm_shipments WHERE status IN ('已发出','运输中','已签收')
                UNION ALL
                SELECT order_id,DATE(COALESCE(confirmed_at,return_date)),-amount FROM crm_returns
                WHERE status IN ('已入库','已退款')
            ) x JOIN crm_orders o ON o.id=x.order_id
            JOIN crm_employees e ON e.id=o.owner_id LEFT JOIN crm_departments d ON d.id=e.department_id
            JOIN crm_customers c ON c.id=o.customer_id LEFT JOIN crm_leads l ON l.id=c.source_lead_id
            WHERE o.deleted_at IS NULL AND o.status<>'已取消' AND x.day>=? AND x.day<? AND
            """+scope("o.owner_id"),start,end);
    }

    Map<String,Object> performance(List<Map<String,Object>> departments) {
        var sales=sales();
        var employees=db.queryForList("""
            SELECT e.id,e.name,COALESCE(d.name,'未分配') AS dept,
              (SELECT GROUP_CONCAT(r.name ORDER BY r.id SEPARATOR ' / ') FROM crm_employee_roles er
               JOIN crm_roles r ON r.id=er.role_id WHERE er.employee_id=e.id) AS role
            FROM crm_employees e LEFT JOIN crm_departments d ON d.id=e.department_id
            WHERE
            """+scope("e.id"));
        var actual=group(sales,"owner_id");
        var targets=db.queryForList("""
            SELECT scope_id,SUM(amount) AS amount FROM crm_targets
            WHERE scope='employee' AND metric='signed' AND period BETWEEN ? AND ? AND
            """+scope("scope_id")+" GROUP BY scope_id",YearMonth.from(start).toString(),YearMonth.from(end.minusDays(1)).toString());
        var goals=group(targets,"scope_id");
        var staff=new ArrayList<Map<String,Object>>();
        for(var employee:employees) {
            Object id=employee.get("id");
            var rows=actual.getOrDefault(id,List.of());
            double goal=sum(goals.getOrDefault(id,List.of()),"amount");
            if(rows.isEmpty() && goal==0) continue;
            var stat=performanceRow(rows,goal);
            stat.put("name",employee.get("name"));
            stat.put("dept",employee.get("dept")); stat.put("deptTop",employee.get("dept"));
            stat.put("role",employee.get("role"));
            staff.add(stat);
        }
        staff.sort(Comparator.comparingDouble((Map<String,Object> r)->number(r,"signed")).reversed());
        var top=staff.stream().limit(10).toList();
        var depts=new ArrayList<Map<String,Object>>();
        for(var row:departments) {
            String dept=row.get("dept").toString();
            var stats=performanceRow(sales.stream().filter(r->dept.equals(r.get("dept"))).toList(),number(row,"target"));
            long count=staff.stream().filter(r->dept.equals(r.get("dept"))).count();
            stats.put("dept",dept); stats.put("headcount",count);
            stats.put("perHead",count==0 ? null : number(stats,"signed")/count);
            depts.add(stats);
        }
        var buckets=new ArrayList<Map<String,Object>>();
        String[] labels={"低于 60%","60%–79%","80%–99%","达到 100%"};
        String[] tones={"danger","warning","brand","success"};
        long[] counts=new long[4];
        for(var row:staff) {
            if(row.get("completion") instanceof Number pct) {
                double n=pct.doubleValue();
                counts[n<60 ? 0 : n<80 ? 1 : n<100 ? 2 : 3]++;
            }
        }
        for(int i=0;i<4;i++) buckets.add(Map.of("label",labels[i],"count",counts[i],"tone",tones[i]));
        var quarters=new ArrayList<Map<String,Object>>();
        int year=end.minusDays(1).getYear();
        for(int q=1;q<=4;q++) {
            LocalDate from=LocalDate.of(year,(q-1)*3+1,1);
            LocalDate to=from.plusMonths(3);
            if(!from.isBefore(end) || !to.isAfter(start)) continue;
            var rows=sales.stream().filter(r->!day(r).isBefore(from) && day(r).isBefore(to)).toList();
            double goal=targetsForQuarter(from,to);
            var row=performanceRow(rows,goal);
            row.put("label","Q"+q);
            quarters.add(row);
        }
        return Map.of("depts",depts,"staff",staff,"top10",top,"buckets",buckets,"quarters",quarters);
    }

    private double targetsForQuarter(LocalDate from,LocalDate to) {
        return db.queryForObject("""
            SELECT COALESCE(SUM(amount),0) FROM crm_targets WHERE scope='employee' AND metric='signed'
              AND period BETWEEN ? AND ? AND
            """+scope("scope_id"),Double.class,YearMonth.from(from).toString(),YearMonth.from(to.minusDays(1)).toString());
    }

    private static Map<String,Object> performanceRow(List<Map<String,Object>> rows,double goal) {
        double sales=sum(rows,"amount");
        long deals=rows.stream().filter(r->number(r,"amount")>0).map(r->r.get("orderId")).distinct().count();
        var row=new LinkedHashMap<String,Object>();
        row.put("signed",sales); row.put("target",goal>0?goal:null);
        row.put("deals",deals); row.put("completion",rate(sales,goal));
        row.put("avgDeal",deals==0?null:sales/deals); row.put("gap",goal>0?goal-sales:null);
        return row;
    }

    private static List<YearMonth> months(LocalDate today) {
        return java.util.stream.IntStream.rangeClosed(0,11).mapToObj(i -> YearMonth.from(today).minusMonths(11-i)).toList();
    }

    private static Map<Object,List<Map<String,Object>>> group(List<Map<String,Object>> rows,String key) {
        var grouped=new LinkedHashMap<Object,List<Map<String,Object>>>();
        for(var row:rows) grouped.computeIfAbsent(row.get(key),id->new ArrayList<>()).add(row);
        return grouped;
    }

    private static LocalDate day(Map<String,Object> row) { return LocalDate.parse(row.get("day").toString()); }
    private static double number(Map<String,Object> row,String key) {
        return row.get(key) instanceof Number n ? n.doubleValue() : 0;
    }
    private static double sum(List<Map<String,Object>> rows,String key) {
        return rows.stream().mapToDouble(r -> number(r,key)).sum();
    }
    private static double monthly(List<Map<String,Object>> rows,YearMonth month,String key) {
        return rows.stream().filter(r -> YearMonth.from(day(r)).equals(month)).mapToDouble(r -> number(r,key)).sum();
    }
    private static Double rate(double part,double whole) {
        return whole==0 ? null : Math.round(part*1000/whole)/10.0;
    }
}