<template>
  <div class="page">
    <PageHead
      title="回款分析"
      desc="现金流视角：应收还压着多少、逾期多久、哪个销售的回款最慢"
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
      <StatTile label="应收余额" :value="pa.receivable" money hint="已开票未核销的货款" icon="receipt" />
      <StatTile label="已回款" :value="pa.received" money hint="财务核销到账金额" icon="wallet" tone="success" />
      <StatTile label="逾期金额" :value="pa.overdue" money hint="超过约定账期仍未到账" icon="flag" tone="danger" />
      <StatTile label="回款率" :value="pa.rate" unit="%" :delta="pa.rateDelta" :hint="'已开票金额中已核销的比例'" icon="trend-up" />
    </section>

    <section class="two-col">
      <ChartCard title="应收与回款走势" sub="近 12 个月 · 万元" :legend="[
        { label: '应收', color: '#94a3b8', line: true },
        { label: '回款', color: '#0f766e', line: true }
      ]">
        <LineChart :labels="MONTH_LABELS" :series="trendSeries" :height="222" />
        
      </ChartCard>

      <ChartCard title="账龄分布" sub="应收余额按逾期时长分桶" flush>
        <div class="pad">
          <HBarList :rows="agingRows" :max="100" />
        </div>
        
      </ChartCard>
    </section>

    <ChartCard title="逾期明细" sub="按逾期天数排序" class="block">
      <AppTable :columns="overdueColumns" :rows="pa.overdueList" row-key="contract" :show-pager="false" compact>
        <template #cell-amount="{ row }">{{ money(row.amount) }}</template>
        <template #cell-days="{ row }">
          <span class="tag" :class="row.days >= 60 ? 'tag-danger' : row.days >= 30 ? 'tag-warning' : 'tag-gray'">
            {{ row.days }} 天
          </span>
        </template>
        <template #cell-ops="{ row }">
          <button class="btn-text" type="button" @click="urge(row)">催收</button>
        </template>
      </AppTable>
      
    </ChartCard>

    <ChartCard title="按销售回款率" sub="应收越大、回款率越低，越要盯" class="block" flush>
      <AppTable :columns="ownerColumns" :rows="pa.byOwner" row-key="owner" :show-pager="false" compact>
        <template #cell-receivable="{ row }">{{ money(row.receivable) }}</template>
        <template #cell-received="{ row }">{{ money(row.received) }}</template>
        <template #cell-rate="{ row }">
          <div class="cmp">
            <div class="cmp-track">
              <div class="cmp-fill" :class="row.rate >= 80 ? 'success' : row.rate >= 65 ? 'warning' : 'danger'" :style="{ width: row.rate + '%' }" />
            </div>
            <span class="cmp-txt">{{ row.rate == null ? '—' : row.rate + '%' }}</span>
          </div>
        </template>
      </AppTable>
      
    </ChartCard>
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
import HBarList from '@/components/analytics/HBarList.vue'
import { useDataScope } from '@/composables/useDataScope'
import { toast } from '@/composables/useToast'
import { wan, money } from '@/data/analytics'

const { period, dept, owner, depts, owners, scopeLabel, periods, report, exportReport } = useDataScope('payments')
const pa = computed(() => report.value || { aging: [], overdueList: [], byOwner: [] })
const monthly = computed(() => report.value?.monthly || [])
const MONTH_LABELS = computed(() => monthly.value.map((point) => point.label))


const trendSeries = computed(() => [
  { name: '应收', color: '#94a3b8', data: monthly.value.map((m) => Number(wan(m.signed))) },
  { name: '回款', color: '#0f766e', area: true, data: monthly.value.map((m) => Number(wan(m.received))) }
])

const agingRows = computed(() =>
  pa.value.aging.map((a) => ({
    label: a.label,
    value: a.ratio,
    display: `¥${wan(a.amount, 1)} 万`,
    sub: `${a.ratio}%`,
    tone: a.tone
  }))
)

const overdueColumns = [
  { key: 'contract', label: '合同号', width: '136px' },
  { key: 'customer', label: '客户' },
  { key: 'owner', label: '负责人', width: '88px' },
  { key: 'amount', label: '金额', width: '124px', align: 'right' },
  { key: 'dueDate', label: '到期日', width: '108px' },
  { key: 'days', label: '逾期', width: '88px' },
  { key: 'method', label: '账期', width: '102px' },
  { key: 'ops', label: '操作', width: '76px', align: 'right' }
]

const ownerColumns = [
  { key: 'owner', label: '销售' },
  { key: 'dept', label: '部门', width: '128px' },
  { key: 'receivable', label: '应收', width: '136px', align: 'right' },
  { key: 'received', label: '已回款', width: '136px', align: 'right' },
  { key: 'rate', label: '回款率', width: '180px' }
]

function urge(row) {
  toast(`已生成「${row.customer}」的催收提醒`)
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
.block {
  margin-top: 16px;
}
.pad {
  padding: 16px 18px 18px;
}
.cmp {
  display: flex;
  align-items: center;
  gap: 8px;
}
.cmp-track {
  flex: 1;
  gap: 0;
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
  color: var(--muted);
  font-variant-numeric: tabular-nums;
  min-width: 44px;
  text-align: right;
}
@media (max-width: 1180px) {
  .kpis {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
  .two-col {
    grid-template-columns: 1fr;
  }
}
</style>
