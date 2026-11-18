<template>
  <div class="page">
    <PageHead title="对账单" desc="按客户与账期生成的应收结算凭证，客户确认后才允许开票；期末应收 = 期初 + 本期发货 − 本期回款">
      <SourceTag :mode="sourceState.statements" hint="对账单列表接口未返回数据，当前展示演示对账单" />
      <button class="btn" type="button" @click="exportStatement(current)">
        <AppIcon name="download" :size="14" />导出
      </button>
      <button v-can="'statement.create'" class="btn btn-primary" type="button" @click="openCreate">
        <AppIcon name="plus" :size="14" />生成对账单
      </button>
    </PageHead>

    <div class="summary">
      <div class="kpi card">
        <span>应收余额合计</span>
        <b>¥{{ wan(totalClose) }}<i>万</i></b>
        <em>{{ rows.length }} 张对账单</em>
      </div>
      <div class="kpi card">
        <span>待客户确认</span>
        <b class="warn">{{ countOf('待确认') }}<i>张</i></b>
        <em>确认前不能开票</em>
      </div>
      <div class="kpi card">
        <span>已确认待开票</span>
        <b>{{ countOf('已确认') }}<i>张</i></b>
        <em>可提交开票申请</em>
      </div>
      <div class="kpi card">
        <span>本期已回款</span>
        <b class="ok">¥{{ wan(totalReceived) }}<i>万</i></b>
        <em>含承兑到账</em>
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
          <input v-model="keyword" class="input" type="text" placeholder="搜索对账单号 / 客户 / 账期" />
        </div>
        <select v-model="period" class="select">
          <option value="">全部账期</option>
          <option v-for="p in periods" :key="p">{{ p }}</option>
        </select>
        <div class="spacer" />
        <span class="faint hint">期末应收必须与期初 + 发货 − 回款 一致，否则财务退回</span>
      </div>

      <AppTable :columns="columns" :rows="filtered" :page-size="8">
        <template #cell-id="{ row }">
          <div class="cell-main link" @click="openDetail(row)">{{ row.id }}</div>
          <div class="cell-sub">{{ row.period }} · {{ row.orders }} 张订单</div>
        </template>
        <template #cell-open="{ row }">
          <span class="num faint-num">{{ moneyWan(row.open) }}</span>
        </template>
        <template #cell-shipped="{ row }">
          <span class="num">{{ moneyWan(row.shipped) }}</span>
        </template>
        <template #cell-received="{ row }">
          <span class="num text-ok">{{ moneyWan(row.received) }}</span>
        </template>
        <template #cell-close="{ row }">
          <b class="num">{{ moneyWan(closeOf(row)) }}</b>
        </template>
        <template #cell-status="{ row }">
          <span class="tag" :class="tone[row.status]">{{ row.status }}</span>
        </template>
        <template #cell-ops="{ row }">
          <div class="row-tight ops">
            <button class="btn-text" type="button" @click="openDetail(row)">明细</button>
            <button
              v-if="row.status === '待确认'"
              v-can="'statement.confirm'"
              class="btn-text"
              type="button"
              @click="confirmStatement(row)"
            >
              确认
            </button>
          </div>
        </template>
      </AppTable>
    </div>

    <!-- 生成对账单 -->
    <ModalDialog v-model="createOpen" title="生成对账单" desc="同一客户同一账期只能生成一张，已存在时会提示" ok-text="生成" @confirm="submitCreate">
      <div v-if="fromOrder" class="from-note">
        <AppIcon name="flag" :size="12" />
        从订单 <b>{{ fromOrder }}</b> 的签收记录带过来：客户与账期已填好，确认无误直接生成。
      </div>
      <div class="form-grid">
        <div class="field span-2">
          <label class="label">客户<span class="req">*</span></label>
          <select v-model="form.customer" class="select">
            <option value="">请选择客户</option>
            <option v-for="c in customerNames" :key="c">{{ c }}</option>
          </select>
        </div>
        <div class="field">
          <label class="label">账期<span class="req">*</span></label>
          <select v-model="form.period" class="select">
            <option v-for="p in periodOptions" :key="p">{{ p }}</option>
          </select>
        </div>
        <div class="field">
          <label class="label">截止日</label>
          <input class="input" type="text" :value="endOf(form.period)" disabled />
        </div>
      </div>
      <div v-if="form.customer && form.period" class="preview">
        <div v-if="preview.live" class="pv-note">
          该客户是真实客户：期初应收、本期发货、本期回款由服务端按账期汇总（只算已签收的发货），
          点「生成」后以返回的实际金额为准。
        </div>
        <template v-else>
          <div class="pv"><span>期初应收</span><b>{{ moneyWan(preview.open) }}</b></div>
          <div class="pv"><span>本期发货</span><b>{{ moneyWan(preview.shipped) }}</b></div>
          <div class="pv"><span>本期回款</span><b class="text-ok">{{ moneyWan(preview.received) }}</b></div>
          <div class="pv strong"><span>期末应收</span><b>{{ moneyWan(preview.close) }}</b></div>
        </template>
      </div>
    </ModalDialog>

    <!-- 明细 -->
    <ModalDialog v-model="detailOpen" width="wide" :title="current.id || ''" :desc="current.customer" hide-footer>
      <div v-if="current.id" class="detail">
        <div class="eq">
          <div class="eq-item"><span>期初应收</span><b>{{ moneyWan(current.open) }}</b></div>
          <div class="eq-op">+</div>
          <div class="eq-item"><span>本期发货</span><b>{{ moneyWan(current.shipped) }}</b></div>
          <div class="eq-op">−</div>
          <div class="eq-item"><span>本期回款</span><b>{{ moneyWan(current.received) }}</b></div>
          <div class="eq-op">=</div>
          <div class="eq-item strong"><span>期末应收</span><b>{{ moneyWan(closeOf(current)) }}</b></div>
        </div>

        <div class="d-sec">
          <div class="d-title">本期订单</div>
          <AppTable :columns="orderColumns" :rows="relatedOrders" :show-pager="false" compact empty-text="本期没有订单">
            <template #cell-amount="{ row }">
              <span class="num">¥{{ amountOf(row).toLocaleString() }}</span>
            </template>
            <template #cell-status="{ row }">
              <span class="tag" :class="orderTone[row.status]">{{ row.status }}</span>
            </template>
          </AppTable>
        </div>

        <div class="d-sec">
          <div class="d-title">状态流转</div>
          <div class="flow">
            <span class="fs" :class="{ on: true }">生成 {{ current.createdAt }}</span>
            <i class="fl" />
            <span class="fs" :class="{ on: !!current.confirmedAt }">
              客户确认 {{ current.confirmedAt || '待确认' }}
            </span>
            <i class="fl" />
            <span class="fs" :class="{ on: ['已开票', '已回款'].includes(current.status) }">开票</span>
            <i class="fl" />
            <span class="fs" :class="{ on: current.status === '已回款' }">回款核销</span>
          </div>
        </div>
      </div>
    </ModalDialog>
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import { toast } from '@/composables/useToast'
import SourceTag from '@/components/SourceTag.vue'
import { orderApi } from '@/api/orders'
import { loadStatements, attempt, sourceState } from '@/api/orderSource'
import { useCustomerOptions } from '@/composables/useCustomerOptions'
import {
  statements as seed, orders, receipts, orderAmount,
  statementClose, STATEMENT_STATUS_TONE, ORDER_STATUS_TONE
} from '@/data/orderCenter'
import { todayStr } from '@/utils/date'

const rows = ref(seed.map((r) => ({ ...r })))

/* 后端 /statements 有数据就用真数据，否则保留演示，页头有标记。
   这里的 Promise 留着，从订单详情「去对账」带参数跳过来时要等它落地才知道账期是否已生成 */
const rowsReady = loadStatements()
  .then((live) => { if (live) rows.value = live })
  .catch((e) => toast(e.message, 'error'))

/* 客户下拉走真实客户库（见 useCustomerOptions）；生成对账单要传 customerId，
   演示客户没有 id，据此决定走接口还是走本地演示 */
const { names: customerNames, idOf: customerIdOf, isLive: isLiveCustomer, ready: customersReady } = useCustomerOptions()
const keyword = ref('')
const status = ref('')
const period = ref('')

const tone = STATEMENT_STATUS_TONE
const orderTone = ORDER_STATUS_TONE
const periods = [...new Set(rows.value.map((r) => r.period))].sort().reverse()

const tabs = computed(() => {
  const c = (s) => rows.value.filter((r) => (s === '' ? true : r.status === s)).length
  return [
    { label: '全部', value: '', count: rows.value.length },
    { label: '待确认', value: '待确认', count: c('待确认') },
    { label: '已确认', value: '已确认', count: c('已确认') },
    { label: '已开票', value: '已开票', count: c('已开票') },
    { label: '已回款', value: '已回款', count: c('已回款') }
  ]
})

const columns = [
  { key: 'id', label: '对账单号', width: '164px' },
  { key: 'customer', label: '客户' },
  { key: 'open', label: '期初', width: '94px', align: 'right' },
  { key: 'shipped', label: '本期发货', width: '94px', align: 'right' },
  { key: 'received', label: '本期回款', width: '94px', align: 'right' },
  { key: 'close', label: '期末应收', width: '100px', align: 'right' },
  { key: 'status', label: '状态', width: '92px' },
  { key: 'ops', label: '操作', align: 'right', width: '96px' }
]

const filtered = computed(() =>
  rows.value.filter((r) => {
    if (status.value && r.status !== status.value) return false
    if (period.value && r.period !== period.value) return false
    if (keyword.value) {
      const k = keyword.value.trim()
      if (![r.id, r.customer, r.period].join(' ').includes(k)) return false
    }
    return true
  })
)

const closeOf = (r) => statementClose(r)
const moneyWan = (n) => `¥${(n / 10000).toFixed(1)}万`
const wan = (n) => (n / 10000).toFixed(1)

const totalClose = computed(() => filtered.value.reduce((s, r) => s + closeOf(r), 0))
const totalReceived = computed(() => filtered.value.reduce((s, r) => s + r.received, 0))
const countOf = (s) => rows.value.filter((r) => r.status === s).length

async function confirmStatement(row) {
  if (row.status !== '待确认') return toast(`「${row.id}」当前是${row.status}，不需要再确认`, 'error')
  const r = await attempt({
    label: 'POST /statements/{id}/confirm',
    call: () => orderApi.confirmStatement(row.dbId),
    demoNote: '确认接口未就绪，已在本地演示'
  })
  row.status = '已确认'
  row.confirmedAt = r.mode === 'live' ? (r.data?.confirmedAt || todayStr()) : todayStr()
  toast(r.mode === 'live' ? `「${row.id}」已确认，可以申请开票` : `「${row.id}」已确认（${r.note}）`)
}

/* ---------------- 生成 ---------------- */
const createOpen = ref(false)
const route = useRoute()
const router = useRouter()
const form = reactive({ customer: '', period: '' })

/* 账期选项按当月往前推 6 个月，别写死——写死过一版，跨月就选不到当期了 */
function monthOf(offset = 0) {
  const d = new Date()
  d.setDate(1)
  d.setMonth(d.getMonth() - offset)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}
const periodOptions = computed(() => {
  const list = Array.from({ length: 6 }, (_, i) => monthOf(i))
  /* 从订单带过来的账期可能早于这 6 个月，得补进选项，否则下拉显示空白 */
  if (form.period && !list.includes(form.period)) list.unshift(form.period)
  return list
})

function endOf(p) {
  if (!p) return '—'
  const [y, m] = p.split('-').map(Number)
  const last = new Date(y, m, 0).getDate()
  return `${p}-${String(last).padStart(2, '0')}`
}

/* 期初取该客户上一张对账单的期末，发货与回款按当期订单 / 收款单聚合。
   注意：这套算法只对演示数据成立——真实客户的单据在服务端，前端没有出货流水，
   硬算会得出「全是 0」，所以真实客户直接交给后端，别在前端摆假数字。 */
const preview = computed(() => {
  if (!form.customer) return { open: 0, shipped: 0, received: 0, close: 0 }
  if (isLiveCustomer(form.customer)) return { live: true }
  const prev = rows.value
    .filter((r) => r.customer === form.customer && r.period < form.period)
    .sort((a, b) => (a.period < b.period ? 1 : -1))[0]
  const open = prev ? closeOf(prev) : 0
  const shipped = Math.round(
    orders
      .filter((o) => o.customer === form.customer && o.date.startsWith(form.period) && o.status !== '已取消')
      .reduce((s, o) => s + orderAmount(o), 0)
  )
  const received = receipts
    .filter((r) => r.customer === form.customer && r.payDate.startsWith(form.period))
    .reduce((s, r) => s + r.amount, 0)
  return { open, shipped, received, close: open + shipped - received }
})

function openCreate() {
  form.customer = ''
  form.period = monthOf(0)
  createOpen.value = true
}

/* 从订单详情的「回款」节点跳过来：/orders/statements?customer=客户名&periods=2026-11&from=SO-…
   - 该账期已经对过账 → 直接打开那张（下一步是开票，不是再生成一张）
   - 没对过账 → 打开生成弹窗，客户与账期预填好
   多个签收月份时取最早一个还没对账的，符合「按月滚动结算」的实际做法。 */
const fromOrder = ref('')
onMounted(async () => {
  const q = route.query
  const name = typeof q.customer === 'string' ? q.customer : ''
  if (!name) return

  /* 两件事都得等：有没有对过账看 rows，客户是不是真的看客户列表 */
  await Promise.allSettled([rowsReady, customersReady()])
  router.replace({ query: {} }) // 参数已消费，避免刷新再弹一次

  const wanted = String(q.periods || '')
    .split(',')
    .map((s) => s.trim())
    .filter((s) => /^\d{4}-\d{2}$/.test(s))
    .filter((s) => s <= monthOf(0)) // 晚于当期的账期服务端会直接 400
  const taken = (p) => rows.value.find((r) => r.customer === name && r.period === p)

  if (!isLiveCustomer(name)) {
    toast(`客户「${name}」不在客户列表里（可能超出数据范围），请手动选择客户`, 'error')
    return openCreate()
  }

  fromOrder.value = typeof q.from === 'string' ? q.from : ''
  const free = wanted.find((p) => !taken(p))
  if (free) {
    form.customer = name
    form.period = free
    createOpen.value = true
    return
  }

  const last = wanted.length ? taken(wanted[wanted.length - 1]) : null
  if (last) {
    toast(`${last.period} 已生成对账单 ${last.id}，已为你打开`, 'info')
    return openDetail(last)
  }

  /* 没带账期（理论上不该发生）：退回当期 */
  form.customer = name
  form.period = monthOf(0)
  createOpen.value = true
})

async function submitCreate() {
  if (!form.customer) return toast('请选择客户', 'error')
  const dup = rows.value.find((r) => r.customer === form.customer && r.period === form.period)
  if (dup) return toast(`该客户 ${form.period} 的对账单已存在（${dup.id}）`, 'error')

  /* 有 customerId 就走后端生成：期初/发货/回款由后端按账期算，前端不再自己凑 */
  const cid = customerIdOf(form.customer)
  if (cid) {
    const r = await attempt({
      label: 'POST /statements',
      call: () => orderApi.generateStatement({ customerId: cid, period: form.period }),
      demoNote: '生成接口未就绪，已在本地演示'
    })
    if (r.mode === 'live' && r.data) {
      rows.value.unshift({
        id: r.data.code, dbId: r.data.id, customer: form.customer, period: form.period,
        start: r.data.startDate || `${form.period}-01`, end: r.data.endDate || endOf(form.period),
        open: Number(r.data.open || 0), shipped: Number(r.data.shipped || 0),
        received: Number(r.data.received || 0), close: Number(r.data.close || 0),
        status: r.data.status || '待确认', orders: Number(r.data.orders || 0),
        createdAt: todayStr(), confirmedAt: ''
      })
      createOpen.value = false
      toast(`已生成对账单 ${r.data.code}，期末应收 ¥${Number(r.data.close || 0).toLocaleString()}`)
      return
    }
  }

  const p = preview.value
  rows.value.unshift({
    id: `DZ-${form.period}-${String(rows.value.length + 1).padStart(3, '0')}`,
    customer: form.customer,
    period: form.period,
    start: `${form.period}-01`,
    end: endOf(form.period),
    open: p.open,
    shipped: p.shipped,
    received: p.received,
    status: '待确认',
    orders: orders.filter((o) => o.customer === form.customer && o.date.startsWith(form.period)).length,
    createdAt: todayStr(),
    confirmedAt: ''
  })
  createOpen.value = false
  toast(`已生成对账单，期末应收 ${moneyWan(p.close)}`)
}

/* ---------------- 明细 ---------------- */
const detailOpen = ref(false)
const current = ref({})

const amountOf = (o) => Number(o.amount || 0)
const relatedOrders = ref([])

const orderColumns = [
  { key: 'id', label: '订单号', width: '150px' },
  { key: 'date', label: '下单日', width: '104px' },
  { key: 'amount', label: '金额', width: '124px', align: 'right' },
  { key: 'status', label: '状态', width: '92px' }
]

async function openDetail(row) {
  if (!row.dbId) return toast('请先生成真实对账单', 'error')
  try {
    const detail = await orderApi.statementDetail(row.dbId)
    relatedOrders.value = detail.orders.map((line) => ({ ...line, id: line.code, status: '已签收' }))
    current.value = row
    detailOpen.value = true
  } catch (e) { toast(e.message, 'error') }
}

async function exportStatement(row) {
  if (!row.dbId) return toast('请先打开要导出的对账单明细')
  try {
    const file = await orderApi.exportStatement(row.dbId)
    const link = document.createElement('a')
    link.href = URL.createObjectURL(file)
    link.download = row.id + '.xlsx'
    link.click()
    URL.revokeObjectURL(link.href)
  } catch (e) { toast(e.message, 'error') }
}
</script>

<style scoped>
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
.kpi b.ok {
  color: var(--success);
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

.link {
  color: var(--brand);
  cursor: pointer;
}
.link:hover {
  text-decoration: underline;
}
.faint-num {
  color: var(--muted);
}
.text-ok {
  color: var(--success);
}
.ops {
  justify-content: flex-end;
}
.hint {
  font-size: 12px;
}

/* 生成预览 */
.preview {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 10px;
  margin-top: 14px;
  padding: 12px 14px;
  background: #fafbfc;
  border-radius: 10px;
}
.pv {
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.pv span {
  font-size: 11.5px;
  color: var(--muted);
}
.pv b {
  font-size: 14px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}
.pv.strong b {
  font-size: 16px;
  color: var(--brand);
}
/* 真实客户：金额由服务端算，这里只解释口径，不摆四个 0 糊弄人 */
.pv-note {
  grid-column: 1 / -1;
  font-size: 12px;
  color: var(--muted);
  line-height: 1.6;
}

/* 从订单详情跳过来的说明条 */
.from-note {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 14px;
  padding: 8px 11px;
  border-radius: 8px;
  background: var(--brand-50, rgba(43, 108, 176, 0.06));
  font-size: 12px;
  color: var(--text-2, #40506b);
  line-height: 1.5;
}
.from-note b {
  font-weight: 600;
  font-family: var(--mono, ui-monospace, monospace);
}

/* 明细 */
.detail {
  display: flex;
  flex-direction: column;
  gap: 18px;
}
.eq {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 14px 16px;
  background: #fafbfc;
  border-radius: 10px;
}
.eq-item {
  display: flex;
  flex-direction: column;
  gap: 3px;
  flex: 1;
  min-width: 0;
}
.eq-item span {
  font-size: 11.5px;
  color: var(--muted);
}
.eq-item b {
  font-size: 14px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}
.eq-item.strong b {
  font-size: 17px;
  color: var(--brand);
}
.eq-op {
  color: var(--faint);
  font-size: 16px;
  padding-top: 12px;
}

.d-title {
  font-size: 12.5px;
  font-weight: 600;
  color: var(--ink);
  margin-bottom: 8px;
}

.flow {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}
.fs {
  font-size: 11.5px;
  color: var(--faint);
  padding: 4px 9px;
  border-radius: 6px;
  background: #f4f6f8;
  font-variant-numeric: tabular-nums;
}
.fs.on {
  background: var(--brand-soft);
  color: var(--brand);
}
.fl {
  width: 16px;
  height: 1px;
  background: var(--line);
}

@media (max-width: 900px) {
  .summary,
  .preview {
    grid-template-columns: 1fr 1fr;
  }
}
</style>
