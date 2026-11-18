import { request } from './http'

/**
 * 订单中心接口契约
 * ------------------------------------------------------------
 * 后端现状：合同 / 回款 / 发票 / 费用四张表都不存在，本轮全部是前端演示数据。
 * 这里的方法名与参数即为将来后端实现的契约，字段口径见 docs/orders-api.md。
 *
 * 统一约定：
 *  - 金额单位「元」，保留 2 位小数，不接受字符串
 *  - 时间统一 ISO 日期 `YYYY-MM-DD`，时间戳 `YYYY-MM-DD HH:mm:ss`
 *  - 列表接口返回 { rows, total }，分页参数 page / pageSize
 *  - 所有写接口必须做幂等键校验（前端会带 requestId），避免重复提交产生两张单
 */
export const orderApi = {
  sign: (id) => request(`/shipments/${id}/sign`, { method: 'POST' }),
  tracking: (id) => request(`/shipments/${id}/tracking`),
  /* ---------------- 订单 ---------------- */

  /** GET /orders?type=&status=&customerId=&ownerId=&period=&page=&pageSize= */
  list: (params) => request('/orders', { query: params }),

  /** GET /orders/{id} -> { order, items, shipments, returns, invoices, receipts } */
  detail: (id) => request(`/orders/${id}`, {
    errors: { 404: '订单不存在或已被删除', 403: '没有查看该订单的权限' }
  }),

  /**
   * POST /orders
   * body: { type, customerId, contractId?, expectDate?, remark?, items:[{productId, unit, qty, price?}] }
   * 后端必须做：取价校验（低于成本价转审批）、信用额度校验、库存可用量校验
   */
  create: (body) => request('/orders', {
    method: 'POST',
    body,
    errors: {
      400: '商品明细不完整',
      409: '客户信用额度不足，已转为待审批',
      422: '成交价低于成本价，需上级审批'
    }
  }),

  /** POST /orders/{id}/approve  body: { result: 'pass'|'reject', note } */
  approve: (id, body) => request(`/orders/${id}/approve`, { method: 'POST', body }),

  /** POST /orders/quote  下单前预览单价与毛利，返回 [{productId, unit, price, priceSource, floor, margin}] */
  quote: (body) => request('/orders/quote', { method: 'POST', body }),

  /** GET /orders/credit?customerId=&amount=  下单前信用额度预检 */
  credit: (query) => request('/orders/credit', { query }),

  /* ---------------- 发货 ---------------- */

  /** POST /orders/{id}/shipments  body: { items:[{productId, unit, qty}], logistics, trackingNo, at } */
  ship: (id, body) => request(`/orders/${id}/shipments`, {
    method: 'POST',
    body,
    errors: { 400: '发货数量超过订单未发数量', 409: '订单已取消，不能发货' }
  }),

  /** GET /shipments?orderId=&status= */
  shipments: (query) => request('/shipments', { query }),

  /* ---------------- 退货 ---------------- */

  /** GET /returns?status=&customerId=&period= */
  returns: (query) => request('/returns', { query }),

  /**
   * POST /returns
   * body: { orderId, reason, note, items:[{productId, unit, qty}] }
   * 退货必须同时：冲减订单已发数量、生成红字应收、回写库存
   */
  createReturn: (body) => request('/returns', {
    method: 'POST',
    body,
    errors: { 400: '退货数量超过已发货数量', 409: '该订单已全额退货' }
  }),

  /** POST /returns/{id}/confirm  body: { result: 'pass'|'reject', restock: boolean } */
  confirmReturn: (id, body) => request(`/returns/${id}/confirm`, { method: 'POST', body }),

  /* ---------------- 合同 ---------------- */

  /** GET /contracts?status=&type=&customerId=&ownerId= */
  contracts: (query) => request('/contracts', { query }),

  /** GET /contracts/{id} -> { contract, items, orders, approvals, summary } */
  contractDetail: (id) => request(`/contracts/${id}`),

  /**
   * POST /contracts  -> 201 { id, code, status, warnings[] }
   * body: { name, customerId, type, discount, termDays, paymentTerm,
   *         signDate, startDate, endDate, remark, items:[{productId, unit, qty, price}] }
   * amount 不传：由明细汇总。status 固定为「待审批」，新合同必须审批才生效。
   * 权限 contract.create；owner 取当前登录人，不接受前端指定。
   * 完整规则见 docs/contracts-api.md
   */
  createContract: (body) => request('/contracts', {
    method: 'POST',
    body,
    errors: { 400: '合同信息有误：检查客户、日期区间和商品明细', 409: '该客户已有同名合同' }
  }),

  /**
   * POST /contracts/{id}/approve  -> 204
   * body: { result: 'pass'|'reject', note }
   * pass → 执行中；reject → 草稿（note 必填）。禁自审，非待审批返回 409。
   * 权限 contract.approve
   */
  approveContract: (id, body) => request(`/contracts/${id}/approve`, {
    method: 'POST',
    body,
    errors: { 409: '这份合同已经审过了，或状态不是待审批', 403: '不能审批自己负责的合同' }
  }),

  /* ---------------- 对账单 ---------------- */

  /** GET /statements?customerId=&period=&status= */
  statements: (query) => request('/statements', { query }),

  /** GET /statements/{id} -> { statement, lines, orders, invoices, receipts } */
  statementDetail: (id) => request(`/statements/${id}`),

  /**
   * POST /statements  按客户 + 账期生成
   * body: { customerId, period }
   * 后端必须保证：期末应收 = 期初 + 本期发货 - 本期回款；同一客户同一账期唯一
   */
  generateStatement: (body) => request('/statements', {
    method: 'POST',
    body,
    errors: { 409: '该客户本期对账单已存在' }
  }),

  /** POST /statements/{id}/confirm  客户确认，确认后才允许开票 */
  confirmStatement: (id) => request(`/statements/${id}/confirm`, { method: 'POST' }),

  /** GET /statements/{id}/export  导出对账单（Excel / PDF） */
  exportStatement: (id) => request(`/statements/${id}/export`, { raw: true }),

  /* ---------------- 发票 ---------------- */

  /** GET /invoices?status=&type=&customerId=&period= */
  invoices: (query) => request('/invoices', { query }),

  /**
   * POST /invoices  body: { statementId?, contractId?, customerId, amount, taxRate, type }
   * 开票金额不得超过对账单已确认金额
   */
  createInvoice: (body) => request('/invoices', {
    method: 'POST',
    body,
    errors: { 400: '开票金额超过对账单可开票金额', 409: '对账单尚未确认' }
  }),

  /** POST /invoices/{id}/issue  body: { no }  实际开票，回填发票号 */
  issueInvoice: (id, body) => request(`/invoices/${id}/issue`, { method: 'POST', body }),

  /** POST /invoices/{id}/red-flush  body: { reason }  红冲，必须留原票号 */
  redFlushInvoice: (id, body) => request(`/invoices/${id}/red-flush`, { method: 'POST', body }),

  /* ---------------- 回款与核销 ---------------- */

  /** GET /receipts?customerId=&status=&period= */
  receipts: (query) => request('/receipts', { query }),

  /** GET /receipts/{id} -> { receipt, allocations, availableInvoices } */
  receiptDetail: (id) => request(`/receipts/${id}`),

  /** POST /receipts  body: { customerId, amount, payDate, method, bank, remark } */
  createReceipt: (body) => request('/receipts', { method: 'POST', body }),

  /**
   * POST /receipts/{id}/allocate  核销
   * body: { allocations: [{ targetType: 'invoice'|'order', targetId, amount }] }
   * 校验：单条核销额 ≤ 单据未收金额；合计 ≤ 收款单未核销余额
   */
  allocate: (id, body) => request(`/receipts/${id}/allocate`, {
    method: 'POST',
    body,
    errors: {
      400: '核销金额超过单据待收金额',
      409: '收款单已核销完毕',
      422: '合计核销金额超过本笔到账金额'
    }
  }),

  /** POST /receipts/{id}/revoke-allocation  body: { allocationId, reason }  反核销 */
  revokeAllocation: (id, body) => request(`/receipts/${id}/revoke-allocation`, { method: 'POST', body }),

  /* ---------------- 导出 ---------------- */

  /** GET /orders/export?type=&status=&period=  返回 xlsx 流 */
  exportOrders: (query) => request('/orders/export', { query, raw: true })
}

