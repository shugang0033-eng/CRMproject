# 角色管理 / 部门管理：删除接口对接说明

前端已完成「编辑 + 删除」的界面与调用逻辑，**只差后端两个 DELETE 接口**。接口按下面的契约实现后，页面直接生效，前端不需要再改一行。

## 1. 需要新增的两个接口

### `DELETE /api/roles/{id}`

| 状态码 | 含义 |
|---|---|
| 204 | 删除成功（无响应体） |
| 404 | 角色不存在 |
| 409 | 内置角色（`crm_roles.is_builtin = 1`）或仍有员工关联（`crm_employee_roles`） |
| 403 | 当前账号无 `role.manage` 权限 |

### `DELETE /api/departments/{id}`

| 状态码 | 含义 |
|---|---|
| 204 | 删除成功（无响应体） |
| 404 | 部门不存在 |
| 409 | 该部门有下级部门，或部门下仍有在职员工 |
| 403 | 当前账号无 `dept.manage` 权限 |

## 2. 前端已经写好的调用

```js
// src/api/roles.js
remove: (id) => request(`/roles/${id}`, { method: 'DELETE' })

// src/api/departments.js
remove: (id) => request(`/departments/${id}`, { method: 'DELETE' })
```

前端行为：

1. 角色卡片底部「删除」、部门行「删除」→ 弹确认框；
2. 角色有成员、部门有在职员工时，**必须勾选知情项**才能点「确认删除」；
3. 内置角色、当前登录身份所属角色、有下级部门的部门，删除按钮直接置灰并给出原因；
4. 确认后按上表状态码处理：

| 后端返回 | 前端表现 |
|---|---|
| 204 | 关闭弹窗，toast「角色/部门已删除」，重新拉列表 |
| 409 | 保留弹窗，toast 提示先解除关联（角色）/先处理子部门或员工（部门） |
| 404 | 关闭弹窗，toast「已不存在，列表已刷新」，重新拉列表 |
| 405 | 页面顶部出现「删除接口尚未接入后端」提示条（**当前就是这一状态**） |
| 其它 | 直接展示后端 `message`，没有则按状态码兜底 |

## 3. 实现要点建议

**角色**
- `crm_roles` 没有 `deleted_at`，按物理删除处理；
- 先 `DELETE FROM crm_role_permissions WHERE role_id = ?`，再删 `crm_roles`，否则 `fk_role_permission_role` 会拦住；
- 内置角色必须拒绝删除：`is_builtin = 1`（`super_admin` 尤其要守住，前端已置灰，但后端也要拦）；
- 建议后端也校验「不能删除自己当前所属的角色」，避免把自己踢成无权限账号。

**部门**
- `crm_departments` 没有 `deleted_at`，物理删除；
- 有三条外键会拦住：`fk_department_parent`（下级部门）、`fk_employee_department`（在职员工）、`fk_department_managers`（负责人关联）；
- 建议在 Service 里先显式校验并抛 `409 + 中文 message`，而不是让数据库抛异常变成 500；
- 删成功时记得清理 `crm_department_managers` 中的记录。

**通用**
- Spring 默认 `server.error.include-message=never`，409 的 message 到不了前端；如果需要前端展示具体原因，建议开启，或在 409 时前端按状态码兜底（现在已经这样处理）。

## 4. 已有的接口（无需改动）

| 接口 | 状态 |
|---|---|
| `GET /api/roles` | 已实现，前端在用 |
| `POST /api/roles` | 已实现 |
| `PUT /api/roles/{id}` | 已实现（名称、描述、权限点） |
| `GET /api/employees/{id}/roles`、`PUT ...` | 已实现 |
| `GET /api/departments`、`POST`、`PUT /{id}` | 已实现 |

## 5. 顺带提一个可选项

`crm_roles` 表已经有 `data_scope` 字段（`self / department / department_tree / all`），但 `GET /api/roles` 没有返回它。如果之后要做「数据范围」行级隔离，建议在角色列表里带上 `dataScope`，前端可以在角色卡片上直接展示和编辑。
