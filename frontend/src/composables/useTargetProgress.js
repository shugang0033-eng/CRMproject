import { computed, reactive, watch } from 'vue'
import { can } from '@/store/permissions'
import { session } from '@/store/session'
import { request } from '@/api/http'
import { flattenDepartments, loadDepartments } from '@/store/departments'
import { employeeStore, loadEmployees } from '@/store/employees'
import {
  targetOf, targetOfEmployee, targetState, loadTargets, periodsWithTarget,
  normalizePeriod, periodLabel, monthsOfQuarter,
  loadTargetScope, deptInTargetScope, targetScope
} from '@/store/targets'

const pad = (n) => String(n).padStart(2, '0')

/** '2026 Q4' / '2026-Q4' → { label:'2026 Q4', from:'2026-10-01', to:'2026-12-31' } */
export function quarterRange(label) {
  const m = /(\d{4})\s*-?\s*Q([1-4])/.exec(String(label || ''))
  if (!m) return null
  const y = Number(m[1])
  const q = Number(m[2])
  const startMonth = (q - 1) * 3 + 1
  const endMonth = q * 3
  const lastDay = new Date(y, endMonth, 0).getDate()
  return {
    label: `${y} Q${q}`,
    period: `${y}-Q${q}`,
    from: `${y}-${pad(startMonth)}-01`,
    to: `${y}-${pad(endMonth)}-${pad(lastDay)}`
  }
}

export function currentQuarter(now = new Date()) {
  const y = now.getFullYear()
  const q = Math.floor(now.getMonth() / 3) + 1
  return quarterRange(`${y} Q${q}`)
}

/** 当前自然季度，侧栏固定看这个 */
export const QUARTER = currentQuarter()

/** 页面正在看的季度（可切） */
export const periodState = reactive({ label: QUARTER.label })

export const activeQuarter = computed(() => quarterRange(periodState.label) || QUARTER)
export const isCurrentQuarter = computed(() => periodState.label === QUARTER.label)

export function setPeriod(label) {
  const q = quarterRange(label)
  if (q) periodState.label = q.label
}

export function shiftPeriod(delta) {
  const q = quarterRange(periodState.label)
  if (!q) return
  let y = Number(q.label.slice(0, 4))
  let n = Number(q.label.slice(-1)) + delta
  while (n < 1) { n += 4; y -= 1 }
  while (n > 4) { n -= 4; y += 1 }
  periodState.label = `${y} Q${n}`
}

/** 季度下拉：当前季度前后各几个，再把「设过目标的季度」并进来（历史能回看） */
export const periodOptions = computed(() => {
  const set = new Set()
  const base = quarterRange(QUARTER.label)
  let y = Number(base.label.slice(0, 4))
  let n = Number(base.label.slice(-1))
  for (let d = -4; d <= 2; d += 1) {
    let yy = y
    let nn = n + d
    while (nn < 1) { nn += 4; yy -= 1 }
    while (nn > 4) { nn -= 4; yy += 1 }
    set.add(`${yy} Q${nn}`)
  }
  periodsWithTarget().forEach((p) => {
    const q = quarterRange(p)
    if (q) set.add(q.label)
  })
  set.add(periodState.label)
  /* 新的在前；同一年里 Q4 > Q3 恰好也是字符串序，直接倒序即可 */
  return [...set].sort().reverse()
})

const results = reactive({})
const pending = new Map()
watch(() => session.user?.id, () => {
  pending.clear()
  Object.keys(results).forEach((key) => delete results[key])
}, { flush: 'sync' })
export const progressState = reactive({ loading: false, error: '',
  get contractsReady() { return dataOf(monthState.label)?.summary.achieved != null }
})

const dataOf = (label) => results[normalizePeriod(label)]
const rowsOf = (label) => dataOf(label)?.rows || []

async function loadProgress(label, force) {
  const period = normalizePeriod(label)
  if (pending.has(period)) return pending.get(period)
  if (results[period] && !force) return
  const query = { period, scope: period.includes('-Q') ? 'dept' : 'employee' }
  const job = request('/targets/progress', { query }).then((data) => {
    if (pending.get(period) === job) results[period] = data
  }).catch((e) => {
    if (pending.get(period) === job) {
      delete results[period]
      progressState.error = e.message
    }
  }).finally(() => {
    if (pending.get(period) === job) pending.delete(period)
  })
  pending.set(period, job)
  return job
}

export async function loadTargetBase({ force = false } = {}) {
  if (!can('target.view')) return
  progressState.loading = true
  progressState.error = ''
  try {
    const periods = new Set([QUARTER.label, periodState.label, currentMonth(), monthState.label])
    await Promise.allSettled([
      loadDepartments(), loadEmployees(), loadTargets({ force }), loadTargetScope({ force }),
      ...[...periods].map((label) => loadProgress(label, force))
    ])
  } finally {
    progressState.loading = pending.size > 0
  }
}

export const quarterSigned = computed(() => dataOf(periodState.label)?.summary.achieved ?? null)
export const timePct = computed(() => dataOf(periodState.label)?.summary.timePct ?? 0)

/** 季度剩余天数（历史季度为 0，未来季度为全部天数） */
export const daysLeft = computed(() => {
  const q = activeQuarter.value
  const end = new Date(`${q.to}T23:59:59`).getTime()
  return Math.max(0, Math.ceil((end - Date.now()) / 86400000))
})

/** 节奏：完成率 − 时间进度。±5 个点以内算跟得上 */
export function paceOf(pct, time, configured) {
  if (!configured) return { gap: null, tone: 'none', text: '—' }
  const gap = pct - time
  if (gap >= 5) return { gap, tone: 'ahead', text: `领先 ${gap} 个点` }
  if (gap > -5) return { gap, tone: 'ontrack', text: '跟得上节奏' }
  return { gap, tone: 'behind', text: `落后 ${Math.abs(gap)} 个点` }
}

/** 表格行：真实部门 × 该季度目标 × 真实完成额 */
/**
 * 当前账号范围内能看/能改的部门（含下级）。
 * depth 按「可见的父部门」重算：销售一组组长的可见范围只有销售一组，
 * 若沿用整棵树的 depth，会渲染成「└ 销售一组」却没有上级，看着像数据缺了。
 */
export const scopeDepts = computed(() => {
  const flat = flattenDepartments()
  const visSet = new Set(flat.filter((d) => deptInTargetScope(d.id)).map((d) => String(d.id)))
  const parentOf = new Map(flat.map((d) => [String(d.id), d.parentId == null ? null : String(d.parentId)]))
  const depthOf = (id) => {
    let depth = 0
    let p = parentOf.get(id)
    while (p != null && visSet.has(p) && depth < 8) {
      depth++
      p = parentOf.get(p)
    }
    return depth
  }
  return flat
    .filter((d) => visSet.has(String(d.id)))
    .map((d) => ({ ...d, depth: depthOf(String(d.id)) }))
})

/** 「销售部、销售一组」这种范围描述，用于页面上的权限说明 */
export const scopeDeptNames = computed(() => scopeDepts.value.map((d) => d.name))

export const targetProgress = computed(() => {
  const label = periodState.label
  const resultsByDept = new Map(rowsOf(label).map((r) => [String(r.scopeId), r]))

  const flat = scopeDepts.value

  const childCount = new Map()
  flat.forEach((d) => {
    if (d.parentId == null) return
    childCount.set(String(d.parentId), (childCount.get(String(d.parentId)) || 0) + 1)
  })

  return flat
    .map((d) => {
      const row = targetOf(d.id, label)
      const target = Number(row?.target || 0)
      const progress = resultsByDept.get(String(d.id))
      const done = progress?.achieved ?? null
      const configured = target > 0
      const pct = progress?.pct ?? null
      return {
        id: d.id,
        name: d.name,
        depth: d.depth,
        leader: d.leader || '—',
        headcount: d.count || 0,
        children: childCount.get(String(d.id)) || 0,
        target,
        achieved: done,
        note: row?.note || '',
        configured,
        pct,
        gapAmount: Math.max(0, progress?.gap ?? 0),
        pace: serverPace(progress)
      }
    })
    /* 没目标、没业绩、也没人的部门不占行，避免表格全是 0 */
    .filter((r) => r.configured || (r.achieved || 0) > 0 || r.headcount > 0)
})

function serverPace(row) {
  if (!row?.pace) return paceOf(0, 0, false)
  const gap = row.pct - row.timePct
  const text = row.pace === 'ahead' ? '领先 ' + gap + ' 个点'
    : row.pace === 'behind' ? '落后 ' + Math.abs(gap) + ' 个点' : '跟得上节奏'
  return { gap, tone: row.pace, text }
}

export function summaryOf(label) {
  const summary = dataOf(label)?.summary
  const target = summary?.target ?? 0
  const achieved = summary?.achieved ?? null
  return {
    label, quarter: quarterRange(label) || QUARTER, target, achieved,
    configured: target > 0, pct: summary?.pct ?? null,
    diff: target > 0 && achieved != null ? target - achieved : null,
    rows: summary?.configuredCount ?? 0,
    timePct: summary?.timePct ?? 0, pace: serverPace(summary)
  }
}

/** 页面正在看的季度 */
export const targetSummary = computed(() => summaryOf(periodState.label))

/** 侧栏固定看当前自然季度，不受页面切换影响 */
export const currentQuarterSummary = computed(() => summaryOf(QUARTER.label))

/* ============================================================
 * 个人月度目标
 * ------------------------------------------------------------
 * 部门目标是「承诺」，个人目标是「执行」。销售按月冲刺、按月算提成，
 * 所以个人目标一律按自然月存（'2026-11'），季度数由三个月求和得到。
 *
 * 完成额口径与部门一致：本人负责的合同、签订日在本月、状态不是待审批/作废/终止。
 * 负责人用 owner_id 精确匹配，不按姓名匹配（重名、改名都会归错人）。
 * ============================================================ */

/** 本月 'YYYY-MM' */
export function currentMonth(now = new Date()) {
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}`
}

/** 页面正在看的月份（业绩目标页可切） */
export const monthState = reactive({ label: currentMonth() })

export function monthRange(label) {
  const m = /(\d{4})-(\d{2})/.exec(normalizePeriod(label))
  if (!m) return null
  const y = Number(m[1])
  const mo = Number(m[2])
  const days = new Date(y, mo, 0).getDate()
  return {
    label: `${m[1]}-${m[2]}`,
    from: `${m[1]}-${m[2]}-01`,
    to: `${m[1]}-${m[2]}-${pad(days)}`,
    days
  }
}

export function setMonth(label) {
  const r = monthRange(label)
  if (r) monthState.label = r.label
}

export function shiftMonth(delta) {
  const r = monthRange(monthState.label) || monthRange(currentMonth())
  const d = new Date(Number(r.label.slice(0, 4)), Number(r.label.slice(5, 7)) - 1 + delta, 1)
  monthState.label = currentMonth(d)
}

/** 月份下拉：本月前后各 11 个月 + 设过个人目标的月份 */
export const monthOptions = computed(() => {
  const set = new Set()
  const now = new Date()
  for (let d = -11; d <= 3; d += 1) {
    const t = new Date(now.getFullYear(), now.getMonth() + d, 1)
    set.add(currentMonth(t))
  }
  targetState.rows.forEach((r) => {
    if (r.scope === 'employee' && /^\d{4}-\d{2}$/.test(r.period)) set.add(r.period)
  })
  set.add(monthState.label)
  return [...set].sort().reverse()
})

export const isCurrentMonth = computed(() => monthState.label === currentMonth())

function employeeProgress(employeeId, label) {
  return rowsOf(label).find((r) => String(r.scopeId) === String(employeeId))
}

export function achievedOfEmployee(employeeId, label) {
  return employeeProgress(employeeId, label)?.achieved ?? null
}

export const monthSummary = computed(() => {
  const row = dataOf(monthState.label)?.summary
  const target = row?.target ?? 0
  const achieved = row?.achieved ?? null
  return {
    target, achieved, pct: row?.pct ?? null, configured: target > 0,
    diff: target > 0 && achieved != null ? target - achieved : null,
    setCount: row?.configuredCount ?? 0, unsetCount: row?.unsetCount ?? 0,
    unsetAchieved: row?.unsetAchieved ?? null,
    totalCount: (row?.configuredCount ?? 0) + (row?.unsetCount ?? 0),
    timePct: row?.timePct ?? 0, pace: serverPace(row)
  }
})

export const employeeAchieved = computed(() =>
  new Map(rowsOf(monthState.label).map((r) => [String(r.scopeId), r.achieved]))
)

watch([() => periodState.label, () => monthState.label], () => loadTargetBase())

/** 月度时间进度：这个月已经过去百分之多少 */
export function timePctOfMonth(label) {
  const r = monthRange(label)
  if (!r) return 0
  const from = new Date(`${r.from}T00:00:00`).getTime()
  const to = new Date(`${r.to}T23:59:59`).getTime()
  const now = Date.now()
  if (now <= from) return 0
  if (now >= to) return 100
  return Math.round(((now - from) / (to - from)) * 100)
}

/** 当月剩余天数（历史月份为 0） */
export function daysLeftInMonth(label) {
  const r = monthRange(label)
  if (!r) return 0
  return Math.max(0, Math.ceil((new Date(`${r.to}T23:59:59`).getTime() - Date.now()) / 86400000))
}

/**
 * 某个人的月度目标档案。
 * configured=false 时 driven 的字段全是 null/0，调用方必须显示「还没设」，
 * 不能显示成「0 / 0 = 0%」——那会让人以为目标就是 0。
 */
export function goalOfEmployee(employeeId, monthLabel) {
  const r = monthRange(monthLabel)
  const row = targetOfEmployee(employeeId, monthLabel)
  const target = Number(row?.target || 0)
  const configured = target > 0
  const achieved = achievedOfEmployee(employeeId, monthLabel)
  const pct = configured && achieved != null ? Math.round((achieved / target) * 100) : null
  const progress = employeeProgress(employeeId, monthLabel)
  const time = progress?.timePct ?? timePctOfMonth(monthLabel)
  return {
    label: monthLabel,
    month: periodLabel(monthLabel),
    target,
    achieved,
    configured,
    pct,
    diff: configured && achieved != null ? target - achieved : null,
    note: row?.note || '',
    timePct: time,
    daysLeft: daysLeftInMonth(monthLabel),
    /* 完成额算不出来时节奏也判断不了：拿 0% 去比时间进度，只会得出「落后 52 个点」这种假结论 */
    pace: serverPace(progress)
  }
}

/** 业绩目标页正在看的月份、全体员工的行（按部门树顺序排，同部门内按姓名） */
export const monthGoalRows = computed(() => {
  const label = monthState.label
  const done = employeeAchieved.value
  const order = new Map()
  flattenDepartments().forEach((d, i) => order.set(String(d.id), i))

  const rows = employeeStore.list
    /* 只看得到范围内的部门：范围外的同事不列出来，否则会显示成「未设目标」的假信息 */
    .filter((e) => deptInTargetScope(e.deptId))
    /* 停用员工不参与排目标；但他若在本月还有目标，仍然列出来，否则账对不上 */
    .filter((e) => e.status !== '停用' || Number(targetOfEmployee(e.rawId, label)?.target || 0) > 0)
    .map((e) => {
      const row = targetOfEmployee(e.rawId, label)
      const target = Number(row?.target || 0)
      /* 本月没合同就是 0，不是「未知」；contracts 没拉到时才是 null */
      const doneAmt = done.has(String(e.rawId)) ? done.get(String(e.rawId)) : 0
      const achieved = done.has(String(e.rawId)) ? doneAmt : null
      /* 有目标、一笔没签 → 0%，不能让完成率显示成「—」 */
      const pct = target > 0 && achieved != null ? Math.round((achieved / target) * 100) : null
      return {
        id: e.rawId,
        name: e.name,
        deptId: e.deptId,
        dept: e.dept,
        target,
        achieved,
        configured: target > 0,
        pct,
        note: row?.note || ''
      }
    })

  /* 不排序的话名单是后端返回顺序，销售部的人会散落在财务、运营之间，看不出组织结构 */
  return rows.sort((a, b) => {
    const oa = order.get(String(a.deptId)) ?? 999
    const ob = order.get(String(b.deptId)) ?? 999
    if (oa !== ob) return oa - ob
    return String(a.name).localeCompare(String(b.name), 'zh-Hans-CN')
  })
})

/**
 * 有没有资格看全员的个人目标。
 * 后端对没有 target.manage 的人只返回他自己那一行目标，前端若照样把全员列出来，
 * 同事会全部显示成「未设目标」——他们其实有目标，只是不让这个账号看。这是假信息，
 * 所以列表本身就得跟着权限收，而不是只把按钮藏掉。
 */
export const canSeeAllPeople = computed(() => can('target.manage'))

/** 业绩目标页个人视图能列出来的人：能管目标看全员，否则只有自己 */
export const goalRows = computed(() => {
  if (canSeeAllPeople.value) return monthGoalRows.value
  const me = String(session.user?.id ?? '')
  if (!me) return []
  return monthGoalRows.value.filter((r) => String(r.id) === me)
})

/** 当前登录人的本月目标（工作台「我的目标」；固定自然月，不受页面切换影响） */
export const myMonthGoal = computed(() => {
  const me = session.user
  if (!me?.id) {
    return {
      label: currentMonth(), configured: false, target: 0, achieved: null, pct: null,
      diff: null, timePct: timePctOfMonth(currentMonth()), daysLeft: daysLeftInMonth(currentMonth()),
      pace: paceOf(0, 0, false), note: ''
    }
  }
  return goalOfEmployee(me.id, currentMonth())
})

/** 个人本季度目标 = 该季度三个月目标之和；一个月都没设返回 null */
export function myQuarterTarget() {
  const me = session.user
  if (!me?.id) return null
  let sum = 0
  let any = false
  for (const m of monthsOfQuarter(QUARTER.label)) {
    const row = targetOfEmployee(me.id, m)
    if (row && Number(row.target) > 0) {
      any = true
      sum += Number(row.target)
    }
  }
  return any ? sum : null
}
