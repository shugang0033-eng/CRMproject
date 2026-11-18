package com.crm.customer.mapper;

import com.crm.customer.model.CustomerContact;
import com.crm.customer.model.CustomerRow;
import org.apache.ibatis.annotations.*;

import java.util.List;

import static com.crm.lead.mapper.LeadMapper.DEPARTMENT_TREE;
import static com.crm.lead.mapper.LeadMapper.SALES_SCOPE;

@Mapper
public interface CustomerMapper {
    @Insert("""
        INSERT INTO crm_customers (source_lead_id, name, industry, level, owner_id, created_by, phone, source, region)
        SELECT id, company, industry, level, owner_id, #{employee}, phone, source, NULLIF(CONCAT_WS(' · ',province,city),'') FROM crm_leads WHERE lead_no = #{leadNo}
        """)
    void createFromLead(String leadNo, long employee);

    @Insert("""
        INSERT INTO crm_customer_contacts (customer_id, name, phone, is_primary)
        SELECT c.id, l.contact, l.phone, 1 FROM crm_customers c
        JOIN crm_leads l ON l.id = c.source_lead_id WHERE l.lead_no = #{leadNo}
        """)
    void copyContact(String leadNo);

    @Select(DEPARTMENT_TREE + """
        SELECT l.id, l.code, DATE(l.created_at) AS createdAt, l.name, l.industry, l.level, l.owner_id, e.name AS owner, l.region, l.last_follow_at AS lastFollowAt,
               t.amount,t.orders,t.lastOrderAt,t.hasDeal,
               IF(#{payment},t.received,NULL) AS received,
               IF(#{payment},t.receivable,NULL) AS receivable,
               IF(#{payment},t.overdue,NULL) AS overdue,
               CASE WHEN NOT t.hasDeal THEN '跟进中' WHEN t.overdue>0 AND #{payment} THEN '待回款'
                    WHEN DATEDIFF(CURDATE(),t.lastOrderAt)>90 THEN '流失风险' ELSE '合作中' END AS status,
               (SELECT COUNT(*) FROM crm_customer_contacts c WHERE c.customer_id = l.id) AS contacts
        FROM crm_customers l JOIN crm_employees e ON e.id = l.owner_id JOIN crm_customer_trade t ON t.id=l.id
        WHERE l.merged_into_id IS NULL AND
        """ + SALES_SCOPE + " ORDER BY l.id DESC")
    List<java.util.Map<String,Object>> list(long employee, String permission, boolean payment);

    @Select(DEPARTMENT_TREE + """
        SELECT c.id, c.name, l.name AS customer, IF(LENGTH(c.phone)>7 AND LOCATE('*',c.phone)=0,CONCAT(LEFT(c.phone,3),'****',RIGHT(c.phone,4)),c.phone) AS phone, e.name AS owner
        FROM crm_customer_contacts c JOIN crm_customers l ON l.id = c.customer_id
        JOIN crm_employees e ON e.id = l.owner_id WHERE l.merged_into_id IS NULL AND
        """ + SALES_SCOPE + " ORDER BY c.id DESC")
    List<CustomerContact> contacts(long employee, String permission);

    @Select("SELECT owner_id FROM crm_customers WHERE id = #{id} AND merged_into_id IS NULL FOR UPDATE")
    Long lockOwner(long id);

    @Select(DEPARTMENT_TREE + """
        SELECT EXISTS (SELECT 1 FROM crm_customers l JOIN crm_employees e ON e.id = l.owner_id JOIN crm_customer_trade t ON t.id=l.id
                       WHERE l.id = #{id} AND l.merged_into_id IS NULL AND
        """ + SALES_SCOPE + ")")
    boolean canAccess(long employee, long id, String permission);

    @Update("UPDATE crm_customers SET owner_id = #{ownerId}, pool_entered_at = IF(#{ownerId} IS NULL,NOW(),NULL), pool_reason = IF(#{ownerId} IS NULL,#{reason},NULL) WHERE id = #{id}")
    void move(long id, Long ownerId, String reason);

    @Update("UPDATE crm_customer_follow_tasks SET owner_id = #{ownerId} WHERE customer_id = #{id} AND state <> 'done'")
    void moveTasks(long id, long ownerId);

    @Insert("""
        INSERT INTO crm_customer_transfers (customer_id, previous_owner_id, owner_id, operator_id, reason)
        VALUES (#{id}, #{previousOwner}, #{ownerId}, #{employee}, #{reason})
        """)
    void history(long id, Long previousOwner, Long ownerId, long employee, String reason);
}







