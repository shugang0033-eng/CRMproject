package com.crm.profile.mapper;

import com.crm.profile.model.LoginRecord;
import com.crm.profile.model.Profile;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface ProfileMapper {
    @Select("""
        SELECT e.id, e.username, e.employee_no, e.name, d.name, d.id,
               (SELECT GROUP_CONCAT(r.name ORDER BY r.id SEPARATOR ' / ')
                FROM crm_employee_roles er JOIN crm_roles r ON r.id = er.role_id WHERE er.employee_id = e.id),
               (SELECT r.code FROM crm_employee_roles er JOIN crm_roles r ON r.id = er.role_id
                WHERE er.employee_id = e.id ORDER BY r.id LIMIT 1),
               e.phone, e.email, e.avatar, e.hire_date, e.status, l.logged_at, l.ip,
               e.password_updated_at, e.password_updated_at IS NULL
        FROM crm_employees e JOIN crm_departments d ON d.id = e.department_id
        LEFT JOIN crm_employee_logins l ON l.id = (
            SELECT id FROM crm_employee_logins WHERE employee_id = e.id AND id != #{loginId}
            ORDER BY logged_at DESC, id DESC LIMIT 1
        )
        WHERE e.id = #{id}
        """)
    Profile find(long id, String loginId);

    @Update("UPDATE crm_employees SET name = #{name}, phone = #{phone}, email = #{email} WHERE id = #{id}")
    void update(long id, String name, String phone, String email);

    @Update("UPDATE crm_employees SET avatar = #{avatar} WHERE id = #{id}")
    void updateAvatar(long id, String avatar);

    @Update("""
        UPDATE crm_employees SET password_hash = #{newHash}, password_updated_at = CURRENT_TIMESTAMP
        WHERE id = #{id} AND password_hash = #{oldHash} AND status = 'active' AND deleted_at IS NULL
        """)
    int updatePassword(long id, String oldHash, String newHash);

    @Insert("INSERT INTO crm_employee_logins (id, employee_id, device, ip) VALUES (#{loginId}, #{id}, #{device}, #{ip})")
    void recordLogin(long id, String loginId, String device, String ip);

    @Select("""
        SELECT id, device, ip, logged_at, id = #{loginId}
        FROM crm_employee_logins WHERE employee_id = #{id} ORDER BY logged_at DESC, id DESC LIMIT 10
        """)
    List<LoginRecord> logins(long id, String loginId);
}
