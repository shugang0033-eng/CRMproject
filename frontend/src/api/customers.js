import { request } from './http'

/**
 * 客户接口契约
 * ------------------------------------------------------------
 * 后端现状（2026-11-14 22:54 同步）：
 *   已实现 list / contacts / detail / update(PATCH) / timeline / orders /
 *          followups / contacts 增改 / merge / duplicates / pool / claim / follow-board
 *   未实现 POST /customers（新建），调用返回 405，前端会明确提示「客户没有保存」。
 * 字段口径见 docs/customers-api.md。
 */
export const customerApi = {
  pool: () => request('/customers/pool'),
  claim: (id) => request(`/customers/${id}/claim`, { method: 'POST', errors: { 409: '该客户已被领取' } }),
  /** GET /customers 已实现 */
  list: () => request('/customers'),

  /** GET /customers/contacts 已实现（注意：这个路径会和 /customers/{id} 冲突，见文档） */
  contacts: () => request('/contacts'),

  /**
   * POST /customers  待实现（前端已接，当前返回 405）
   * body: { name, industry, level, region, phone, address, source, note,
   *         paymentTerm?, creditLimit?, ownerId?, contacts?: [{ name, title, phone }] }
   * 规则见 docs/customers-api.md 第八节：
   *  - 客户编号由后端生成，不接受前端传；status 固定「跟进中」
   *  - ownerId 只有持 lead.transfer 的人能指定，其他人一律落当前登录人
   *  - paymentTerm / creditLimit 需要 customer.credit，否则 403
   *  - 必须查重（同名 / 同手机号），命中返回 409，不能静默建重复档案
   */
  create: (body) => request('/customers', {
    method: 'POST',
    body,
    errors: {
      400: '客户名称或联系方式不合法',
      403: '没有新建客户的权限，或不能给他人建档',
      405: '新建客户接口还没实现（POST /customers），客户没有保存',
      409: '已有同名或同号客户，请先确认是否重复建档'
    }
  }),

  /**
   * GET /customers/{id}  待实现
   * 返回 { profile, metrics, contacts, timeline, contracts, payments, monthly, attach }
   */
  detail: (id) => request(`/customers/${id}`, {
    errors: {
      404: '客户档案已不存在',
      403: '没有查看该客户的权限'
    }
  }),

  /** GET /customers/{id}/timeline?before=&limit=  待实现：客户动态分页 */
  timeline: (id, query) => request(`/customers/${id}/timeline`, { query }),

  /** GET /customers/{id}/orders  待实现：该客户的合同 + 回款 */
  orders: (id) => request(`/customers/${id}/orders`),

  /**
   * PATCH /customers/{id}  已实现
   * body: 只传真正改动的字段（传了才改，不传不动）
   *        { name, industry, level, region, phone, address, source, note,
   *          paymentTerm?, creditLimit? }
   * 返回 { changed: ["note","paymentTerm"] }，值没变的字段后端会跳过
   * 规则：
   *  - 只允许改档案字段；status / 累计金额 / last_order_at 由系统回写，不接受前端传
   *  - paymentTerm / creditLimit 需要 customer.credit 权限，否则 403
   *  - 名称变更要做重复校验（复用 POST /customers/duplicates/check）
   *  - ownerId 不在这里改，走 POST /customers/transfer
   */
  update: (id, body) => request(`/customers/${id}`, {
    method: 'PATCH',
    body,
    errors: {
      400: '客户名称或账期不合法',
      403: '没有编辑该客户的权限，账期与额度需要主管才能改',
      404: '客户档案已不存在',
      409: '同名客户已存在，请确认是否要合并'
    }
  }),

  /** POST /customers/{id}/followups  待实现：写跟进（同时更新 last_follow_at） */
  addFollowUp: (id, body) => request(`/customers/${id}/followups`, {
    method: 'POST',
    body,
    errors: { 400: '请填写跟进内容', 409: '客户负责人已变更，请刷新后重试' }
  }),

  /** POST /customers/{id}/contacts  待实现：新增联系人 */
  addContact: (id, body) => request(`/customers/${id}/contacts`, { method: 'POST', body }),

  /** PATCH /customers/{id}/contacts/{contactId}  待实现：设为主联系人 / 改角色 */
  updateContact: (id, contactId, body) => request(`/customers/${id}/contacts/${contactId}`, {
    method: 'PATCH',
    body
  }),

  /** POST /customers/merge  待实现：合并重复客户到主档案 */
  merge: (body) => request('/customers/merge', {
    method: 'POST',
    body,
    errors: {
      400: '至少选择两个客户才能合并',
      409: '目标客户存在未结清合同，无法合并'
    }
  }),

  /** POST /customers/duplicates/check  待实现：新建客户前查重 */
  checkDuplicate: (body) => request('/customers/duplicates/check', { method: 'POST', body }),

  /** GET /customers/follow-board?range=week  待实现：团队跟进看板 */
  followBoard: (query) => request('/customers/follow-board', { query }),

  /** PATCH /customers/follow-tasks/{taskId}  待实现：勾选完成 / 改期 */
  updateTask: (taskId, body) => request(`/customers/follow-tasks/${taskId}`, {
    method: 'PATCH',
    body
  }),

  /** POST /customers/transfer 已实现 */
  transfer: (body) => request('/customers/transfer', {
    method: 'POST', body, errors: {
      400: '请选择不同的在职接收人',
      403: '没有该客户的转移权限',
      404: '客户档案已不存在'
    }
  })
}


