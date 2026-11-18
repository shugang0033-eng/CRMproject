import { computed, ref } from 'vue'
import { request } from '@/api/http'
import { can } from '@/store/permissions'

const PAGE_SIZE = 500

async function loadPages(path) {
  const first = await request(path, { query: { pageSize: PAGE_SIZE } })
  const rows = [...first.rows]
  for (let page = 2; rows.length < first.total; page++) {
    const next = await request(path, { query: { page, pageSize: PAGE_SIZE } })
    rows.push(...next.rows)
    if (next.rows.length < PAGE_SIZE) break
  }
  return rows
}

/** 线索状态是英文枚举，列表里显示中文；搜索结果的角标跟界面文案保持一致 */
const LEAD_STATUS = {
  pending: '待联系',
  contacted: '已联系',
  quoted: '已报价',
  negotiating: '谈判中',
  won: '已转化',
  invalid: '无效'
}

/** 命中字段：能拿编号、名称、联系人、负责人都算，销售找东西的方式不止一种 */
const SOURCES = [
  {
    key: 'customers',
    label: '客户',
    icon: 'users',
    perm: 'customer.view',
    path: '/customers',
    fetch: () => request('/customers'),
    fields: (r) => [r.name, r.code, r.phone, r.owner, r.industry, r.region],
    title: (r) => r.name,
    sub: (r) => [r.code, r.owner ? `负责人 ${r.owner}` : '', r.industry].filter(Boolean).join(' · '),
    meta: (r) => r.status
  },
  {
    key: 'leads',
    label: '线索',
    icon: 'target',
    perm: 'lead.view',
    path: '/leads',
    fetch: () => request('/leads'),
    fields: (r) => [r.company, r.contact, r.phone, r.id, r.owner, r.source, r.region],
    title: (r) => r.company || r.contact || r.id,
    sub: (r) => [r.id, r.contact, r.phone].filter(Boolean).join(' · '),
    meta: (r) => LEAD_STATUS[r.status] || r.status
  },
  {
    key: 'contracts',
    label: '合同',
    icon: 'briefcase',
    perm: 'contract.view',
    path: '/orders/contracts',
    fetch: () => loadPages('/contracts'),
    fields: (r) => [r.code, r.name, r.customer, r.owner],
    title: (r) => r.name || r.code,
    sub: (r) => [r.code, r.customer].filter(Boolean).join(' · '),
    meta: (r) => r.status
  },
  {
    key: 'orders',
    label: '订单',
    icon: 'box',
    perm: 'order.view',
    path: '/orders',
    fetch: () => loadPages('/orders'),
    fields: (r) => [r.code, r.customer, r.owner],
    title: (r) => r.code,
    sub: (r) => [r.customer, r.date].filter(Boolean).join(' · '),
    meta: (r) => r.status
  }
]

/** 一次只拉一份，多个页面（顶栏 / 以后可能的工作台）共用 */
const book = ref({})
const loading = ref(false)
const error = ref('')
let inflight = null

/* 页面只读这两个状态：正在拉 / 拉失败的原因 */
export const searchLoading = loading
export const searchError = error

const rowsOf = (payload) => (Array.isArray(payload) ? payload : payload?.rows || [])

/** 拉一次全量索引；失败的那一路只记错误，不影响其它来源 */
export function loadSearchBook({ force = false } = {}) {
  if (inflight) return inflight
  if (!force && Object.keys(book.value).length) return Promise.resolve(book.value)
  loading.value = true
  error.value = ''
  const active = SOURCES.filter((s) => can(s.perm))
  inflight = Promise.allSettled(active.map((s) => s.fetch())).then((results) => {
    const next = {}
    const failed = []
    results.forEach((r, i) => {
      const src = active[i]
      if (r.status === 'fulfilled') next[src.key] = rowsOf(r.value)
      else failed.push(src.label)
    })
    // 权限内一路都没有才是真的拉不到；局部失败照常显示已拉到的
    if (failed.length === active.length) error.value = '搜索数据没拉到，请稍后重试'
    else if (failed.length) error.value = `${failed.join('、')}暂时搜不到`
    book.value = next
    loading.value = false
    inflight = null
    return next
  })
  return inflight
}

export const searchableCount = computed(() =>
  Object.values(book.value).reduce((s, list) => s + list.length, 0)
)

const hit = (q, value) => String(value ?? '').toLowerCase().includes(q)

/**
 * 命中结果按来源分组，每组最多 5 条——顶栏下拉不该变成一个需要滚很久的表格。
 * 多出来的用 more 提示「还有 N 条」，点组头进对应模块继续找。
 */
export function searchAll(raw, { perGroup = 5 } = {}) {
  const q = String(raw || '').trim().toLowerCase()
  if (q.length < 1) return { groups: [], total: 0 }
  const groups = []
  let total = 0
  for (const src of SOURCES) {
    const rows = book.value[src.key]
    if (!rows?.length) continue
    const matched = rows.filter((r) => src.fields(r).some((v) => hit(q, v)))
    if (!matched.length) continue
    total += matched.length
    groups.push({
      key: src.key,
      label: src.label,
      icon: src.icon,
      path: src.path,
      count: matched.length,
      more: Math.max(0, matched.length - perGroup),
      items: matched.slice(0, perGroup).map((r) => ({
        key: `${src.key}-${r.id}`,
        title: src.title(r) || '（未命名）',
        sub: src.sub(r),
        meta: src.meta(r) || '',
        path: ['customers', 'orders'].includes(src.key) ? src.path + '/' + r.id : src.path,
        keyword: src.title(r) || ''
      }))
    })
  }
  return { groups, total }
}
