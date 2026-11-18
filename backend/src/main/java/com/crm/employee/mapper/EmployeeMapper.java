package com.crm.employee.mapper;

import com.crm.employee.model.Employee;
import com.crm.employee.model.EmployeeForm;
import org.apache.ibatis.annotations.*;

import java.util.List;
import java.util.Map;

@Mapper
public interface EmployeeMapper {
    String SELECT_EMPLOYEE = """
        SELECT e.id, e.employee_no, e.username, e.name, e.department_id,
               d.name AS department_name, e.phone, e.email, e.hire_date, e.status,
               (SELECT GROUP_CONCAT(r.name ORDER BY r.id SEPARATOR '、')
                FROM crm_employee_roles er JOIN crm_roles r ON r.id = er.role_id
                WHERE er.employee_id = e.id) AS role_names
        FROM crm_employees e JOIN crm_departments d ON d.id = e.department_id
        WHERE e.deleted_at IS NULL
        """;

    @Select("<script>" + SELECT_EMPLOYEE + """
        <if test="keyword != null and keyword != ''">
          AND (LOCATE(#{keyword}, e.name) > 0 OR LOCATE(#{keyword}, e.employee_no) > 0
               OR LOCATE(#{keyword}, e.username) > 0 OR LOCATE(#{keyword}, e.phone) > 0)
        </if>
        <if test="departmentId != null">AND e.department_id = #{departmentId}</if>
        <if test="status != null">AND e.status = #{status}</if>
        ORDER BY e.id DESC
        </script>
        """)
    List<Employee> findAll(String keyword, Long departmentId, String status);

    @Select(SELECT_EMPLOYEE + " AND e.id = #{id}")
    Employee findById(long id);

    @Insert("""
        INSERT INTO crm_employees (employee_no, username, name, department_id, phone, email, hire_date, status, password_hash)
        VALUES (#{employeeNo}, #{form.username}, #{form.name}, #{form.departmentId}, #{form.phone},
                #{form.email}, COALESCE(#{form.hireDate}, CURRENT_DATE), COALESCE(#{form.status}, 'active'), #{passwordHash})
        """)
    @Options(useGeneratedKeys = true, keyProperty = "id")
    void insert(Map<String, Object> employee);

    @Update("""
        UPDATE crm_employees
        SET username = #{form.username}, name = #{form.name}, department_id = #{form.departmentId},
            phone = #{form.phone}, email = #{form.email},
            hire_date = COALESCE(#{form.hireDate}, hire_date), status = COALESCE(#{form.status}, status)
        WHERE id = #{id} AND deleted_at IS NULL
        """)
    int update(long id, EmployeeForm form);

    @Update("UPDATE crm_employees SET status = #{status} WHERE id = #{id} AND deleted_at IS NULL")
    int updateStatus(long id, String status);

    @Update("UPDATE crm_employees SET deleted_at = CURRENT_TIMESTAMP WHERE id = #{id} AND deleted_at IS NULL")
    int softDelete(long id);
    @Update("UPDATE crm_employees SET department_id=#{departmentId} WHERE id=#{id} AND deleted_at IS NULL")
    int updateDepartment(long id,long departmentId);

}

