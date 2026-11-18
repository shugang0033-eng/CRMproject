import { request } from './http'

/**
 * 线索流转接口
 *
 * ── 转移（销售线索 › 行内「转移」）：线索从 A 名下改派给 B ────────────────
 *   POST /api/leads/{id}/transfer
 *        body { ownerId, reason, note }
 *        -> 204
 *   POST /api/leads/transfer
 *        body { ids: string[], ownerId, reason, note }
 *        -> 204  （单条也用它也认，但前端单条走上面那个）
 *
 *   400  接收人不存在 / 已停用 / 与当前负责人相同
 *   404  线索不存在
 *   409  线索已转为客户或已标记无效，不允许转移
 *
 * ── 分配（线索池 › 行内「分配」/「批量分配」）：无归属线索指派给某人 ──────
 *   POST /api/leads/assign
 *        body { ids: string[], ownerId, reason, notify }
 *        -> 204
 *
 *   400  接收人不存在 / 已停用
 *   409  线索已被他人领取或已不在线索池中（前端整体回滚并提示刷新）
 *
 * ── 撞单检查（分配 / 转移前的前置核对）──────────────────────────────────
 *   POST /api/leads/conflicts
 *        body { ids: string[], ownerId?: number }
 *        -> { items: [{ leadId, type, code, name, owner, ownerId, status, detail }] }
 *
 *   type = 'customer'  已是客户档案（客户模块里的同名牌）
 *   type = 'lead'      已有同名线索在别人名下（或另一条重复线索）
 *   只在“准备分配 / 转移”时调用，用于提醒，不阻断；后端未实现（404/405）时
 *   前端退回本地核对（客户档案 + 当前线索列表），不弹错误。
 *
 * ── 接收人候选 ────────────────────────────────────────────────────────
 *   GET /api/leads/assignees?keyword=
 *        -> [{ id, name, department, role, activeLeads, capacity }]
 *        （接口保留，但前端「分配 / 转移」已不用它）
 *
 *   前端现在统一用 GET /api/employees 作为接收人名单，原因有两条：
 *   1) 分配弹窗要显示并搜索「工号」，assignees 不返回 employeeNo；
 *   2) 要和「设置 › 员工管理」看到的是同一份人，避免两边对不上。
 *      另外 assignees 的 department 目前返回的是人名（SQL 里 e.name 与 d.name
 *      同名列没起别名），后端修好后可以再切回来。参见 docs/leads-api.md。
 *
 */

export const REASON_TRANSFER = [
  '区域调整',
  '人员离职 / 调岗',
  '客户意向变更',
  '工作量再平衡',
  '跨部门协作',
  '其他'
]

export const REASON_ASSIGN = ['区域匹配', '行业匹配', '新人练手', '主管指派', '客户指定', '其他']

/**
 * 线索接口各自的错误文案。
 * 后端 ResponseStatusException 默认不带 message，只能用状态码兜底；
 * 而通用文案（400 = 账号格式、409 = 账号已存在）套到线索上完全说不通，
 * 所以每个动作带一份自己的解释。
 */
const MOVE_ERRORS = {
  400: '接收人无效或已停用，请重新选择',
  401: '登录已失效，请重新登录',
  403: '没有该线索的操作权限',
  404: '线索不存在，可能已被删除',
  409: '线索状态已变化（已被领取或已转化），请刷新后重试',
  500: '线索流转失败，请稍后重试'
}

export const leadApi = {
  create: (body) => request('/leads', { method: 'POST', body, errors: { 400: '请检查线索必填项及字段长度' } }),
  convert: (id) => request(`/leads/${encodeURIComponent(id)}/convert`, {
    method: 'POST', errors: { 409: '线索未分配、已转化或已失效' }
  }),
  list: (pool = false) => request(`/leads?pool=${pool}`),
  assignees: (keyword = '') =>
    request(`/leads/assignees${keyword ? `?keyword=${encodeURIComponent(keyword)}` : ''}`),

  /** 单条转移 */
  transfer: (id, body) => request(`/leads/${id}/transfer`, { method: 'POST', body, errors: MOVE_ERRORS }),

  /** 批量转移 */
  transferBatch: (body) => request('/leads/transfer', { method: 'POST', body, errors: MOVE_ERRORS }),

  /** 线索池分配（单条 / 批量同一接口） */
  assign: (body) => request('/leads/assign', { method: 'POST', body, errors: MOVE_ERRORS }),

  /** 撞单核对：同名牌是否已有客户档案 / 已有线索在他人名下 */
  conflicts: (body) => request('/leads/conflicts', { method: 'POST', body })
}



