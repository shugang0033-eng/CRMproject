import { request } from './http'

/**
 * 角色管理接口
 *
 *   GET    /api/roles               -> Role[]  { id, name, code, description, builtin, members, permissionCodes: string[] }
 *   POST   /api/roles               -> 201
 *   PUT    /api/roles/{id}          -> 204       已实现（codex）
 *   DELETE /api/roles/{id}          -> 204       删除成功
 *                                    409       角色仍有成员，或为内置角色（is_builtin=1）
 *   GET    /api/employees/{id}/roles
 *   PUT    /api/employees/{id}/roles
 *
 * 删除约定：内置角色（super_admin 等 is_builtin=1）必须拒绝；
 * 角色下仍有成员时返回 409，前端会提示先解除成员关联。
 */
export const roleApi = {
  list: () => request('/roles'),
  create: (body) => request('/roles', { method: 'POST', body }),
  update: (id, body) => request(`/roles/${id}`, { method: 'PUT', body }),
  remove: (id) => request(`/roles/${id}`, { method: 'DELETE' }),
  employeeRoles: (id) => request(`/employees/${id}/roles`),
  assign: (id, roleIds) => request(`/employees/${id}/roles`, { method: 'PUT', body: { roleIds } })
}


