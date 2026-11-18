<template>
  <div class="page">
    <PageHead
      title="销售漏斗分析"
      desc="线索六态流转：待联系 → 已联系 → 已报样/报价 → 谈判中 → 成交 / 无效，看每一段卡在哪"
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
      <StatTile label="线索接入" :value="funnel.stages[0]?.count" unit="条" hint="含展会、1688、官网与转介绍" icon="target" />
      <StatTile label="成交线索" :value="wonStage?.count" unit="条" hint="签订供货协议或首批订单" icon="check-circle" tone="success" />
      <StatTile label="整体转化率" :value="funnel.overallRate" unit="%" :delta="funnel.overallRateDelta" hint="成交 / 线索接入" icon="trend-up" />
      <StatTile label="平均成交周期" :value="cycleDays" unit="天" hint="从接入到成交的累计停留" icon="clock" />
    </section>

    <section class="two-col">
      <ChartCard title="阶段转化" sub="本年度累计 · 无效线索单列">
        <FunnelChart :stages="funnel.stages" :invalid="funnel.invalid" />
        
      </ChartCard>

      <ChartCard title="流失原因" sub="失败线索归因，可多选">
        <HBarList :rows="lossRows" />
        
      </ChartCard>
    </section>

    <ChartCard title="阶段明细" sub="段间转化 = 本段 / 上一段" class="block">
      <AppTable :columns="stageColumns" :rows="stageRows" :show-pager="false" compact>
        <template #cell-count="{ row }">
          <b class="num">{{ row.count.toLocaleString('zh-CN') }}</b>
        </template>
        <template #cell-fromPrev="{ row }">
          <span v-if="row.index === 0" class="faint">—</span>
          <span v-else class="tag" :class="row.fromPrev >= 55 ? 'tag-success' : 'tag-warning'">{{ row.fromPrev }}%</span>
        </template>
        <template #cell-total="{ row }">{{ row.total }}%</template>
        <template #cell-days="{ row }">
          <span class="faint">{{ row.avgDays ? `${row.avgDays} 天` : '—' }}</span>
        </template>
      </AppTable>
    </ChartCard>

    <section class="two-col wide">
      <ChartCard title="分来源漏斗对比" sub="同一套阶段，看哪类线索更能往下走" flush>
        <AppTable :columns="sourceColumns" :rows="funnel.bySource" row-key="source" :show-pager="false" compact>
          <template #cell-rate="{ row }">
            <span class="tag" :class="row.rate >= 14 ? 'tag-success' : row.rate >= 10 ? 'tag-brand' : 'tag-gray'">{{ row.rate }}%</span>
          </template>
        </AppTable>
        
      </ChartCard>

      <ChartCard title="整体转化率趋势" sub="近 6 个月 · %">
        <LineChart :labels="funnel.trend.map((t) => t.label)" :series="[{ name: '转化率', color: '#2b6cb0', area: true, data: funnel.trend.map((t) => t.value) }]" :height="248" unit="%" prescaled />
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
import LineChart from '@/components/analytics/LineChart.vue'
import FunnelChart from '@/components/analytics/FunnelChart.vue'
import HBarList from '@/components/analytics/HBarList.vue'
import { useDataScope } from '@/composables/useDataScope'
import { toast } from '@/composables/useToast'


const { period, dept, owner, depts, owners, scopeLabel, periods, report, exportReport } = useDataScope('funnel')
const funnel = computed(() => report.value || { stages: [], lossReasons: [], bySource: [], trend: [] })


const wonStage = computed(() => funnel.value.stages[funnel.value.stages.length - 1])
const cycleDays = computed(() => Math.round(funnel.value.stages.reduce((s, x) => s + x.avgDays, 0)))

/* 段间转化最低的一段，用来提示先修哪里 */
const weakest = computed(() =>
  [...funnel.stages.slice(1)].sort((a, b) => a.fromPrev - b.fromPrev)[0]
)

const lossRows = computed(() =>
  funnel.value.lossReasons.map((r) => ({ label: r.label, value: r.count, display: `${r.count} 条`, sub: `${r.ratio}%` }))
)

const stageColumns = [
  { key: 'label', label: '阶段', width: '34%' },
  { key: 'count', label: '线索数', width: '16%' },
  { key: 'fromPrev', label: '段间转化', width: '18%' },
  { key: 'total', label: '累计转化', width: '16%' },
  { key: 'days', label: '平均停留', width: '16%' }
]

const stageRows = computed(() =>
  funnel.value.stages.map((s, i) => ({
    id: s.key,
    index: i,
    label: s.label,
    count: s.count,
    fromPrev: s.fromPrev,
    total: Number(((s.count / (funnel.value.stages[0]?.count || 1)) * 100).toFixed(1)),
    avgDays: s.avgDays
  }))
)

/* 半宽卡片里放 7 列会挤到换行，去掉「已联系」中间态，保留拐点和结果 */
const sourceColumns = [
  { key: 'source', label: '来源' },
  { key: 'count', label: '线索', width: '68px', align: 'right' },
  { key: 'quoted', label: '报价', width: '64px', align: 'right' },
  { key: 'negotiating', label: '谈判', width: '64px', align: 'right' },
  { key: 'won', label: '成交', width: '64px', align: 'right' },
  { key: 'rate', label: '转化率', width: '84px' }
]


</script>

<style scoped>
.kpis {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 16px;
}
.two-col {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  margin-top: 16px;
}
.two-col.wide {
  grid-template-columns: 1.65fr 1fr;
}
/* 表格单元格不折行，宁可让表格内部横向滚动，也不要把「汽配城拜访」拆成三行 */
.block :deep(.table th),
.block :deep(.table td),
.two-col.wide :deep(.table th),
.two-col.wide :deep(.table td) {
  white-space: nowrap;
}
.block {
  margin-top: 16px;
}
.num {
  font-variant-numeric: tabular-nums;
  color: var(--ink);
}
@media (max-width: 1180px) {
  .kpis {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
  .two-col,
  .two-col.wide {
    grid-template-columns: 1fr;
  }
}
</style>
