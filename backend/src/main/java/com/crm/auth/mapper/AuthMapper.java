package com.crm.auth.mapper;

import com.crm.auth.model.LoginAccount;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface AuthMapper {
    String ACTIVE_ACCOUNT = """
        SELECT e.id, e.username, e.name, d.name AS dept, e.password_hash
        FROM crm_employees e JOIN crm_departments d ON d.id = e.department_id
        WHERE e.deleted_at IS NULL AND e.status = 'active'
        """;

    @Select(ACTIVE_ACCOUNT + " AND e.username = #{username}")
    LoginAccount findByUsername(String username);

    @Select(ACTIVE_ACCOUNT + " AND e.id = #{id}")
    LoginAccount findById(long id);

    @Select("""
        SELECT r.name FROM crm_employee_roles er JOIN crm_roles r ON r.id = er.role_id
        WHERE er.employee_id = #{id} ORDER BY r.id
        """)
    List<String> roleNames(long id);

    @Select("""
        SELECT DISTINCT p.code FROM crm_employee_roles er
        JOIN crm_role_permissions rp ON rp.role_id = er.role_id
        JOIN crm_permissions p ON p.id = rp.permission_id
        WHERE er.employee_id = #{id} ORDER BY p.code
        """)
    List<String> permissions(long id);

    @Select("SELECT id FROM crm_employees WHERE password_hash IS NULL AND deleted_at IS NULL")
    List<Long> employeesWithoutPassword();

    @Update("UPDATE crm_employees SET password_hash = #{hash} WHERE id = #{id} AND password_hash IS NULL")
    void initializePassword(long id, String hash);
}

