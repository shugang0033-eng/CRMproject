<template>
  <div class="page">
    <PageHead
      title="客户分析"
      desc="耗材生意靠复购：看跟进是否到位、谁在沉睡、下一次该找谁下单"
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
      <StatTile label="客户总数" :value="ca.total" unit="家" hint="在跟与已合作合计" icon="users" />
      <StatTile label="复购率" :value="ca.repeatRate" unit="%" :delta="ca.repeatRateDelta" hint="近 12 个月下过 2 单及以上" icon="refresh" tone="success" />
      <StatTile label="平均复购周期" :value="ca.avgCycle" unit="天" :delta="ca.avgCycleDelta" hint="按相邻合同计算" icon="clock" />
      <StatTile label="超期未跟进" :value="ca.follow.overdue" unit="家" hint="按客户跟进计划统计" icon="flag" tone="warning" />
    </section>

    <section class="two-col">
      <ChartCard title="复购周期分布" sub="按客户最近两次下单间隔">
        <BarChart :labels="ca.cycleBuckets.map((b) => b.label)" :series="[{ name: '客户数', color: '#2b6cb0', data: ca.cycleBuckets.map((b) => b.count) }]" :height="212" unit="家" />
        
      </ChartCard>

      <ChartCard title="客户状态流转" sub="本月月初 → 月末" flush>
        <div class="flow">
          <div v-for="s in ca.statusFlow" :key="s.label" class="flow-row">
            <span class="fl-label">{{ s.label }}</span>
            <span class="fl-num">{{ s.from }}</span>
            <AppIcon name="arrow-right" :size="13" class="fl-arrow" />
            <span class="fl-num strong">{{ s.to }}</span>
            <span class="fl-delta" :class="s.moved > 0 ? 'up' : 'down'">
              {{ s.moved > 0 ? '+' : '' }}{{ s.moved }}
            </span>
          </div>
        </div>
        
      </ChartCard>
    </section>

    <section class="two-col">
      <ChartCard title="跟进结果分布" sub="本年度 2,860 条跟进">
        <HBarList :rows="resultRows" :max="100" />
        
      </ChartCard>

      <ChartCard title="跟进方式" sub="按条数">
        <HBarList :rows="typeRows" :max="100" />
        
      </ChartCard>
    </section>

    <ChartCard title="沉睡客户" sub="超过 60 天没有出货，按历史金额排序" class="block">
      <AppTable :columns="sleepColumns" :rows="ca.sleepingList" :show-pager="false" compact>
        <template #cell-level="{ row }">
          <span class="tag" :class="row.level === 'B 类' ? 'tag-brand' : 'tag-gray'">{{ row.level }}</span>
        </template>
        <template #cell-days="{ row }">
          <span class="tag" :class="row.days >= 70 ? 'tag-danger' : 'tag-warning'">{{ row.days }} 天</span>
        </template>
        <template #cell-amount="{ row }">{{ money(row.amount) }}</template>
        <template #cell-ops="{ row }">
          <button class="btn-text" type="button" @click="follow(row)">去跟进</button>
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
import BarChart from '@/components/analytics/BarChart.vue'
import HBarList from '@/components/analytics/HBarList.vue'
import { useDataScope } from '@/composables/useDataScope'
import { toast } from '@/composables/useToast'
import { money } from '@/data/analytics'

const { period, dept, owner, depts, owners, scopeLabel, periods, report, exportReport } = useDataScope('customers')
const ca = computed(() => report.value || { follow: { resultDist: [], typeDist: [] }, cycleBuckets: [], sleepingList: [], statusFlow: [] })


const resultRows = computed(() =>
  ca.value.follow.resultDist.map((r) => ({
    label: r.label,
    value: r.count,
    display: `${r.count} 条`,
    sub: `${r.ratio}%`,
    tone: r.tone
  }))
)

const typeRows = computed(() =>
  ca.value.follow.typeDist.map((r) => ({ label: r.label, value: r.count, display: `${r.count} 条`, sub: `${r.ratio}%` }))
)

const sleepColumns = [
  { key: 'name', label: '客户' },
  { key: 'owner', label: '负责人', width: '92px' },
  { key: 'level', label: '等级', width: '80px' },
  { key: 'lastOrder', label: '上次下单', width: '112px' },
  { key: 'days', label: '未下单', width: '92px' },
  { key: 'amount', label: '历史金额', width: '112px', align: 'right' },
  { key: 'ops', label: '操作', width: '92px', align: 'right' }
]

function follow(row) {
  toast(`已为「${row.name}」创建回访任务`)
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
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  margin-top: 16px;
}
.block {
  margin-top: 16px;
}
.flow {
  padding: 8px 18px 14px;
}
.flow-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 11px 0;
  border-bottom: 1px solid var(--line-soft);
}
.flow-row:last-child {
  border-bottom: 0;
}
.fl-label {
  flex: 1;
  font-size: 12.5px;
  color: var(--text);
}
.fl-num {
  font-size: 13px;
  color: var(--muted);
  font-variant-numeric: tabular-nums;
  min-width: 32px;
  text-align: right;
}
.fl-num.strong {
  color: var(--ink);
  font-weight: 650;
}
.fl-arrow {
  color: #c3c9d3;
}
.fl-delta {
  min-width: 40px;
  text-align: right;
  font-size: 11.5px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}
.fl-delta.up {
  color: var(--danger);
}
.fl-delta.down {
  color: var(--success);
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
