import { request } from './http'

/**
 * 行政财务接口契约
 * ------------------------------------------------------------
 * 覆盖四个页面：费用报销 / 借款预支 / 请假申请 / 审批中心。
 * 后端现状：这四类单据的表都不存在，本轮全部是前端演示数据（src/data/office.js）。
 * 方法名与参数即为将来的契约，字段口径见 docs/office-api.md。
 *
 * 三条统一约定：
 *  1. 金额单位「元」DECIMAL(12,2)；天数整数；日期 `YYYY-MM-DD`
 *  2. 列表返回 { rows, total }，分页 page / pageSize；每行带上算好的派生字段
 *     （报销的 totalAmount/billCount、借款的 clearedAmount/openAmount、请假的 days）
 *  3. 写接口带 requestId 幂等键。报销单是员工反复点提交的高频动作，
 *     前端超时重试很常见，没有幂等键必然出两张单。
 */
/**
 * 审批接口 403 的真实含义只有两种：审自己提的单，或者单子不在管辖范围内
 * （后端 OfficeService.decide：applicant == 审批人 或 !inScope → FORBIDDEN）。
 * 默认的「没有权限执行该操作」会把人骗去查角色配置，那里什么都没错。
 */
const DENY_403 = '不能审批本人提交的申请，或该申请不在你的审批范围内（本部门及下级）'

export const officeApi = {
  /* ---------------- 费用报销 ---------------- */

  /** GET /expenses?status=&type=&applicantId=&period=&keyword=&page=&pageSize= */
  expenses: (query) => request('/expenses', { query }),

  /** GET /expenses/{id} -> { expense, items, trip, attachments, deduct, approvals } */
  expenseDetail: (id) => request(`/expenses/${id}`, {
    errors: { 404: '报销单不存在', 403: '没有查看该报销单的权限' }
  }),

  /**
   * POST /expenses
   * body: {
   *   applicantId, deptId, projectName?, applyDate, remark?, requestId,
   *   items: [{ date, type, amount, note, bills }],
   *   trip?: { from, to, start, end },
   *   deduct?: { loanId, amount },
   *   attachments: [{ name, fileId }]
   * }
   * 后端必须做：明细金额汇总、差旅行程必填校验、抵扣不超借款余额、单笔超线转财务复核
   */
  createExpense: (body) => request('/expenses', {
    method: 'POST',
    body,
    errors: {
      400: '费用明细不完整',
      409: '关联借款已结清或不属于该员工',
      422: '抵扣金额超过借款未还余额'
    }
  }),

  /** POST /expenses/{id}/approve  body: { result: 'pass'|'reject', note } */
  approveExpense: (id, body) => request(`/expenses/${id}/approve`, {
    method: 'POST', body, errors: { 403: DENY_403 }
  }),

  /** POST /expenses/{id}/withdraw  撤回（仅审批中可撤回） */
  withdrawExpense: (id) => request(`/expenses/${id}/withdraw`, { method: 'POST' }),

  /* ---------------- 借款预支 ---------------- */

  /** GET /loans?status=&type=&applicantId=&page=&pageSize= */
  loans: (query) => request('/loans', { query }),

  /** GET /loans/{id} -> { loan, writeOffs } */
  loanDetail: (id) => request(`/loans/${id}`),

  /** POST /loans  body: { applicantId, deptId, type, amount, purpose, dueDate, requestId } */
  createLoan: (body) => request('/loans', {
    method: 'POST',
    body,
    errors: { 400: '借款用途不能为空', 422: '应清账日不能早于申请日' }
  }),

  /** POST /loans/{id}/approve  body: { result, note } */
  approveLoan: (id, body) => request(`/loans/${id}/approve`, {
    method: 'POST', body, errors: { 403: DENY_403 }
  }),

  /** GET /loans/open?applicantId=  报销单抵扣下拉用，只返回未清的 */
  openLoans: (query) => request('/loans/open', { query }),

  /**
   * POST /loans/{id}/write-off  手工核销（报销单抵扣走报销审批链路，这个用于现金退回）
   * body: { amount, source: 'cash'|'expense', expenseId?, note }
   */
  writeOffLoan: (id, body) => request(`/loans/${id}/write-off`, {
    method: 'POST',
    body,
    errors: { 422: '核销金额超过未还余额' }
  }),

  /* ---------------- 请假申请 ---------------- */

  /** GET /leaves?status=&type=&applicantId=&month=&page=&pageSize= */
  leaves: (query) => request('/leaves', { query }),

  /** GET /leaves/{id} */
  leaveDetail: (id) => request(`/leaves/${id}`),

  /** GET /leaves/quota?applicantId=&year=  -> { 年假: {quota, used, left}, ... } */
  leaveQuota: (query) => request('/leaves/quota', { query }),

  /**
   * POST /leaves  body: { applicantId, deptId, type, start, end, reason, handoverId, requestId }
   *
   * 400 是后端的兜底校验，覆盖「日期缺失/倒挂/跨年、事由为空、类型不合法、天数为 0」好几种情况，
   * 以前这里写死「请假天数为 0」，用户明明填了 4 天却被提示天数为 0，完全找不到北。
   * 前端在提交前已经把这几条逐个拦掉了（见 Leaves.vue 的 submitCreate），
   * 能走到 400 基本就是参数没拼对，所以文案说实话即可。
   */
  createLeave: (body) => request('/leaves', {
    method: 'POST',
    body,
    errors: {
      400: '请假信息校验未通过，请检查请假类型、起止日期和事由',
      409: '这段时间里你已经有一张待审批或已通过的请假单了',
      422: '该类型的剩余额度不够，请改类型或缩短天数'
    }
  }),

  /** POST /leaves/{id}/approve  body: { result, note } */
  approveLeave: (id, body) => request(`/leaves/${id}/approve`, {
    method: 'POST', body, errors: { 403: DENY_403 }
  }),

  /** POST /leaves/{id}/revoke  撤销（已通过但未开始的可以撤） */
  revokeLeave: (id) => request(`/leaves/${id}/revoke`, { method: 'POST' }),

  /* ---------------- 审批中心 ---------------- */

  /**
   * GET /approvals?box=pending|mine|done&kind=&keyword=&page=&pageSize=
   * 后端不要另建审批表，直接从三类单据 UNION 出来，否则会出现
   * 「审批中心点通过了，报销页还是审批中」这种两边不一致的鬼故事。
   */
  approvals: (query) => request('/approvals', { query }),

  /** POST /approvals/decide  body: { kind, docId, result, note }  统一审批入口 */
  decide: (body) => request('/approvals/decide', {
    method: 'POST',
    body,
    errors: { 409: '该单据已被处理，请刷新', 403: DENY_403 }
  }),

  /** GET /approvals/{kind}/{docId}/history  审批流水 */
  history: (kind, docId) => request(`/approvals/${kind}/${docId}/history`),

  /* ---------------- 导出 ---------------- */

  /** GET /expenses/export?status=&period=  返回 xlsx 流 */
  exportExpenses: (query) => request('/expenses/export', { query, raw: true }),

  /** GET /loans/export?status=  借款台账 */
  exportLoans: (query) => request('/loans/export', { query, raw: true })
}
