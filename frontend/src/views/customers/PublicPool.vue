<template>
  <div class="page">
    <PageHead title="客户池" desc="无主客户才会进这里，任何人都可以领取；领取后有 30 天保护期。已成交（合作中 / 待回款）的客户不参与自动回退">
      <select v-model="rule" class="select rule-select">
        <option value="30">退回规则：30 天无跟进自动退回（成交客户除外）</option>
        <option value="90">退回规则：90 天无成交自动退回（成交客户除外）</option>
      </select>
      <button class="btn" type="button" @click="toast('已导出客户池（演示）')">
        <AppIcon name="download" :size="14" />导出
      </button>
    </PageHead>

    <div class="grid-4 stat-row">
      <div class="mini card">
        <span>池内客户</span>
        <b>{{ rows.length }} <i>家</i></b>
        <em>超过 30 天无人领取会通知主管</em>
      </div>
      <div class="mini card">
        <span>本月新入池</span>
        <b>{{ monthlyIn }} <i>家</i></b>
        <em>退回多说明跟进动作没做到位</em>
      </div>
      <div class="mini card">
        <span>平均滞留</span>
        <b>{{ avgDays }} <i>天</i></b>
        <em>从入池到今天，越久越难救</em>
      </div>
      <div class="mini card">
        <span>池内历史采购</span>
        <b>¥{{ wan(reclaim) }} <i>万</i></b>
        <em>有成交记录的客户更值得领</em>
      </div>
    </div>

    <div class="card">
      <div class="toolbar">
        <div class="search">
          <AppIcon name="search" :size="15" />
          <input v-model="keyword" class="input" type="text" placeholder="搜索客户名称 / 客户类型 / 原负责人" />
        </div>
        <select v-model="industry" class="select">
          <option value="">全部客户类型</option>
          <option v-for="i in industries" :key="i">{{ i }}</option>
        </select>
        <select v-model="reason" class="select">
          <option value="">全部退回原因</option>
          <option v-for="r in reasons" :key="r">{{ r }}</option>
        </select>
        <div class="spacer" />
        <span class="faint hint-txt">领取后保护期 30 天 · 30 天内无跟进自动回池</span>
      </div>

      <AppTable :columns="columns" :rows="filtered" :page-size="8">
        <template #cell-name="{ row }">
          <div>
            <div class="cell-main">{{ row.name }}</div>
            <div class="cell-sub">{{ row.id }} · {{ row.region }}</div>
          </div>
        </template>
        <template #cell-amount="{ row }">
          <div>
            <div class="num">{{ row.amount ? `¥${row.amount.toLocaleString()}` : '—' }}</div>
            <div class="cell-sub">{{ row.orders ? `${row.orders} 单历史成交` : '无成交记录' }}</div>
          </div>
        </template>
        <template #cell-lastFollow="{ row }">
          <span class="faint">{{ row.lastFollow }}</span>
        </template>
        <template #cell-reason="{ row }">
          <span class="tag" :class="row.reason.includes('离职') ? 'tag-info' : 'tag-gray'">{{ row.reason }}</span>
        </template>
        <template #cell-ops="{ row }">
          <div class="row-tight ops">
            <button class="btn-text" type="button" @click="toast(`查看「${row.name}」历史跟进与合同（演示）`)">
              历史
            </button>
            <button v-can="'customer.public.claim'" class="btn btn-sm btn-primary" type="button" @click="claim(row)">
              领取
            </button>
          </div>
        </template>
      </AppTable>
    </div>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import { customerApi } from '@/api/customers'
import { toast } from '@/composables/useToast'

/* 与看板共用同一个时间锚点，保证「滞留天数」在演示时稳定 */
const ANCHOR = new Date()

const rows = ref([])
customerApi.pool().then((data) => { rows.value = data }).catch((e) => toast(e.message, 'error'))
const keyword = ref('')
const industry = ref('')
const reason = ref('')
const rule = ref('30')

const industries = computed(() => [...new Set(rows.value.map((r) => r.industry).filter(Boolean))])
const reasons = computed(() => [...new Set(rows.value.map((r) => r.reason))])

function wan(v) {
  return (Number(v || 0) / 10000).toFixed(1)
}

function daysIn(row) {
  return Math.max(0, Math.round((ANCHOR - new Date(row.releasedAt)) / 86400000))
}

const avgDays = computed(() => {
  if (!rows.value.length) return 0
  return Math.round(rows.value.reduce((s, r) => s + daysIn(r), 0) / rows.value.length)
})

/* 2026-11 入池的算「本月新增」 */
const monthlyIn = computed(() => rows.value.filter((r) => r.releasedAt.startsWith('2026-11')).length)

const columns = [
  { key: 'name', label: '客户名称' },
  { key: 'industry', label: '客户类型', width: '112px' },
  { key: 'prevOwner', label: '原负责人', width: '96px' },
  { key: 'amount', label: '历史采购', width: '150px', align: 'right' },
  { key: 'lastFollow', label: '最后跟进', width: '108px' },
  { key: 'releasedAt', label: '入池时间', width: '108px' },
  { key: 'reason', label: '退回原因', width: '128px' },
  { key: 'ops', label: '操作', align: 'right', width: '116px' }
]

const filtered = computed(() =>
  rows.value.filter((r) => {
    if (industry.value && r.industry !== industry.value) return false
    if (reason.value && r.reason !== reason.value) return false
    if (keyword.value) {
      const k = keyword.value.trim()
      if (!`${r.name}${r.industry}${r.prevOwner}${r.region}`.includes(k)) return false
    }
    return true
  })
)

const reclaim = computed(() => filtered.value.reduce((s, r) => s + r.amount, 0))

async function claim(row) {
  try {
    await customerApi.claim(row.id)
    rows.value = rows.value.filter((r) => r.id !== row.id)
    toast('客户已领取')
  } catch (e) { toast(e.message, 'error') }
}
</script>

<style scoped>
.rule-select {
  width: 262px;
  height: 36px;
}
.stat-row {
  margin-bottom: 16px;
}
.mini {
  padding: 14px 18px;
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.mini span {
  font-size: 12.5px;
  color: var(--muted);
}
.mini b {
  font-size: 21px;
  font-weight: 650;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
  line-height: 1.25;
}
.mini i {
  font-style: normal;
  font-size: 12px;
  font-weight: 500;
  color: var(--faint);
}
.mini em {
  font-style: normal;
  font-size: 11px;
  color: var(--faint);
  line-height: 1.5;
}
.ops {
  justify-content: flex-end;
}
.hint-txt {
  font-size: 11.5px;
}
.num {
  font-variant-numeric: tabular-nums;
  color: var(--ink);
}

@media (max-width: 1180px) {
  .stat-row {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
</style>

