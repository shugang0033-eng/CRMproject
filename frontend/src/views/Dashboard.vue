<template>
  <div class="page">
    <PageHead :title="greeting" :desc="dateLine">
      <span class="range-tag">{{ monthLabel }}</span>
      <button class="btn" type="button" :disabled="dashLoading" @click="refresh">
        <AppIcon name="refresh" :size="14" :class="{ spin: dashLoading }" />
        刷新
      </button>
    </PageHead>

    <!-- ==================== 实时概况（全部来自订单 / 回款 / 线索） ==================== -->
    <section class="kpi-row">
      <article v-for="k in kpi" :key="k.key" class="kpi card">
        <div class="kpi-top">
          <span>{{ k.label }}</span>
          <span class="kpi-ico"><AppIcon :name="kpiIcon[k.key]" :size="15" /></span>
        </div>
        <div class="kpi-val">
          <template v-if="k.money">¥{{ (k.value / 10000).toFixed(1) }}<i>万</i></template>
          <template v-else>{{ k.value }}<i>{{ k.unit }}</i></template>
        </div>
        <div class="kpi-foot">
          <span v-if="k.delta != null" class="delta" :class="k.delta >= 0 ? 'pos' : 'neg'">
            <AppIcon :name="k.delta >= 0 ? 'arrow-up' : 'arrow-down'" :size="11" />
            {{ Math.abs(k.delta).toFixed(1) }}%
          </span>
          <span class="faint">{{ k.hint }}</span>
        </div>
      </article>
    </section>

    <!-- ==================== 我的本月目标 ====================
         上面四个 KPI 是公司口径（所有人加起来），这一条是「我自己」的数。
         销售每天打开系统第一眼该看到的是「这个月还差多少」，所以放在 KPI 正下方。 -->
    <section v-if="canSeeGoal" class="my-goal card">
      <template v-if="goal.configured">
        <div class="mg-head">
          <span class="dot" />
          <span class="mg-title">我的本月目标</span>
          <span class="mg-month">{{ goal.month }}</span>
          <span class="spacer" />
          <span class="mg-pace" :class="goalTone">
            {{ goal.pace.text }}
          </span>
        </div>
        <div class="mg-body">
          <div class="mg-nums">
            <b>¥{{ (goal.target / 10000).toFixed(1) }}<i>万</i></b>
            <span class="mg-sub">
              已完成 {{ goal.achieved == null ? '—' : money(goal.achieved) }}
              <template v-if="goal.diff != null">
                · {{ goal.diff <= 0 ? `超额 ${money(-goal.diff)}` : `还差 ${money(goal.diff)}` }}
              </template>
              <template v-else-if="!canSeeAchieved">· 完成额需合同查看权限，找管理员看</template>
            </span>
          </div>
          <div class="mg-bar">
            <div class="bar">
              <i :style="{ width: Math.min(100, goal.pct || 0) + '%', background: goalColor }" />
            </div>
            <span>{{ goal.pct == null ? '—' : goal.pct + '%' }}</span>
          </div>
          <div class="mg-meta">
            <span>本月剩余 {{ goal.daysLeft }} 天</span>
            <span class="faint">时间已过 {{ goal.timePct }}%</span>
          </div>
        </div>
      </template>
      <template v-else>
        <div class="mg-head">
          <span class="dot" />
          <span class="mg-title">我的本月目标</span>
          <span class="mg-month">{{ goal.month }}</span>
        </div>
        <p class="mg-empty">
          这个月还没有给你设个人目标，所以「还差多少」算不出来。
          {{ deptTargetHint }}
        </p>
      </template>
    </section>

    <!-- ==================== 待办 / 日历 / 日程 ==================== -->
    <section class="three-col">
      <!-- 待办：数字全部来自与「待办」页同一份聚合，不再用演示计数 -->
      <div class="card todo-card">
        <div class="card-head">
          <div class="card-title"><span class="dot" />待办事项</div>
          <span class="card-sub">共 {{ todoCounts.total }} 项待处理</span>
        </div>
        <div class="todo-list">
          <button
            v-for="t in todoRows"
            :key="t.key"
            type="button"
            class="todo-item"
            @click="go(t.path)"
          >
            <span class="todo-ico" :class="{ warn: t.danger }">
              <AppIcon :name="t.icon" :size="15" />
            </span>
            <span class="todo-txt">
              <strong>{{ t.label }}</strong>
              <em>{{ t.desc }}</em>
            </span>
            <span class="todo-num" :class="{ warn: t.danger }">{{ t.count }}</span>
            <AppIcon class="todo-arrow" name="chevron-right" :size="14" />
          </button>
          <p v-if="!todoRows.length" class="todo-empty">
            <AppIcon name="check-circle" :size="15" />
            当前没有待处理事项
          </p>
        </div>
        <div class="todo-foot clickable" @click="go('/todos')">
          <AppIcon name="check-circle" :size="14" />
          {{ todoCounts.overdue ? `${todoCounts.overdue} 项已逾期，去待办页处理` : '查看全部待办' }}
          <AppIcon class="todo-arrow" name="chevron-right" :size="13" />
        </div>
      </div>

      <!-- 日历：标记来自真实待办的到期日，点某天看当天要处理什么 -->
      <div class="card cal-card">
        <div class="card-head">
          <div class="card-title"><span class="dot" />日历</div>
          <span class="card-sub">本月 {{ todoMarksCount }} 个到期日</span>
        </div>
        <div class="card-body">
          <MiniCalendar :marks="todoMarks" @select="onSelectDate" />
        </div>
      </div>

      <!-- 当日待办：原来是写死的「今日日程」，现在换成真实待办 -->
      <div class="card agenda-card">
        <div class="card-head">
          <div class="card-title"><span class="dot" />{{ isToday ? '今日待办' : '当日待办' }}</div>
          <span class="card-sub">{{ dayTodos.length }} 项</span>
        </div>
        <div v-if="dayTodos.length" class="agenda">
          <div v-for="item in dayTodos" :key="item.key" class="agenda-item">
            <div class="ag-time">{{ item.kind }}</div>
            <div class="ag-line"><i /></div>
            <div class="ag-body">
              <strong>{{ item.title }}</strong>
              <span v-if="item.desc">
                <AppIcon name="flag" :size="12" />
                {{ item.desc }}
              </span>
              <span class="tag plain" :class="`tag-${item.tone}`">{{ item.dueText }}</span>
            </div>
          </div>
        </div>
        <div v-else class="empty">
          <div class="empty-icon"><AppIcon name="check-circle" :size="20" /></div>
          <span>{{ isToday ? '今天没有到期的待办' : '该日没有待办' }}</span>
        </div>
        <div class="agenda-foot" @click="go('/todos')">
          查看全部待办 <AppIcon name="chevron-right" :size="13" />
        </div>
      </div>
    </section>

    <!-- ==================== 走势 / 漏斗 ==================== -->
    <section class="two-col">
      <div class="card">
        <div class="card-head">
          <div class="card-title"><span class="dot" />近 7 日下单金额</div>
          <div class="legend">
            <span><i class="lg-bar" />近 7 日</span>
            <span><i class="lg-line" />日均 ¥{{ avg.toFixed(1) }} 万</span>
          </div>
        </div>
        <div class="card-body">
          <div class="chart">
            <div class="chart-y">
              <span v-for="t in yTicks" :key="t">{{ t }}</span>
            </div>
            <div class="chart-plot">
              <div class="grid-lines">
                <i v-for="n in 4" :key="n" />
              </div>
              <div class="avg-line" :style="{ bottom: avgBottom }" />
              <div class="bars">
                <div v-for="d in trend" :key="d.day" class="bar-col">
                  <span class="bar-val">{{ d.value }}</span>
                  <div class="bar-shape" :style="{ height: barHeight(d.value) }">
                    <i />
                  </div>
                  <span class="bar-day">{{ d.day }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="card">
        <div class="card-head">
          <div class="card-title"><span class="dot" />询盘漏斗</div>
          <span class="card-sub">全部线索 · 按到达阶段累计</span>
        </div>
        <div class="card-body funnel-body">
          <div v-for="(f, i) in funnel" :key="f.stage" class="funnel-row">
            <div class="funnel-meta">
              <span class="f-stage">{{ f.stage }}</span>
              <span class="f-right">
                <span class="f-count">{{ f.count }} <em>条</em></span>
                <span class="f-rate">{{ f.rate }}%</span>
              </span>
            </div>
            <div class="funnel-track">
              <div class="funnel-fill" :style="{ width: widthOf(f) + '%', opacity: 0.42 + i * 0.14 }" />
            </div>
          </div>
          <div class="funnel-foot">
            询盘到成交整体转化率 <b>{{ overallRate == null ? '—' : overallRate.toFixed(1) + '%' }}</b>
            <span class="faint">{{ funnel[0]?.count || 0 }} 条线索成交 {{ funnel[4]?.count || 0 }} 单</span>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import MiniCalendar from '@/components/MiniCalendar.vue'
import { session } from '@/store/session'
import { useTodos, KINDS, KIND_META } from '@/composables/useTodos'
import { useDashboard } from '@/composables/useDashboard'
import { myMonthGoal, currentQuarterSummary } from '@/composables/useTargetProgress'
import { targetScope } from '@/store/targets'
import { can } from '@/store/permissions'

const router = useRouter()

/* ---------------- 我的本月目标 ----------------
 * 个人目标是月度口径（旧数据里部门目标是季度），所以这一条只认月份：
 * 本月没设就直说没设，不拿季度目标除 3 来冒充。
 */
const goal = computed(() => myMonthGoal.value)
/* 只要能看到业绩目标就显示这一条：市场专员这类没有合同权限的人也有目标，
   把整条藏掉等于告诉他们「你没有目标」。看不到完成额时如实标注，不编数字 */
const canSeeGoal = computed(() => can('target.view') && Boolean(session.user?.id))
const canSeeAchieved = computed(() => can('contract.view'))
const goalTone = computed(() => {
  const tone = goal.value.pace.tone
  return tone === 'ahead' ? 'pos' : tone === 'behind' ? 'neg' : ''
})
const goalColor = computed(() => {
  const p = goal.value.pct
  if (p == null) return '#c8ced8'
  if (p >= 100) return 'var(--success)'
  if (p >= 60) return '#2b6cb0'
  return '#c98a2e'
})
const deptTargetHint = computed(() => {
  const t = currentQuarterSummary.value.target
  if (!t) return '部门季度目标也还没设，先去「业绩目标」把季度数定了。'
  const who = targetScope.all ? '公司' : '本部门'
  return `本季度${who}目标 ¥${(t / 10000).toFixed(1)} 万，可以让部门负责人拆到这个月。`
})
/** 一万以上按万显示，几千块就按原值 —— 销售看自己的数时不希望「还差 ¥0.3 万」 */
function money(n) {
  if (n == null) return '—'
  return Math.abs(n) >= 10000 ? `¥${(n / 10000).toFixed(1)} 万` : `¥${Math.round(n).toLocaleString()}`
}

/* 待办与「待办」页共用同一份聚合结果，数字不会两处不一致 */
const { counts: todoCounts, items: todoItems, refresh: refreshTodos } = useTodos()

/* 四个 KPI + 走势 + 漏斗全部来自真实单据 */
const { kpi, trend, funnel, loading: dashLoading, load: loadDash } = useDashboard()

onMounted(() => {
  refreshTodos().catch(() => {})
  loadDash()
})

const kpiIcon = {
  orders: 'file',
  received: 'wallet',
  deals: 'check-circle',
  ship: 'box'
}

/* ---------------- 问候与日期 ---------------- */
const today = new Date()
const selected = ref(fmt(today))

const greeting = computed(() => {
  const h = new Date().getHours()
  const word = h < 6 ? '夜深了' : h < 11 ? '早上好' : h < 14 ? '中午好' : h < 18 ? '下午好' : '晚上好'
  return `${word}，${session.user?.name || '同事'}`
})

const dateLine = computed(() => {
  const d = new Date()
  const week = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][d.getDay()]
  const tail = todoCounts.value.today
    ? `今天有 ${todoCounts.value.today} 项到期待办`
    : todoCounts.value.total
      ? `共 ${todoCounts.value.total} 项待办，今天没有到期的`
      : '待办已清空'
  return `${d.getFullYear()} 年 ${d.getMonth() + 1} 月 ${d.getDate()} 日 ${week} · ${tail}`
})

const KIND_LABEL = {
  审批: '待我审批',
  合同: '待审合同',
  发货: '待发货订单',
  对账: '待确认对账',
  退货: '待审核退货',
  跟进: '待跟进客户',
  线索: '待联系线索'
}

const KIND_DESC = {
  审批: '报销、借款与请假',
  合同: '审批通过才能执行',
  发货: '已确认待出库',
  对账: '客户确认后才能开票',
  退货: '确认入库或驳回',
  跟进: '按到期日排好了',
  线索: '24 小时内首次联系'
}

/** 有数才列，按数量降序取前 6 类（固定顺序截断会把条数最多的那类挤掉） */
const todoRows = computed(() => {
  const c = todoCounts.value.byKind
  return KINDS.filter((k) => (c[k] || 0) > 0)
    .sort((a, b) => (c[b] || 0) - (c[a] || 0))
    .slice(0, 6)
    .map((k) => ({
      key: k,
      icon: KIND_META[k].icon,
      label: KIND_LABEL[k],
      desc: KIND_DESC[k],
      count: c[k],
      path: KIND_META[k].path,
      danger: todoItems.value.some((t) => t.kind === k && t.bucket === 'overdue')
    }))
})

const isToday = computed(() => selected.value === fmt(today))

/* 日历标记：真实待办的到期日，key 用完整日期（跨月不会标到同号的另一天） */
const todoMarks = computed(() => {
  const map = {}
  todoItems.value.forEach((t) => {
    if (!t.due) return
    const [y, m, d] = String(t.due).slice(0, 10).split('-').map(Number)
    if (!y || !m || !d) return
    const key = `${y}-${m}-${d}`
    map[key] = (map[key] || 0) + 1
  })
  return map
})

const todoMarksCount = computed(() => Object.keys(todoMarks.value).length)

/* 选中日期的待办；无待办的日子就是空 */
const dayTodos = computed(() =>
  todoItems.value.filter((t) => {
    if (!t.due) return false
    const [y, m, d] = String(t.due).slice(0, 10).split('-').map(Number)
    return `${y}-${m}-${d}` === selected.value
  })
)

function fmt(d) {
  return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`
}

function onSelectDate(key) {
  selected.value = key
}

/* y 轴跟着真实最大值走，不再写死 35 万。
   先按 10 的幂取整，再保证 4 等分后刻度好读（0.3 / 0.25 这类都比 0.30000004 强） */
const maxTrend = computed(() => {
  const max = Math.max(...trend.value.map((d) => d.value), 0)
  if (max <= 0) return 4
  const step = Math.pow(10, Math.floor(Math.log10(max)))
  const v = Math.ceil(max / step) * step
  return Math.round(v * 100) / 100
})

const yTicks = computed(() => {
  const m = maxTrend.value
  return [4, 3, 2, 1, 0].map((i) => {
    const v = (m / 4) * i
    if (Number.isInteger(v)) return String(v)
    return v.toFixed(2).replace(/0+$/, '').replace(/\.$/, '')
  })
})

function barHeight(v) {
  return `${Math.min(100, Math.round((v / maxTrend.value) * 100))}%`
}

const avg = computed(() => {
  if (!trend.value.length) return 0
  return trend.value.reduce((s, d) => s + d.value, 0) / trend.value.length
})
const avgBottom = computed(() => `calc(${(avg.value / maxTrend.value) * 100}% - 18px)`)

/* 漏斗条长代表「到达该阶段的线索数占总量」，不是阶段间转化率；
   否则每根条都接近满宽，看不出漏斗形状 */
const widthOf = (f) => {
  const base = funnel.value[0]?.count || 0
  return base ? Math.max(4, Math.round((f.count / base) * 100)) : 0
}

const overallRate = computed(() => {
  const base = funnel.value[0]?.count || 0
  if (!base) return null
  return ((funnel.value[4]?.count || 0) / base) * 100
})

const monthLabel = computed(() => {
  const d = new Date()
  return `${d.getFullYear()} 年 ${d.getMonth() + 1} 月`
})

function go(path) {
  router.push(path)
}

async function refresh() {
  await Promise.all([loadDash(), refreshTodos().catch(() => {})])
}
</script>

<style scoped>
.range {
  width: 108px;
  height: 36px;
}

.range-tag {
  font-size: 12.5px;
  color: var(--muted);
  padding: 5px 10px;
  background: #f3f5f8;
  border-radius: 7px;
  font-variant-numeric: tabular-nums;
}

.agenda-foot {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
  margin-top: auto;
  padding: 10px 0 2px;
  border-top: 1px solid var(--line-soft);
  font-size: 11.5px;
  color: var(--faint);
  cursor: pointer;
  transition: color 0.14s;
}
.agenda-foot:hover {
  color: var(--brand);
}

.spin {
  animation: spin 0.7s linear infinite;
}
@keyframes spin {
  to { transform: rotate(360deg); }
}

/* ---------------- 我的本月目标 ---------------- */
/* 个人视角的一条，别做得比上面的公司 KPI 还抢眼 */
.my-goal {
  margin-top: 16px;
  padding: 14px 18px;
}
.mg-head {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12.5px;
  color: var(--muted);
}
.mg-title {
  color: var(--ink);
  font-weight: 600;
}
.mg-month {
  font-size: 11.5px;
  color: var(--faint);
}
.mg-head .spacer {
  flex: 1;
}
.mg-pace {
  font-size: 12px;
  color: var(--muted);
}
.mg-pace.pos {
  color: var(--success);
}
.mg-pace.neg {
  color: var(--danger);
}
.mg-body {
  display: flex;
  align-items: center;
  gap: 22px;
  margin-top: 11px;
  flex-wrap: wrap;
}
.mg-nums {
  display: flex;
  align-items: baseline;
  gap: 10px;
  min-width: 200px;
}
.mg-nums b {
  font-size: 22px;
  font-weight: 650;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.3px;
}
.mg-nums b i {
  font-style: normal;
  font-size: 12px;
  font-weight: 500;
  color: var(--faint);
  margin-left: 2px;
}
.mg-sub {
  font-size: 12px;
  color: var(--muted);
  font-variant-numeric: tabular-nums;
}
.mg-bar {
  flex: 1;
  min-width: 200px;
  display: flex;
  align-items: center;
  gap: 10px;
}
.mg-bar .bar {
  flex: 1;
}
.mg-bar span {
  min-width: 38px;
  font-size: 12px;
  color: var(--muted);
  font-variant-numeric: tabular-nums;
}
.mg-meta {
  display: flex;
  gap: 14px;
  font-size: 11.5px;
  color: var(--muted);
}
.mg-empty {
  margin: 9px 0 0;
  font-size: 12.5px;
  line-height: 1.7;
  color: var(--muted);
}

/* ---------------- KPI ---------------- */
.kpi-row {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 16px;
}
.kpi {
  padding: 16px 18px 14px;
  transition: box-shadow 0.2s, transform 0.2s;
}
.kpi:hover {
  box-shadow: var(--shadow-sm);
  transform: translateY(-1px);
}
.kpi-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 12.5px;
  color: var(--muted);
}
.kpi-ico {
  width: 26px;
  height: 26px;
  border-radius: 7px;
  display: grid;
  place-items: center;
  background: var(--brand-soft);
  color: var(--brand);
}
.kpi-val {
  margin: 10px 0 10px;
  font-size: 26px;
  font-weight: 650;
  color: var(--ink);
  letter-spacing: -0.2px;
  font-variant-numeric: tabular-nums;
  line-height: 1.1;
}
.kpi-val i {
  font-style: normal;
  font-size: 12.5px;
  font-weight: 500;
  color: var(--faint);
  margin-left: 3px;
  letter-spacing: 0;
}
.kpi-foot {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 11.5px;
}
.delta {
  display: inline-flex;
  align-items: center;
  gap: 1px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}

/* ---------------- 三列 ---------------- */
.three-col {
  display: grid;
  grid-template-columns: 1.15fr 1fr 1fr;
  gap: 16px;
  margin-top: 16px;
  align-items: stretch;
}

.todo-card,
.cal-card,
.agenda-card {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.todo-list {
  flex: 1;
  padding: 8px;
}

.todo-item {
  display: flex;
  align-items: center;
  gap: 11px;
  width: 100%;
  padding: 10px 10px;
  border: none;
  background: transparent;
  border-radius: 9px;
  cursor: pointer;
  text-align: left;
  transition: background 0.15s;
}
.todo-item:hover {
  background: #f6f8fa;
}
.todo-item:hover .todo-arrow {
  opacity: 1;
  transform: translateX(2px);
}

.todo-ico {
  width: 30px;
  height: 30px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  background: var(--brand-soft);
  color: var(--brand);
  flex-shrink: 0;
}
.todo-ico.warn {
  background: var(--danger-bg);
  color: var(--danger);
}

.todo-txt {
  display: flex;
  flex-direction: column;
  line-height: 1.45;
  flex: 1;
  min-width: 0;
}
.todo-txt strong {
  font-size: 13px;
  font-weight: 550;
  color: var(--ink);
}
.todo-txt em {
  font-style: normal;
  font-size: 11.5px;
  color: var(--faint);
}

.todo-num {
  font-size: 17px;
  font-weight: 650;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
}
.todo-num.warn {
  color: var(--danger);
}
.todo-arrow {
  color: #c3c9d3;
  opacity: 0;
  transition: all 0.15s;
}

.todo-foot {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 11px 18px;
  border-top: 1px solid var(--line-soft);
  font-size: 11.5px;
  color: var(--faint);
  background: #fbfcfd;
  border-radius: 0 0 10px 10px;
}
.todo-foot.clickable {
  cursor: pointer;
  transition: background 0.14s, color 0.14s;
}
.todo-foot.clickable:hover {
  background: var(--brand-soft);
  color: var(--brand);
}
.todo-foot .todo-arrow {
  margin-left: auto;
}

.todo-empty {
  display: flex;
  align-items: center;
  gap: 7px;
  margin: 0;
  padding: 26px 18px;
  font-size: 12px;
  color: var(--faint);
}

.cal-card .card-body {
  padding: 14px 16px 16px;
}

/* 日程 */
.agenda {
  padding: 6px 16px 14px;
}
.agenda-item {
  display: flex;
  gap: 0;
  padding: 9px 0;
}
.ag-time {
  width: 42px;
  flex-shrink: 0;
  font-size: 12px;
  font-weight: 600;
  color: var(--text);
  font-variant-numeric: tabular-nums;
  padding-top: 1px;
}
.ag-line {
  position: relative;
  width: 12px;
  flex-shrink: 0;
  display: flex;
  justify-content: center;
}
.ag-line::before {
  content: '';
  position: absolute;
  top: 12px;
  bottom: -14px;
  width: 1px;
  background: var(--line);
}
.agenda-item:last-child .ag-line::before {
  display: none;
}
.ag-line i {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #fff;
  border: 2px solid var(--brand);
  margin-top: 5px;
  z-index: 1;
}
.ag-body {
  display: flex;
  flex-direction: column;
  gap: 3px;
  min-width: 0;
  padding-left: 8px;
}
.ag-body strong {
  font-size: 12.8px;
  font-weight: 550;
  color: var(--ink);
  line-height: 1.4;
}
.ag-body span {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 11.5px;
  color: var(--faint);
}
.ag-body .tag {
  align-self: flex-start;
  margin-top: 2px;
}

/* ---------------- 走势 / 漏斗 ---------------- */
.two-col {
  display: grid;
  grid-template-columns: 1.7fr 1fr;
  gap: 16px;
  margin-top: 16px;
}

.legend {
  display: flex;
  align-items: center;
  gap: 14px;
  font-size: 11.5px;
  color: var(--faint);
}
.legend span {
  display: inline-flex;
  align-items: center;
  gap: 5px;
}
.lg-bar {
  width: 8px;
  height: 8px;
  border-radius: 2px;
  background: var(--brand);
}
.lg-line {
  width: 12px;
  height: 0;
  border-top: 1.5px dashed #c1ccda;
}

.chart {
  display: flex;
  gap: 10px;
  height: 208px;
}
.chart-y {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding-bottom: 22px;
  width: 22px;
  flex-shrink: 0;
  text-align: right;
}
.chart-y span {
  font-size: 10.5px;
  color: var(--faint);
  font-variant-numeric: tabular-nums;
}

.chart-plot {
  position: relative;
  flex: 1;
  min-width: 0;
  padding-bottom: 22px;
}
.grid-lines {
  position: absolute;
  inset: 0 0 22px 0;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}
.grid-lines i {
  height: 1px;
  background: #f1f3f7;
}
.avg-line {
  position: absolute;
  left: 0;
  right: 0;
  border-top: 1.5px dashed #cfd9e5;
  z-index: 2;
}
.bars {
  position: absolute;
  inset: 0 0 0 0;
  display: flex;
  align-items: flex-end;
  justify-content: space-around;
  gap: 8px;
}
.bar-col {
  position: relative;
  flex: 1;
  max-width: 62px;
  height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  align-items: center;
  padding-bottom: 22px;
}
.bar-val {
  font-size: 10.5px;
  color: var(--faint);
  margin-bottom: 5px;
  font-variant-numeric: tabular-nums;
}
.bar-shape {
  width: 100%;
  max-width: 34px;
  border-radius: 4px 4px 2px 2px;
  background: linear-gradient(180deg, #4f8fd0, #2b6cb0);
  transition: height 0.5s cubic-bezier(0.22, 1, 0.36, 1);
  position: relative;
}
.bar-shape i {
  position: absolute;
  inset: 0;
  border-radius: inherit;
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.22), transparent 60%);
}
.bar-col:hover .bar-shape {
  background: linear-gradient(180deg, #3d7fc4, #245a95);
}
.bar-day {
  position: absolute;
  bottom: 0;
  font-size: 11px;
  color: var(--faint);
}

.funnel-body {
  padding: 18px 20px 14px;
}
.funnel-row + .funnel-row {
  margin-top: 14px;
}
.funnel-meta {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  margin-bottom: 6px;
}
.f-stage {
  font-size: 12.5px;
  color: var(--text);
  font-weight: 500;
}
.f-right {
  display: inline-flex;
  align-items: baseline;
  gap: 8px;
}
.f-count {
  font-size: 12.5px;
  font-weight: 600;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
}
.f-count em {
  font-style: normal;
  font-size: 10.5px;
  color: var(--faint);
  font-weight: 400;
}
.funnel-track {
  position: relative;
  height: 20px;
  border-radius: 4px;
  background: #f4f6f9;
  overflow: hidden;
}
.funnel-fill {
  height: 100%;
  border-radius: 4px;
  background: var(--brand);
  transition: width 0.6s ease;
}
.f-rate {
  min-width: 34px;
  text-align: right;
  font-size: 11px;
  color: var(--muted);
  font-variant-numeric: tabular-nums;
}
.funnel-foot {
  margin-top: 16px;
  padding-top: 12px;
  border-top: 1px solid var(--line-soft);
  font-size: 11.5px;
  color: var(--faint);
  display: flex;
  align-items: center;
  gap: 5px;
}
.funnel-foot b {
  color: var(--ink);
  font-size: 12.5px;
}
.funnel-foot span {
  font-weight: 600;
}

/* ---------------- 响应式 ---------------- */
@media (max-width: 1180px) {
  .kpi-row {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 1320px) {
  .three-col {
    grid-template-columns: 1fr 1fr;
  }
  .agenda-card {
    grid-column: 1 / -1;
  }
  .agenda {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0 28px;
  }
}

@media (max-width: 1080px) {
  .two-col {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 860px) {
  .three-col {
    grid-template-columns: 1fr;
  }
  .agenda {
    display: block;
  }
}
</style>
