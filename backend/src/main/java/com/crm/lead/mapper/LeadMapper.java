package com.crm.lead.mapper;

import com.crm.lead.model.Assignee;
import com.crm.lead.model.LeadRow;
import com.crm.lead.model.LeadForm;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface LeadMapper {
    @Insert("""
        INSERT INTO crm_leads(lead_no,company,contact,phone,source,industry,level,note,created_by,stage_entered_at)
        VALUES(#{id},#{form.company},#{form.contact},#{form.phone},#{form.source},#{form.industry},
               #{form.level},#{form.note},#{employee},NOW())
        """)
    void create(String id, long employee, LeadForm form);

    String COLUMNS = """
        SELECT l.lead_no, l.company, l.contact, l.phone, l.source, l.industry, l.level,
               l.status, l.owner_id, e.name, CONCAT_WS(' · ', l.province, l.city),
               l.pool_reason, COALESCE(l.pool_entered_at, l.created_at), l.pool_entered_at IS NOT NULL
        FROM crm_leads l LEFT JOIN crm_employees e ON e.id = l.owner_id
        """;

    String DEPARTMENT_TREE = """
        WITH RECURSIVE department_tree AS (
            SELECT department_id AS id FROM crm_employees WHERE id = #{employee}
            UNION ALL
            SELECT d.id FROM crm_departments d JOIN department_tree t ON d.parent_id = t.id
        )
        """;

    String SALES_SCOPE = """
        EXISTS (
            SELECT 1 FROM crm_employee_roles er
            JOIN crm_roles r ON r.id = er.role_id
            JOIN crm_role_permissions rp ON rp.role_id = r.id
            JOIN crm_permissions p ON p.id = rp.permission_id
            JOIN crm_employees actor ON actor.id = er.employee_id
            WHERE er.employee_id = #{employee} AND p.code = #{permission}
              AND (r.data_scope = 'all' OR l.owner_id = actor.id
                   OR (l.owner_id IS NULL AND l.created_by = actor.id)
                   OR (r.data_scope = 'department' AND e.department_id = actor.department_id)
                   OR (r.data_scope = 'department_tree' AND e.department_id IN (SELECT id FROM department_tree)))
        )
        """;

    @Select(DEPARTMENT_TREE + COLUMNS + """
        WHERE (l.pool_entered_at IS NOT NULL) = #{pool}
          AND (#{pool} OR\s""" + SALES_SCOPE + """
        )
        ORDER BY COALESCE(l.pool_entered_at, l.created_at) DESC, l.id DESC
        """)
    List<LeadRow> list(long employee, boolean pool, String permission);

    @Select(DEPARTMENT_TREE + "SELECT EXISTS (SELECT 1 FROM crm_leads l "
        + "LEFT JOIN crm_employees e ON e.id = l.owner_id WHERE l.lead_no = #{id} AND " + SALES_SCOPE + ")")
    boolean canAccess(long employee, String id, String permission);

    @Select(COLUMNS + " WHERE l.lead_no = #{id} FOR UPDATE")
    LeadRow lock(String id);

    @Select("""
        SELECT e.id, e.name, d.name AS department,
               (SELECT GROUP_CONCAT(r.name ORDER BY r.id)
                FROM crm_employee_roles er JOIN crm_roles r ON r.id = er.role_id WHERE er.employee_id = e.id),
               (SELECT COUNT(*) FROM crm_leads l WHERE l.owner_id = e.id AND l.status IN ('pending','contacted')),
               NULL
        FROM crm_employees e JOIN crm_departments d ON d.id = e.department_id
        WHERE e.status = 'active' AND e.deleted_at IS NULL
          AND (LOCATE(#{keyword}, e.name) > 0 OR LOCATE(#{keyword}, e.username) > 0 OR #{keyword} = '')
        ORDER BY e.name, e.id
        """)
    List<Assignee> assignees(String keyword);

    @Select("SELECT id FROM crm_employees WHERE id = #{id} AND status = 'active' AND deleted_at IS NULL FOR SHARE")
    Long activeEmployee(long id);

    @Update("UPDATE crm_leads SET status = 'won', stage_entered_at = NOW() WHERE lead_no = #{id}")
    void markConverted(String id);

    @Update("UPDATE crm_leads SET owner_id = #{ownerId}, pool_entered_at = NULL, pool_reason = NULL WHERE lead_no = #{id}")
    void move(String id, long ownerId);

    @Insert("""
        INSERT INTO crm_lead_owner_history (lead_id, action, previous_owner_id, new_owner_id, operator_id, reason)
        SELECT id, #{action}, #{previousOwner}, #{ownerId}, #{operator}, #{reason}
        FROM crm_leads WHERE lead_no = #{id}
        """)
    void history(String id, String action, Long previousOwner, long ownerId, long operator, String reason);
}






