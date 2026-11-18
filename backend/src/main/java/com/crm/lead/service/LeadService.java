package com.crm.lead.service;

import com.crm.auth.service.AuthService;
import com.crm.lead.mapper.LeadMapper;
import com.crm.lead.model.Assignee;
import com.crm.lead.model.LeadMove;
import com.crm.lead.model.LeadForm;
import com.crm.common.DocCode;
import org.springframework.jdbc.core.JdbcTemplate;
import com.crm.lead.model.LeadConflict;
import com.crm.lead.model.LeadRow;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.ArrayList;
import java.util.Locale;

@Service
public class LeadService {
    private final LeadMapper mapper;
    private final JdbcTemplate db;
    private final AuthService auth;

    public LeadService(LeadMapper mapper, AuthService auth, JdbcTemplate db) {
        this.mapper = mapper;
        this.auth = auth;
        this.db = db;
    }

    @Transactional
    public String create(Long employee, LeadForm form) {
        require(employee, "lead.create");
        if (form.company() == null || form.company().isBlank() || form.company().length() > 200
                || form.contact() == null || form.contact().isBlank() || form.contact().length() > 100
                || form.source() == null || form.source().isBlank() || form.source().length() > 50
                || form.level() == null || !List.of("A", "B", "C").contains(form.level())
                || (form.phone() != null && form.phone().length() > 32)
                || (form.industry() != null && form.industry().length() > 100)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
        }
        String id = DocCode.next(db, "LD", "crm_leads", "lead_no");
        mapper.create(id, employee, form);
        return id;
    }

    public List<LeadRow> list(Long employee, boolean pool) {
        require(employee, pool ? "lead.pool" : "lead.view");
        return mapper.list(employee, pool, "lead.view");
    }

    public List<Assignee> assignees(Long employee, String keyword) {
        require(employee, "lead.transfer", "lead.pool.assign");
        return mapper.assignees(keyword);
    }

    public List<LeadConflict> conflicts(Long employee, LeadMove form) {
        require(employee, "lead.transfer", "lead.pool.assign");
        if (form.ids() == null || form.ids().isEmpty()) return List.of();

        var permissions = auth.current(employee).permissions();
        var visible = new ArrayList<LeadRow>();
        if (permissions.contains("lead.view")) visible.addAll(mapper.list(employee, false, "lead.view"));
        if (permissions.contains("lead.pool")) visible.addAll(mapper.list(employee, true, "lead.view"));

        var items = new ArrayList<LeadConflict>();
        for (LeadRow lead : visible) {
            if (!form.ids().contains(lead.id())) continue;
            String company = companyKey(lead.company());
            String phone = phoneKey(lead.phone());
            for (LeadRow other : visible) {
                if (lead.id().equals(other.id()) || "invalid".equals(other.status())) continue;
                if (form.ownerId() != null && form.ownerId().equals(other.ownerId())) continue;
                boolean sameCompany = !company.isEmpty() && company.equals(companyKey(other.company()));
                boolean samePhone = !phone.isEmpty() && phone.equals(phoneKey(other.phone()));
                if (!sameCompany && !samePhone) continue;

                String type = form.ids().contains(other.id()) ? "duplicate" : other.inPool() ? "pool" : "lead";
                items.add(new LeadConflict(lead.id(), lead.company(), type, other.id(), other.company(),
                        other.owner(), other.ownerId(), other.status(), other.source()));
            }
        }
        return items;
    }

    private String companyKey(String company) {
        return company.replaceAll("(?U)\\s+", "").toLowerCase(Locale.ROOT);
    }

    private String phoneKey(String phone) {
        if (phone == null || phone.contains("*")) return "";
        String digits = phone.replaceAll("\\D", "");
        return digits.length() >= 7 ? digits : "";
    }

    @Transactional
    public void move(Long employee, List<String> ids, LeadMove form, boolean assign) {
        require(employee, assign ? "lead.pool.assign" : "lead.transfer");
        if (ids == null || ids.isEmpty() || form.ownerId() == null || mapper.activeEmployee(form.ownerId()) == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "请选择线索和在职接收人");
        }

        String reason = form.reason() == null ? "" : form.reason().strip();
        if (form.note() != null && !form.note().isBlank()) {
            reason = (reason + " " + form.note().strip()).strip();
        }
        if (reason.length() > 255) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "原因和备注合计不能超过 255 字符");
        }

        for (String id : ids.stream().distinct().sorted().toList()) {
            LeadRow lead = mapper.lock(id);
            if (lead == null) {
                throw new ResponseStatusException(HttpStatus.NOT_FOUND, "线索不存在");
            }
            if (("won".equals(lead.status()) || "converted".equals(lead.status())) || "invalid".equals(lead.status())) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "线索已转化或已标记无效，不能流转");
            }
            /* 分配：只处理还没有负责人的线索（新线索直接派、池内回收线索再派）；
               有主的改派属于转移。别再要求线索必须已经在池里，否则运营在
               「销售线索」里分新线索永远 409 */
            if (assign && lead.ownerId() != null) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "线索已有负责人，请用转移");
            }
            if (!assign && lead.ownerId() == null) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "线索还没有负责人，请用分配");
            }
            if (!mapper.canAccess(employee, id, assign ? "lead.pool.assign" : "lead.transfer")) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN);
            }
            if (form.ownerId().equals(lead.ownerId())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "接收人已是当前负责人");
            }
            mapper.move(id, form.ownerId());
            mapper.history(id, assign ? "assign" : "transfer", lead.ownerId(), form.ownerId(), employee, reason);
        }
    }

    public boolean has(Long employee,String permission) {
        return employee != null && auth.current(employee).permissions().contains(permission);
    }

    public void require(Long employee, String... permissions) {
        if (employee == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        }
        var granted = auth.current(employee).permissions();
        for (String permission : permissions) {
            if (granted.contains(permission)) return;
        }
        throw new ResponseStatusException(HttpStatus.FORBIDDEN);
    }
}






