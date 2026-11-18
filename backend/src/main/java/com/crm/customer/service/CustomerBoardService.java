package com.crm.customer.service;

import com.crm.auth.service.AuthService;
import com.crm.lead.service.LeadService;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.util.*;

@Service
public class CustomerBoardService {
    private final JdbcTemplate db;
    private final AuthService auth;
    private final LeadService permissions;

    public CustomerBoardService(JdbcTemplate db, AuthService auth, LeadService permissions) {
        this.db = db;
        this.auth = auth;
        this.permissions = permissions;
    }

    @Transactional
    public Map<String,Object> board(Long employee,String range,Long dept,Long owner) {
        permissions.require(employee,"followup.board");
        var allowed = members(employee);
        if ((owner != null && allowed.stream().noneMatch(m -> owner == id(m,"id")))
                || (dept != null && allowed.stream().noneMatch(m -> dept == id(m,"deptId")))) forbidden();
        LocalDate today = LocalDate.now();
        LocalDate until = switch (range) {
            case "today" -> today;
            case "month" -> today.plusMonths(1);
            case "week" -> today.plusDays(6);
            default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
        };
        var visible = allowed.stream().filter(m -> (dept == null || dept == id(m,"deptId"))
                && (owner == null || owner == id(m,"id"))).toList();
        for (var member : visible) {
            long id = id(member,"id");
            refresh(id);
            var tasks = db.queryForList("""
                SELECT t.id,c.name AS customer,t.customer_id AS customerId,t.state,t.due_date AS due,
                       c.last_follow_at AS last,t.content,
                       (SELECT result FROM crm_customer_followups f WHERE f.customer_id=c.id
                         ORDER BY f.created_at DESC,f.id DESC LIMIT 1) AS result
                FROM crm_customer_follow_tasks t JOIN crm_customers c ON c.id=t.customer_id
                WHERE t.owner_id=? AND c.merged_into_id IS NULL AND c.owner_id IS NOT NULL AND t.due_date<=?
                  AND (t.state<>'done' OR t.done_at>=?)
                ORDER BY FIELD(t.state,'overdue','due','plan','done'),t.due_date,t.id
                """,id,until,today.minusDays(range.equals("today") ? 0 : range.equals("month") ? 29 : 6));
            long done = tasks.stream().filter(t -> "done".equals(t.get("state"))).count();
            member.put("tasks",tasks);
            member.put("done",done);
            member.put("total",tasks.size());
            member.put("rate",tasks.isEmpty() ? 0 : Math.round(100.0*done/tasks.size()));
        }
        return Map.of("serverDate",today,"members",visible);
    }

    @Transactional
    public void update(Long employee,long task,Task form) {
        permissions.require(employee,"followup.board","followup.create");
        var rows = db.queryForList("SELECT owner_id FROM crm_customer_follow_tasks WHERE id=? FOR UPDATE",task);
        if (rows.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        long owner = id(rows.get(0),"owner_id");
        if (owner != employee && (!auth.current(employee).permissions().contains("followup.board")
                || members(employee).stream().noneMatch(m -> id(m,"id")==owner))) forbidden();
        if (form.dueDate()!=null) db.update("UPDATE crm_customer_follow_tasks SET due_date=? WHERE id=?",form.dueDate(),task);
        if (form.done()!=null) {
            if (form.done()) db.update("UPDATE crm_customer_follow_tasks SET state='done',done_at=NOW(),done_by=? WHERE id=?",employee,task);
            else db.update("UPDATE crm_customer_follow_tasks SET state='plan',done_at=NULL,done_by=NULL WHERE id=?",task);
        }
        refresh(owner);
    }

    public Object pool(Long employee) {
        permissions.require(employee,"customer.public");
        return db.queryForList("""
            SELECT id,name,industry,level,region,COALESCE(pool_reason,'') AS reason,
                   pool_entered_at AS releasedAt,last_follow_at AS lastFollow,0 AS amount,0 AS orders
            FROM crm_customers WHERE owner_id IS NULL AND pool_entered_at IS NOT NULL
            AND merged_into_id IS NULL ORDER BY pool_entered_at DESC
            """);
    }

    @Transactional
    public void claim(Long employee,long id) {
        permissions.require(employee,"customer.public.claim");
        if (db.update("""
            UPDATE crm_customers SET owner_id=?,pool_entered_at=NULL,pool_reason=NULL
            WHERE id=? AND owner_id IS NULL AND pool_entered_at IS NOT NULL AND merged_into_id IS NULL
            """,employee,id)==0) throw new ResponseStatusException(HttpStatus.CONFLICT);
        db.update("INSERT INTO crm_customer_transfers(customer_id,owner_id,operator_id) VALUES(?,?,?)",id,employee,employee);
        db.update("UPDATE crm_customer_follow_tasks SET owner_id=? WHERE customer_id=? AND state<>'done'",employee,id);
    }

    public List<Map<String,Object>> pendingTasks(Long employee) {
        permissions.require(employee,"followup.board");
        var tasks = new java.util.ArrayList<Map<String,Object>>();
        for (var member : members(employee)) {
            tasks.addAll(db.queryForList("""
                SELECT t.id,c.name AS customer,t.customer_id AS customerId,t.due_date AS due,
                       t.content,e.name AS owner
                FROM crm_customer_follow_tasks t JOIN crm_customers c ON c.id=t.customer_id
                JOIN crm_employees e ON e.id=t.owner_id
                WHERE t.owner_id=? AND t.state<>'done' AND c.merged_into_id IS NULL AND c.owner_id IS NOT NULL
                """,id(member,"id")));
        }
        return tasks;
    }

    private void refresh(long owner) {
        db.update("""
            UPDATE crm_customer_follow_tasks
            SET state=CASE WHEN due_date<CURDATE() THEN 'overdue' WHEN due_date=CURDATE() THEN 'due' ELSE 'plan' END
            WHERE owner_id=? AND state<>'done'
            """,owner);
    }

    private List<Map<String,Object>> members(long employee) {
        var points = auth.current(employee).permissions();
        return db.queryForList("""
            WITH RECURSIVE tree AS (
                SELECT department_id AS id FROM crm_employees WHERE id=?
                UNION ALL SELECT d.id FROM crm_departments d JOIN tree t ON d.parent_id=t.id
            )
            SELECT e.id,e.name,d.id AS deptId,d.name AS dept,
                   (SELECT GROUP_CONCAT(r.name ORDER BY r.id SEPARATOR ' / ') FROM crm_employee_roles er
                    JOIN crm_roles r ON r.id=er.role_id WHERE er.employee_id=e.id) AS role
            FROM crm_employees e JOIN crm_departments d ON d.id=e.department_id
            WHERE e.status='active' AND e.deleted_at IS NULL
              AND (? OR e.id=? OR (? AND d.id IN (SELECT id FROM tree)))
            ORDER BY d.id,e.name,e.id
            """,employee,points.contains("data.scope.all"),employee,points.contains("data.scope.dept"));
    }

    private long id(Map<String,Object> row,String key) { return ((Number)row.get(key)).longValue(); }
    private void forbidden() { throw new ResponseStatusException(HttpStatus.FORBIDDEN); }
    public record Task(Boolean done,LocalDate dueDate) {}
}

