<template>
  <div class="page">
    <PageHead title="回款" desc="银行到账登记与核销。一笔到账可冲抵多张发票，未核销的余额需财务认领">
      <SourceTag :mode="sourceState.receipts" hint="收款单列表接口未返回数据，当前展示演示收款" />
      <button class="btn" type="button" @click="toast('已导出收款单（演示）')">
        <AppIcon name="download" :size="14" />导出
      </button>
      <button v-can="'payment.create'" class="btn btn-primary" type="button" @click="openCreate">
        <AppIcon name="plus" :size="14" />登记收款
      </button>
    </PageHead>

    <div class="summary">
      <div class="kpi card">
        <span>累计到账</span>
        <b class="ok">¥{{ totalReceived.toLocaleString() }}</b>
        <em>{{ receivedCount }} 笔</em>
      </div>
      <div class="kpi card">
        <span>已核销</span>
        <b>¥{{ totalAllocated.toLocaleString() }}</b>
        <em>已认领到具体单据</em>
      </div>
      <div class="kpi card">
        <span>未核销</span>
        <b class="warn">¥{{ totalOpen.toLocaleString() }}</b>
        <em>钱到了但还没认领</em>
      </div>
      <div class="kpi card">
        <span>应收余额</span>
        <b class="danger">¥{{ receivable.toLocaleString() }}</b>
        <em>已开票未收回</em>
      </div>
    </div>

    <div class="card">
      <div class="tabs">
        <button
          v-for="t in tabs"
          :key="t.value"
          class="tab"
          :class="{ active: filter === t.value }"
          type="button"
          @click="filter = t.value"
        >
          {{ t.label }}<span class="tab-count">{{ t.count }}</span>
        </button>
      </div>

      <div class="toolbar">
        <div class="search">
          <AppIcon name="search" :size="15" />
          <input v-model="keyword" class="input" type="text" placeholder="搜索收款单号 / 客户 / 银行" />
        </div>
        <select v-model="method" class="select">
          <option value="">全部方式</option>
          <option>银行转账</option>
          <option>银行承兑</option>
          <option>对公转账</option>
          <option>现金</option>
        </select>
        <div class="spacer" />
        <span class="faint hint">未核销余额超过 7 天未认领会自动提醒财务</span>
      </div>

      <AppTable :columns="columns" :rows="filtered" :page-size="8">
        <template #cell-id="{ row }">
          <div class="cell-main mono">{{ row.id }}</div>
          <div class="cell-sub">{{ row.bank }}</div>
        </template>
        <template #cell-amount="{ row }">
          <span class="num">¥{{ row.amount.toLocaleString() }}</span>
        </template>
        <template #cell-allocated="{ row }">
          <span class="num">{{ allocatedOf(row) ? '¥' + allocatedOf(row).toLocaleString() : '—' }}</span>
          <div v-if="row.allocations.length" class="cell-sub">{{ row.allocations.length }} 张单据</div>
        </template>
        <template #cell-open="{ row }">
          <span :class="openOf(row) > 0 ? 'text-warn num' : 'faint'">
            {{ openOf(row) > 0 ? '¥' + openOf(row).toLocaleString() : '已核清' }}
          </span>
        </template>
        <template #cell-status="{ row }">
          <span class="tag" :class="statusTone(statusOf(row))">{{ statusOf(row) }}</span>
        </template>
        <template #cell-ops="{ row }">
          <div class="row-tight ops">
            <button
              v-if="openOf(row) > 0"
              v-can="'payment.confirm'"
              class="btn-text"
              type="button"
              @click="openAllocate(row)"
            >
              核销
            </button>
            <button class="btn-text" type="button" @click="openAllocate(row)">明细</button>
          </div>
        </template>
      </AppTable>
    </div>

    <!-- 登记收款 -->
    <ModalDialog v-model="createOpen" title="登记收款" desc="录入银行到账，核销留给财务在明细里处理" ok-text="确认登记" @confirm="submitCreate">
      <div class="form-grid">
        <div class="field span-2">
          <label class="label">客户<span class="req">*</span></label>
          <select v-model="form.customer" class="select">
            <option value="">请选择客户</option>
            <option v-for="c in customerNames" :key="c">{{ c }}</option>
          </select>
        </div>
        <div class="field">
          <label class="label">到账金额<span class="req">*</span></label>
          <div class="money-input">
            <span>¥</span>
            <input v-model.number="form.amount" class="input" type="number" min="0" />
          </div>
        </div>
        <div class="field">
          <label class="label">到账日期</label>
          <input v-model="form.payDate" class="input" type="date" />
        </div>
        <div class="field">
          <label class="label">收款方式</label>
          <select v-model="form.method" class="select">
            <option>银行转账</option>
            <option>银行承兑</option>
            <option>对公转账</option>
            <option>现金</option>
          </select>
        </div>
        <div class="field">
          <label class="label">开户行</label>
          <input v-model="form.bank" class="input" type="text" placeholder="如：招商银行杭州分行" />
        </div>
        <div class="field span-2">
          <label class="label">备注</label>
          <input v-model="form.remark" class="input" type="text" placeholder="如：11 月集采预付" />
        </div>
      </div>
    </ModalDialog>

    <!-- 核销 -->
    <ModalDialog
      v-model="allocOpen"
      width="wide"
      :title="allocRow.id ? `核销 · ${allocRow.id}` : '核销明细'"
      :desc="allocRow.id ? `${allocRow.customer} · 到账 ¥${allocRow.amount.toLocaleString()} · 未核销 ¥${openOf(allocRow).toLocaleString()}` : ''"
      :ok-text="allocRow.id && openOf(allocRow) > 0 ? '确认核销' : '关闭'"
      @confirm="submitAllocate"
    >
      <div v-if="allocRow.id" class="alloc">
        <div class="alloc-top">
          <div class="at"><span>到账金额</span><b>¥{{ allocRow.amount.toLocaleString() }}</b></div>
          <div class="at"><span>已核销</span><b>¥{{ allocatedOf(allocRow).toLocaleString() }}</b></div>
          <div class="at"><span>本次核销</span><b class="text-brand">¥{{ draftTotal.toLocaleString() }}</b></div>
          <div class="at"><span>剩余未核销</span><b :class="leftAfter < 0 ? 'text-danger' : ''">¥{{ leftAfter.toLocaleString() }}</b></div>
        </div>

        <div class="d-title">可核销单据</div>
        <table class="mini">
          <thead>
            <tr>
              <th>单据</th>
              <th>客户</th>
              <th class="r">金额</th>
              <th class="r">已核销</th>
              <th class="r">待收</th>
              <th class="r w-in">本次核销</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="t in allocTargets" :key="t.key">
              <td>{{ t.code }}<div class="cell-sub">{{ t.type }}</div></td>
              <td class="ellip">{{ t.customer }}</td>
              <td class="r">¥{{ t.amount.toLocaleString() }}</td>
              <td class="r">¥{{ (t.amount - t.available).toLocaleString() }}</td>
              <td class="r">¥{{ t.available.toLocaleString() }}</td>
              <td class="r">
                <input
                  v-model.number="draft[t.key]"
                  class="input w-in"
                  :class="{ over: Number(draft[t.key]) > capOf(t) }"
                  type="number"
                  min="0"
                  :max="capOf(t)"
                  :title="`本行最多可核 ¥${capOf(t).toLocaleString()}`"
                  placeholder="0"
                  @keydown.enter.prevent="submitAllocate"
                />
              </td>
            </tr>
            <tr v-if="!allocTargets.length">
              <td colspan="6" class="empty-line">
                该客户还没有「已开票」且还有待收的发票。这笔钱先挂在本笔到账上（状态：待核销），
                等发票开出来再回来核。先收款后开票的，请在合同详情登记预收，不要在这里核。
              </td>
            </tr>
          </tbody>
        </table>

        <!-- 口径写在弹窗里，省得财务问「核销到底动了什么」 -->
        <p class="alloc-note">
          <b>核销只认发票</b>：把这笔到账指到具体发票上，消掉那张发票的待收。一笔到账可拆给多张发票，
          每行最多核到「待收」金额；核不完的留在到账里（待核销／部分核销），之后可再核或做退款。
          合同不参与核销——合同回款进度在合同详情登记，避免同一笔钱在合同和发票上各算一次。
        </p>

        <div v-if="alreadyAllocated" class="already">
          <div class="d-title">
            已核销记录
            <em class="d-hint">核错了可以反核销，钱会退回这笔到账</em>
          </div>
          <div v-for="a in allocRow.allocations" :key="a.id ?? a.targetId" class="al-row">
            <span class="al-main">
              <i class="al-tag" :class="a.type === '发票' ? 'tag-inv' : 'tag-other'">{{ a.type }}</i>
              {{ a.targetId }}
              <em v-if="a.at" class="al-date">{{ String(a.at).slice(0, 10) }}</em>
            </span>
            <b>¥{{ a.amount.toLocaleString() }}</b>
            <button
              v-if="a.id" v-can="'payment.revoke'"
              class="btn-text al-revoke"
              type="button"
              :disabled="revokeBusy"
              @click="startRevoke(a)"
            >
              反核销
            </button>
          </div>

          <!-- 反核销就地填理由，不再叠一层弹窗 -->
          <div v-if="revoking" class="revoke-box">
            <div class="rv-head">
              反核销「{{ revokeTarget?.targetId }}」¥{{ (revokeTarget?.amount || 0).toLocaleString() }}
              <em>· 反核销后这笔钱回到「待核销」，发票待收恢复</em>
            </div>
            <div class="rv-body">
              <input
                v-model="revokeReason"
                class="input"
                type="text"
                placeholder="理由（必填，例如：核错单据 / 客户退回 / 金额填错）"
                @keydown.enter.prevent="submitRevoke"
              />
              <button class="btn-text" type="button" :disabled="revokeBusy" @click="cancelRevoke">取消</button>
              <button class="btn btn-danger btn-sm" type="button" :disabled="revokeBusy" @click="submitRevoke">
                {{ revokeBusy ? '处理中…' : '确认反核销' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </ModalDialog>
  </div>
</template>

<script setup>
import { requestId as newRequestId } from '@/utils/requestId'
import { computed, reactive, ref } from 'vue'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import { toast } from '@/composables/useToast'
import SourceTag from '@/components/SourceTag.vue'
import { orderApi } from '@/api/orders'
import { loadReceipts, loadInvoices, attempt, sourceState } from '@/api/orderSource'
import { useCustomerOptions } from '@/composables/useCustomerOptions'
import {
  receipts as seed, invoices as demoInvoices, receiptAllocated, invoiceSettled
} from '@/data/orderCenter'
import { todayStr } from '@/utils/date'

const rows = ref(seed.map((r) => ({ ...r, allocations: [...r.allocations] })))

/* 可核销发票也从接口取：核销弹窗要列本客户已开票且还有待收金额的票 */
const invoices = ref(demoInvoices)
loadInvoices()
  .then((live) => { if (live) invoices.value = live })
  .catch((e) => toast(e.message, 'error'))

loadReceipts()
  .then((live) => { if (live) rows.value = live.map((r) => ({ ...r, allocations: [...r.allocations] })) })
  .catch((e) => toast(e.message, 'error'))

/* 后端给了已核销额就用后端的，没有就按核销明细加总（演示数据） */
const invoiceSettledOf = (i) => (i.settled == null ? invoiceSettled(i.id) : i.settled)
const keyword = ref('')
const method = ref('')
const filter = ref('')

/* 客户下拉走真实客户库；登记收款要传 customerId，演示客户没有 id 才走本地演示 */
const { names: customerNames, idOf: customerIdOf } = useCustomerOptions()

/* 后端列表给的是 allocatedAmount；演示数据才按 allocations 明细加总 */
const allocatedOf = (r) => {
  if (r.allocatedAmount != null) return Number(r.allocatedAmount)
  if (r.allocated != null) return Number(r.allocated)
  return receiptAllocated(r)
}
/* 未核销 = 到账 − 已核销。真接口不回核销明细，别再走 receiptOpen（那只认演示数据） */
const openOf = (r) => Math.round(Math.max(0, Number(r.amount) - allocatedOf(r)) * 100) / 100
const statusOf = (r) => {
  const open = openOf(r)
  if (open <= 0) return '已核销'
  if (allocatedOf(r) > 0) return '部分核销'
  return '待核销'
}
const statusTone = (s) => ({ 待核销: 'tag-warning', 部分核销: 'tag-brand', 已核销: 'tag-success' }[s] || 'tag-gray')

const tabs = computed(() => {
  const c = (v) => rows.value.filter((r) => (v === '' ? true : statusOf(r) === v)).length
  return [
    { label: '全部', value: '', count: rows.value.length },
    { label: '待核销', value: '待核销', count: c('待核销') },
    { label: '部分核销', value: '部分核销', count: c('部分核销') },
    { label: '已核销', value: '已核销', count: c('已核销') }
  ]
})

const columns = [
  { key: 'id', label: '收款单号', width: '172px' },
  { key: 'customer', label: '客户' },
  { key: 'amount', label: '到账金额', width: '126px', align: 'right' },
  { key: 'allocated', label: '已核销', width: '126px', align: 'right' },
  { key: 'open', label: '未核销', width: '122px', align: 'right' },
  { key: 'payDate', label: '到账日', width: '104px' },
  { key: 'method', label: '方式', width: '96px' },
  { key: 'status', label: '状态', width: '94px' },
  { key: 'ops', label: '操作', align: 'right', width: '96px' }
]

/* 关键字与方式是真筛选，四个汇总卡跟着变；
   状态 tab 只是「看哪一批」，不该让「本期到账」跟着跳，所以 KPI 不算 status */
const scopedRows = computed(() =>
  rows.value.filter((r) => {
    if (method.value && r.method !== method.value) return false
    if (keyword.value) {
      const k = keyword.value.trim()
      if (![r.id, r.customer, r.bank].join(' ').includes(k)) return false
    }
    return true
  })
)

const filtered = computed(() =>
  scopedRows.value.filter((r) => !filter.value || statusOf(r) === filter.value)
)

const totalReceived = computed(() => scopedRows.value.reduce((s, r) => s + Number(r.amount), 0))
const totalAllocated = computed(() => scopedRows.value.reduce((s, r) => s + allocatedOf(r), 0))
const totalOpen = computed(() => scopedRows.value.reduce((s, r) => s + openOf(r), 0))
const receivedCount = computed(() => scopedRows.value.length)
const receivable = computed(() =>
  Math.round(
    invoices.value.reduce((s, i) => s + (i.status === '已开票' ? i.amount - invoiceSettledOf(i) : 0), 0)
  )
)

/* ---------------- 登记收款 ---------------- */
const createOpen = ref(false)
const form = reactive({ customer: '', amount: 0, payDate: '', method: '银行转账', bank: '', remark: '' })

function openCreate() {
  form.customer = ''
  form.amount = 0
  form.payDate = todayStr()
  form.method = '银行转账'
  form.bank = ''
  form.remark = ''
  createOpen.value = true
}

async function submitCreate() {
  if (!form.customer) return toast('请选择客户', 'error')
  if (!form.amount || form.amount <= 0) return toast('请输入有效的到账金额', 'error')

  const cid = customerIdOf(form.customer)
  if (cid) {
    const r = await attempt({
      label: 'POST /receipts',
      call: () => orderApi.createReceipt({
        customerId: cid, amount: form.amount, payDate: form.payDate,
        method: form.method, bank: form.bank, remark: form.remark
      }),
      demoNote: '登记收款接口未就绪，已在本地演示'
    })
    if (r.mode === 'live' && r.data) {
      rows.value.unshift({
        id: r.data.code, dbId: r.data.id, customer: form.customer,
        amount: Number(r.data.amount || form.amount), payDate: form.payDate,
        method: form.method, bank: form.bank || '—', remark: form.remark,
        status: '待核销', allocations: [], allocated: 0
      })
      createOpen.value = false
      toast(`已登记收款 ${r.data.code} ¥${Number(r.data.amount || form.amount).toLocaleString()}，待核销`)
      return
    }
  }

  rows.value.unshift({
    id: `SK-2026-${String(232 + rows.value.length).padStart(4, '0')}`,
    customer: form.customer,
    amount: form.amount,
    payDate: form.payDate,
    method: form.method,
    bank: form.bank || '—',
    remark: form.remark,
    allocations: []
  })
  createOpen.value = false
  toast(`已登记收款 ¥${Number(form.amount).toLocaleString()}，待核销`)
}

/* ---------------- 核销 ---------------- */
const allocOpen = ref(false)
const allocRow = ref({ allocations: [] })
const draft = reactive({})
let allocationRequest = null

/* 可核销目标：只认发票（口径 2026-11-16 定）。
   后端还会返回 availableContracts，那是留给「预收登记」用的，这里不用——
   同一笔钱既核合同又核发票会在 crm_receipt_allocations 里记两次，账永远对不平。 */
const allocTargets = ref([])

const alreadyAllocated = computed(() => (allocRow.value.allocations || []).length > 0)

/* 反核销：就地填理由，调 POST /receipts/{id}/revoke-allocation（后端软删除 + 理由落库） */
const revoking = ref(null)
const revokeReason = ref('')
const revokeBusy = ref(false)
const revokeTarget = computed(() => allocRow.value.allocations.find((a) => a.id === revoking.value) || null)

/* 单行输入的硬上限：该单据待收 与 本笔到账未核销 取小。
   多行合起来超了还有一道提交校验，这里只管住「一行就填爆」这种明显错。 */
const capOf = (t) => Math.round(Math.min(t.available, Math.max(0, openOf(allocRow.value))) * 100) / 100

const draftTotal = computed(() =>
  Object.values(draft).reduce((s, v) => s + (Number(v) || 0), 0)
)
const leftAfter = computed(() => Math.round((openOf(allocRow.value) - draftTotal.value) * 100) / 100)

/* 后端 /receipts/{id} 的核销记录 → 本地结构（id 给反核销用，target 是单号） */
const mapAllocation = (a) => ({
  id: a.id,
  type: a.targetType === 'contract' ? '合同' : a.targetType === 'invoice' ? '发票' : '订单',
  targetType: a.targetType,
  targetId: a.target,
  amount: Number(a.amount),
  at: a.at
})

async function openAllocate(row) {
  allocationRequest = null
  allocTargets.value = []
  if (row.dbId) {
    try {
      const data = await orderApi.receiptDetail(row.dbId)
      /* 只列已开票且待收 > 0 的发票。合肥皖通这种「签了年框还没开票」的客户，
         弹窗会是空的——这是对的：没开票就没有可核对象，钱先挂着。 */
      allocTargets.value = (data.availableInvoices || []).map((i) => {
        const amount = Number(i.amount)
        return {
          key: `invoice:${i.id}`,
          type: '发票',
          targetType: 'invoice',
          dbId: i.id,
          code: i.code,
          customer: row.customer,
          amount,
          available: Number(i.available)
        }
      })
      /* id 是反核销要用的，at 是核销时间，都别丢 */
      row.allocations = (data.allocations || []).map(mapAllocation)
    } catch (e) { return toast(e.message, 'error') }
  }
  allocRow.value = row
  Object.keys(draft).forEach((k) => delete draft[k])
  revoking.value = null
  revokeReason.value = ''
  allocOpen.value = true
}

function startRevoke(a) {
  revoking.value = a.id
  revokeReason.value = ''
}
function cancelRevoke() {
  revoking.value = null
  revokeReason.value = ''
}

async function submitRevoke() {
  const a = revokeTarget.value
  if (!a) return
  const reason = revokeReason.value.trim()
  if (reason.length < 2) return toast('请填写反核销理由（至少 2 个字）', 'error')
  if (!allocRow.value.dbId) return toast('当前是演示数据，无法反核销', 'error')

  revokeBusy.value = true
  try {
    await orderApi.revokeAllocation(allocRow.value.dbId, { allocationId: a.id, reason })
  } catch (e) {
    /* 失败什么都不改：这条核销记录还在 */
    revokeBusy.value = false
    return toast(e.message || '反核销失败，请重试', 'error')
  }

  allocRow.value.allocations = allocRow.value.allocations.filter((x) => x.id !== a.id)
  /* 本笔已核销额要回退，否则「剩余未核销」还是 0，等于没退 */
  const next = Math.max(0, Math.round((allocatedOf(allocRow.value) - a.amount) * 100) / 100)
  allocRow.value.allocatedAmount = next
  allocRow.value.allocated = next
  revokeBusy.value = false
  cancelRevoke()
  toast(`已反核销「${a.targetId}」¥${a.amount.toLocaleString()}，这笔钱回到待核销`)
}

async function submitAllocate() {
  if (!allocRow.value.id || openOf(allocRow.value) <= 0) {
    allocOpen.value = false
    return
  }
  if (draftTotal.value <= 0) {
    toast('请输入要核销的金额', 'error')
    return
  }
  if (leftAfter.value < 0) {
    toast(`合计核销金额超过本笔到账，最多 ${openOf(allocRow.value).toLocaleString()}`, 'error')
    return
  }
  const batch = []
  for (const [key, v] of Object.entries(draft)) {
    const amt = Number(v) || 0
    if (amt <= 0) continue
    const t = allocTargets.value.find((x) => x.key === key)
    if (!t) continue
    /* 上限按行校验，别等后端 400 再告诉用户哪一行错了 */
    if (amt > t.available) {
      return toast(`「${t.code}」本次核销 ¥${amt.toLocaleString()} 超过待收 ¥${t.available.toLocaleString()}`, 'error')
    }
    batch.push({ t, amount: Math.round(amt * 100) / 100 })
  }

  /* 先把「核完还剩多少」定住：下面回写 allocatedAmount 后 leftAfter 会变成 0−本次 的负数 */
  const remaining = leftAfter.value
  const submitted = draftTotal.value
  const allocations = batch.map(({ t, amount }) => ({ targetType: t.targetType, targetId: t.dbId, amount }))
  const payload = JSON.stringify(allocations)
  if (allocationRequest?.payload !== payload) {
    allocationRequest = { payload, id: newRequestId() }
  }

  /* 后端核销是一批一次性提交：任一条超限整批回滚，避免只核一半 */
  let r
  try {
    r = await attempt({
      label: 'POST /receipts/{id}/allocate',
      call: () => orderApi.allocate(allocRow.value.dbId, {
        requestId: allocationRequest.id, allocations
      }),
      demoNote: '核销接口未就绪，已在本地演示'
    })
  } catch (e) {
    /* 失败不改本地任何状态：这笔到账仍然是「待核销」 */
    return toast(e.message || '核销失败，请重试', 'error')
  }

  if (r.mode === 'live') {
    /* 核销接口只回 204，不带新记录 id。重拉一次明细，把 id 拿到——
       否则刚核完的这条没有反核销按钮，看着像不能反。顺带让已核销额与库一致。 */
    try {
      const d = await orderApi.receiptDetail(allocRow.value.dbId)
      allocRow.value.allocations = (d.allocations || []).map(mapAllocation)
      const next = allocRow.value.allocations.reduce((s, x) => s + x.amount, 0)
      allocRow.value.allocatedAmount = Math.round(next * 100) / 100
      allocRow.value.allocated = allocRow.value.allocatedAmount
    } catch {
      /* 重拉失败不影响「已核销」这个结论，本地先记一笔，下次打开会校准 */
      for (const b of batch) {
        allocRow.value.allocations.push({ type: b.t.type, targetId: b.t.code, amount: b.amount })
      }
      const next = Math.round((allocatedOf(allocRow.value) + submitted) * 100) / 100
      allocRow.value.allocatedAmount = next
      allocRow.value.allocated = next
    }
  }
  allocOpen.value = false
  toast(`已核销 ¥${submitted.toLocaleString()}，剩余 ¥${remaining.toLocaleString()}${r.mode === 'live' ? '' : `（${r.note}）`}`)
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

.mono {
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.2px;
}
.text-warn {
  color: var(--warning);
}
.text-danger {
  color: var(--danger);
}
.text-brand {
  color: var(--brand) !important;
}
.ops {
  justify-content: flex-end;
}
.hint {
  font-size: 12px;
}
.ellip {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
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

/* 核销 */
.alloc {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.alloc-top {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
  padding: 12px 14px;
  background: #fafbfc;
  border-radius: 10px;
}
.at {
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.at span {
  font-size: 11.5px;
  color: var(--muted);
}
.at b {
  font-size: 15px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}
.d-title {
  font-size: 12.5px;
  font-weight: 600;
  color: var(--ink);
  margin-bottom: 8px;
  display: flex;
  align-items: baseline;
  gap: 8px;
}
.d-hint {
  font-style: normal;
  font-weight: 400;
  font-size: 11px;
  color: var(--faint);
}
.mini {
  width: 100%;
  border-collapse: collapse;
  font-size: 12.5px;
  border: 1px solid var(--line);
  border-radius: 8px;
  overflow: hidden;
}
.mini th {
  text-align: left;
  font-weight: 500;
  color: var(--muted);
  background: #fafbfc;
  padding: 8px 10px;
  border-bottom: 1px solid var(--line);
  white-space: nowrap;
}
.mini td {
  padding: 7px 10px;
  border-bottom: 1px solid #f2f4f7;
  vertical-align: middle;
}
.mini tr:last-child td {
  border-bottom: none;
}
.mini .r {
  text-align: right;
  font-variant-numeric: tabular-nums;
}
.mini .w-in {
  width: 108px;
}
.mini .input {
  height: 28px;
  font-size: 12.5px;
  text-align: right;
}
/* 填超了当场标红，别让人点完「确认核销」才看到报错 */
.mini .input.over {
  border-color: var(--danger);
  background: #fff7f7;
}
.empty-line {
  text-align: center;
  color: var(--faint);
  padding: 16px 0;
}
/* 核销口径说明：灰底小字，别抢表格的注意力 */
.alloc-note {
  margin: 14px 0 0;
  padding: 9px 12px;
  border-radius: 8px;
  background: #f6f8fa;
  font-size: 11.5px;
  line-height: 1.7;
  color: var(--muted);
}
.al-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
  font-size: 12.5px;
  padding: 6px 0;
  border-bottom: 1px dashed var(--line);
  color: var(--muted);
}
.al-row:last-child {
  border-bottom: 0;
}
.al-row b {
  color: var(--ink);
  font-variant-numeric: tabular-nums;
  margin-left: auto;
}
.al-main {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  color: var(--ink);
}
.al-tag {
  font-style: normal;
  font-size: 10.5px;
  line-height: 1;
  padding: 3px 5px;
  border-radius: 4px;
}
.tag-inv {
  color: #1a56c4;
  background: #eaf1ff;
}
.tag-other {
  color: #8a6d1f;
  background: #fdf5e2;
}
.al-date {
  font-style: normal;
  font-size: 11px;
  color: var(--faint);
}
.al-revoke {
  font-size: 12px;
  color: var(--muted);
  flex: none;
}
.al-revoke:hover {
  color: var(--danger);
}
.revoke-box {
  margin-top: 10px;
  padding: 11px 13px;
  border: 1px solid #f0c9c4;
  border-radius: 9px;
  background: #fffafa;
}
.rv-head {
  font-size: 12px;
  color: var(--ink);
  margin-bottom: 9px;
}
.rv-head em {
  font-style: normal;
  color: var(--muted);
}
.rv-body {
  display: flex;
  align-items: center;
  gap: 8px;
}
.rv-body .input {
  flex: 1;
  height: 30px;
  font-size: 12.5px;
}

@media (max-width: 900px) {
  .summary,
  .alloc-top {
    grid-template-columns: 1fr 1fr;
  }
}
</style>
