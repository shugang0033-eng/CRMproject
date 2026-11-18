<template>
  <div class="page">
    <PageHead
      title="业绩分析"
      desc="部门、员工、完成度与成交排行放在一处：业绩口径统一按订单发货额，退货冲减"
    >
      <button class="btn" type="button" @click="exportReport">
        <AppIcon name="download" :size="14" />导出
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

    <section class="kpis">
      <StatTile label="年度发货额" :value="summary.ytdSigned" money :delta="summary.signedDelta" hint="年度累计，含本月" icon="trend-up" />
      <StatTile label="年度目标" :value="summary.annualTarget" money hint="按业绩目标统计" icon="target" />
      <StatTile
        label="整体完成度"
        :value="summary.completion"
        unit="%"
        :hint="`时间进度 ${summary.timeProgress}%，缺口 ¥${wan(summary.annualTarget - summary.ytdSigned, 0)} 万`"
        icon="chart"
        :tone="summary.completion >= summary.timeProgress ? 'success' : 'warning'"
      />
      <StatTile label="达标人数" :value="`${qualified} / ${pa.staff.length}`" hint="完成度 ≥ 100% 的销售" icon="star" />
    </section>

    <section class="two-col">
      <ChartCard title="部门业绩" sub="点击一行只看该部门的人" flush>
        <AppTable :columns="deptColumns" :rows="pa.depts" row-key="dept" :show-pager="false" compact>
          <template #cell-dept="{ row }">
            <button class="dept-link" type="button" @click="pickDept(row.dept)">{{ row.dept }}</button>
          </template>
          <template #cell-target="{ row }"><span class="faint">{{ wan(row.target, 0) }}</span></template>
          <template #cell-signed="{ row }"><b class="num">{{ wan(row.signed, 0) }}</b></template>
          <template #cell-completion="{ row }">
            <div class="cmp">
              <div class="cmp-track">
                <div class="cmp-fill" :class="completionTone(row.completion)" :style="{ width: Math.min(100, row.completion) + '%' }" />
              </div>
              <span class="cmp-txt" :class="completionTone(row.completion)">{{ row.completion == null ? '—' : row.completion + '%' }}</span>
            </div>
          </template>
          <template #cell-perHead="{ row }"><span class="faint">{{ wan(row.perHead, 1) }}</span></template>
        </AppTable>
        
      </ChartCard>

      <ChartCard title="季度达成" sub="目标 vs 实际发货 · 万元" :legend="[{ label: '目标', color: '#cbd5e1' }, { label: '实际', color: '#2b6cb0' }]">
        <BarChart :labels="pa.quarters.map((q) => q.label)" :series="quarterSeries" :height="212" />
        
      </ChartCard>
    </section>

    <section class="two-col wide">
      <ChartCard :title="dimension === 'staff' ? '员工业绩明细' : '部门业绩明细'" sub="按发货额排序" flush>
        <template #action>
          <div class="seg small">
            <button type="button" class="seg-btn" :class="{ on: dimension === 'dept' }" @click="dimension = 'dept'">按部门</button>
            <button type="button" class="seg-btn" :class="{ on: dimension === 'staff' }" @click="dimension = 'staff'">按员工</button>
          </div>
        </template>

        <div v-if="activeDept" class="filter-note">
          已筛选 <b>{{ activeDept }}</b>
          <button class="btn-text" type="button" @click="activeDept = ''">看全部</button>
        </div>

        <AppTable :columns="tableColumns" :rows="tableRows" row-key="name" :page-size="10">
          <template #cell-name="{ row }">
            <div v-if="dimension === 'staff'" class="who">
              <span class="avatar" :style="{ background: nameColor(row.name) }">{{ initials(row.name) }}</span>
              <span>{{ row.name }}</span>
            </div>
            <button v-else class="dept-link" type="button" @click="pickDept(row.name)">{{ row.name }}</button>
          </template>
          <template #cell-target="{ row }"><span class="faint">{{ wan(row.target, 0) }}</span></template>
          <template #cell-signed="{ row }"><b class="num">{{ wan(row.signed, 0) }}</b></template>
          <template #cell-completion="{ row }">
            <div class="cmp">
              <div class="cmp-track">
                <div class="cmp-fill" :class="completionTone(row.completion)" :style="{ width: Math.min(100, row.completion) + '%' }" />
              </div>
              <span class="cmp-txt" :class="completionTone(row.completion)">{{ row.completion == null ? '—' : row.completion + '%' }}</span>
            </div>
          </template>
          <template #cell-gap="{ row }">
            <span :class="row.gap > 0 ? 'neg' : 'pos'">{{ row.gap == null ? '—' : row.gap > 0 ? `-${wan(row.gap, 0)}` : `+${wan(-row.gap, 0)}` }}</span>
          </template>
        </AppTable>
      </ChartCard>

      <ChartCard title="成交员工 Top 10" sub="按发货额">
        <div class="top-list">
          <button v-for="(p, i) in pa.top10" :key="p.name" type="button" class="top-row" @click="pickStaff(p.name)">
            <span class="top-rank" :class="{ gold: i === 0, silver: i === 1, bronze: i === 2 }">{{ i + 1 }}</span>
            <span class="avatar sm" :style="{ background: nameColor(p.name) }">{{ initials(p.name) }}</span>
            <span class="top-body">
              <span class="top-name">{{ p.name }}<em>{{ p.dept }}</em></span>
              <span class="top-bar">
                <i :style="{ width: Math.min(100, p.completion) + '%' }" :class="completionTone(p.completion)" />
              </span>
            </span>
            <span class="top-num">
              <b>{{ wan(p.signed, 0) }}</b>
              <em>{{ p.completion }}%</em>
            </span>
          </button>
        </div>
        
      </ChartCard>
    </section>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import AnalyticsFilter from '@/components/analytics/AnalyticsFilter.vue'
import StatTile from '@/components/analytics/StatTile.vue'
import ChartCard from '@/components/analytics/ChartCard.vue'
import BarChart from '@/components/analytics/BarChart.vue'
import { useDataScope } from '@/composables/useDataScope'
import { analyticsApi } from '@/api/analytics'
import { toast } from '@/composables/useToast'
import { nameColor, initials } from '@/utils/avatar'
import { wan, completionTone } from '@/data/analytics'

const { period, dept, owner, depts, owners, scopeLabel, periods, report, exportReport } = useDataScope('performance')
const pa = computed(() => report.value || { staff: [], depts: [], quarters: [], top10: [], buckets: [] })

/* performance 接口只返回部门 / 员工 / 季度，不带总览 KPI。
   不补这一次请求，顶部四个指标会全是「—」，读者会以为页面坏了 */
const kpi = ref({})
watch([period, dept, owner], async () => {
  try {
    const data = await analyticsApi.summary({ period: period.value, deptId: dept.value, ownerId: owner.value })
    kpi.value = data?.kpis || {}
  } catch {
    kpi.value = {}
  }
}, { immediate: true })
const summary = computed(() => kpi.value)


const dimension = ref('staff')
const activeDept = ref('')

const qualified = computed(() => pa.value.staff.filter((s) => s.completion >= 100).length)

const topShare = computed(() => {
  const top3 = pa.value.top10.slice(0, 3).reduce((s, p) => s + p.signed, 0)
  return ((top3 / (summary.value.ytdSigned || 1)) * 100).toFixed(0)
})

const quarterSeries = computed(() => [
  { name: '目标', color: '#cbd5e1', data: pa.value.quarters.map((q) => Number(wan(q.target))) },
  { name: '实际', color: '#2b6cb0', data: pa.value.quarters.map((q) => Number(wan(q.signed))) }
])

const deptColumns = [
  { key: 'dept', label: '部门' },
  { key: 'headcount', label: '人数', width: '72px', align: 'right' },
  { key: 'target', label: '目标', width: '96px', align: 'right' },
  { key: 'signed', label: '发货', width: '96px', align: 'right' },
  { key: 'completion', label: '完成度', width: '176px' },
  { key: 'perHead', label: '人均', width: '92px', align: 'right' }
]

const tableColumns = computed(() => [
  { key: 'name', label: dimension.value === 'dept' ? '部门' : '姓名' },
  ...(dimension.value === 'staff' && !activeDept.value ? [{ key: 'dept', label: '部门', width: '116px' }] : []),
  { key: 'target', label: '目标', width: '90px', align: 'right' },
  { key: 'signed', label: '发货', width: '90px', align: 'right' },
  { key: 'completion', label: '完成度', width: '170px' },
  { key: 'deals', label: '单量', width: '72px', align: 'right' },
  { key: 'gap', label: '缺口', width: '84px', align: 'right' }
])

/* 部门视角看部门汇总；员工视角看人，选了部门就只看该部门的人 */
const tableRows = computed(() => {
  if (dimension.value === 'dept') {
    return pa.value.depts.map((d) => ({
      name: d.dept,
      target: d.target,
      signed: d.signed,
      completion: d.completion,
      deals: d.deals,
      gap: d.target - d.signed
    }))
  }
  return pa.value.staff.filter((s) => !activeDept.value || s.deptTop === activeDept.value || s.dept === activeDept.value)
})

function pickDept(d) {
  dimension.value = 'staff'
  activeDept.value = activeDept.value === d ? '' : d
}

function pickStaff(name) {
  dimension.value = 'staff'
  activeDept.value = ''
  const id = String(owners.value.find((person) => person.name === name)?.id || '')
  owner.value = owner.value === id ? '' : id
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
  grid-template-columns: 1.25fr 1fr;
  gap: 16px;
  margin-top: 16px;
}
.two-col.wide {
  grid-template-columns: 1fr 340px;
}
.dept-link {
  border: 0;
  background: none;
  padding: 0;
  font-size: 13px;
  color: var(--brand);
  cursor: pointer;
}
.dept-link:hover {
  text-decoration: underline;
}
.num {
  font-variant-numeric: tabular-nums;
  color: var(--ink);
}
/* 部门名不折行：「主机厂配套部」被拆成两行会显得表格没对齐 */
:deep(.table th),
:deep(.table td) {
  white-space: nowrap;
}
.cmp {
  display: flex;
  align-items: center;
  gap: 8px;
}
.cmp-track {
  flex: 1;
  min-width: 42px;
  height: 6px;
  border-radius: 3px;
  background: #f2f4f7;
  overflow: hidden;
}
.cmp-fill {
  height: 100%;
  border-radius: 3px;
  background: var(--brand);
}
.cmp-fill.success {
  background: var(--success);
}
.cmp-fill.warning {
  background: var(--warning);
}
.cmp-fill.danger {
  background: var(--danger);
}
.cmp-txt {
  font-size: 11.5px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  color: var(--muted);
  min-width: 44px;
  text-align: right;
}
.cmp-txt.success {
  color: var(--success);
}
.cmp-txt.warning {
  color: var(--warning);
}
.cmp-txt.danger {
  color: var(--danger);
}
.who {
  display: flex;
  align-items: center;
  gap: 8px;
}
.avatar {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  color: #fff;
  font-size: 10.5px;
  font-weight: 600;
  flex-shrink: 0;
}
.avatar.sm {
  width: 22px;
  height: 22px;
  font-size: 10px;
}
.filter-note {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 9px 18px;
  background: var(--brand-soft);
  font-size: 12px;
  color: var(--brand);
  border-bottom: 1px solid var(--line-soft);
}
.seg.small {
  padding: 2px;
}
.seg {
  display: inline-flex;
  gap: 2px;
  border: 1px solid var(--line-soft);
  border-radius: 7px;
  background: #f6f8fa;
}
.seg-btn {
  padding: 4px 10px;
  border: 0;
  border-radius: 5px;
  background: none;
  color: var(--muted);
  font-size: 12px;
  cursor: pointer;
}
.seg-btn.on {
  background: #fff;
  color: var(--ink);
  font-weight: 600;
  box-shadow: var(--shadow-xs);
}
.top-list {
  padding: 6px 8px 10px;
}
.top-row {
  display: flex;
  align-items: center;
  gap: 9px;
  width: 100%;
  padding: 7px 8px;
  border: 0;
  background: none;
  border-radius: 8px;
  cursor: pointer;
  text-align: left;
  transition: background 0.15s;
}
.top-row:hover {
  background: #f8fafc;
}
.top-rank {
  width: 17px;
  font-size: 11px;
  font-weight: 650;
  color: var(--faint);
  text-align: center;
  flex-shrink: 0;
  font-variant-numeric: tabular-nums;
}
.top-rank.gold {
  color: #b45309;
}
.top-rank.silver {
  color: #64748b;
}
.top-rank.bronze {
  color: #92400e;
}
.top-body {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.top-name {
  font-size: 12.5px;
  color: var(--ink);
  display: flex;
  align-items: baseline;
  gap: 6px;
}
.top-name em {
  font-style: normal;
  font-size: 10.5px;
  color: var(--faint);
}
.top-bar {
  height: 4px;
  border-radius: 2px;
  background: #f2f4f7;
  overflow: hidden;
}
.top-bar i {
  display: block;
  height: 100%;
  border-radius: 2px;
  background: var(--brand);
}
.top-bar i.success {
  background: var(--success);
}
.top-bar i.warning {
  background: var(--warning);
}
.top-bar i.danger {
  background: var(--danger);
}
.top-num {
  text-align: right;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  min-width: 52px;
}
.top-num b {
  font-size: 12.5px;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
}
.top-num em {
  font-style: normal;
  font-size: 10.5px;
  color: var(--faint);
}
.pos {
  color: var(--success);
  font-weight: 600;
}
.neg {
  color: var(--danger);
  font-weight: 600;
}
@media (max-width: 1240px) {
  .two-col,
  .two-col.wide {
    grid-template-columns: 1fr;
  }
}
@media (max-width: 1180px) {
  .kpis {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
</style>
