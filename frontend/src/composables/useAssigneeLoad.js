import { customerBook, customerBookReady } from '@/composables/useCustomerBook'

/**
 * 接收人负载
 * ------------------------------------------------------------
 * 主管分配线索时最需要的不是「这个人是谁」，而是「他还接不接得住」。
 * 这里把两处数据合成一份负载：
 *   在跟线索 —— 来自真实 /api/leads（按 ownerId 精确统计，已转化 / 无效不计）
 *   客户档案 —— 来自真实 /api/customers（见 useCustomerBook，按负责人姓名匹配）
 *
 * 容量优先取员工自带的 capacity（后端给了就用），否则用 LEAD_CAPACITY。
 * 达到上限只是提示，不硬拦：临时插一条急单是常态。
 */

/** 单人「在跟线索」建议上限，后端若返回 capacity 则以返回值为准 */
export const LEAD_CAPACITY = 30

/** 已转化 / 无效是终态，不再占用销售精力，不计入负载 */
const END_STATES = new Set(['converted', 'invalid'])

/**
 * 负载档位。只有偏忙 / 已满给颜色，空闲和正常不加色——
 * 十几行里全是彩色等于没有重点，真正需要提醒的是「装不下了」。
 */
export function loadBand(active, capacity = LEAD_CAPACITY) {
  const cap = capacity > 0 ? capacity : LEAD_CAPACITY
  const pct = Math.min(1, active / cap)
  if (active >= cap) return { key: 'full', label: '已满', pct }
  if (pct >= 0.75) return { key: 'busy', label: '偏忙', pct }
  if (pct >= 0.4) return { key: 'ok', label: '正常', pct }
  return { key: 'idle', label: '空闲', pct }
}

/** 把线索 / 客户压成两张索引表：负责人 id -> 线索计数，负责人姓名 -> 客户计数 */
export function buildLoadIndex(leads = [], customers = []) {
  const byOwnerId = new Map()
  const byOwnerName = new Map()

  for (const lead of leads) {
    if (!lead.ownerId) continue
    const key = String(lead.ownerId)
    const cur = byOwnerId.get(key) || { active: 0, pending: 0, converted: 0, invalid: 0 }
    if (lead.status === 'converted') cur.converted += 1
    else if (lead.status === 'invalid') cur.invalid += 1
    else {
      cur.active += 1
      if (lead.status === 'pending') cur.pending += 1
    }
    byOwnerId.set(key, cur)
  }

  for (const c of customers) {
    if (!c.owner) continue
    const cur = byOwnerName.get(c.owner) || { count: 0, amount: 0 }
    cur.count += 1
    cur.amount += Number(c.amount) || 0
    byOwnerName.set(c.owner, cur)
  }

  return { byOwnerId, byOwnerName }
}

const EMPTY_LEADS = { active: 0, pending: 0, converted: 0, invalid: 0 }
const EMPTY_CUSTOMERS = { count: 0, amount: 0 }

/**
 * 给「可指派员工」列表挂上负载。
 * employees 沿用 store/employees.js 的 assignableEmployees 结构（rawId / name / no / dept / role）。
 */
export function withAssigneeLoad(employees = [], { leads = [], customers = customerBook.value } = {}) {
  const { byOwnerId, byOwnerName } = buildLoadIndex(leads, customers)
  const customersKnown = customerBookReady.value

  return employees.map((e) => {
    const s = byOwnerId.get(String(e.rawId)) || EMPTY_LEADS
    const c = byOwnerName.get(e.name) || EMPTY_CUSTOMERS
    const capacity = Number(e.capacity) > 0 ? Number(e.capacity) : LEAD_CAPACITY
    return {
      ...e,
      capacity,
      load: {
        active: s.active,
        pending: s.pending,
        converted: s.converted,
        invalid: s.invalid,
        customers: c.count,
        amount: c.amount,
        customersKnown,
        capacity,
        free: Math.max(0, capacity - s.active),
        band: loadBand(s.active, capacity)
      }
    }
  })
}

/** 「12 万」这种粗粒度金额，用于悬浮说明，不占行内空间 */
export function compactAmount(n) {
  if (!n) return '0'
  if (n >= 10000) return `${Math.round(n / 10000)} 万`
  return String(n)
}

/** 行的悬浮说明：把判断依据一次说清楚 */
export function loadTitle(e) {
  const l = e.load
  if (!l) return ''
  const parts = [
    `在跟线索 ${l.active} 条（上限 ${l.capacity}）`,
    l.customersKnown
      ? `客户档案 ${l.customers} 家${l.amount ? `，年采购约 ¥${compactAmount(l.amount)}` : ''}`
      : '客户档案数没加载到（无 customer.view 权限或接口异常）'
  ]
  if (l.pending) parts.push(`其中待联系 ${l.pending} 条`)
  parts.push(l.free > 0 ? `还能接 ${l.free} 条` : '已到上限，建议先顾现有线索')
  return parts.join(' · ')
}
