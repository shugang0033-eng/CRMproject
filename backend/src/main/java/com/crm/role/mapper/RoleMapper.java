package com.crm.role.mapper;

import com.crm.role.model.Role;
import com.crm.role.model.RoleForm;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface RoleMapper {
    @Select("""
        SELECT r.id, r.name, r.code, r.description, r.is_builtin,
               (SELECT COUNT(*) FROM crm_employee_roles er JOIN crm_employees e ON e.id = er.employee_id
                WHERE er.role_id = r.id AND e.deleted_at IS NULL) AS members
        FROM crm_roles r ORDER BY r.id
        """)
    @ConstructorArgs({
        @Arg(column = "id", javaType = Long.class),
        @Arg(column = "name", javaType = String.class),
        @Arg(column = "code", javaType = String.class),
        @Arg(column = "description", javaType = String.class),
        @Arg(column = "is_builtin", javaType = boolean.class),
        @Arg(column = "members", javaType = long.class)
    })
    List<Role> findAll();

    @Select("""
        SELECT rp.role_id, p.code FROM crm_role_permissions rp
        JOIN crm_permissions p ON p.id = rp.permission_id ORDER BY rp.role_id, p.code
        """)
    List<RolePermission> findPermissions();

    record RolePermission(Long roleId, String code) {}

    @Insert("INSERT INTO crm_roles (name, code, description) VALUES (#{name}, #{code}, #{desc})")
    void insert(RoleForm form);

    @Select("SELECT id FROM crm_roles WHERE code = #{code}")
    long findId(String code);

    @Update("UPDATE crm_roles SET name = #{form.name}, description = #{form.desc} WHERE id = #{id}")
    int update(long id, RoleForm form);

    @Delete("DELETE FROM crm_role_permissions WHERE role_id = #{id}")
    void clearPermissions(long id);

    @Insert("INSERT INTO crm_role_permissions SELECT #{id}, p.id FROM crm_permissions p WHERE p.code = #{code}")
    int addPermission(long id, String code);

    @Select("SELECT is_builtin FROM crm_roles WHERE id = #{id} FOR UPDATE")
    Boolean lockBuiltinFlag(long id);

    @Select("""
        SELECT EXISTS(SELECT 1 FROM crm_employee_roles er JOIN crm_employees e ON e.id = er.employee_id
                      WHERE er.role_id = #{id} AND e.deleted_at IS NULL)
        """)
    boolean hasMembers(long id);

    @Delete("DELETE FROM crm_roles WHERE id = #{id}")
    void delete(long id);

    @Select("SELECT id FROM crm_employees WHERE id = #{id} AND deleted_at IS NULL FOR UPDATE")
    Long lockEmployee(long id);

    @Select("SELECT role_id FROM crm_employee_roles WHERE employee_id = #{id} ORDER BY role_id")
    List<Long> employeeRoles(long id);

    @Delete("DELETE FROM crm_employee_roles WHERE employee_id = #{id}")
    void clearEmployeeRoles(long id);

    @Insert("INSERT INTO crm_employee_roles SELECT #{id}, r.id FROM crm_roles r WHERE r.id = #{roleId}")
    int addEmployeeRole(long id, long roleId);
}


