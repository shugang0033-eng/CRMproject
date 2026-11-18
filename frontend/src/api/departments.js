import { request } from './http'

/**
 * 部门管理接口 —— 对应后端 DepartmentController
 *
 *   GET    /api/departments                 -> DepartmentNode[]  树形结构
 *   GET    /api/departments/leader-options  -> LeaderOption[]    { id, name, employeeNo }
 *   POST   /api/departments                 -> { id }            201
 *   PUT    /api/departments/{id}            -> 204               已实现
 *   DELETE /api/departments/{id}            -> 204               删除成功
 *                                              409             部门下有子部门或员工记录
 *
 * 说明：后端 update 只更新 name、leader、sort_order，不处理 parentId（不支持改挂父级）；
 *      count 由 crm_employees 实时统计，只读，前端不可提交。
 *      删除约定：有下级部门应返回 409；部门下仍有关联员工记录时返回 409，
 *      由前端提示「先把员工调到其他部门」。
 */
export const departmentApi = {
  tree: () => request('/departments'),

  leaderOptions: () => request('/departments/leader-options'),

  create: ({ name, parentId = null, leaderId = null, sortOrder = 0 }) =>
    request('/departments', {
      method: 'POST',
      body: { name, parentId, leaderId, sortOrder }
    }),

  update: (id, { name, parentId = null, leaderId = null, sortOrder = 0 }) =>
    request(`/departments/${id}`, {
      method: 'PUT',
      body: { name, parentId, leaderId, sortOrder }
    }),

  remove: (id) => request(`/departments/${id}`, { method: 'DELETE' })
}

