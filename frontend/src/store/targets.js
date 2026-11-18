import { reactive, watch } from 'vue'
import { session } from '@/store/session'
import { request } from '@/api/http'

/**
 * 业绩目标数据源（真实后端）
 * ------------------------------------------------------------
 * 两张口径，一张表：
 *   scope='dept'     scopeId=部门 id，period='2026-Q4'   —— 部门季度承诺
 *   scope='employee' scopeId=员工 id，period='2026-11'   —— 个人月度执行
 *
 * 为什么个人目标是月、部门目标是季：部门目标是对老板的季度承诺，
 * 个人目标是每月考核/算提成用的。季度个人目标不单独存，由三个月求和得到
 * （见 quarterEmployeeTarget），这样月底改一个人的目标不会牵动整张季度表。
 *
 * 「业绩目标页」和「侧栏目标卡」共用这一份，不再各存一份 localStorage ——
 * 目标属于公司配置，换台电脑、换个浏览器都该是同一个数。
 */

export const targetState = reactive({
  /** [{ scope:'dept'|'employee', scopeId, name, period, target, note }] */
  rows: [],
  loading: false,
  loaded: false,
  error: '',
  saving: false
})

/**
 * 当前账号的目标范围：能看、能改哪些部门。
 * { all: true } 全公司；否则 deptIds = 本人部门子树 ∪ 本人担任负责人的部门子树。
 *
 * 目标列表本身后端已经按范围过滤过了，这里再单独拿一份，是因为
 * 「还没设目标的部门」不会出现在目标列表里，但必须有地方能给它设。
 */
export const targetScope = reactive({ all: true, deptIds: [], loaded: false })

let inflight = null
let scopeInflight = null

watch(() => session.user?.id, () => {
  inflight = null
  scopeInflight = null
  Object.assign(targetState, { rows: [], loaded: false, loading: false, error: '' })
  Object.assign(targetScope, { all: true, deptIds: [], loaded: false })
}, { flush: 'sync' })

export async function loadTargetScope({ force = false } = {}) {
  if (scopeInflight) return scopeInflight
  if (targetScope.loaded && !force) return targetScope

  const job = (async () => {
    try {
      const data = await request('/targets/scope')
      if (scopeInflight !== job) return targetScope
      targetScope.all = Boolean(data?.all)
      targetScope.deptIds = Array.isArray(data?.deptIds) ? data.deptIds.map(Number) : []
      targetScope.loaded = true
      return targetScope
    } finally {
      if (scopeInflight === job) scopeInflight = null
    }
  })()

  scopeInflight = job
  return job
}

/** 这个部门在不在当前账号范围内。范围没拿到时先放行——数据本身是后端过滤的 */
export function deptInTargetScope(id) {
  if (!targetScope.loaded) return true
  if (targetScope.all) return true
  return targetScope.deptIds.includes(Number(id))
}

/** 同 loadTargetBase：永远返回 Promise，别让调用方的 .catch 扑空 */
export async function loadTargets({ force = false } = {}) {
  if (inflight) return inflight
  if (targetState.loaded && !force) return targetState.rows

  targetState.loading = true
  targetState.error = ''

  const job = (async () => {
    try {
      const data = await request('/targets')
      if (inflight !== job) return []
      const rows = Array.isArray(data) ? data : (data?.rows || [])
      targetState.rows = rows.filter((r) => !r.metric || r.metric === 'signed').map(({ period, scope, scopeId, scopeName, amount, note }) => ({
        scope: scope || 'dept',
        scopeId,
        name: scopeName || '',
        period: normalizePeriod(period),
        target: Number(amount || 0),
        note: note || ''
      }))
      targetState.loaded = true
      return targetState.rows
    } catch (e) {
      if (inflight !== job) return []
      targetState.rows = []
      targetState.error = e?.message || '业绩目标没拉到'
      throw e
    } finally {
      if (inflight === job) {
        targetState.loading = false
        inflight = null
      }
    }
  })()

  inflight = job
  return job
}

const pad = (n) => String(n).padStart(2, '0')

/** '2026 Q4' / '2026-Q4' / '2026-11' / '2026 年 11 月' → '2026-Q4' | '2026-11' */
export function normalizePeriod(p) {
  const s = String(p || '').trim()
  const q = /(\d{4})\s*-?\s*Q\s*([1-4])/i.exec(s)
  if (q) return `${q[1]}-Q${q[2]}`
  const m = /(\d{4})\s*[-年]\s*(\d{1,2})/.exec(s)
  if (m && Number(m[2]) >= 1 && Number(m[2]) <= 12) return `${m[1]}-${pad(m[2])}`
  return ''
}

export function isMonthPeriod(p) {
  return /^\d{4}-\d{2}$/.test(normalizePeriod(p))
}

/** 界面上季度写 '2026 Q4'，月度写 '2026 年 11 月' */
export function periodLabel(p) {
  const n = normalizePeriod(p)
  if (!n) return ''
  if (n.includes('-Q')) return n.replace('-', ' ')
  const [y, m] = n.split('-')
  return `${y} 年 ${Number(m)} 月`
}

/** 季度 '2026-Q4' → 该季度的三个月份 ['2026-10','2026-11','2026-12'] */
export function monthsOfQuarter(period) {
  const m = /(\d{4})-Q([1-4])/.exec(normalizePeriod(period))
  if (!m) return []
  const q = Number(m[2])
  return [0, 1, 2].map((i) => `${m[1]}-${pad((q - 1) * 3 + i + 1)}`)
}

/** 月份 → 所属季度 '2026-11' → '2026-Q4' */
export function quarterOfMonth(period) {
  const m = /(\d{4})-(\d{2})/.exec(normalizePeriod(period))
  if (!m) return ''
  return `${m[1]}-Q${Math.floor((Number(m[2]) - 1) / 3) + 1}`
}

function find(scope, id, period) {
  const p = normalizePeriod(period)
  return targetState.rows.find(
    (r) => r.scope === scope && String(r.scopeId) === String(id) && r.period === p
  ) || null
}

/** 部门季度目标 */
export function targetOf(deptId, period) {
  return find('dept', deptId, period)
}

/** 个人月度目标（period 传 '2026-11'） */
export function targetOfEmployee(employeeId, period) {
  return find('employee', employeeId, period)
}

/**
 * 个人季度目标 = 该季度三个月的个人目标之和。
 * 三个月都没设返回 null（和「设成 0」区分开，页面才好说「还没拆」）。
 */
export function quarterEmployeeTarget(employeeId, quarterPeriod) {
  const months = monthsOfQuarter(quarterPeriod)
  if (!months.length) return null
  let sum = 0
  let any = false
  for (const m of months) {
    const row = targetOfEmployee(employeeId, m)
    if (row && Number(row.target) > 0) {
      any = true
      sum += Number(row.target)
    }
  }
  return any ? sum : null
}

/** 某个月设了个人目标的行 */
export function employeeTargetsIn(period) {
  const p = normalizePeriod(period)
  return targetState.rows.filter((r) => r.scope === 'employee' && r.period === p)
}

/**
 * 批量保存。
 * 季度规划是一次填一整张表的动作，逐行提交既慢又会出现「只存进去一半」，
 * 所以这里一次 PUT 把所有变更行发过去（后端数组入参、事务内逐条 upsert）。
 *
 * @param {Array<{scope?:'dept'|'employee', scopeId:number, period:string, target:number, note?:string}>} list
 */
export async function saveTargets(list) {
  if (!list.length) return []

  const body = list.map((r) => ({
    period: normalizePeriod(r.period),
    scope: r.scope || 'dept',
    scopeId: r.scopeId,
    metric: 'signed',
    amount: Number(r.target || 0),
    note: r.note || ''
  }))

  targetState.saving = true
  try {
    await request('/targets', { method: 'PUT', body })
  } finally {
    targetState.saving = false
  }

  /* 后端只回 204，本地按提交内容回写：amount=0 视作删除 */
  for (const r of body) {
    const i = targetState.rows.findIndex(
      (x) => x.scope === r.scope && String(x.scopeId) === String(r.scopeId) && x.period === r.period
    )
    if (r.amount <= 0) {
      if (i >= 0) targetState.rows.splice(i, 1)
    } else if (i >= 0) {
      targetState.rows.splice(i, 1, { ...targetState.rows[i], target: r.amount, note: r.note })
    } else {
      targetState.rows.push({
        scope: r.scope,
        scopeId: r.scopeId,
        name: '',
        period: r.period,
        target: r.amount,
        note: r.note
      })
    }
  }
  return body
}

/** 单行保存的语法糖（行内快速调整用） */
export function saveTarget(row) {
  return saveTargets([row])
}

export function targetsOf(period) {
  const p = normalizePeriod(period)
  return targetState.rows.filter((r) => r.scope === 'dept' && r.period === p)
}

/** 某季度部门目标合计。0 有两种含义，调用方要配合 hasTarget 判断「没设」还是「设成 0」 */
export function totalTarget(period) {
  return targetsOf(period).reduce((s, r) => s + Number(r.target || 0), 0)
}

export function hasTarget(period) {
  return targetsOf(period).some((r) => Number(r.target) > 0)
}

/** 哪些周期设过目标，用于季度切换里补齐历史 */
export function periodsWithTarget() {
  return [...new Set(targetState.rows.map((r) => r.period))].filter(Boolean)
}
