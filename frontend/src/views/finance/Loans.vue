<template>
  <div class="page">
    <PageHead
      title="借款预支"
      desc="出差前领款、展位垫付、仓库备用金。报销时在报销单里抵扣，审批通过即核销；余额不清会影响下次借款"
    >
      <button class="btn" type="button" @click="toast('已导出借款台账（演示）')">
        <AppIcon name="download" :size="14" />导出
      </button>
      <button v-can="'loan.create'" class="btn btn-primary" type="button" @click="openCreate">
        <AppIcon name="plus" :size="14" />申请借款
      </button>
    </PageHead>

    <div class="summary">
      <div class="kpi card">
        <span>在借总额</span>
        <b>¥{{ totalOpen.toLocaleString() }}</b>
        <em>{{ openCount }} 笔未清</em>
      </div>
      <div class="kpi card">
        <span>待审批</span>
        <b class="warn">{{ pendingList.length }}<i>笔</i></b>
        <em>审批通过才打款</em>
      </div>
      <div class="kpi card">
        <span>本月已核销</span>
        <b class="ok">¥{{ monthCleared.toLocaleString() }}</b>
        <em>由报销单抵扣</em>
      </div>
      <div class="kpi card">
        <span>超期未清</span>
        <b class="danger">{{ overdueList.length }}<i>笔</i></b>
        <em>超应清账日仍未还完</em>
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
          <input v-model="keyword" class="input" type="text" placeholder="搜索单号 / 申请人 / 用途" />
        </div>
        <select v-model="type" class="select">
          <option value="">全部类型</option>
          <option v-for="t in LOAN_TYPES" :key="t">{{ t }}</option>
        </select>
        <div class="spacer" />
        <span class="faint sum">未还合计 ¥{{ totalOpen.toLocaleString() }}</span>
      </div>

      <AppTable
        :columns="columns"
        :rows="filtered"
        :page-size="8"
        empty-text="没有符合条件的借款单，点右上「申请借款」发起一笔"
      >
        <template #cell-id="{ row }">
          <div class="cell-main link" @click="openDetail(row)">{{ row.id }}</div>
          <div class="cell-sub">{{ row.purpose }}</div>
        </template>
        <template #cell-applicant="{ row }">
          <div class="row-tight">
            <UserAvatar :name="row.applicant" size="sm" />
            <div class="who">
              <span>{{ row.applicant }}</span>
              <em>{{ row.dept }}</em>
            </div>
          </div>
        </template>
        <template #cell-type="{ row }">
          <span class="tag tag-gray plain">{{ row.type }}</span>
        </template>
        <template #cell-amount="{ row }">
          <span class="num">¥{{ row.amount.toLocaleString() }}</span>
        </template>
        <template #cell-cleared="{ row }">
          <span class="num faint-num">{{ loanCleared(row) ? `¥${loanCleared(row).toLocaleString()}` : '—' }}</span>
        </template>
        <template #cell-open="{ row }">
          <b v-if="row.status === '已通过'" class="num" :class="{ 'text-danger': loanStatus(row) === '已超期' }">
            ¥{{ loanOpen(row).toLocaleString() }}
          </b>
          <span v-else-if="row.status === '待审批'" class="faint">待打款</span>
          <span v-else class="faint">—</span>
        </template>
        <template #cell-dueDate="{ row }">
          <div class="num">{{ row.dueDate || '—' }}</div>
          <div v-if="loanOpen(row) > 0 && row.dueDate" class="cell-sub" :class="{ late: loanStatus(row) === '已超期' }">
            {{ leftText(row) }}
          </div>
        </template>
        <template #cell-status="{ row }">
          <span class="tag" :class="LOAN_TONE[loanStatus(row)]">{{ loanStatus(row) }}</span>
          <div v-if="row.status === '待审批' && isMine(row)" class="cell-sub">本人申请</div>
        </template>
        <template #cell-ops="{ row }">
          <div class="row-tight ops">
            <template v-if="row.status === '待审批' && canAudit('loan.approve', row)">
              <button class="btn-text" type="button" @click="audit(row, true)">通过</button>
              <button class="btn-text danger" type="button" @click="audit(row, false)">驳回</button>
            </template>
            <button v-else class="btn-text" type="button" @click="openDetail(row)">明细</button>
          </div>
        </template>
      </AppTable>
    </div>

    <!-- 申请借款 -->
    <ModalDialog
      v-model="createOpen"
      title="申请借款"
      desc="差旅预支按行程天数估，备用金按月用量估；借款未清不影响新申请，但会提示审批人"
      ok-text="提交审批"
      @confirm="submitCreate"
    >
      <div class="form-grid">
        <div class="field">
          <label class="label">申请人<span class="req">*</span></label>
          <input class="input" :value="form.applicant" readonly />
        </div>
        <div class="field">
          <label class="label">所属部门<span class="req">*</span></label>
          <input class="input" :value="form.dept" readonly />
        </div>
        <div class="field">
          <label class="label">借款类型</label>
          <select v-model="form.type" class="select">
            <option v-for="t in LOAN_TYPES" :key="t">{{ t }}</option>
          </select>
        </div>
        <div class="field">
          <label class="label">借款金额<span class="req">*</span></label>
          <div class="money-input">
            <span>¥</span>
            <input v-model.number="form.amount" class="input" type="number" min="0" placeholder="0.00" />
          </div>
        </div>
        <div class="field">
          <label class="label">应清账日</label>
          <input v-model="form.dueDate" class="input" type="date" />
        </div>
        <div class="field">
          <label class="label">申请日期</label>
          <input :value="TODAY_STR" class="input" type="text" disabled />
        </div>
        <div class="field span-2">
          <label class="label">用途说明<span class="req">*</span></label>
          <input v-model="form.purpose" class="input" type="text" placeholder="如：宁波甬安汽修厂首单铺货跟车，往返 3 天" />
        </div>
      </div>
      <div v-if="unsettled.length" class="warn-box">
        <AppIcon name="bell" :size="14" />
        <span>
          {{ form.applicant }} 还有 {{ unsettled.length }} 笔未清（合计 ¥{{ unsettledOpen.toLocaleString() }}），
          审批人能看到，报销抵扣后自动减少
        </span>
      </div>
    </ModalDialog>

    <!-- 借款明细 -->
    <ModalDialog
      v-model="detailOpen"
      width="wide"
      :title="detail.id ? `借款明细 · ${detail.id}` : '借款明细'"
      :desc="detail.id ? `${detail.applicant} · ${detail.dept} · ${detail.type}` : ''"
      hide-footer
    >
      <div v-if="detail.id" class="doc">
        <div class="detail-top">
          <div class="dt"><span>借款金额</span><b>¥{{ detail.amount.toLocaleString() }}</b></div>
          <div class="dt"><span>已核销</span><b class="ok">¥{{ loanCleared(detail).toLocaleString() }}</b></div>
          <div class="dt"><span>未还余额</span><b :class="{ 'text-danger': loanOpen(detail) > 0 }">¥{{ loanOpen(detail).toLocaleString() }}</b></div>
          <div class="dt">
            <span>状态</span>
            <b><span class="tag" :class="LOAN_TONE[loanStatus(detail)]">{{ loanStatus(detail) }}</span></b>
          </div>
        </div>

        <div class="d-title">借款信息</div>
        <div class="kv-grid">
          <div class="kv"><span>用途</span><em>{{ detail.purpose }}</em></div>
          <div class="kv"><span>审批人</span><em>{{ detail.approver || '—' }}</em></div>
          <div class="kv"><span>申请日期</span><em>{{ detail.applyDate }}</em></div>
          <div class="kv"><span>打款日期</span><em>{{ detail.payDate || '未打款' }}</em></div>
          <div class="kv"><span>应清账日</span><em>{{ detail.dueDate || '—' }}</em></div>
          <div class="kv"><span>剩余</span><em>{{ leftText(detail) }}</em></div>
        </div>

        <div class="d-title">
          抵扣记录
          <span class="d-hint">每笔来自一张报销单，审批通过后自动生成</span>
        </div>
        <table v-if="detail.writeOffs && detail.writeOffs.length" class="mini">
          <thead>
            <tr>
              <th>来源单据</th>
              <th>抵扣日期</th>
              <th class="r">抵扣金额</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="w in detail.writeOffs" :key="w.docId">
              <td class="mono">{{ w.docId }}</td>
              <td class="faint-num">{{ w.at }}</td>
              <td class="r num">¥{{ w.amount.toLocaleString() }}</td>
            </tr>
          </tbody>
        </table>
        <div v-else class="empty-slim">
          {{ detail.status === '已驳回' ? `驳回原因：${detail.rejectReason || '—'}` : '还没有抵扣记录。报销时在这张单上抵扣，审批通过后会自动出现' }}
        </div>

        <div v-if="loanOpen(detail) > 0 && detail.status === '已通过'" class="warn-box">
          <AppIcon name="bell" :size="14" />
          <span>还剩 ¥{{ loanOpen(detail).toLocaleString() }} 未清，填报销单时选这张借款就能冲掉；确实没花完的部分找财务退回现金。</span>
        </div>
      </div>
    </ModalDialog>
  </div>
</template>

<script setup>
import { requestId as newRequestId } from '@/utils/requestId'
import { computed, onMounted, reactive, ref } from 'vue'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import UserAvatar from '@/components/UserAvatar.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import { session } from '@/store/session'
import { canAudit, isMine } from '@/store/permissions'
import { toast } from '@/composables/useToast'
import {
  loanDaysLeft,
  LOAN_TYPES,
  LOAN_TONE,
  DEPTS,
  STAFF,
  TODAY_STR
} from '@/data/office'

import { officeApi } from '@/api/office'
import { localDate } from '@/utils/date'

const loans = ref([])
const adapt = (row) => ({
  ...row, docId: row.id, id: row.code, project: row.projectName,
  rejectReason: row.reject_reason, deductLoanId: row.deduct_loan_id, deductAmount: Number(row.deduct_amount || 0),
  items: (row.type || '').split(',').filter(Boolean).map((type, index) => ({
    type, amount: index === 0 ? Number(row.totalAmount || 0) : 0, bills: index === 0 ? row.billCount || 0 : 0
  }))
})
let requestId
const saving = ref(false)
async function loadRows() {
  loans.value = (await officeApi.loans({ pageSize: 500 })).rows.map(adapt)
  
}
onMounted(() => loadRows().catch((e) => toast(e.message, 'error')))
const status = ref('')
const keyword = ref('')
const type = ref('')

const columns = [
  { key: 'id', label: '借款单号' },
  { key: 'applicant', label: '申请人', width: '132px' },
  { key: 'type', label: '类型', width: '104px' },
  { key: 'amount', label: '借款金额', width: '108px', align: 'right' },
  { key: 'cleared', label: '已核销', width: '104px', align: 'right' },
  { key: 'open', label: '未还余额', width: '108px', align: 'right' },
  { key: 'dueDate', label: '应清账日', width: '112px' },
  { key: 'status', label: '状态', width: '96px' },
  { key: 'ops', label: '操作', align: 'right', width: '110px' }
]

const loanOpen = (row) => Number(row.openAmount || 0)
const loanCleared = (row) => Number(row.clearedAmount || 0)
const loanStatus = (row) => {
  if (row.status !== '已通过') return row.status
  if (!loanOpen(row)) return '已核销'
  if (row.dueDate && row.dueDate < TODAY_STR) return '已超期'
  return loanCleared(row) ? '部分核销' : '待还'
}
const active = computed(() => loans.value.filter((l) => l.status === '已通过'))
const totalOpen = computed(() => active.value.reduce((s, l) => s + loanOpen(l), 0))
const openCount = computed(() => active.value.filter((l) => loanOpen(l) > 0).length)
const pendingList = computed(() => loans.value.filter((l) => l.status === '待审批'))
const overdueList = computed(() => loans.value.filter((l) => loanStatus(l) === '已超期'))
const monthKey = TODAY_STR.slice(0, 7)
const monthCleared = computed(() =>
  loans.value.reduce(
    (s, l) => s + (l.writeOffs || []).filter((w) => (w.at || '').startsWith(monthKey)).reduce((a, w) => a + w.amount, 0),
    0
  )
)

const tabs = computed(() => [
  { label: '全部', value: '', count: loans.value.length },
  { label: '待审批', value: '待审批', count: pendingList.value.length },
  {
    label: '待还',
    value: '待还',
    count: loans.value.filter((l) => ['待还', '部分核销', '已超期'].includes(loanStatus(l))).length
  },
  { label: '已核销', value: '已核销', count: loans.value.filter((l) => loanStatus(l) === '已核销').length },
  { label: '已驳回', value: '已驳回', count: loans.value.filter((l) => loanStatus(l) === '已驳回').length }
])

const filtered = computed(() =>
  loans.value.filter((l) => {
    const st = loanStatus(l)
    if (status.value === '待还') {
      if (!['待还', '部分核销', '已超期'].includes(st)) return false
    } else if (status.value && st !== status.value) return false
    if (type.value && l.type !== type.value) return false
    if (keyword.value) {
      const k = keyword.value.trim()
      if (![l.id, l.applicant, l.purpose, l.dept].join(' ').includes(k)) return false
    }
    return true
  })
)

function leftText(l) {
  if (l.status === '待审批') return '待打款'
  if (l.status === '已驳回') return '—'
  if (loanOpen(l) <= 0) return '已清账'
  if (!l.dueDate) return '—'
  const d = loanDaysLeft(l)
  if (d === null) return '—'
  if (d < 0) return `已超期 ${-d} 天`
  if (d === 0) return '今天到期'
  return `还剩 ${d} 天`
}

/* ------------------------------ 申请借款 ------------------------------ */
const createOpen = ref(false)
const form = reactive({ applicant: '宋江', dept: DEPTS[0], type: LOAN_TYPES[0], amount: null, dueDate: '', purpose: '' })

const unsettled = computed(() =>
  loans.value.filter((l) => l.applicant === form.applicant && l.status === '已通过' && loanOpen(l) > 0)
)
const unsettledOpen = computed(() => unsettled.value.reduce((s, l) => s + loanOpen(l), 0))

function openCreate() {
  requestId = newRequestId()
  form.applicant = session.user.name
  form.dept = session.user.dept
  form.type = LOAN_TYPES[0]
  form.amount = null
  const due = new Date()
  due.setDate(due.getDate() + 30)
  form.dueDate = localDate(due) // 本地日期，别用 toISOString（UTC 会退一天）
  form.purpose = ''
  createOpen.value = true
}

async function submitCreate() {
  if (saving.value) return
  saving.value = true
  try {
    const saved = await officeApi.createLoan({ requestId, type: form.type, amount: form.amount, purpose: form.purpose, dueDate: form.dueDate || null })
    createOpen.value = false
    toast(saved.code + ' 已提交')
    await loadRows()
  } catch (e) { toast(e.message, 'error') }
  finally { saving.value = false }
}

/* ------------------------------ 明细与审批 ------------------------------ */
const detailOpen = ref(false)
const detail = ref({})

async function openDetail(row) {
  try {
    const data = await officeApi.loanDetail(row.docId)
    detail.value = { ...adapt(data.loan), writeOffs: data.writeOffs.map((w) => ({ ...w, at: w.created_at })) }
    detailOpen.value = true
  } catch (e) { toast(e.message, 'error') }
}

async function audit(row, pass) {
  try {
    await officeApi.approveLoan(row.docId, { result: pass ? 'pass' : 'reject' })
    await loadRows()
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
  gap: 2px;
}
.kpi span {
  font-size: 12.5px;
  color: var(--muted);
}
.kpi b {
  font-size: 21px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.01em;
}
.kpi b i {
  font-style: normal;
  font-size: 12.5px;
  font-weight: 400;
  color: var(--faint);
  margin-left: 2px;
}
.kpi b.ok {
  color: #1a7f5a;
}
.kpi b.warn {
  color: #b7791f;
}
.kpi b.danger {
  color: #c0392b;
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
.ops {
  justify-content: flex-end;
}
.sum {
  font-size: 12px;
  font-variant-numeric: tabular-nums;
}
.link {
  cursor: pointer;
}
.link:hover {
  color: var(--brand);
}
.who {
  display: flex;
  flex-direction: column;
  line-height: 1.3;
}
.who em {
  font-style: normal;
  font-size: 11px;
  color: var(--faint);
}
.cell-sub.late {
  color: var(--danger);
}
.num {
  font-variant-numeric: tabular-nums;
}
.faint-num {
  color: var(--faint);
  font-variant-numeric: tabular-nums;
}
.text-danger {
  color: var(--danger) !important;
}

.doc {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.d-title {
  display: flex;
  align-items: baseline;
  gap: 8px;
  margin-top: 4px;
  padding-top: 13px;
  border-top: 1px dashed var(--line-soft);
  font-size: 12.5px;
  font-weight: 600;
}
.d-title:first-child {
  margin-top: 0;
  padding-top: 0;
  border-top: none;
}
.d-hint {
  font-weight: 400;
  font-size: 11.5px;
  color: var(--faint);
}
.detail-top {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
  padding: 12px 14px;
  border-radius: 10px;
  background: #f7f9fc;
  border: 1px solid var(--line-soft);
}
.dt {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.dt span {
  font-size: 11.5px;
  color: var(--faint);
}
.dt b {
  font-size: 15px;
  font-variant-numeric: tabular-nums;
}
.kv-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px 20px;
}
.kv {
  display: flex;
  gap: 10px;
  font-size: 12.5px;
}
.kv span {
  flex: none;
  width: 62px;
  color: var(--faint);
}
.kv em {
  font-style: normal;
  color: var(--text);
}
.mini {
  width: 100%;
  border-collapse: collapse;
  font-size: 12.5px;
}
.mini th {
  padding: 8px 10px;
  text-align: left;
  font-weight: 500;
  font-size: 11.5px;
  color: var(--faint);
  background: #fafbfd;
  border-bottom: 1px solid var(--line-soft);
}
.mini td {
  padding: 9px 10px;
  border-bottom: 1px solid var(--line-soft);
}
.mini .r {
  text-align: right;
}
.mono {
  font-family: ui-monospace, Menlo, Consolas, monospace;
  font-size: 12px;
}
.empty-slim {
  padding: 22px 18px 26px;
  text-align: center;
  font-size: 12.5px;
  color: var(--faint);
}
.warn-box {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  padding: 10px 13px;
  border-radius: 9px;
  background: #fff8e8;
  border: 1px solid #f2e2c0;
  color: #8a6a1f;
  font-size: 12px;
  line-height: 1.65;
}
.money-input {
  display: flex;
  align-items: center;
  gap: 4px;
  border: 1px solid var(--line);
  border-radius: 8px;
  padding-left: 10px;
  background: #fff;
}
.money-input span {
  color: var(--faint);
  font-size: 12.5px;
}
.money-input .input {
  border: none;
  padding-left: 0;
  height: 34px;
  background: transparent;
}
.money-input .input:focus {
  box-shadow: none;
}
@media (max-width: 1100px) {
  .summary {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
</style>

