<template>
  <div class="page">
    <PageHead title="销售概况" desc="全公司经营视角：发货、回款、客户与转化，一屏看完本月到今年的位置">
      <button class="btn" type="button" @click="exportReport">
        <AppIcon name="download" :size="14" />导出快报
      </button>
    </PageHead>

    <AnalyticsFilter
      v-model:period="period"
      v-model:dept="dept"
      v-model:owner="owner"
      :periods="periods"
      :depts="depts"
      :owners="owners"
      :scope-label="scopeLabel"
    />
    <p v-for="note in report?.unavailable" :key="note" class="muted">{{ note }}</p>

    <!-- KPI -->
    <section class="kpis">
      <StatTile
        label="年度发货额"
        :value="summary.ytdSigned"
        money
        :delta="summary.signedDelta"
        hint="业绩口径 = 订单发货额，退货冲减"
        icon="trend-up"
      />
      <StatTile
        label="业绩完成度"
        :value="summary.completion"
        unit="%"
        :hint="`目标 ¥${wan(summary.annualTarget, 0)} 万 · 时间进度 ${summary.timeProgress == null ? '—' : summary.timeProgress + '%'}`"
        icon="target"
        :tone="summary.completion >= summary.timeProgress ? 'success' : 'warning'"
      />
      <StatTile
        label="已回款金额"
        :value="summary.ytdReceived"
        money
        :delta="summary.receivedDelta"
        hint="只做质量指标，不计入完成度"
        icon="wallet"
      />
      <StatTile
        label="新增客户"
        :value="summary.ytdCustomers"
        unit="家"
        :delta="summary.customersDelta"
        hint="成交转客户，含公海领取"
        icon="users"
      />
    </section>

    <!-- 趋势 + 部门贡献 -->
    <section class="two-col">
      <ChartCard
        title="发货与回款走势"
        sub="近 12 个月 · 万元"
        :legend="[
          { label: '发货额', color: '#2b6cb0', line: true },
          { label: '回款额', color: '#0f766e', line: true }
        ]"
      >
        <LineChart :labels="MONTH_LABELS" :series="trendSeries" :height="228" />
        
      </ChartCard>

      <ChartCard title="部门发货贡献" sub="按发货额排序" flush>
        <div class="pad">
          <HBarList :rows="deptRows" />
        </div>
        
      </ChartCard>
    </section>

    <!-- 漏斗 + 来源 -->
    <section class="two-col">
      <ChartCard title="线索漏斗" sub="本年度累计">
        <FunnelChart :stages="funnelStages" :invalid="funnel.invalid" />
        
      </ChartCard>

      <ChartCard title="来源成交贡献" sub="按成交单数排序">
        <HBarList :rows="sourceRows" />
        
      </ChartCard>
    </section>

    <!-- 预警 -->
    <section class="card alert-card">
      <div class="card-head">
        <div class="card-title"><span class="dot" />需要处理</div>
        <span class="card-sub">按紧急程度排序</span>
      </div>
      <div class="alert-list">
        <button v-for="a in visibleAlerts" :key="a.key" type="button" class="alert-item" @click="go(a.path)">
          <span class="al-dot" :class="a.level" />
          <span class="al-body">
            <strong>{{ a.title }} <b>{{ a.count }}</b></strong>
            <em>{{ a.desc }}</em>
          </span>
          <AppIcon name="chevron-right" :size="14" class="al-arrow" />
        </button>
      </div>
    </section>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AnalyticsFilter from '@/components/analytics/AnalyticsFilter.vue'
import StatTile from '@/components/analytics/StatTile.vue'
import ChartCard from '@/components/analytics/ChartCard.vue'
import LineChart from '@/components/analytics/LineChart.vue'
import HBarList from '@/components/analytics/HBarList.vue'
import FunnelChart from '@/components/analytics/FunnelChart.vue'
import { useDataScope } from '@/composables/useDataScope'
import { analyticsApi } from '@/api/analytics'
import { can } from '@/store/permissions'
import { wan } from '@/data/analytics'

const router = useRouter()
const { period, dept, owner, depts, owners, scopeLabel, periods, report, exportReport } = useDataScope('summary')
const summary = computed(() => report.value?.kpis || {})
const monthly = computed(() => report.value?.monthly || [])
const alerts = computed(() => report.value?.alerts || [])
const detail = ref({})
watch([period, dept, owner], async (_, __, onCleanup) => {
  let current = true
  onCleanup(() => { current = false })
  detail.value = {}
  const filters = { period: period.value, deptId: dept.value, ownerId: owner.value }
  for (const [key, permission] of [['funnel', 'data.funnel'], ['sources', 'data.sources']]) {
    if (!can(permission)) continue
    try {
      const data = await analyticsApi[key](filters)
      if (current) detail.value[key] = data
    } catch { /* The overview can still show the primary report. */ }
  }
}, { immediate: true })
const deptPerf = computed(() => report.value?.depts || [])
const funnel = computed(() => detail.value.funnel || { invalid: 0 })
const funnelStages = computed(() => funnel.value.stages || [])
const sourceRoi = computed(() => detail.value.sources?.rows || [])
const MONTH_LABELS = computed(() => monthly.value.map((point) => point.label))



/* 折线图坐标用万元，避免轴上出现 8 位数 */
const trendSeries = computed(() => [
  { name: '发货额', color: '#2b6cb0', area: true, data: monthly.value.map((m) => Number(wan(m.signed))) },
  { name: '回款额', color: '#0f766e', data: monthly.value.map((m) => Number(wan(m.received))) }
])

/* 条长必须代表「发货额」——如果按完成度画，读者会拿条长当金额看 */
const deptRows = computed(() =>
  deptPerf.value.map((d) => ({
    label: d.dept,
    value: d.signed,
    display: `¥${wan(d.signed, 0)} 万`,
    note: `完成 ${d.completion == null ? '—' : d.completion + '%'} · 目标 ¥${wan(d.target, 0)} 万`,
    sub: summary.value.ytdSigned ? `${((d.signed / summary.value.ytdSigned) * 100).toFixed(0)}%` : '—',
    tone: d.completion >= 91.7 ? 'success' : d.completion >= 73 ? 'warning' : 'danger'
  }))
)

const sourceRows = computed(() =>
  [...sourceRoi.value]
    .sort((a, b) => b.won - a.won)
    .map((s) => ({
      label: s.source,
      value: s.won,
      display: `${s.won} 单 · ¥${wan(s.amount, 0)} 万`,
      note: `转化率 ${s.rate}% · 客单 ¥${wan(s.avgDeal, 0)} 万`
    }))
)

const visibleAlerts = computed(() => alerts.value.filter((a) => can(a.perm)))

function go(path) {
  if (path) router.push(path)
}


</script>

<style scoped>
.kpis {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 16px;
}
.two-col {
  display: grid;
  grid-template-columns: 1.55fr 1fr;
  gap: 16px;
  margin-top: 16px;
}
.pad {
  padding: 16px 18px 18px;
}
.alert-card {
  margin-top: 16px;
}
.alert-list {
  padding: 6px 8px 8px;
}
.alert-item {
  display: flex;
  align-items: center;
  gap: 11px;
  width: 100%;
  padding: 11px 12px;
  border: 0;
  background: none;
  border-radius: 9px;
  cursor: pointer;
  text-align: left;
  transition: background 0.15s;
}
.alert-item:hover {
  background: #f8fafc;
}
.alert-item:hover .al-arrow {
  opacity: 1;
  transform: translateX(2px);
}
.al-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
  background: var(--info);
}
.al-dot.danger {
  background: var(--danger);
}
.al-dot.warning {
  background: var(--warning);
}
.al-body {
  display: flex;
  flex-direction: column;
  gap: 2px;
  flex: 1;
  min-width: 0;
}
.al-body strong {
  font-size: 13px;
  font-weight: 550;
  color: var(--ink);
}
.al-body strong b {
  color: var(--danger);
  margin-left: 4px;
  font-variant-numeric: tabular-nums;
}
.al-body em {
  font-style: normal;
  font-size: 11.5px;
  color: var(--faint);
}
.al-arrow {
  color: #c3c9d3;
  opacity: 0;
  transition: all 0.15s;
}
.pos {
  color: var(--success);
  font-weight: 600;
}
.neg {
  color: var(--danger);
  font-weight: 600;
}

@media (max-width: 1180px) {
  .kpis {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
@media (max-width: 1080px) {
  .two-col {
    grid-template-columns: 1fr;
  }
}
</style>
