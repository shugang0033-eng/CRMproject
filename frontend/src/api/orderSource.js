import { reactive } from 'vue'
import { orderApi } from './orders'

/**
 * 订单中心数据源适配层
 * ------------------------------------------------------------
 * 为什么要这一层：第二批/第三批的页面是先按演示数据做的，后端接口分批上。
 * 如果页面直接 fetch，接口没上线时整页空白；如果继续写死假数据，
 * 接口上线后还得逐页改。这一层让每个资源独立判定「真数据 / 演示数据」：
 *
 *   · 接口返回了数据  → rows 换成后端数据，标「实时」
 *   · 接口未实现(404/405) 或有表无数据 → 保留演示数据，标「演示」
 *   · 接口报业务错误(400/403/409/422) → 照常抛出，页面 toast 出来
 *
 * 后端补完一个接口，对应页面自动变实时，前端不用再改一行。
 */

const SOURCES = ['orders', 'contracts', 'statements', 'invoices', 'receipts']

/** 每个资源当前的数据来源：live 实时 / demo 演示 */
export const sourceState = reactive(
  Object.fromEntries(SOURCES.map((k) => [k, 'demo']))
)

/** 接口未就绪的记录，联调时在控制台一眼看到还差什么 */
export const pendingApis = reactive([])

const num = (v) => Number(v ?? 0)
const codeOf = (r) => r.code || String(r.id)

/* 这些状态码代表「后端还没写这个接口」，走降级；其余 4xx 是真实业务错误 */
const NOT_READY = new Set([404, 405, 501])

function notePending(label, error) {
  pendingApis.push({ api: label, status: error?.status || 0, at: new Date().toLocaleTimeString() })
  // 504/网络错误说明后端没起，属于环境问题，值得报出来
  if (!error || !error.status) console.warn(`[orderSource] ${label} 后端未响应，已使用演示数据`)
}

/**
 * 取列表。返回 null 表示「这次用不了真数据」，调用方继续用演示数据。
 */
async function loadList(label, call) {
  try {
    const data = await call()
    const rows = data?.rows || []
    return rows
  } catch (error) {
    if (NOT_READY.has(error.status) || !error.status) {
      notePending(label, error)
      return null
    }
    throw error
  }
}

/* ------------------------------ 字段适配 ------------------------------
 * 后端是 snake_case（crm_* 表直出），页面按驼峰渲染。
 * 适配后 id 用业务单号（HT-2026-0187），另存 dbId 供写接口寻址。
 */

function adaptContract(r) {
  return {
    id: codeOf(r),
    dbId: r.id,
    customerId: r.customer_id,
    name: r.name,
    customer: r.customer,
    type: r.type,
    /* 合同负责人就是提单人。挂到 applicantId 上，页面直接复用 canAudit()
       判断「本人提交」——后端口径一致：不能审自己的单 */
    ownerId: r.owner_id,
    applicantId: r.owner_id,
    amount: num(r.amount),
    discount: r.discount == null ? 1 : num(r.discount),
    term: r.payment_term || (r.term_days ? `月结 ${r.term_days} 天` : ''),
    signDate: r.sign_date || '',
    start: r.start_date || '',
    end: r.end_date || '',
    owner: r.owner || '',
    status: r.status,
    remark: r.remark || '',
    items: r.items || [],
    approvals: r.approvals || [],
    /* 后端在合同列表里带上已下单额，省得前端把所有订单拉下来再加总 */
    orderedAmount: r.orderedAmount == null ? null : num(r.orderedAmount)
  }
}

function adaptStatement(r) {
  return {
    id: codeOf(r),
    dbId: r.id,
    customerId: r.customer_id,
    customer: r.customer,
    period: r.period,
    start: r.start_date,
    end: r.end_date,
    open: num(r.open_amount),
    shipped: num(r.shipped_amount),
    received: num(r.received_amount),
    close: num(r.close_amount),
    status: r.status,
    orders: num(r.order_count),
    createdAt: (r.created_at || '').slice(0, 10),
    confirmedAt: (r.confirmed_at || '').slice(0, 10)
  }
}

function adaptInvoice(r) {
  return {
    id: codeOf(r),
    dbId: r.id,
    customerId: r.customer_id,
    no: r.no || '',
    customer: r.customer,
    contractId: r.contractCode || '',
    statementId: r.statementCode || '',
    amount: num(r.amount),
    taxRate: r.tax_rate == null ? 0.13 : num(r.tax_rate),
    taxAmount: r.tax_amount == null ? null : num(r.tax_amount),
    type: r.type,
    applyDate: r.apply_date || '',
    issueDate: r.issue_date || '',
    status: r.status,
    /* 已核销金额：后端能算就返回，算不出来给 null，页面回落到演示算法 */
    settled: r.settledAmount == null ? null : num(r.settledAmount)
  }
}

function adaptReceipt(r) {
  return {
    id: codeOf(r),
    dbId: r.id,
    customerId: r.customer_id,
    customer: r.customer,
    amount: num(r.amount),
    payDate: r.pay_date || '',
    method: r.method || '',
    bank: r.bank || '',
    remark: r.remark || '',
    status: r.status,
    allocations: r.allocations || [],
    allocated: r.allocatedAmount == null ? null : num(r.allocatedAmount)
  }
}

/* ------------------------------ 读接口 ------------------------------ */

export async function loadContracts() {
  const rows = await loadList('GET /contracts', () => orderApi.contracts({ pageSize: 500 }))
  if (!rows) return null
  sourceState.contracts = 'live'
  return rows.map(adaptContract)
}

export async function loadStatements() {
  const rows = await loadList('GET /statements', () => orderApi.statements({ pageSize: 500 }))
  if (!rows) return null
  sourceState.statements = 'live'
  return rows.map(adaptStatement)
}

export async function loadInvoices() {
  const rows = await loadList('GET /invoices', () => orderApi.invoices({ pageSize: 500 }))
  if (!rows) return null
  sourceState.invoices = 'live'
  return rows.map(adaptInvoice)
}

export async function loadReceipts() {
  const rows = await loadList('GET /receipts', () => orderApi.receipts({ pageSize: 500 }))
  if (!rows) return null
  sourceState.receipts = 'live'
  return rows.map(adaptReceipt)
}

/* ------------------------------ 写接口 ------------------------------
 * 页面上的动作统一走这里：调得通就按后端结果算，调不通（接口没写）就在本地改，
 * 并告诉用户「演示模式」。这样这轮交付的按钮点了都有反馈，不会一点就报错。
 *
 * 用法：
 *   const r = await attempt({
 *     label: 'POST /statements/{id}/confirm',
 *     call: () => orderApi.confirmStatement(row.dbId),
 *     demoNote: '后端接口未就绪，已在本地演示'
 *   })
 *   if (r.mode === 'live') { ...以后端返回为准... } else { ...本地改... }
 */
export async function attempt({ label, call, demoNote }) {
  try {
    const data = await call()
    return { mode: 'live', data }
  } catch (error) {
    if (NOT_READY.has(error.status) || !error.status) {
      notePending(label, error)
      return { mode: 'demo', error, note: demoNote }
    }
    throw error
  }
}

/** 订单列表自己取数，取完把状态记上，页头标记才能一致 */
export function markOrders(count) {
  /* 空表和演示是两件事：空表要引导用户建档，不能标成「演示数据」误导 */
  sourceState.orders = count > 0 ? 'live' : 'empty'
}

/** 当前有几个资源已经是真数据，用于页头提示 */
export function liveCount() {
  return SOURCES.filter((k) => sourceState[k] === 'live').length
}

export const sourceTotal = SOURCES.length

