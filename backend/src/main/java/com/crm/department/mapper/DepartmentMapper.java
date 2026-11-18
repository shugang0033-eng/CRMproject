package com.crm.department.mapper;

import com.crm.department.model.DepartmentNode;
import com.crm.department.model.LeaderOption;
import org.apache.ibatis.annotations.*;
import java.util.List;
import java.util.Map;

@Mapper
public interface DepartmentMapper {
    @Select("""
        SELECT d.id, d.parent_id, d.name, d.sort_order, e.id AS leader_id, e.name AS leader,
               (SELECT COUNT(*) FROM crm_employees m
                WHERE m.department_id = d.id AND m.deleted_at IS NULL) AS count
        FROM crm_departments d
        LEFT JOIN crm_department_managers dm ON dm.department_id = d.id
        LEFT JOIN crm_employees e ON e.id = dm.employee_id AND e.deleted_at IS NULL
        ORDER BY d.sort_order, d.id
        """)
    @ConstructorArgs({
        @Arg(column = "id", javaType = Long.class),
        @Arg(column = "parent_id", javaType = Long.class),
        @Arg(column = "name", javaType = String.class),
        @Arg(column = "sort_order", javaType = int.class),
        @Arg(column = "leader_id", javaType = Long.class),
        @Arg(column = "leader", javaType = String.class),
        @Arg(column = "count", javaType = long.class)
    })
    List<DepartmentNode> findAll();

    @Select("""
        SELECT id, name, employee_no FROM crm_employees
        WHERE deleted_at IS NULL AND status = 'active'
        ORDER BY name, id
        """)
    List<LeaderOption> findLeaderOptions();

    @Delete("DELETE FROM crm_departments WHERE id = #{id}")
    int delete(long id);

    @Select("SELECT EXISTS(SELECT 1 FROM crm_departments WHERE id = #{id})")
    boolean exists(long id);

    @Select("""
        SELECT EXISTS(SELECT 1 FROM crm_employees
                      WHERE id = #{id} AND deleted_at IS NULL AND status = 'active')
        """)
    boolean canLead(long id);

    @Insert("INSERT INTO crm_departments (name, parent_id, sort_order) VALUES (#{name}, #{parentId}, #{sortOrder})")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    void insert(Map<String, Object> department);

    @Update("""
        UPDATE crm_departments SET name = #{name}, sort_order = COALESCE(#{sortOrder}, sort_order)
        WHERE id = #{id}
        """)
    void update(long id, String name, Integer sortOrder);

    @Delete("DELETE FROM crm_department_managers WHERE department_id = #{id}")
    void clearLeader(long id);

    @Insert("""
        INSERT INTO crm_department_managers (department_id, employee_id) VALUES (#{id}, #{leaderId})
        """)
    void insertLeader(long id, long leaderId);
}

