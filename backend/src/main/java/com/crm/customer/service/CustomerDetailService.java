package com.crm.customer.service;

import com.crm.customer.mapper.CustomerMapper;
import com.crm.lead.service.LeadService;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.*;
import java.util.stream.IntStream;

@Service
public class CustomerDetailService {
    private final JdbcTemplate db;
    private final CustomerMapper customers;
    private final LeadService auth;

    public CustomerDetailService(JdbcTemplate db, CustomerMapper customers, LeadService auth) {
        this.db = db;
        this.customers = customers;
        this.auth = auth;
    }

    public Object detail(Long employee, long id) {
        check(employee,id,"customer.view");
        var profile = db.queryForMap("""
            SELECT c.id,c.code,c.name,c.industry,c.level,c.owner_id AS ownerId,e.name AS owner,
                   DATE(c.created_at) AS createdAt,c.phone,c.address,c.region,c.source,c.note,c.status,
                   c.payment_term AS term,c.credit_limit,c.credit_used,COALESCE(p.discount,1) AS discount
            FROM crm_customers c LEFT JOIN crm_employees e ON e.id=c.owner_id
            LEFT JOIN crm_customer_prices p ON p.customer_id=c.id WHERE c.id=?
            """,id);
        profile.put("credit",Map.of("limit",profile.remove("credit_limit"),"used",profile.remove("credit_used")));
        profile.put("tags",List.of());
        var contacts = db.queryForList("""
            SELECT id,name,title,phone,email,role,is_primary AS `primary`,DATE(last_contact_at) AS lastContact,
                   CASE role WHEN 'decision' THEN '决策人' WHEN 'payer' THEN '付款人' ELSE '使用人' END AS roleLabel
            FROM crm_customer_contacts WHERE customer_id=? ORDER BY is_primary DESC,id
            """,id);
        mask(profile);
        contacts.forEach(this::mask);
        boolean payment = auth.has(employee,"payment.view");
        var metrics = db.queryForMap("""
            SELECT amount AS total,orders,net90,cycle,lastOrderAt AS lastOrder,hasDeal,
                   ROUND(amount/NULLIF(orders,0),2) AS avgOrder,
                   IF(?,receivable,NULL) AS receivable,IF(?,overdue,NULL) AS overdue,
                   IF(?,received,NULL) AS received,
                   CASE WHEN NOT hasDeal THEN '跟进中' WHEN overdue>0 AND ? THEN '待回款'
                        WHEN DATEDIFF(CURDATE(),lastOrderAt)>90 THEN '流失风险' ELSE '合作中' END AS status
            FROM crm_customer_trade WHERE id=?
            """,payment,payment,payment,payment,id);
        profile.put("status",metrics.get("status"));
        var credit = (Map<?,?>)profile.get("credit");
        metrics.put("creditRemain",((java.math.BigDecimal)credit.get("limit")).subtract((java.math.BigDecimal)credit.get("used")));
        var monthly = IntStream.rangeClosed(0,5).mapToObj(i -> {
            var month = YearMonth.now().minusMonths(5-i);
            Object amount = db.queryForObject("""
                SELECT COALESCE(SUM(amount),0) FROM crm_orders WHERE customer_id=? AND deleted_at IS NULL
                AND status NOT IN ('草稿','已取消','已退货') AND order_date>=? AND order_date<?
                """,java.math.BigDecimal.class,id,month.atDay(1),month.plusMonths(1).atDay(1));
            return Map.of("month",String.format("%02d",month.getMonthValue()),"amount",amount);
        }).toList();
        var trade = trade(employee,id);
        return Map.of("profile",profile,"metrics",metrics,"contacts",contacts,"timeline",timeline(employee,id,null,50),
                "contracts",trade.get("contracts"),"payments",trade.get("payments"),"monthly",monthly,
                "attach",db.queryForList("SELECT id,name,type,url,CONCAT(size_bytes,' B') AS size,DATE(created_at) AS at,TRUE AS ok FROM crm_customer_attachments WHERE customer_id=?",id));
    }

    public List<Map<String,Object>> timeline(Long employee,long id,String before,int limit) {
        check(employee,id,"customer.view");
        return db.queryForList("""
            SELECT * FROM (
                SELECT f.created_at AS at,'follow' AS kind,CONCAT(type,' · ',e.name) AS title,
                       content AS `desc`,COALESCE(CONCAT('下次跟进 ',next_date),result) AS meta,'success' AS tone
                FROM crm_customer_followups f JOIN crm_employees e ON e.id=f.employee_id WHERE customer_id=?
                UNION ALL
                SELECT t.created_at,'transfer',CONCAT('负责人变更 · ',COALESCE(e.name,'系统')),t.reason,
                       COALESCE(n.name,'客户池'),'brand'
                FROM crm_customer_transfers t LEFT JOIN crm_employees e ON e.id=t.operator_id
                LEFT JOIN crm_employees n ON n.id=t.owner_id WHERE t.customer_id=?
            ) events WHERE (? IS NULL OR at < ?) ORDER BY at DESC LIMIT ?
            """,id,id,before,before,Math.max(1,Math.min(100,limit)));
    }

    public Object orders(Long employee,long id) {
        check(employee,id,"customer.view");
        return trade(employee,id);
    }

    private Map<String,Object> trade(Long employee,long id) {
        return Map.of(
            "contracts",auth.has(employee,"contract.view") ? db.queryForList("""
                SELECT c.id,c.code,c.name,c.amount,c.sign_date,c.term_days,c.status,
                       CASE WHEN ? THEN LEAST(100,ROUND(100*COALESCE((SELECT SUM(a.amount)
                         FROM crm_receipt_allocations a WHERE a.target_type='contract' AND a.target_id=c.id
                         AND a.revoked_at IS NULL),0)/NULLIF(c.amount,0))) END AS paid FROM crm_contracts c
                WHERE customer_id=? AND deleted_at IS NULL ORDER BY sign_date DESC,id DESC
                """,auth.has(employee,"payment.view"),id) : List.of(),
            "payments",auth.has(employee,"payment.view") ? db.queryForList("""
                SELECT id,code,amount,pay_date,method,remark FROM crm_receipts WHERE customer_id=? ORDER BY pay_date DESC,id DESC
                """,id) : List.of());
    }

    @Transactional
    public void follow(Long employee,long id,Follow form) {
        lock(employee,id,"followup.create");
        if (form.content()==null || form.content().isBlank() || form.content().length()>500) bad();
        db.update("INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date) VALUES (?,?,?,?,?,?)",
                id,employee,form.type(),form.result(),form.content(),form.next());
        db.update("UPDATE crm_customers SET last_follow_at=NOW() WHERE id=?",id);
        db.update("""
            UPDATE crm_customer_follow_tasks SET state='done',done_at=NOW(),done_by=?
            WHERE customer_id=? AND owner_id=? AND state<>'done' AND due_date<=CURDATE()
            """,employee,id,employee);
        if (form.next()!=null) db.update("""
            INSERT INTO crm_customer_follow_tasks(customer_id,owner_id,due_date,content,source,created_by)
            SELECT id,owner_id,?,?,'followup',? FROM crm_customers WHERE id=? AND owner_id IS NOT NULL
            """,form.next(),form.content(),employee,id);
    }

    @Transactional
    public void addContact(Long employee,long id,Contact form) {
        lock(employee,id,"contact.edit");
        if (form.name()==null || form.name().isBlank()) bad();
        if (Boolean.TRUE.equals(form.primary())) clearPrimary(id);
        db.update("INSERT INTO crm_customer_contacts(customer_id,name,title,phone,email,role,is_primary) VALUES (?,?,?,?,?,COALESCE(?,'user'),?)",
                id,form.name(),form.title(),form.phone(),form.email(),form.role(),Boolean.TRUE.equals(form.primary()));
    }

    @Transactional
    public void editContact(Long employee,long id,long contact,Contact form) {
        lock(employee,id,"contact.edit");
        if (Boolean.TRUE.equals(form.primary())) clearPrimary(id);
        if (db.update("UPDATE crm_customer_contacts SET role=COALESCE(?,role),is_primary=COALESCE(?,is_primary) WHERE id=? AND customer_id=?",
                form.role(),form.primary(),contact,id)==0) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
    }

    private static final Map<String,String> EDIT_FIELDS = Map.ofEntries(
        Map.entry("name","name"), Map.entry("industry","industry"), Map.entry("level","level"),
        Map.entry("region","region"), Map.entry("phone","phone"), Map.entry("address","address"),
        Map.entry("source","source"), Map.entry("note","note"),
        Map.entry("paymentTerm","payment_term"), Map.entry("creditLimit","credit_limit"));

    @Transactional
    public Object update(Long employee,long id,Map<String,com.fasterxml.jackson.databind.JsonNode> fields) {
        lock(employee,id,"customer.edit");
        var before = db.queryForMap("SELECT * FROM crm_customers WHERE id=?",id);
        var changed = new ArrayList<String>();
        for (var entry : fields.entrySet()) {
            String field = entry.getKey();
            String column = EDIT_FIELDS.get(field);
            if (column == null) bad();
            var value = entry.getValue();
            Object next;
            if (field.equals("paymentTerm") || field.equals("creditLimit")) {
                auth.require(employee,"customer.credit");
                if (field.equals("paymentTerm")) {
                    if (!value.isIntegralNumber() || !value.canConvertToInt() || value.intValue()<0 || value.intValue()>180) bad();
                    next = value.intValue();
                } else {
                    if (!value.isNumber()) bad();
                    var limit = value.decimalValue();
                    if (limit.scale()>2 || limit.signum()<0 || limit.compareTo(new java.math.BigDecimal("999999999999.99"))>0
                            || limit.compareTo((java.math.BigDecimal) before.get("credit_used"))<0) bad();
                    next = limit;
                }
            } else {
                if (!value.isTextual() && !value.isNull()) bad();
                String text = value.isNull() ? null : value.asText().strip();
                int max = switch(field) {
                    case "name" -> 200; case "industry" -> 100; case "level" -> 20;
                    case "region","source" -> 64; case "phone" -> 32; case "address" -> 255; default -> 500;
                };
                if (text!=null && (text.length()>max || field.equals("phone") && text.contains("*"))) bad();
                if (field.equals("name")) {
                    if (text==null || text.isBlank()) bad();
                    if (!text.equals(before.get(column)) && db.queryForObject(
                        "SELECT COUNT(*) FROM crm_customers WHERE id<>? AND name=? AND merged_into_id IS NULL",
                        Long.class,id,text)>0) throw new ResponseStatusException(HttpStatus.CONFLICT);
                }
                if (field.equals("level") && (text==null || text.isBlank())) bad();
                next = field.equals("level") ? level(text) : text;
            }
            Object old = before.get(column);
            if (Objects.equals(old,next) || old instanceof Number && next instanceof Number
                    && new java.math.BigDecimal(old.toString()).compareTo(new java.math.BigDecimal(next.toString()))==0) continue;
            db.update("UPDATE crm_customers SET "+column+"=? WHERE id=?",next,id);
            db.update("INSERT INTO crm_customer_changes(customer_id,field,before_value,after_value,operator_id) VALUES(?,?,?,?,?)",
                id,field,Objects.toString(old,null),Objects.toString(next,null),employee);
            changed.add(field);
        }
        return Map.of("changed",changed);
    }

    @Transactional
    public Object create(Long employee, Create form) {
        auth.require(employee,"customer.create");
        long owner = employee;
        if (form.ownerId()!=null) {
            auth.require(employee,"lead.transfer");
            owner = form.ownerId();
        }
        if (form.paymentTerm()!=null || form.creditLimit()!=null) auth.require(employee,"customer.credit");
        int term = form.paymentTerm()==null ? 0 : form.paymentTerm();
        var limit = form.creditLimit()==null ? java.math.BigDecimal.ZERO : form.creditLimit();
        if (term<0 || term>180 || limit.signum()<0 || limit.scale()>2
                || limit.compareTo(new java.math.BigDecimal("999999999999.99"))>0) bad();
        if (db.queryForList("SELECT id FROM crm_employees WHERE id=? AND status='active' AND deleted_at IS NULL FOR SHARE",owner).isEmpty()) bad();
        String name = field(form.name(),200);
        if (name==null) bad();
        String phone = phone(form.phone());
        String code = com.crm.common.DocCode.next(db,"C","crm_customers");
        var duplicates = db.queryForList("""
            SELECT id FROM crm_customers WHERE merged_into_id IS NULL AND
            (TRIM(name)=? OR (? IS NOT NULL AND REGEXP_REPLACE(phone,'[^0-9]','')=REGEXP_REPLACE(?,'[^0-9]','')))
            LIMIT 20
            """,name,phone,phone);
        if (!duplicates.isEmpty()) {
            throw new DuplicateCustomer(duplicates.stream().map(row -> {
                long id = ((Number)row.get("id")).longValue();
                return customers.canAccess(employee,id,"customer.view") ? Map.of("id",id,"name",db.queryForObject(
                    "SELECT name FROM crm_customers WHERE id=?",String.class,id)) : Map.of("name","已有客户");
            }).toList());
        }
        db.update("""
            INSERT INTO crm_customers(code,name,industry,level,region,phone,source,address,note,
              payment_term,credit_limit,owner_id,created_by,status,status_at)
            VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,'跟进中',NOW())
            """,code,name,field(form.industry(),100),level(form.level()),field(form.region(),64),phone,
            field(form.source(),64),field(form.address(),255),field(form.note(),500),term,limit,owner,employee);
        long id = db.queryForObject("SELECT id FROM crm_customers WHERE code=?",Long.class,code);
        if (form.contacts()!=null) {
            if (form.contacts().stream().filter(InitialContact::isPrimary).count()>1) bad();
            for (var contact : form.contacts()) {
                String contactName = field(contact.name(),100);
                if (contactName==null) bad();
                db.update("INSERT INTO crm_customer_contacts(customer_id,name,title,phone,is_primary) VALUES(?,?,?,?,?)",
                    id,contactName,field(contact.title(),64),phone(contact.phone()),contact.isPrimary());
            }
        }
        return Map.of("id",id,"code",code,"name",name,"ownerId",owner,"status","跟进中");
    }

    private String field(String text,int max) {
        if (text==null || text.isBlank()) return null;
        String value=text.strip();
        if (value.length()>max) bad();
        return value;
    }

    private String phone(String text) {
        String value=field(text,32);
        if (value!=null && (value.contains("*") || !value.matches(".*[0-9].*"))) bad();
        return value;
    }

    private String level(String text) {
        return switch (text==null ? "" : text.strip().replace(" ","")) {
            case "战略客户" -> "战略客户";
            case "A","A类" -> "A 类";
            case "B","B类" -> "B 类";
            case "","C","C类" -> "C 类";
            default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
        };
    }

    public record Create(String name,String level,String industry,String region,String phone,String source,
                         String address,String note,Integer paymentTerm,java.math.BigDecimal creditLimit,
                         Long ownerId,List<InitialContact> contacts) {}
    public record InitialContact(String name,String title,String phone,boolean isPrimary) {}
    public static class DuplicateCustomer extends RuntimeException {
        public final List<? extends Map<String,?>> duplicates;
        DuplicateCustomer(List<? extends Map<String,?>> duplicates) { this.duplicates=duplicates; }
    }

    private void clearPrimary(long id) {
        db.update("UPDATE crm_customer_contacts SET is_primary=0 WHERE customer_id=? AND is_primary=1",id);
    }

    @Transactional
    public void merge(Long employee,long from,long to,String note) {
        if (from==to) bad();
        lock(employee,Math.min(from,to),"customer.merge");
        lock(employee,Math.max(from,to),"customer.merge");
        if (Boolean.TRUE.equals(db.queryForObject("SELECT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=? AND is_primary=1)",Boolean.class,to))) clearPrimary(from);
        int contacts = db.update("UPDATE crm_customer_contacts SET customer_id=? WHERE customer_id=?",to,from);
        int follows = db.update("UPDATE crm_customer_followups SET customer_id=? WHERE customer_id=?",to,from);
        db.update("UPDATE crm_customer_follow_tasks SET customer_id=? WHERE customer_id=?",to,from);
        db.update("UPDATE crm_customer_attachments SET customer_id=? WHERE customer_id=?",to,from);
        db.update("UPDATE crm_customers SET merged_into_id=? WHERE id=?",to,from);
        db.update("INSERT INTO crm_customer_merges(from_id,to_id,operator_id,moved_contacts,moved_followups,note) VALUES(?,?,?,?,?,?)",
                from,to,employee,contacts,follows,note);
    }

    public Object duplicates(Long employee,String name,String phone) {
        auth.require(employee,"customer.create","customer.edit");
        var found = db.queryForList("""
            SELECT c.id,c.name,e.name AS owner,IF(c.phone=?,1,0.8) AS score FROM crm_customers c
            LEFT JOIN crm_employees e ON e.id=c.owner_id WHERE c.merged_into_id IS NULL
              AND ((? <> '' AND LOCATE(?,c.name)=1) OR (? <> '' AND c.phone=?))
            ORDER BY score DESC LIMIT 50
            """,phone,name,name,phone,phone);
        return Map.of("duplicates",found.stream().filter(r -> customers.canAccess(employee,((Number)r.get("id")).longValue(),"customer.edit")
                || customers.canAccess(employee,((Number)r.get("id")).longValue(),"customer.create")).toList());
    }

    private void lock(Long employee,long id,String permission) {
        db.queryForList("SELECT id FROM crm_customers WHERE id=? FOR UPDATE",id);
        check(employee,id,permission);
    }

    private void check(Long employee,long id,String permission) {
        auth.require(employee,permission);
        if (db.queryForList("SELECT id FROM crm_customers WHERE id=? AND merged_into_id IS NULL",id).isEmpty())
            throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        if (!customers.canAccess(employee,id,permission)) throw new ResponseStatusException(HttpStatus.FORBIDDEN);
    }

    private void mask(Map<String,Object> row) {
        if (row.get("phone") instanceof String phone && phone.length()>7 && !phone.contains("*")) {
            row.put("phone",phone.substring(0,3)+"****"+phone.substring(phone.length()-4));
        }
    }

    private void bad() { throw new ResponseStatusException(HttpStatus.BAD_REQUEST); }

    public record Follow(String type,String result,String content,LocalDate next) {}
    public record Contact(String name,String title,String phone,String email,String role,Boolean primary) {}
}






