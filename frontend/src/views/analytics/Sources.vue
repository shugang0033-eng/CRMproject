<template>
  <div class="page">
    <PageHead
      title="线索来源 ROI"
      desc="每个渠道花了多少钱、带回来多少发货额，明年预算该往哪切"
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
      :depts="[]"
      :owners="[]"
      :scope-label="scopeLabel"
    />
    <p v-for="note in report?.unavailable" :key="note" class="muted">{{ note }}</p>

    <section class="kpis">
      <StatTile label="线索总量" :value="totalLeads" unit="条" hint="当前筛选范围" icon="target" />
      <StatTile label="成交单数" :value="totalWon" unit="单" hint="已标记成交的线索" icon="check-circle" tone="success" />
      <StatTile label="市场投入" :value="totalCost" money hint="展位、推广、差旅与样品" icon="wallet" />
      <StatTile label="综合获客成本" :value="cac" unit="元/单" hint="市场投入 ÷ 成交单数" icon="chart" tone="warning" />
    </section>

    <ChartCard title="渠道 ROI 明细" sub="ROI = 发货额 ÷ 市场投入" flush>
      <AppTable :columns="columns" :rows="rows" row-key="source" :show-pager="false" compact>
        <template #cell-source="{ row }">
          <div class="src">
            <strong>{{ row.source }}</strong>
            <em>{{ row.note }}</em>
          </div>
        </template>
        <template #cell-rate="{ row }">
          <span class="tag" :class="row.rate >= 14 ? 'tag-success' : row.rate >= 10 ? 'tag-brand' : 'tag-gray'">{{ row.rate == null ? '—' : row.rate + '%' }}</span>
        </template>
        <template #cell-amount="{ row }">{{ money(row.amount) }}</template>
        <template #cell-cost="{ row }">{{ money(row.cost) }}</template>
        <template #cell-cac="{ row }"><b class="num">{{ money(row.cac) }}</b></template>
        <template #cell-roi="{ row }">
          <span class="roi" :class="row.roi >= 50 ? 'high' : row.roi >= 20 ? 'mid' : 'low'">{{ row.roi }}x</span>
        </template>
      </AppTable>
      
    </ChartCard>

    <section class="two-col">
      <ChartCard title="月度线索接入" sub="按渠道堆叠 · 条">
        <BarChart :labels="MONTH_LABELS" :series="stackSeries" :height="228" stacked unit="条" />
      </ChartCard>

      <ChartCard title="渠道转化率对比" sub="成交 / 线索" flush>
        <div class="pad">
          <HBarList :rows="rateRows" :max="20" />
        </div>
        
      </ChartCard>
    </section>

    
  </div>
</template>

<script setup>
import { computed } from 'vue'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import AnalyticsFilter from '@/components/analytics/AnalyticsFilter.vue'
import StatTile from '@/components/analytics/StatTile.vue'
import ChartCard from '@/components/analytics/ChartCard.vue'
import BarChart from '@/components/analytics/BarChart.vue'
import HBarList from '@/components/analytics/HBarList.vue'
import { useDataScope } from '@/composables/useDataScope'
import { toast } from '@/composables/useToast'
import { wan, money } from '@/data/analytics'

const { period, dept, owner, depts, owners, scopeLabel, periods, report, exportReport } = useDataScope('sources')
const sourceRoi = computed(() => report.value?.rows || [])
const sourceTrend = computed(() => report.value?.trend || [])
const MONTH_LABELS = computed(() => sourceTrend.value.map((point) => point.label))

const rows = computed(() => sourceRoi.value)
const totalLeads = computed(() => sourceRoi.value.reduce((s, r) => s + r.leads, 0))
const totalWon = computed(() => sourceRoi.value.reduce((s, r) => s + r.won, 0))
const totalCost = computed(() => sourceRoi.value.reduce((s, r) => s + r.cost, 0))
const cac = computed(() => totalWon.value && totalCost.value ? Math.round(totalCost.value / totalWon.value) : null)

const columns = [
  { key: 'source', label: '渠道' },
  { key: 'leads', label: '线索', width: '72px', align: 'right' },
  { key: 'won', label: '成交', width: '72px', align: 'right' },
  { key: 'rate', label: '转化率', width: '88px' },
  { key: 'amount', label: '发货额', width: '128px', align: 'right' },
  { key: 'cost', label: '市场费用', width: '112px', align: 'right' },
  { key: 'cac', label: '获客成本', width: '104px', align: 'right' },
  { key: 'roi', label: 'ROI', width: '78px', align: 'right' }
]

const stackSeries = computed(() =>
  sourceRoi.value.map(({ source: name }) => ({
    name,
    data: sourceTrend.value.map((t) => t[name] || 0)
  }))
)

const rateRows = computed(() =>
  [...sourceRoi.value]
    .sort((a, b) => b.rate - a.rate)
    .map((r) => ({
      label: r.source,
      value: r.rate,
      display: `${r.rate}%`,
      note: `${r.won} 单 · 客单 ¥${wan(r.avgDeal, 0)} 万`,
      tone: r.rate >= 14 ? 'success' : r.rate >= 10 ? 'brand' : 'warning'
    }))
)


</script>

<style scoped>
.kpis {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 16px;
}
.two-col {
  display: grid;
  grid-template-columns: 1.5fr 1fr;
  gap: 16px;
  margin-top: 16px;
}
.pad {
  padding: 16px 18px 18px;
}
.src {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.src strong {
  font-size: 12.8px;
  font-weight: 550;
  color: var(--ink);
}
.src em {
  font-style: normal;
  font-size: 11px;
  color: var(--faint);
}
.num {
  font-variant-numeric: tabular-nums;
  color: var(--ink);
}
.roi {
  font-weight: 650;
  font-variant-numeric: tabular-nums;
}
.roi.high {
  color: var(--success);
}
.roi.mid {
  color: var(--brand);
}
.roi.low {
  color: var(--danger);
}
.conclusions {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 16px;
  margin-top: 16px;
}
.concl {
  padding: 16px 18px 18px;
}
.concl h4 {
  margin: 9px 0 6px;
  font-size: 14px;
  font-weight: 600;
  color: var(--ink);
}
.concl p {
  margin: 0;
  font-size: 12px;
  line-height: 1.7;
  color: var(--muted);
}
.cc-tag {
  display: inline-flex;
  align-items: center;
  height: 20px;
  padding: 0 8px;
  border-radius: 5px;
  font-size: 11px;
  font-weight: 600;
}
.cc-tag.success {
  background: var(--success-bg);
  color: var(--success);
}
.cc-tag.brand {
  background: var(--brand-soft);
  color: var(--brand);
}
.cc-tag.danger {
  background: var(--danger-bg);
  color: var(--danger);
}
@media (max-width: 1180px) {
  .kpis {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
  .two-col,
  .conclusions {
    grid-template-columns: 1fr;
  }
}
</style>
