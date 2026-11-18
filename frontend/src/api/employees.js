import { request } from './http'

/**
 * 员工管理接口 —— 已与后端 com.crm.employee 对齐
 *
 *   GET    /api/employees?keyword=&departmentId=&status=   -> Employee[]
 *   GET    /api/employees/{id}                             -> Employee
 *   POST   /api/employees                                  -> { id }  201
 *   PUT    /api/employees/{id}                             -> 204
 *   PATCH  /api/employees/{id}/status  { status }           -> 204
 *   DELETE /api/employees/{id}                             -> 204（软删，写 deleted_at）
 *
 * Employee 返回字段（Employee record）：
 *   { id, employeeNo, username, name, departmentId, departmentName,
 *     phone, email, hireDate, status, roleNames }
 *
 * 提交体（EmployeeForm）只接受这 7 个字段：
 *   { username, name, departmentId, phone, email, hireDate, status }
 *   —— employeeNo 由后端生成（"E" + UUID），角色 roleIds 后端暂不接收。
 *
 * 后端校验（service 层）：
 *   username  1–64 位字母或数字，重复返回 409
 *   name      1–100 字
 *   departmentId 必须已存在，否则 400
 *   status    仅 active | disabled
 * 注意：Spring 默认不返回 message，前端按状态码映射文案。
 */

function toQuery(params = {}) {
  const search = new URLSearchParams()
  Object.entries(params).forEach(([k, v]) => {
    if (v !== undefined && v !== null && v !== '') search.append(k, v)
  })
  const qs = search.toString()
  return qs ? `?${qs}` : ''
}

export const employeeApi = {
  /** 列表（后端可按 keyword/departmentId/status 过滤；也允许前端全量拉取后再筛） */
  list: (params) => request(`/employees${toQuery(params)}`),

  detail: (id) => request(`/employees/${id}`),

  /**
   * payload 只传 EmployeeForm 的 7 个字段：
   *   { username, name, departmentId, phone, email, hireDate, status }
   * employeeNo 由后端生成，角色关联暂不支持随员工一起提交。
   */
  create: (payload) => request('/employees', { method: 'POST', body: payload }),

  update: (id, payload) => request(`/employees/${id}`, { method: 'PUT', body: payload }),

  moveDepartment: (id, departmentId) =>
    request('/employees/' + id + '/department', { method: 'PATCH', body: { departmentId } }),

  /** 启用 / 停用：status 取 active | disabled */
  setStatus: (id, status) => request(`/employees/${id}/status`, { method: 'PATCH', body: { status } }),

  remove: (id) => request(`/employees/${id}`, { method: 'DELETE' })
}

/** 前端展示态 <-> 后端枚举 */
export const STATUS_TO_API = { 在职: 'active', 停用: 'disabled' }
export const STATUS_TO_VIEW = { active: '在职', disabled: '停用' }
