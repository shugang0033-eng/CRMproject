<template>
  <div class="page">
    <PageHead
      title="产品分析"
      desc="卖得动的是哪几类、毛利靠谁撑、哪些 SKU 在仓库里躺着"
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
      <StatTile label="出货金额" :value="totalSales" money hint="按合同明细汇总" icon="box" />
      <StatTile label="出货数量" :value="(totalQty / 10000).toFixed(1)" unit="万件" hint="折最小销售单位" icon="layers" />
      <StatTile
        v-if="canCost"
        label="综合毛利率"
        :value="avgMargin"
        unit="%"
       
        hint="毛利 = 出货额 − 成本"
        icon="chart"
        tone="success"
      />
      <StatTile v-else label="在售 SKU" :value="12" unit="个" hint="毛利相关指标需「查看成本价」权限" icon="box" />
      <StatTile label="滞销 SKU" :value="pa.slowMoving.length" unit="个" hint="按库存与出货记录统计" icon="flag" tone="warning" />
    </section>

    <section class="two-col">
      <ChartCard title="品类结构" sub="按出货金额" flush>
        <div class="pad">
          <HBarList :rows="categoryRows" :max="100" />
        </div>
        
      </ChartCard>

      <ChartCard title="品类走势" sub="近 12 个月 · 万元" :legend="legend">
        <LineChart :labels="MONTH_LABELS" :series="trendSeries" :height="222" />
        
      </ChartCard>
    </section>

    <ChartCard title="畅销 SKU Top 10" sub="按出货金额排序" class="block">
      <AppTable :columns="skuColumns" :rows="pa.topSku" row-key="code" :show-pager="false" compact>
        <template #cell-name="{ row }">
          <div class="sku">
            <strong>{{ row.name }}</strong>
            <em>{{ row.code }}</em>
          </div>
        </template>
        <template #cell-qty="{ row }">{{ row.qty.toLocaleString('zh-CN') }}</template>
        <template #cell-amount="{ row }"><b class="num">{{ money(row.amount) }}</b></template>
        <template #cell-margin="{ row }">
          <span class="tag" :class="row.margin >= 36 ? 'tag-success' : row.margin >= 32 ? 'tag-brand' : 'tag-gray'">
            {{ row.margin == null ? '—' : row.margin + '%' }}
          </span>
        </template>
      </AppTable>
      
    </ChartCard>

    <ChartCard title="滞销与占压" sub="60 天零出货，按库存金额排序" class="block">
      <AppTable :columns="slowColumns" :rows="pa.slowMoving" row-key="code" :show-pager="false" compact>
        <template #cell-name="{ row }">
          <div class="sku">
            <strong>{{ row.name }}</strong>
            <em>{{ row.code }}</em>
          </div>
        </template>
        <template #cell-stock="{ row }">{{ row.stock.toLocaleString('zh-CN') }}</template>
        <template #cell-amount="{ row }"><b class="num">{{ money(row.amount) }}</b></template>
        <template #cell-days="{ row }">
          <span class="tag" :class="row.days >= 80 ? 'tag-danger' : 'tag-warning'">{{ row.days }} 天</span>
        </template>
        <template #cell-ops="{ row }">
          <button class="btn-text" type="button" @click="promote(row)">做促销</button>
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
import { can } from '@/store/permissions'
import { wan, money } from '@/data/analytics'

const { period, dept, owner, depts, owners, scopeLabel, periods, report, exportReport } = useDataScope('products')
const pa = computed(() => report.value || { categories: [], topSku: [], slowMoving: [], trend: [] })
const MONTH_LABELS = computed(() => pa.value.trend.map((point) => point.label))

/* 没有「查看成本价」权限就不下发毛利字段，页面也不能自己算 */
const canCost = computed(() => can('product.cost'))

const totalSales = computed(() => pa.value.categories.reduce((s, c) => s + c.sales, 0))
const totalQty = computed(() => pa.value.categories.reduce((s, c) => s + c.qty, 0))
const avgMargin = computed(() => {
  const gross = pa.value.categories.reduce((s, c) => s + c.gross, 0)
  return Number(((gross / (totalSales.value || 1)) * 100).toFixed(1))
})
const top3Share = computed(() => {
  const top3 = pa.value.topSku.slice(0, 3).reduce((s, k) => s + k.amount, 0)
  return ((top3 / (totalSales.value || 1)) * 100).toFixed(0)
})

const categoryRows = computed(() =>
  pa.value.categories.map((c) => ({
    label: c.name,
    value: c.ratio,
    display: `¥${wan(c.sales, 0)} 万`,
    note: `${(c.qty / 10000).toFixed(1)} 万件${canCost.value ? ` · 毛利 ${c.margin}%` : ''}`,
    sub: `${c.ratio}%`,
    tone: c.delta >= 0 ? 'success' : 'warning'
  }))
)

const colors = ['#2b6cb0', '#0f766e', '#b45309', '#7c3aed']
const trendSeries = computed(() => {
  const names = [...new Set(pa.value.trend.flatMap((point) => Object.keys(point).filter((key) => key !== 'label')))]
  return names.map((name, i) => ({
    name, color: colors[i % colors.length], data: pa.value.trend.map((point) => point[name] ?? 0)
  }))
})
const legend = computed(() => trendSeries.value.map(({ name, color }) => ({ label: name, color, line: true })))

const skuColumns = computed(() => [
  { key: 'name', label: '产品', width: '30%' },
  { key: 'category', label: '品类', width: '112px' },
  { key: 'qty', label: '销量', width: '100px', align: 'right' },
  { key: 'amount', label: '出货额', width: '132px', align: 'right' },
  ...(canCost.value ? [{ key: 'margin', label: '毛利率', width: '96px' }] : []),
  { key: 'owner', label: '主要来源', width: '120px' }
])

const slowColumns = [
  { key: 'name', label: '产品', width: '30%' },
  { key: 'category', label: '品类', width: '112px' },
  { key: 'stock', label: '库存', width: '100px', align: 'right' },
  { key: 'amount', label: '占压金额', width: '128px', align: 'right' },
  { key: 'days', label: '零出货', width: '100px' },
  { key: 'ops', label: '操作', width: '90px', align: 'right' }
]

function promote(row) {
  toast(`已把「${row.name}」加入促销候选`)
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
  grid-template-columns: 1fr 1.3fr;
  gap: 16px;
  margin-top: 16px;
}
.block {
  margin-top: 16px;
}
.pad {
  padding: 16px 18px 18px;
}
.sku {
  display: flex;
  flex-direction: column;
  gap: 2px;
  line-height: 1.35;
}
.sku strong {
  font-size: 12.8px;
  font-weight: 550;
  color: var(--ink);
}
.sku em {
  font-style: normal;
  font-size: 11px;
  color: var(--faint);
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}
.num {
  font-variant-numeric: tabular-nums;
  color: var(--ink);
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
