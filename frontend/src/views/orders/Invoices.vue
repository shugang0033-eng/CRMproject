<template>
  <div class="page">
    <PageHead title="发票" desc="按已确认的对账单开票，价税合计 13% 专票；红冲需保留原票号，已核销的发票不能直接作废">
      <SourceTag :mode="sourceState.invoices" hint="发票列表接口未返回数据，当前展示演示发票" />
      <button class="btn" type="button" @click="toast('已导出发票列表（演示）')">
        <AppIcon name="download" :size="14" />导出
      </button>
      <button v-can="'invoice.create'" class="btn btn-primary" type="button" @click="openIssue">
        <AppIcon name="plus" :size="14" />申请开票
      </button>
    </PageHead>

    <div class="summary">
      <div class="kpi card">
        <span>已开票金额</span>
        <b class="ok">¥{{ wan(issued) }}<i>万</i></b>
        <em>价税合计</em>
      </div>
      <div class="kpi card">
        <span>待开票金额</span>
        <b class="warn">¥{{ wan(waiting) }}<i>万</i></b>
        <em>需先确认对账单</em>
      </div>
      <div class="kpi card">
        <span>其中税额</span>
        <b>¥{{ wan(taxTotal) }}<i>万</i></b>
        <em>13% 专票 / 普票</em>
      </div>
      <div class="kpi card">
        <span>未核销</span>
        <b class="danger">¥{{ wan(unsettled) }}<i>万</i></b>
        <em>已开票未收到钱</em>
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
          <input v-model="keyword" class="input" type="text" placeholder="搜索发票号 / 客户 / 对账单" />
        </div>
        <select v-model="type" class="select">
          <option value="">全部类型</option>
          <option>增值税专用</option>
          <option>增值税普通</option>
        </select>
      </div>

      <AppTable :columns="columns" :rows="filtered" :page-size="8">
        <template #cell-id="{ row }">
          <div class="cell-main">{{ row.id }}</div>
          <div class="cell-sub">{{ row.statementId || '无对账单' }}</div>
        </template>
        <template #cell-amount="{ row }">
          <span class="num">¥{{ row.amount.toLocaleString() }}</span>
          <div class="cell-sub">税 ¥{{ invoiceTax(row).toLocaleString() }}</div>
        </template>
        <template #cell-settled="{ row }">
          <span :class="settledOf(row) >= row.amount ? 'num text-ok' : 'num faint'">
            ¥{{ settledOf(row).toLocaleString() }}
          </span>
          <div class="cell-sub">{{ row.amount ? Math.round((settledOf(row) / row.amount) * 100) : 0 }}%</div>
        </template>
        <template #cell-no="{ row }">
          <span v-if="row.no" class="mono-num">{{ row.no }}</span>
          <span v-else class="faint">—</span>
        </template>
        <template #cell-status="{ row }">
          <span class="tag" :class="statusTone[row.status]">{{ row.status }}</span>
        </template>
        <template #cell-ops="{ row }">
          <div class="row-tight ops">
            <button
              v-if="row.status === '待开票'"
              v-can="'invoice.create'"
              class="btn-text"
              type="button"
              @click="issue(row)"
            >
              立即开票
            </button>
            <button v-if="row.status === '已驳回'" class="btn-text" type="button" @click="resubmit(row)">
              重新提交
            </button>
            <button
              v-if="row.status === '已开票' && settledOf(row) === 0"
              v-can="'invoice.redflush'"
              class="btn-text danger"
              type="button"
              @click="redFlush(row)"
            >
              红冲
            </button>
            <button v-if="row.status !== '待开票'" class="btn-text" type="button" @click="toast(`查看「${row.id}」发票详情`)">
              查看
            </button>
          </div>
        </template>
      </AppTable>
    </div>

    <!-- 申请开票 -->
    <ModalDialog v-model="issueOpen" title="申请开票" desc="只能对已确认的对账单开票，金额不得超过可开票金额" ok-text="提交申请" @confirm="submitIssue">
      <div class="form-grid">
        <div class="field span-2">
          <label class="label">客户<span class="req">*</span></label>
          <select v-model="form.customer" class="select">
            <option value="">请选择客户</option>
            <option v-for="c in customerNames" :key="c">{{ c }}</option>
          </select>
        </div>
        <div class="field">
          <label class="label">对账单<span class="req">*</span></label>
          <select v-model="form.statementId" class="select">
            <option value="">请选择</option>
            <option v-for="s in invoiceable" :key="s.id" :value="s.id">{{ s.id }}（{{ s.period }}）</option>
          </select>
        </div>
        <div class="field">
          <label class="label">发票类型</label>
          <select v-model="form.type" class="select">
            <option>增值税专用</option>
            <option>增值税普通</option>
          </select>
        </div>
        <div class="field">
          <label class="label">开票金额<span class="req">*</span></label>
          <div class="money-input">
            <span>¥</span>
            <input v-model.number="form.amount" class="input" type="number" min="0" />
          </div>
        </div>
        <div class="field">
          <label class="label">税额</label>
          <input class="input" type="text" :value="'¥' + previewTax.toLocaleString()" disabled />
        </div>
      </div>
      <div v-if="invoiceable.length === 0 && form.customer" class="tip-warn">
        该客户没有已确认、未开票的对账单，先去「对账单」页确认
      </div>
    </ModalDialog>
  </div>
</template>

<script setup>
import { computed, reactive, ref } from 'vue'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import { toast } from '@/composables/useToast'
import SourceTag from '@/components/SourceTag.vue'
import { orderApi } from '@/api/orders'
import { loadInvoices, loadStatements, attempt, sourceState } from '@/api/orderSource'
import { useCustomerOptions } from '@/composables/useCustomerOptions'
import {
  invoices as seed, statements as demoStatements, invoiceTax, invoiceSettled
} from '@/data/orderCenter'
import { todayStr } from '@/utils/date'

const rows = ref(seed.map((r) => ({ ...r })))

/* 可开票的对账单也从接口取：开票申请只认「已确认」的对账单 */
const statements = ref(demoStatements)
loadStatements()
  .then((live) => { if (live) statements.value = live })
  .catch((e) => toast(e.message, 'error'))

loadInvoices()
  .then((live) => { if (live) rows.value = live })
  .catch((e) => toast(e.message, 'error'))
const keyword = ref('')
const type = ref('')
const status = ref('')

const { names: customerNames } = useCustomerOptions()

const statusTone = {
  已开票: 'tag-success',
  待开票: 'tag-warning',
  已驳回: 'tag-danger',
  已红冲: 'tag-gray'
}

const tabs = computed(() => {
  const c = (s) => rows.value.filter((r) => (s === '' ? true : r.status === s)).length
  return [
    { label: '全部', value: '', count: rows.value.length },
    { label: '待开票', value: '待开票', count: c('待开票') },
    { label: '已开票', value: '已开票', count: c('已开票') },
    { label: '已驳回', value: '已驳回', count: c('已驳回') },
    { label: '已红冲', value: '已红冲', count: c('已红冲') }
  ]
})

const columns = [
  { key: 'id', label: '发票单号', width: '158px' },
  { key: 'customer', label: '客户' },
  { key: 'amount', label: '价税合计', width: '128px', align: 'right' },
  { key: 'settled', label: '已核销', width: '112px', align: 'right' },
  { key: 'no', label: '发票号码', width: '140px' },
  { key: 'issueDate', label: '开票日期', width: '104px' },
  { key: 'status', label: '状态', width: '92px' },
  { key: 'ops', label: '操作', align: 'right', width: '124px' }
]

const filtered = computed(() =>
  rows.value.filter((r) => {
    if (status.value && r.status !== status.value) return false
    if (type.value && r.type !== type.value) return false
    if (keyword.value) {
      const k = keyword.value.trim()
      if (![r.id, r.customer, r.no, r.statementId].join(' ').includes(k)) return false
    }
    return true
  })
)

/* 后端列表给的是 settledAmount，演示数据按收款核销明细反算 */
const settledOf = (r) => {
  if (r.settledAmount != null) return Number(r.settledAmount)
  if (r.settled != null) return Number(r.settled)
  return invoiceSettled(r.id)
}
const wan = (n) => (n / 10000).toFixed(1)

const issued = computed(() => filtered.value.filter((r) => r.status === '已开票').reduce((s, r) => s + r.amount, 0))
const waiting = computed(() => filtered.value.filter((r) => r.status === '待开票').reduce((s, r) => s + r.amount, 0))
const taxTotal = computed(() => filtered.value.filter((r) => r.status === '已开票').reduce((s, r) => s + invoiceTax(r), 0))
const unsettled = computed(() =>
  filtered.value.filter((r) => r.status === '已开票').reduce((s, r) => s + (r.amount - settledOf(r)), 0)
)

async function issue(row) {
  /* 真实开票要回填税控发票号，演示里按号段模拟一个 */
  const no = `04412026 ${Math.floor(3390 + Math.random() * 60)}`
  const r = await attempt({
    label: 'POST /invoices/{id}/issue',
    call: () => orderApi.issueInvoice(row.dbId, { no }),
    demoNote: '开票接口未就绪，已在本地演示'
  })
  row.status = '已开票'
  row.no = r.mode === 'live' ? (r.data?.no || no) : no
  row.issueDate = r.mode === 'live' ? (r.data?.issueDate || todayStr()) : todayStr()
  toast(r.mode === 'live' ? `「${row.id}」开票成功` : `「${row.id}」开票成功（${r.note}）`)
}

function resubmit(row) {
  row.status = '待开票'
  toast(`「${row.id}」已重新提交，等待开票`)
}

async function redFlush(row) {
  if (settledOf(row) > 0) return toast('该发票已有核销，需先反核销', 'error')
  const r = await attempt({
    label: 'POST /invoices/{id}/red-flush',
    call: () => orderApi.redFlushInvoice(row.dbId, { reason: '客户要求重开' }),
    demoNote: '红冲接口未就绪，已在本地演示'
  })
  row.status = '已红冲'
  toast(`「${row.id}」已红冲，原票号 ${row.no}${r.mode === 'live' ? '' : `（${r.note}）`}`)
}

/* ---------------- 申请开票 ---------------- */
const issueOpen = ref(false)
const form = reactive({ customer: '', statementId: '', type: '增值税专用', amount: 0 })

const invoiceable = computed(() =>
  statements.value.filter((s) => s.customer === form.customer && ['已确认', '已开票'].includes(s.status))
)

const previewTax = computed(() => Math.round((form.amount * 0.13) / 1.13))

function openIssue() {
  form.customer = ''
  form.statementId = ''
  form.type = '增值税专用'
  form.amount = 0
  issueOpen.value = true
}

async function submitIssue() {
  if (!form.customer) return toast('请选择客户', 'error')
  if (!form.statementId) return toast('请选择对账单', 'error')
  if (!form.amount || form.amount <= 0) return toast('请输入开票金额', 'error')

  /* 走接口时需要的是对账单数字主键，表单里存的是单号 */
  const st = statements.value.find((x) => x.id === form.statementId)
  if (st?.dbId) {
    const r = await attempt({
      label: 'POST /invoices',
      call: () => orderApi.createInvoice({
        statementId: st.dbId, customerId: st.customerId || null,
        amount: form.amount, taxRate: 0.13, type: form.type
      }),
      demoNote: '开票申请接口未就绪，已在本地演示'
    })
    if (r.mode === 'live' && r.data) {
      rows.value.unshift({
        id: r.data.code, dbId: r.data.id, no: '', customer: form.customer,
        contractId: '', statementId: form.statementId, amount: Number(r.data.amount || form.amount),
        taxRate: 0.13, type: form.type, applyDate: todayStr(),
        issueDate: '', status: r.data.status || '待开票'
      })
      issueOpen.value = false
      toast(`开票申请已提交 ${r.data.code}，价税合计 ¥${Number(r.data.amount || form.amount).toLocaleString()}`)
      return
    }
  }

  rows.value.unshift({
    id: `FP-2026-${String(323 + rows.value.length).padStart(4, '0')}`,
    no: '',
    customer: form.customer,
    contractId: '',
    statementId: form.statementId,
    amount: form.amount,
    taxRate: 0.13,
    type: form.type,
    applyDate: todayStr(),
    issueDate: '',
    status: '待开票'
  })
  issueOpen.value = false
  toast(`开票申请已提交，价税合计 ¥${form.amount.toLocaleString()}`)
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
.kpi b.ok {
  color: var(--success);
}
.kpi b.warn {
  color: var(--warning);
}
.kpi b.danger {
  color: var(--danger);
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

.text-ok {
  color: var(--success);
}
.faint {
  color: var(--faint);
}
.ops {
  justify-content: flex-end;
}
.money-input {
  position: relative;
  display: flex;
  align-items: center;
}
.money-input span {
  position: absolute;
  left: 12px;
  color: var(--faint);
  font-size: 14px;
}
.money-input .input {
  padding-left: 26px;
  font-variant-numeric: tabular-nums;
  font-size: 15px;
  font-weight: 550;
}
.tip-warn {
  margin-top: 12px;
  padding: 9px 12px;
  border-radius: 8px;
  background: #fdf6e8;
  border: 1px solid #f3e0b5;
  font-size: 12px;
  color: #8a5a00;
}

@media (max-width: 900px) {
  .summary {
    grid-template-columns: 1fr 1fr;
  }
}
</style>
