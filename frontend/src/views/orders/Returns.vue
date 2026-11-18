<template>
  <div class="page">
    <PageHead
      title="退货与售后"
      desc="退货单是订单的反向单据：确认入库会按明细回补可用库存，并把订单行标记为已退；驳回只改状态，不动库存"
    >
      <button class="btn" type="button" :disabled="loading" @click="load">
        <AppIcon name="refresh" :size="14" :class="{ spin: loading }" />
        刷新
      </button>
      <button v-can="'order.approve'" class="btn btn-primary" type="button" @click="jumpPending">
        <AppIcon name="flag" :size="14" />
        去处理待审核（{{ countOf('待审核') }}）
      </button>
    </PageHead>

    <div class="summary">
      <div class="kpi card">
        <span>待审核</span>
        <b :class="{ warn: countOf('待审核') }">{{ countOf('待审核') }}<i>单</i></b>
        <em>{{ pendingAmount ? `涉及 ¥${pendingAmount.toLocaleString()}` : '暂无待处理' }}</em>
      </div>
      <div class="kpi card">
        <span>本月退货额</span>
        <b>¥{{ (monthReturn / 10000).toFixed(1) }}<i>万</i></b>
        <em>{{ monthCount }} 单 · {{ monthLabel }}</em>
      </div>
      <div class="kpi card">
        <span>本月退货率</span>
        <b>{{ returnRate == null ? '—' : returnRate.toFixed(1) + '%' }}</b>
        <em>退货额 ÷ 本月下单额</em>
      </div>
      <div class="kpi card">
        <span>质量 + 破损占比</span>
        <b>{{ qualityRate == null ? '—' : qualityRate.toFixed(0) + '%' }}</b>
        <em>{{ qualityCount }} / {{ rows.length }} 单</em>
      </div>
    </div>

    <div class="card">
      <div class="reason-bar">
        <span class="rb-label">退货原因分布</span>
        <div v-for="r in reasonStats" :key="r.reason" class="rb-item">
          <i class="rb-dot" :style="{ background: r.color }" />
          <span class="rb-name">{{ r.reason }}</span>
          <b class="rb-num">{{ r.count }}</b>
          <span class="rb-amt">¥{{ (r.amount / 10000).toFixed(1) }} 万</span>
        </div>
      </div>
    </div>

    <div class="card">
      <div class="tabs">
        <button
          v-for="t in tabs"
          :key="t.value"
          class="tab"
          :class="{ active: status === t.value }"
          type="button"
          @click="status = t.value"
        >
          {{ t.label }}<span class="tab-count">{{ t.count }}</span>
        </button>
      </div>

      <div class="toolbar">
        <div class="search">
          <AppIcon name="search" :size="15" />
          <input v-model="keyword" class="input" type="text" placeholder="搜索退货单号 / 客户 / 订单号" />
        </div>
        <select v-model="reason" class="select">
          <option value="">全部原因</option>
          <option v-for="r in REASONS" :key="r">{{ r }}</option>
        </select>
        <div class="spacer" />
        <span v-if="!canApprove" class="faint hint">当前账号没有订单审批权限，只能查看</span>
        <span v-else class="faint hint">确认入库会真实回补库存与订单已退数量</span>
      </div>

      <div v-if="loadError" class="warn-line">
        <AppIcon name="flag" :size="13" />
        <span>{{ loadError }}</span>
      </div>

      <AppTable
        :columns="columns"
        :rows="filtered"
        :page-size="10"
        empty-text="没有符合条件的退货单"
      >
        <template #cell-code="{ row }">
          <div class="cell-main mono">{{ row.code }}</div>
          <div class="cell-sub">{{ row.orderCode || `订单 #${row.order_id}` }}</div>
        </template>
        <template #cell-customer="{ row }">
          <div class="cell-main">{{ row.customer || '—' }}</div>
          <div class="cell-sub">{{ row.owner ? `销售 ${row.owner}` : '无归属' }}</div>
        </template>
        <template #cell-reason="{ row }">
          <span class="tag" :class="reasonTone(row.reason)">{{ row.reason }}</span>
        </template>
        <template #cell-amount="{ row }">
          <span class="num">¥{{ Number(row.amount || 0).toLocaleString() }}</span>
        </template>
        <template #cell-date="{ row }">
          <div class="cell-main">{{ dateOf(row) }}</div>
          <div v-if="row.confirmed_at" class="cell-sub">处理 {{ String(row.confirmed_at).slice(0, 10) }}</div>
        </template>
        <template #cell-status="{ row }">
          <span class="tag" :class="STATUS_TONE[row.status] || 'tag-gray'">{{ row.status }}</span>
          <div v-if="row.reject_reason" class="cell-sub">{{ row.reject_reason }}</div>
        </template>
        <template #cell-ops="{ row }">
          <div class="row-tight ops">
            <button class="btn-text" type="button" @click="goOrder(row)">订单</button>
            <template v-if="row.status === '待审核' && canApprove">
              <button class="btn-text" type="button" @click="ask(row, 'pass')">入库</button>
              <button class="btn-text danger" type="button" @click="ask(row, 'reject')">驳回</button>
            </template>
          </div>
        </template>
      </AppTable>
    </div>

    <ModalDialog
      v-model="confirmOpen"
      :title="confirmResult === 'pass' ? '确认退货入库？' : '确认驳回这笔退货？'"
      :ok-text="confirmResult === 'pass' ? '确认入库' : '确认驳回'"
      :loading="saving"
      @confirm="submit"
    >
      <template v-if="current.code">
        <div class="cf-box">
          <div class="cf-row"><span>退货单</span><b>{{ current.code }}</b></div>
          <div class="cf-row"><span>客户</span><b>{{ current.customer }}</b></div>
          <div class="cf-row"><span>订单</span><b>{{ current.orderCode || `#${current.order_id}` }}</b></div>
          <div class="cf-row"><span>原因</span><b>{{ current.reason }}</b></div>
          <div class="cf-row"><span>金额</span><b>¥{{ Number(current.amount || 0).toLocaleString() }}</b></div>
        </div>

        <div v-if="confirmResult === 'pass'" class="impact pass">
          <AppIcon name="check-circle" :size="14" />
          <div>
            <strong>将执行</strong>
            <p>按退货明细回补商品可用库存，订单行累加已退数量；整单退完时订单自动转「已退货」。库存会真的变，不可撤销。</p>
          </div>
        </div>
        <div v-else class="impact reject">
          <AppIcon name="flag" :size="14" />
          <div>
            <strong>将执行</strong>
            <p>只把退货单状态改为「已驳回」，<b>不动库存、不改订单</b>。</p>
          </div>
        </div>
        <textarea v-if="confirmResult === 'reject'" v-model="rejectReason" class="input" maxlength="500"
                  placeholder="填写驳回理由" aria-label="驳回理由" />
      </template>
    </ModalDialog>
  </div>
</template>

<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import { toast } from '@/composables/useToast'
import { orderApi } from '@/api/orders'
import { can } from '@/store/permissions'
import { todayStr } from '@/utils/date'

const router = useRouter()

const REASONS = ['质量问题', '发错规格', '客户取消', '运输破损', '其他']
const STATUS_TONE = {
  待审核: 'tag-warning',
  已入库: 'tag-success',
  已退款: 'tag-brand',
  已驳回: 'tag-gray'
}
const REASON_TONE = {
  质量问题: 'tag-danger',
  发错规格: 'tag-warning',
  运输破损: 'tag-warning',
  客户取消: 'tag-gray',
  其他: 'tag-gray'
}

const rows = ref([])
const orders = ref([])
const searchRows = ref(null)
const loading = ref(false)
const loadError = ref('')
const canApprove = computed(() => can('order.approve'))

const status = ref('')
const reason = ref('')
const keyword = ref('')

const dateOf = (r) => String(r.return_date || r.date || '').slice(0, 10)

async function load() {
  loading.value = true
  loadError.value = ''
  try {
    /* 订单列表只用来把 order_id 翻成单号、算本月下单额；失败不影响退货单本身 */
    const [ret, ord] = await Promise.all([
      orderApi.returns({ pageSize: 500 }),
      can('order.view') ? orderApi.list({ pageSize: 500 }).catch(() => null) : Promise.resolve(null)
    ])
    orders.value = ord?.rows || []
    const map = new Map(orders.value.map((o) => [o.id, o]))
    rows.value = (ret?.rows || []).map((r) => {
      const o = map.get(r.order_id)
      return { ...r, orderCode: r.orderCode || o?.code || '', customer: r.customer || o?.customer || '' }
    })
  } catch (e) {
    loadError.value = `退货单加载失败：${e.message}`
    rows.value = []
  } finally {
    loading.value = false
  }
}

/* ---------------- 统计 ---------------- */
const monthLabel = computed(() => {
  const d = new Date()
  return `${d.getFullYear()} 年 ${d.getMonth() + 1} 月`
})

const monthPrefix = computed(() => todayStr().slice(0, 7))

const countOf = (s) => rows.value.filter((r) => r.status === s).length
const pendingAmount = computed(() =>
  rows.value.filter((r) => r.status === '待审核').reduce((s, r) => s + Number(r.amount || 0), 0)
)

const monthRows = computed(() => rows.value.filter((r) => dateOf(r).startsWith(monthPrefix.value)))
const monthReturn = computed(() => monthRows.value.reduce((s, r) => s + Number(r.amount || 0), 0))
const monthCount = computed(() => monthRows.value.length)

/* 本月下单额：排除草稿/已取消/已退货这类不构成实际出货的单 */
const monthOrdered = computed(() =>
  orders.value
    .filter((o) => {
      const d = String(o.order_date || o.date || '').slice(0, 10)
      return d.startsWith(monthPrefix.value) && !['草稿', '已取消', '已退货'].includes(o.status)
    })
    .reduce((s, o) => s + Number(o.amount || 0), 0)
)

const returnRate = computed(() => (monthOrdered.value > 0 ? (monthReturn.value / monthOrdered.value) * 100 : null))

const qualityCount = computed(() => rows.value.filter((r) => ['质量问题', '运输破损'].includes(r.reason)).length)
const qualityRate = computed(() => (rows.value.length ? (qualityCount.value / rows.value.length) * 100 : null))

const REASON_COLOR = {
  质量问题: '#d92d20',
  发错规格: '#dc6803',
  运输破损: '#f79009',
  客户取消: '#98a2b3',
  其他: '#cbd5e1'
}

const reasonStats = computed(() =>
  REASONS.map((r) => {
    const hit = rows.value.filter((x) => x.reason === r)
    return {
      reason: r,
      color: REASON_COLOR[r],
      count: hit.length,
      amount: hit.reduce((s, x) => s + Number(x.amount || 0), 0)
    }
  }).filter((r) => r.count > 0)
)

/* ---------------- 列表 ---------------- */
const tabs = computed(() => {
  const c = (s) => (s === '' ? rows.value.length : countOf(s))
  return [
    { label: '全部', value: '', count: c('') },
    { label: '待审核', value: '待审核', count: c('待审核') },
    { label: '已入库', value: '已入库', count: c('已入库') },
    { label: '已退款', value: '已退款', count: c('已退款') },
    { label: '已驳回', value: '已驳回', count: c('已驳回') }
  ]
})

const columns = [
  { key: 'code', label: '退货单号', width: '158px' },
  { key: 'customer', label: '客户' },
  { key: 'reason', label: '原因', width: '104px' },
  { key: 'amount', label: '退货金额', width: '116px', align: 'right' },
  { key: 'date', label: '退货日期', width: '136px' },
  { key: 'status', label: '状态', width: '90px' },
  { key: 'ops', label: '操作', width: '148px', align: 'right' }
]

const filtered = computed(() =>
  (keyword.value.trim() ? searchRows.value || [] : rows.value).filter((r) => {
    if (status.value && r.status !== status.value) return false
    if (reason.value && r.reason !== reason.value) return false
    return true
  })
)

const reasonTone = (r) => REASON_TONE[r] || 'tag-gray'

function goOrder(row) {
  if (!row.order_id) return
  router.push(`/orders/${row.order_id}`)
}

function jumpPending() {
  status.value = '待审核'
}

/* ---------------- 确认 / 驳回 ---------------- */
const confirmOpen = ref(false)
const confirmResult = ref('pass')
const current = ref({})
const saving = ref(false)
const rejectReason = ref('')

function ask(row, result) {
  current.value = row
  confirmResult.value = result
  rejectReason.value = ''
  confirmOpen.value = true
}

async function submit() {
  if (saving.value) return
  const row = current.value
  saving.value = true
  try {
    await orderApi.confirmReturn(row.id, {
      result: confirmResult.value,
      /* 入库才回补库存；驳回时后端根本不看这个字段，传 false 更明确 */
      restock: confirmResult.value === 'pass',
      reason: rejectReason.value.trim()
    })
    confirmOpen.value = false
    toast(confirmResult.value === 'pass' ? `${row.code} 已入库，库存已回补` : `${row.code} 已驳回`)
    await load()
    await search()
  } catch (e) {
    /* 失败不改本地状态，避免界面显示已入库但库里还是待审核 */
    toast(e.message, 'error')
  } finally {
    saving.value = false
  }
}

async function search() {
  const term = keyword.value.trim()
  if (!term) return
  try {
    const data = await orderApi.returns({ keyword: term, pageSize: 500 })
    if (term === keyword.value.trim()) searchRows.value = data.rows
  } catch (e) {
    if (term === keyword.value.trim()) toast(e.message, 'error')
  }
}

watch(keyword, (_, __, onCleanup) => {
  searchRows.value = null
  const timer = setTimeout(search, 250)
  onCleanup(() => clearTimeout(timer))
})

onMounted(load)
</script>

<style scoped>
.spin {
  animation: spin 0.9s linear infinite;
}
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.summary {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 16px;
  margin-bottom: 16px;
}
.kpi {
  padding: 14px 18px;
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.kpi span {
  font-size: 12.5px;
  color: var(--muted);
}
.kpi b {
  font-size: 20px;
  font-weight: 650;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.2px;
}
.kpi b.warn {
  color: var(--warning);
}
.kpi i {
  font-style: normal;
  font-size: 12px;
  font-weight: 500;
  color: var(--faint);
}
.kpi em {
  font-style: normal;
  font-size: 11.5px;
  color: var(--faint);
}

.reason-bar {
  display: flex;
  align-items: center;
  gap: 22px;
  flex-wrap: wrap;
  padding: 13px 18px;
}
.rb-label {
  font-size: 12px;
  color: var(--muted);
  padding-right: 4px;
  border-right: 1px solid var(--line);
  margin-right: 4px;
}
.rb-item {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
}
.rb-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
}
.rb-name {
  color: var(--text);
}
.rb-num {
  font-weight: 600;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
}
.rb-amt {
  color: var(--faint);
  font-size: 11.5px;
}

.tab-count {
  display: inline-block;
  margin-left: 5px;
  padding: 0 5px;
  height: 17px;
  line-height: 17px;
  border-radius: 4px;
  background: #f2f4f7;
  color: var(--muted);
  font-size: 11px;
  font-variant-numeric: tabular-nums;
}
.tab.active .tab-count {
  background: var(--brand-soft);
  color: var(--brand);
}

.mono {
  font-variant-numeric: tabular-nums;
}
.ops {
  justify-content: flex-end;
}
.btn-text.danger {
  color: var(--danger);
}
.hint {
  font-size: 12px;
}

.cf-box {
  display: flex;
  flex-direction: column;
  gap: 9px;
  padding: 13px 15px;
  background: #fafbfc;
  border-radius: 10px;
}
.cf-row {
  display: flex;
  gap: 12px;
  font-size: 12.5px;
  line-height: 1.5;
}
.cf-row span {
  width: 52px;
  flex-shrink: 0;
  color: var(--muted);
}
.cf-row b {
  font-weight: 500;
  color: var(--ink);
}

.impact {
  display: flex;
  gap: 9px;
  margin-top: 12px;
  padding: 11px 13px;
  border-radius: 9px;
  font-size: 12px;
  line-height: 1.55;
}
.impact strong {
  display: block;
  font-size: 12.5px;
  margin-bottom: 2px;
}
.impact p {
  margin: 0;
  color: var(--muted);
}
.impact.pass {
  background: #ecfdf3;
  color: #067647;
}
.impact.reject {
  background: #fffaeb;
  color: #b54708;
}

@media (max-width: 900px) {
  .summary {
    grid-template-columns: 1fr 1fr;
  }
}
</style>
