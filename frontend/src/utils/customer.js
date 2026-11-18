/**
 * 客户交易口径
 * ------------------------------------------------------------
 * 为什么要有这个文件：
 * 之前客户列表和详情的金额、状态是拿客户名去匹配前端演示档案算的，
 * 「杭州驰远」列表显示 186.4 万，数据库里真实订单只有 15.3 万，差 12 倍。
 * 现在统一从 orders / contracts / receipts 三份真实数据算，
 * 列表和详情走同一个函数，保证两处数字对得上。
 *
 * 三个概念必须分开，别再合成一个「状态」：
 *  - 阶段：成交没成交（hasDeal）
 *  - 健康度：钱收得回来吗（receivable / overdue）
 *  - 归属：有没有人负责（owner_id，客户池 = 无主）
 * 口径见 docs/customers-api.md
 */

import { todayStr } from './date'

const DAY = 86400000

/** 作废订单，不计入任何口径 */
export const VOID_ORDER = ['草稿', '已取消', '已退货']
/** 订单已成立（待审批还不算成交） */
export const DEAL_ORDER = ['待发货', '部分发货', '已签收']
/** 合同已生效 */
export const DEAL_CONTRACT = ['执行中', '已完成']

const numOf = (v) => {
  const n = Number(v)
  return Number.isFinite(n) ? n : 0
}

const dateOf = (row) => String(row.order_date || row.date || row.signDate || row.sign_date || '').slice(0, 10)

/** 日期距今天数，负数表示未来 */
export function daysAgo(date, day = null) {
  const d = String(date || '').slice(0, 10)
  if (!d) return null
  const a = new Date(`${d}T00:00:00`)
  const b = new Date(`${day || todayStr()}T00:00:00`)
  if (Number.isNaN(a.getTime())) return null
  return Math.round((b - a) / DAY)
}

/**
 * 逾期金额：回款不落到单，按「先进先出」冲销已签收订单，
 * 剩下的未冲销部分里，已过账期的累加。宁可少算，不虚报。
 */
function overdueOf(signed, received, term) {
  if (term == null || received == null) return null
  const sorted = [...signed].sort((a, b) => dateOf(a).localeCompare(dateOf(b)))
  let left = received
  let overdue = 0
  const now = todayStr()
  for (const o of sorted) {
    const amount = numOf(o.amount)
    const used = Math.min(left, amount)
    left -= used
    const unpaid = amount - used
    if (unpaid <= 0) continue
    const age = daysAgo(dateOf(o), now)
    if (age != null && age > term) overdue += unpaid
  }
  return Math.round(overdue * 100) / 100
}

/**
 * 一个客户的交易汇总。
 * receiptReady=false（无回款查看权限）时，应收 / 逾期返回 null，
 * 让界面显示「—」而不是假的 0。
 */
export function aggregateCustomer({
  orders = [],
  contracts = [],
  receipts = [],
  term = null,
  receiptReady = true
} = {}) {
  const valid = orders.filter((o) => !VOID_ORDER.includes(o.status))
  const signed = valid.filter((o) => o.status === '已签收')
  const deal = valid.filter((o) => DEAL_ORDER.includes(o.status))
  const liveContracts = contracts.filter((c) => DEAL_CONTRACT.includes(c.status))

  const total = valid.reduce((s, o) => s + numOf(o.amount), 0)
  const signedAmount = signed.reduce((s, o) => s + numOf(o.amount), 0)

  const now = todayStr()
  const net90 = valid
    .filter((o) => {
      const age = daysAgo(dateOf(o), now)
      return age != null && age >= 0 && age <= 90
    })
    .reduce((s, o) => s + numOf(o.amount), 0)

  const received = receiptReady ? receipts.reduce((s, r) => s + numOf(r.amount), 0) : null
  const receivable = received == null ? null : Math.max(0, Math.round((signedAmount - received) * 100) / 100)
  const overdue = overdueOf(signed, received, term)

  const dates = valid.map(dateOf).filter(Boolean).sort()
  const lastOrder = dates.length ? dates[dates.length - 1] : ''
  const firstOrder = dates.length ? dates[0] : ''

  /* 复购周期：相邻两张单的平均间隔，一单没法算 */
  let cycle = null
  if (dates.length > 1) {
    let gap = 0
    for (let i = 1; i < dates.length; i += 1) {
      gap += (new Date(`${dates[i]}T00:00:00`) - new Date(`${dates[i - 1]}T00:00:00`)) / DAY
    }
    cycle = Math.round(gap / (dates.length - 1))
  }

  return {
    hasDeal: deal.length > 0 || liveContracts.length > 0,
    orders: valid.length,
    total,
    signedAmount,
    net90,
    receivable,
    overdue,
    received,
    avgOrder: valid.length ? Math.round(total / valid.length) : 0,
    cycle,
    lastOrder,
    firstOrder,
    activeContracts: liveContracts.length,
    contractAmount: liveContracts.reduce((s, c) => s + numOf(c.amount), 0),
    receiptReady
  }
}

/**
 * 状态：后端回写了就以数据库为准，还是「跟进中」说明没回写，由交易事实推导。
 * 优先级：待回款 > 流失风险 > 合作中 > 跟进中。
 */
export function resolveStatus(backendStatus, agg) {
  const fixed = ['合作中', '待回款', '流失风险']
  if (backendStatus && fixed.includes(backendStatus)) return backendStatus
  if (!agg.hasDeal) return '跟进中'
  if (agg.overdue > 0) return '待回款'
  const idle = agg.lastOrder ? daysAgo(agg.lastOrder) : null
  if (idle != null && idle > 90) return '流失风险'
  return '合作中'
}

export const STATUS_TONE = {
  合作中: 'tag-success',
  跟进中: 'tag-info',
  待回款: 'tag-warning',
  流失风险: 'tag-danger'
}

/** 客户价值分层：最近买没买、买得频不频、金额大不大 */
export function tierOf(agg) {
  if (!agg.hasDeal) return { label: '待积累交易', tone: 'tag-gray' }
  if (agg.total >= 1000000 && agg.net90 > 0) return { label: '重要价值', tone: 'tag-brand' }
  if (agg.net90 > 0 && agg.cycle && agg.cycle <= 35) return { label: '保持客户', tone: 'tag-success' }
  if (agg.net90 > 0) return { label: '需激活', tone: 'tag-warning' }
  return { label: '流失预警', tone: 'tag-danger' }
}

/** 近 N 个月采购，按订单日期聚合，没单的月份补 0 */
export function monthlyOf(orders = [], months = 6) {
  const now = new Date()
  const buckets = []
  for (let i = months - 1; i >= 0; i -= 1) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1)
    buckets.push({
      key: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`,
      month: String(d.getMonth() + 1).padStart(2, '0'),
      amount: 0
    })
  }
  const index = Object.fromEntries(buckets.map((b) => [b.key, b]))
  orders
    .filter((o) => !VOID_ORDER.includes(o.status))
    .forEach((o) => {
      const d = dateOf(o)
      const b = index[d.slice(0, 7)]
      if (b) b.amount += numOf(o.amount)
    })
  return buckets.map(({ month, amount }) => ({ month, amount }))
}

/** 把行数据按客户 id 分组，兼容驼峰和下划线两种返回 */
export function groupByCustomer(rows = []) {
  const map = {}
  rows.forEach((r) => {
    const id = String(r.customer_id ?? r.customerId ?? '')
    if (!id) return
    if (!map[id]) map[id] = []
    map[id].push(r)
  })
  return map
}
