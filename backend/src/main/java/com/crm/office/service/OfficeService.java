package com.crm.office.service;

import com.crm.common.DocCode;

import com.crm.auth.service.AuthService;
import com.crm.office.model.OfficeForm;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import java.math.BigDecimal;
import java.time.*;
import java.time.temporal.ChronoUnit;
import java.util.*;

@Service
public class OfficeService {
    private final JdbcTemplate db;
    private final AuthService auth;

    public OfficeService(JdbcTemplate db,AuthService auth) {
        this.db=db;
        this.auth=auth;
    }

    public enum Kind {
        EXPENSE("expenses","expense","费用报销","审批中","FY"),
        LOAN("loans","loan","借款预支","待审批","JK"),
        LEAVE("leaves","leave","请假申请","待审批","QJ");

        final String path,permission,label,pending,prefix;
        Kind(String path,String permission,String label,String pending,String prefix) {
            this.path=path; this.permission=permission; this.label=label; this.pending=pending; this.prefix=prefix;
        }
        public static Kind of(String value) {
            for (Kind k:values()) if (List.of(k.path,k.label,k.permission).contains(value)) return k;
            throw error(HttpStatus.NOT_FOUND);
        }
        String table(){ return "crm_"+path; }
    }

    private List<String> grants(Long employee) {
        if(employee==null) throw error(HttpStatus.UNAUTHORIZED);
        return auth.current(employee).permissions();
    }

    private void require(List<String> grants,String code) {
        if(!grants.contains(code)) throw error(HttpStatus.FORBIDDEN);
    }

    private boolean inScope(long employee,long dept,List<String> grants) {
        if(grants.contains("data.scope.all")) return true;
        return Boolean.TRUE.equals(db.queryForObject("""
            WITH RECURSIVE tree AS (SELECT department_id AS id FROM crm_employees WHERE id=?
              UNION ALL SELECT d.id FROM crm_departments d JOIN tree t ON d.parent_id=t.id)
            SELECT EXISTS(SELECT 1 FROM tree WHERE id=?)
            """,Boolean.class,employee,dept));
    }

    private boolean canRead(long employee,Kind kind,Map<String,Object> row,List<String> grants) {
        return number(row,"applicantId")==employee ||
            (grants.contains(kind.permission+".approve") && inScope(employee,number(row,"deptId"),grants));
    }

    private List<Map<String,Object>> rows(Kind kind,Long id) {
        String extra=switch(kind) {
            case EXPENSE -> """
                ,o.total_amount AS totalAmount,o.bill_count AS billCount,o.project_name AS projectName,
                COALESCE((SELECT GROUP_CONCAT(DISTINCT i.type) FROM crm_expense_items i WHERE i.expense_id=o.id),'') AS type
                """;
            case LOAN -> """
                ,o.due_date AS dueDate,o.pay_date AS payDate,
                COALESCE((SELECT SUM(w.amount) FROM crm_loan_writeoffs w WHERE w.loan_id=o.id),0) AS clearedAmount
                """;
            case LEAVE -> ",o.start_date AS start,o.end_date AS end,h.name AS handover";
        };
        var rows=db.queryForList("SELECT o.*,o.id AS docId,o.applicant_id AS applicantId,o.dept_id AS deptId,"
            +"o.apply_date AS applyDate,e.name AS applicant,d.name AS dept,a.name AS approver"+extra
            +" FROM "+kind.table()+" o JOIN crm_employees e ON e.id=o.applicant_id"
            +" JOIN crm_departments d ON d.id=o.dept_id LEFT JOIN crm_employees a ON a.id=o.approver_id"
            +(kind==Kind.LEAVE?" LEFT JOIN crm_employees h ON h.id=o.handover_id":"")
            +" WHERE (? IS NULL OR o.id=?) ORDER BY o.id DESC",id,id);
        if(kind==Kind.LOAN) rows.forEach(r -> r.put("openAmount","已通过".equals(r.get("status"))
            ? ((BigDecimal)r.get("amount")).subtract((BigDecimal)r.get("clearedAmount")) : BigDecimal.ZERO));
        return rows;
    }

    public Map<String,Object> list(Long employee,Kind kind,Map<String,String> q) {
        var grants=grants(employee);
        require(grants,kind.permission+".view");
        return page(rows(kind,null).stream().filter(r -> canRead(employee,kind,r,grants)).filter(r -> matches(r,q)).toList(),q);
    }

    public Object detail(Long employee,Kind kind,long id) {
        var grants=grants(employee);
        require(grants,kind.permission+".view");
        var row=readable(employee,kind,id,grants);
        return switch(kind) {
            case EXPENSE -> {
                var result=new LinkedHashMap<String,Object>();
                result.put("expense",row);
                result.put("items",db.queryForList("SELECT occur_date AS date,type,amount,note,bills FROM crm_expense_items WHERE expense_id=? ORDER BY sort_no,id",id));
                result.put("attachments",db.queryForList("SELECT file_name AS name,file_id AS fileId FROM crm_expense_attachments WHERE expense_id=?",id));
                result.put("trip",row.get("trip_start")==null ? null : Map.of("from",row.get("trip_from"),"to",row.get("trip_to"),
                    "start",row.get("trip_start"),"end",row.get("trip_end"),"days",row.get("trip_days")));
                result.put("deduct",row.get("deduct_loan_id")==null ? null : Map.of("loanId",row.get("deduct_loan_id"),"amount",row.get("deduct_amount")));
                result.put("approvals",logs(kind,id));
                yield result;
            }
            case LOAN -> Map.of("loan",row,"writeOffs",db.queryForList("SELECT * FROM crm_loan_writeoffs WHERE loan_id=? ORDER BY id DESC",id));
            case LEAVE -> row;
        };
    }

    @Transactional
    public Object create(Long employee,Kind kind,OfficeForm f) {
        require(grants(employee),kind.permission+".create");
        long dept=lockEmployee(employee);
        if(f.requestId()!=null && !f.requestId().isBlank()) {
            var prior=db.queryForList("SELECT id,code,status,applicant_id FROM "+kind.table()+" WHERE request_id=?",f.requestId());
            if(!prior.isEmpty()) {
                var row=prior.get(0);
                if(number(row,"applicant_id")!=employee) throw error(HttpStatus.CONFLICT);
                return Map.of("id",row.get("id"),"code",row.get("code"),"status",row.get("status"));
            }
        }
        String code=DocCode.next(db,kind.prefix,kind.table());
        LocalDate today=LocalDate.now();
        switch(kind) {
            case EXPENSE -> createExpense(employee,dept,code,f,today);
            case LOAN -> {
                positive(f.amount());
                if(blank(f.purpose()) || !Set.of("差旅预支","备用金","采购垫付").contains(text(f.type()))) bad();
                if(f.dueDate()!=null && f.dueDate().isBefore(today)) throw error(HttpStatus.UNPROCESSABLE_ENTITY);
                db.update("""
                    INSERT INTO crm_loans(code,applicant_id,dept_id,type,amount,purpose,apply_date,due_date,request_id,created_by)
                    VALUES(?,?,?,?,?,?,?,?,?,?)
                    """,code,employee,dept,f.type(),f.amount(),f.purpose(),today,f.dueDate(),f.requestId(),employee);
            }
            case LEAVE -> {
                if(f.start()==null) throw new LeaveError("LEAVE_START_REQUIRED","start","请选择开始日期");
                if(f.end()==null || f.end().isBefore(f.start()))
                    throw new LeaveError("LEAVE_DATE_RANGE","end","结束日期不能早于开始日期，请检查请假区间");
                if(f.end().getYear()!=f.start().getYear())
                    throw new LeaveError("LEAVE_CROSS_YEAR","end","跨年请假请分开提交");
                if(blank(f.reason())) throw new LeaveError("LEAVE_REASON_REQUIRED","reason","请填写请假事由");
                if(!Set.of("年假","病假","事假","调休").contains(text(f.type())))
                    throw new LeaveError("LEAVE_TYPE_INVALID","type","请选择有效的请假类型");
                long days=f.start().datesUntil(f.end().plusDays(1))
                    .filter(d -> d.getDayOfWeek().getValue()<6).count();
                if(days==0) throw new LeaveError("LEAVE_NO_WORKDAYS","end","所选日期内没有工作日");
                if(db.queryForObject("""
                    SELECT COUNT(*) FROM crm_leaves WHERE applicant_id=? AND start_date<=? AND end_date>=?
                    AND status IN ('待审批','已通过')
                    """,Long.class,employee,f.end(),f.start())>0) throw error(HttpStatus.CONFLICT);
                if(!"事假".equals(f.type()) && remaining(employee,f.start().getYear(),f.type()).compareTo(BigDecimal.valueOf(days))<0)
                    throw error(HttpStatus.UNPROCESSABLE_ENTITY);
                if(f.handoverId()!=null && db.queryForObject("SELECT COUNT(*) FROM crm_employees WHERE id=? AND status='active' AND deleted_at IS NULL",Long.class,f.handoverId())==0) bad();
                db.update("""
                    INSERT INTO crm_leaves(code,applicant_id,dept_id,type,start_date,end_date,days,reason,handover_id,apply_date,request_id,created_by)
                    VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
                    """,code,employee,dept,f.type(),f.start(),f.end(),days,f.reason(),f.handoverId(),today,f.requestId(),employee);
            }
        }
        long id=db.queryForObject("SELECT id FROM "+kind.table()+" WHERE code=?",Long.class,code);
        log(kind,id,"提交",employee,"");
        return Map.of("id",id,"code",code,"status",kind.pending);
    }

    private void createExpense(long employee,long dept,String code,OfficeForm f,LocalDate today) {
        if(f.items()==null || f.items().isEmpty()) bad();
        BigDecimal total=BigDecimal.ZERO;
        int bills=0;
        for(var i:f.items()) {
            positive(i.amount());
            if(i.date()==null || blank(i.note()) || i.bills()<0 ||
                !Set.of("差旅","客户招待","市场活动","物流运费","样品费","办公用品","其他").contains(text(i.type()))) bad();
            total=total.add(i.amount()); bills+=i.bills();
        }
        var trip=f.trip();
        if(f.items().stream().anyMatch(i -> "差旅".equals(i.type())) && trip==null) bad();
        long days=0;
        if(trip!=null) {
            if(blank(trip.from()) || blank(trip.to()) || trip.start()==null || trip.end()==null || trip.end().isBefore(trip.start())) bad();
            days=ChronoUnit.DAYS.between(trip.start(),trip.end())+1;
        }
        var deduct=f.deduct();
        if(deduct!=null) {
            positive(deduct.amount());
            if(deduct.amount().compareTo(total)>0) throw error(HttpStatus.UNPROCESSABLE_ENTITY);
            checkLoan(deduct.loanId(),employee,deduct.amount());
        }
        db.update("""
            INSERT INTO crm_expenses(code,applicant_id,dept_id,project_name,apply_date,total_amount,bill_count,
                trip_from,trip_to,trip_start,trip_end,trip_days,deduct_loan_id,deduct_amount,remark,request_id,created_by)
            VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """,code,employee,dept,text(f.projectName()),f.applyDate()==null?today:f.applyDate(),total,bills,
            trip==null?"":trip.from(),trip==null?"":trip.to(),trip==null?null:trip.start(),trip==null?null:trip.end(),days,
            deduct==null?null:deduct.loanId(),deduct==null?BigDecimal.ZERO:deduct.amount(),text(f.remark()),f.requestId(),employee);
        long id=db.queryForObject("SELECT id FROM crm_expenses WHERE code=?",Long.class,code);
        int sort=0;
        for(var i:f.items()) db.update("INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no) VALUES(?,?,?,?,?,?,?)",
            id,i.date(),i.type(),i.amount(),i.note(),i.bills(),sort++);
        if(f.attachments()!=null) for(var a:f.attachments()) {
            if(blank(a.fileId()) || blank(a.name())) bad();
            db.update("INSERT INTO crm_expense_attachments(expense_id,file_id,file_name) VALUES(?,?,?)",id,a.fileId(),a.name());
        }
    }

    @Transactional
    public void decide(Long employee,Kind kind,long id,String result,String note) {
        var grants=grants(employee);
        require(grants,kind.permission+".approve");
        if(!Set.of("pass","reject").contains(text(result))) bad();
        var initial=one("SELECT applicant_id FROM "+kind.table()+" WHERE id=?",id);
        long applicant=number(initial,"applicant_id");
        lockEmployee(applicant);
        var row=one("SELECT * FROM "+kind.table()+" WHERE id=? FOR UPDATE",id);
        if(applicant==employee || !inScope(employee,number(row,"dept_id"),grants)) throw error(HttpStatus.FORBIDDEN);
        if(!kind.pending.equals(row.get("status"))) throw error(HttpStatus.CONFLICT);
        boolean pass="pass".equals(result);
        if(pass && kind==Kind.EXPENSE && row.get("deduct_loan_id")!=null) {
            long loan=number(row,"deduct_loan_id");
            var amount=(BigDecimal)row.get("deduct_amount");
            checkLoan(loan,applicant,amount);
            db.update("INSERT INTO crm_loan_writeoffs(loan_id,source,expense_id,amount,created_by) VALUES(?,'expense',?,?,?)",
                loan,id,amount,employee);
        }
        if(pass && kind==Kind.LEAVE && !"事假".equals(row.get("type"))) {
            int year=LocalDate.parse(row.get("start_date").toString()).getYear();
            int changed=db.update("""
              UPDATE crm_leave_quotas SET used_days=used_days+? WHERE employee_id=? AND year=? AND type=? AND quota_days-used_days>=?
              """,row.get("days"),applicant,year,row.get("type"),row.get("days"));
            if(changed==0) throw error(HttpStatus.UNPROCESSABLE_ENTITY);
        }
        String extra=pass && kind==Kind.LOAN ? ",pay_date=CURDATE()" : "";
        db.update("UPDATE "+kind.table()+" SET status=?,approver_id=?,approved_at=NOW(),reject_reason=?"+extra+" WHERE id=?",
            pass?"已通过":"已驳回",employee,pass?"":text(note),id);
        log(kind,id,pass?"同意":"驳回",employee,note);
    }

    @Transactional
    public void withdraw(Long employee,Kind kind,long id) {
        require(grants(employee),kind.permission+".create");
        lockEmployee(employee);
        var row=one("SELECT * FROM "+kind.table()+" WHERE id=? FOR UPDATE",id);
        if(number(row,"applicant_id")!=employee) throw error(HttpStatus.FORBIDDEN);
        String status=row.get("status").toString();
        boolean approvedLeave=kind==Kind.LEAVE && "已通过".equals(status)
            && LocalDate.parse(row.get("start_date").toString()).isAfter(LocalDate.now());
        if(!kind.pending.equals(status) && !approvedLeave) throw error(HttpStatus.CONFLICT);
        if(approvedLeave && !"事假".equals(row.get("type"))) {
            int year=LocalDate.parse(row.get("start_date").toString()).getYear();
            db.update("UPDATE crm_leave_quotas SET used_days=GREATEST(0,used_days-?) WHERE employee_id=? AND year=? AND type=?",
                row.get("days"),employee,year,row.get("type"));
        }
        db.update("UPDATE "+kind.table()+" SET status=? WHERE id=?",kind==Kind.LEAVE?"已撤销":"已撤回",id);
        log(kind,id,"撤回",employee,"");
    }

    public Object open(Long employee,Long applicant) {
        var grants=grants(employee);
        if(!grants.contains("expense.create") && !grants.contains("loan.view")) throw error(HttpStatus.FORBIDDEN);
        if(applicant!=null && !applicant.equals(employee)) throw error(HttpStatus.FORBIDDEN);
        return rows(Kind.LOAN,null).stream().filter(r -> number(r,"applicantId")==employee
            && ((BigDecimal)r.get("openAmount")).signum()>0).toList();
    }

    @Transactional
    public void writeOff(Long employee,long id,BigDecimal amount,String source,String note,String requestId) {
        var grants=grants(employee);
        require(grants,"loan.approve");
        positive(amount);
        if(!"cash".equals(source)) bad();
        var row=one("SELECT applicant_id,dept_id FROM crm_loans WHERE id=? FOR UPDATE",id);
        if(!inScope(employee,number(row,"dept_id"),grants) || number(row,"applicant_id")==employee) throw error(HttpStatus.FORBIDDEN);
        if(!blank(requestId) && db.queryForObject("SELECT COUNT(*) FROM crm_loan_writeoffs WHERE loan_id=? AND request_id=?",Long.class,id,requestId)>0) return;
        checkLoan(id,number(row,"applicant_id"),amount);
        db.update("INSERT INTO crm_loan_writeoffs(loan_id,source,amount,note,created_by,request_id) VALUES(?,'cash',?,?,?,?)",
            id,amount,text(note),employee,requestId);
    }

    public Object quota(Long employee,Long applicant,Integer year) {
        require(grants(employee),"leave.view");
        if(applicant!=null && !applicant.equals(employee)) throw error(HttpStatus.FORBIDDEN);
        int y=year==null ? LocalDate.now().getYear() : year;
        var result=new LinkedHashMap<String,Object>();
        for(String type:List.of("年假","病假","调休")) {
            var rows=db.queryForList("SELECT quota_days,used_days FROM crm_leave_quotas WHERE employee_id=? AND year=? AND type=?",employee,y,type);
            var quota=rows.isEmpty()?BigDecimal.ZERO:(BigDecimal)rows.get(0).get("quota_days");
            var used=rows.isEmpty()?BigDecimal.ZERO:(BigDecimal)rows.get(0).get("used_days");
            result.put(type,Map.of("quota",quota,"used",used,"left",quota.subtract(used),"pending",pendingDays(employee,y,type)));
        }
        return result;
    }

    public Object approvals(Long employee,Map<String,String> q) {
        return page(approvalRows(employee,q),q);
    }

    public List<Map<String,Object>> approvalRows(Long employee,Map<String,String> q) {
        var grants=grants(employee);
        require(grants,"approval.view");
        String box=q.getOrDefault("box","pending");
        if(!Set.of("pending","mine","done").contains(box)) bad();
        var result=new ArrayList<Map<String,Object>>();
        for(Kind kind:Kind.values()) {
            if(!blank(q.get("kind")) && Kind.of(q.get("kind"))!=kind) continue;
            for(var r:rows(kind,null)) {
                long applicant=number(r,"applicantId");
                boolean include=switch(box) {
                    case "mine" -> applicant==employee;
                    case "done" -> r.get("approver_id") instanceof Number n && n.longValue()==employee;
                    default -> applicant!=employee && kind.pending.equals(r.get("status"))
                        && grants.contains(kind.permission+".approve") && inScope(employee,number(r,"deptId"),grants);
                };
                if(!include || !matches(r,q)) continue;
                r.put("kind",kind.label);
                r.put("title",kind.label+" · "+r.get("applicant"));
                r.put("amount",kind==Kind.EXPENSE?r.get("totalAmount"):r.get("amount"));
                result.add(r);
            }
        }
        result.sort(Comparator.comparing((Map<String,Object> r) -> r.get("created_at").toString()).reversed());
        return result;
    }

    public Object history(Long employee,Kind kind,long id) {
        var grants=grants(employee);
        require(grants,"approval.view");
        readable(employee,kind,id,grants);
        return logs(kind,id);
    }

    private Map<String,Object> readable(long employee,Kind kind,long id,List<String> grants) {
        var rows=rows(kind,id);
        if(rows.isEmpty()) throw error(HttpStatus.NOT_FOUND);
        var row=rows.get(0);
        if(!canRead(employee,kind,row,grants)) throw error(HttpStatus.FORBIDDEN);
        return row;
    }

    private Object logs(Kind kind,long id) {
        return db.queryForList("""
            SELECT l.action,e.name AS operator,l.note,l.created_at AS at
            FROM crm_approval_logs l JOIN crm_employees e ON e.id=l.operator_id
            WHERE l.kind=? AND l.doc_id=? ORDER BY l.id
            """,kind.label,id);
    }

    private void log(Kind kind,long id,String action,long employee,String note) {
        db.update("INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note) VALUES(?,?,?,?,?)",
            kind.label,id,action,employee,text(note));
    }

    private long lockEmployee(long employee) {
        return number(one("SELECT department_id FROM crm_employees WHERE id=? FOR UPDATE",employee),"department_id");
    }

    private void checkLoan(long loan,long applicant,BigDecimal amount) {
        var row=one("SELECT amount,applicant_id,status FROM crm_loans WHERE id=? FOR UPDATE",loan);
        if(number(row,"applicant_id")!=applicant || !"已通过".equals(row.get("status"))) throw error(HttpStatus.CONFLICT);
        var paid=db.queryForObject("SELECT COALESCE(SUM(amount),0) FROM crm_loan_writeoffs WHERE loan_id=?",BigDecimal.class,loan);
        var remaining=((BigDecimal)row.get("amount")).subtract(paid);
        if(remaining.signum()==0) throw error(HttpStatus.CONFLICT);
        if(remaining.compareTo(amount)<0) throw error(HttpStatus.UNPROCESSABLE_ENTITY);
    }

    private BigDecimal remaining(long employee,int year,String type) {
        var rows=db.queryForList("SELECT quota_days-used_days AS remaining FROM crm_leave_quotas WHERE employee_id=? AND year=? AND type=?",employee,year,type);
        var available=rows.isEmpty()?BigDecimal.ZERO:(BigDecimal)rows.get(0).get("remaining");
        return available.subtract(pendingDays(employee,year,type));
    }

    private BigDecimal pendingDays(long employee,int year,String type) {
        return db.queryForObject("""
            SELECT COALESCE(SUM(days),0) FROM crm_leaves WHERE applicant_id=? AND YEAR(start_date)=? AND type=? AND status='待审批'
            """,BigDecimal.class,employee,year,type);

    }

    private boolean matches(Map<String,Object> r,Map<String,String> q) {
        for(String key:List.of("status","applicantId")) if(!blank(q.get(key)) && !q.get(key).equals(text(r.get(key)))) return false;
        if(!blank(q.get("type")) && !Arrays.asList(text(r.get("type")).split(",")).contains(q.get("type"))) return false;
        String period=q.getOrDefault("period",q.get("month"));
        if(!blank(period) && !text(r.get("applyDate")).startsWith(period)) return false;
        String keyword=q.get("keyword");
        return blank(keyword) || List.of("code","applicant","projectName","purpose","reason").stream()
            .anyMatch(k -> text(r.get(k)).contains(keyword));
    }

    private Map<String,Object> page(List<Map<String,Object>> rows,Map<String,String> q) {
        int page,size;
        try {page=Integer.parseInt(q.getOrDefault("page","1")); size=Integer.parseInt(q.getOrDefault("pageSize","20"));}
        catch(NumberFormatException e){throw error(HttpStatus.BAD_REQUEST);}
        if(page<1 || size<1 || size>500) bad();
        int start=(int)Math.min(rows.size(),(page-1L)*size);
        return Map.of("rows",rows.subList(start,Math.min(rows.size(),start+size)),"total",rows.size());
    }

    private Map<String,Object> one(String sql,Object... args) {
        var rows=db.queryForList(sql,args);
        if(rows.isEmpty()) throw error(HttpStatus.NOT_FOUND);
        return rows.get(0);
    }
    private static long number(Map<String,Object> row,String key){return ((Number)row.get(key)).longValue();}
    private static String text(Object value){return Objects.toString(value,"");}
    private static boolean blank(String value){return value==null || value.isBlank();}
    private static void positive(BigDecimal value){if(value==null || value.signum()<=0 || value.scale()>2) bad();}
    public static class LeaveError extends RuntimeException {
        public final String code;
        public final String field;

        LeaveError(String code,String field,String message) {
            super(message);
            this.code=code;
            this.field=field;
        }
    }

    private static void bad(){throw error(HttpStatus.BAD_REQUEST);}
    private static ResponseStatusException error(HttpStatus status){return new ResponseStatusException(status);}
}



