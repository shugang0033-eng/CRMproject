<template>
  <div class="page">
    <PageHead
      title="费用报销"
      desc="跑店差旅、客户招待、展会物料与物流运费，按明细逐条录入、审批通过后计入部门成本；与订单回款无关"
    >
      <button class="btn" type="button" @click="toast('已导出费用记录（演示）')">
        <AppIcon name="download" :size="14" />导出
      </button>
      <button v-can="'expense.create'" class="btn btn-primary" type="button" @click="openCreate">
        <AppIcon name="plus" :size="14" />填写报销单
      </button>
    </PageHead>

    <div class="summary">
      <div class="kpi card">
        <span>本月发生</span>
        <b>¥{{ monthTotal.toLocaleString() }}</b>
        <em>{{ monthCount }} 张报销单</em>
      </div>
      <div class="kpi card">
        <span>待审批</span>
        <b class="warn">¥{{ pendingTotal.toLocaleString() }}</b>
        <em>{{ pendingCount }} 张等主管确认</em>
      </div>
      <div class="kpi card">
        <span>已通过</span>
        <b class="ok">¥{{ approvedTotal.toLocaleString() }}</b>
        <em>{{ approvedBills }} 张票据已归档</em>
      </div>
      <div class="kpi card">
        <span>已驳回</span>
        <b class="danger">¥{{ rejectedTotal.toLocaleString() }}</b>
        <em>缺票据或超标</em>
      </div>
    </div>

    <div class="card">
      <div class="tabs">
        <button
          v-for="tab in tabs"
          :key="tab.value"
          class="tab"
          :class="{ active: status === tab.value }"
          type="button"
          @click="status = tab.value"
        >
          {{ tab.label }}<span class="tab-count">{{ tab.count }}</span>
        </button>
      </div>

      <div class="toolbar">
        <div class="search">
          <AppIcon name="search" :size="15" />
          <input v-model="keyword" class="input" type="text" placeholder="搜索单号 / 申请人 / 说明" />
        </div>
        <select v-model="type" class="select">
          <option value="">全部类型</option>
          <option v-for="t in EXPENSE_TYPES" :key="t">{{ t }}</option>
        </select>
        <div class="spacer" />
        <span class="faint sum">合计 ¥{{ total.toLocaleString() }}</span>
      </div>

      <AppTable
        :columns="columns"
        :rows="filtered"
        :page-size="8"
        empty-text="没有符合条件的报销单，点右上「填写报销单」发起一张"
      >
        <template #cell-id="{ row }">
          <div class="cell-main link" @click="openDetail(row)">{{ row.id }}</div>
          <div class="cell-sub">{{ row.desc }}</div>
        </template>
        <template #cell-type="{ row }">
          <span class="tag tag-gray plain">{{ mainType(row) }}</span>
        </template>
        <template #cell-applicant="{ row }">
          <span class="row-tight">
            <UserAvatar :name="row.applicant" size="sm" />
            <span>{{ row.applicant }}</span>
          </span>
        </template>
        <template #cell-amount="{ row }">
          <span class="num">¥{{ expenseTotal(row).toLocaleString() }}</span>
        </template>
        <template #cell-bills="{ row }">
          <span class="num faint-num">{{ expenseBills(row) }}</span>
        </template>
        <template #cell-status="{ row }">
          <span class="tag" :class="EXPENSE_TONE[row.status]">{{ row.status }}</span>
          <div v-if="row.status === '审批中' && isMine(row)" class="cell-sub">本人提交</div>
        </template>
        <template #cell-ops="{ row }">
          <div class="row-tight ops">
            <template v-if="row.status === '审批中' && canAudit('expense.approve', row)">
              <button class="btn-text" type="button" @click="audit(row, '已通过')">通过</button>
              <button class="btn-text danger" type="button" @click="audit(row, '已驳回')">驳回</button>
            </template>
            <button v-else class="btn-text" type="button" @click="openDetail(row)">明细</button>
          </div>
        </template>
      </AppTable>
    </div>

    <!-- ==================== 填写报销单 ==================== -->
    <ModalDialog
      v-model="createOpen"
      width="wide"
      title="填写报销单"
      desc="费用逐条录入，差旅需填行程；有预支的在这里抵扣，审批通过后才真正核销"
      ok-text="提交审批"
      @confirm="submitCreate"
    >
      <div class="doc">
        <div class="d-title">基础信息</div>
        <div class="form-grid">
          <div class="field">
            <label class="label">报销人<span class="req">*</span></label>
            <input class="input" :value="form.applicant" readonly />
          </div>
          <div class="field">
            <label class="label">承担部门<span class="req">*</span></label>
            <input class="input" :value="form.dept" readonly />
          </div>
          <div class="field">
            <label class="label">关联客户 / 项目</label>
            <input v-model="form.project" class="input" type="text" placeholder="如：上海嘉定安驰 4S 店" />
          </div>
          <div class="field">
            <label class="label">申请日期</label>
            <input v-model="form.applyDate" class="input" type="date" />
          </div>
        </div>

        <div class="d-title">
          费用明细<span class="req">*</span>
          <span class="d-hint">按票据逐条录入，金额由明细汇总，不能手填总数</span>
        </div>
        <div class="line-head">
          <span class="w-date">发生日期</span>
          <span class="w-type">费用类型</span>
          <span class="w-amt">金额</span>
          <span class="w-note">说明</span>
          <span class="w-bill">票据</span>
          <span class="w-del" />
        </div>
        <div v-for="(it, i) in form.items" :key="i" class="line-row">
          <input v-model="it.date" class="input w-date" type="date" />
          <select v-model="it.type" class="select w-type">
            <option v-for="t in EXPENSE_TYPES" :key="t">{{ t }}</option>
          </select>
          <input v-model.number="it.amount" class="input w-amt" type="number" min="0" placeholder="0.00" />
          <input v-model="it.note" class="input w-note" type="text" placeholder="如：杭州东—南京南 高铁往返" />
          <input v-model.number="it.bills" class="input w-bill" type="number" min="0" />
          <button
            class="line-del"
            type="button"
            :title="form.items.length === 1 ? '至少保留一行' : '删除该行'"
            @click="removeLine(i)"
          >
            <AppIcon name="close" :size="13" />
          </button>
        </div>
        <button class="line-add" type="button" @click="addLine">
          <AppIcon name="plus" :size="13" />再加一条费用
        </button>

        <!-- 差旅行程：明细里出现差旅才要求填 -->
        <template v-if="needTrip">
          <div class="d-title">
            差旅行程<span class="req">*</span>
            <span class="d-hint">财务按住宿晚数核对，对不上会退单</span>
          </div>
          <div class="form-grid">
            <div class="field">
              <label class="label">出发地</label>
              <input v-model="form.trip.from" class="input" type="text" placeholder="如：杭州" />
            </div>
            <div class="field">
              <label class="label">到达地</label>
              <input v-model="form.trip.to" class="input" type="text" placeholder="如：南京" />
            </div>
            <div class="field">
              <label class="label">开始日期</label>
              <input v-model="form.trip.start" class="input" type="date" />
            </div>
            <div class="field">
              <label class="label">结束日期</label>
              <input v-model="form.trip.end" class="input" type="date" />
            </div>
            <div class="field span-2">
              <span class="trip-days">
                共 <b>{{ tripDays }}</b> 天
                <em v-if="form.trip.start && form.trip.end && tripDays === 0">
                  结束日期不能早于开始日期
                </em>
              </span>
            </div>
          </div>
        </template>

        <div class="d-title">
          借款抵扣
          <span class="d-hint">有预支的人在这里冲，审批通过后自动核销，不用再单独还钱</span>
        </div>
        <div class="form-grid">
          <div class="field">
            <label class="label">关联借款</label>
            <select v-model="form.deductLoanId" class="select" :disabled="!loanOptions.length">
              <option value="">{{ loanOptions.length ? '不抵扣' : '该员工没有未清借款' }}</option>
              <option v-for="l in loanOptions" :key="l.id" :value="l.id">
                {{ l.id }} · 未还 ¥{{ loanOpen(l).toLocaleString() }} · {{ l.purpose }}
              </option>
            </select>
          </div>
          <div class="field">
            <label class="label">本次抵扣</label>
            <div class="money-input">
              <span>¥</span>
              <input
                v-model.number="form.deductAmount"
                class="input"
                type="number"
                min="0"
                :disabled="!form.deductLoanId"
                :placeholder="deductMax ? `最多 ¥${deductMax.toLocaleString()}` : '0'"
              />
            </div>
          </div>
        </div>

        <div class="d-title">
          票据附件
          <span class="d-hint">发票、行程单、水单，拍照或 PDF 都行</span>
        </div>
        <div class="files">
          <span v-for="(f, i) in form.attachments" :key="f" class="file-chip">
            <AppIcon name="file" :size="12" />{{ f }}
            <button type="button" @click="form.attachments.splice(i, 1)"><AppIcon name="close" :size="11" /></button>
          </span>
          <button class="file-add" type="button" @click="mockUpload">
            <AppIcon name="upload" :size="13" />添加附件
          </button>
        </div>

        <div class="field">
          <label class="label">备注</label>
          <input v-model="form.remark" class="input" type="text" placeholder="选填。有特殊情况写一句，审批人少问一轮" />
        </div>

        <p v-if="payable < 0" class="err-msg">
          抵扣超过了明细合计，多出的是借款没花完的部分，要让财务另做退回，不能在这里冲成负数。
        </p>
        <p v-else-if="overReview" class="hint-line">
          单笔超过 ¥{{ REVIEW_LINE.toLocaleString() }}，提交后会转财务复核。
        </p>
        <!-- 汇总条 -->
        <div class="total-bar">
          <div class="tb-item">
            <span>明细合计</span>
            <b>¥{{ draftTotal.toLocaleString() }}</b>
          </div>
          <div class="tb-item">
            <span>借款抵扣</span>
            <b class="ok">− ¥{{ Number(form.deductAmount || 0).toLocaleString() }}</b>
          </div>
          <div class="tb-item strong">
            <span>公司应补</span>
            <b :class="{ 'text-danger': payable < 0 }">¥{{ payable.toLocaleString() }}</b>
          </div>
          <div class="tb-item">
            <span>票据</span>
            <b>{{ draftBills }} 张</b>
          </div>
        </div>
      </div>
    </ModalDialog>

    <!-- ==================== 报销单详情 ==================== -->
    <ModalDialog
      v-model="detailOpen"
      width="wide"
      title="报销单明细"
      :desc="detail.id ? `${detail.id} · ${detail.applicant} · ${detail.dept}` : ''"
      hide-footer
    >
      <div v-if="detail.id" class="doc">
        <div class="detail-top">
          <div class="dt">
            <span>报销金额</span><b>¥{{ expenseTotal(detail).toLocaleString() }}</b>
          </div>
          <div class="dt"><span>票据</span><b>{{ expenseBills(detail) }} 张</b></div>
          <div class="dt"><span>审批人</span><b>{{ detail.approver || '—' }}</b></div>
          <div class="dt">
            <span>状态</span>
            <b><span class="tag" :class="EXPENSE_TONE[detail.status]">{{ detail.status }}</span></b>
          </div>
        </div>

        <div class="d-title">费用明细</div>
        <table class="mini">
          <thead>
            <tr>
              <th>发生日期</th>
              <th>类型</th>
              <th class="r">金额</th>
              <th>说明</th>
              <th class="r">票据</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(it, i) in detail.items" :key="i">
              <td class="faint-num">{{ it.date }}</td>
              <td><span class="tag tag-gray plain">{{ it.type }}</span></td>
              <td class="r num">¥{{ Number(it.amount).toLocaleString() }}</td>
              <td class="ellip">{{ it.note }}</td>
              <td class="r faint-num">{{ it.bills }}</td>
            </tr>
          </tbody>
        </table>

        <template v-if="detail.trip">
          <div class="d-title">差旅行程</div>
          <div class="trip-box">
            <span>{{ detail.trip.from }}</span>
            <AppIcon name="chevron-right" :size="13" />
            <span>{{ detail.trip.to }}</span>
            <em>{{ detail.trip.start }} 至 {{ detail.trip.end }} · {{ detail.trip.days }} 天</em>
          </div>
        </template>

        <template v-if="detail.deductLoanId">
          <div class="d-title">借款抵扣</div>
          <div class="trip-box">
            <span>{{ detail.deductLoanId }}</span>
            <em>
              抵扣 ¥{{ Number(detail.deductAmount).toLocaleString() }} ·
              {{ detail.status === '已通过' ? '已核销到该借款' : '审批通过后核销' }}
            </em>
          </div>
        </template>

        <template v-if="detail.attachments && detail.attachments.length">
          <div class="d-title">票据附件</div>
          <div class="files">
            <span v-for="f in detail.attachments" :key="f" class="file-chip">
              <AppIcon name="file" :size="12" />{{ f }}
            </span>
          </div>
        </template>

        <p v-if="detail.remark" class="hint-line">备注：{{ detail.remark }}</p>
      </div>
    </ModalDialog>
  </div>
</template>

<script setup>
import { requestId as newRequestId } from '@/utils/requestId'
import { computed, onMounted, reactive, ref, watch } from 'vue'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import UserAvatar from '@/components/UserAvatar.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import { session } from '@/store/session'
import { canAudit, isMine } from '@/store/permissions'
import { toast } from '@/composables/useToast'
import {
  expenseTotal,
  expenseBills,
  openLoansOf,
  loanOpen,
  naturalDays,
  EXPENSE_TYPES,
  EXPENSE_TONE,
  DEPTS,
  STAFF,
  REVIEW_LINE,
  TODAY_STR
} from '@/data/office'

import { officeApi } from '@/api/office'

const expenses = ref([])
const availableLoans = ref([])
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
  expenses.value = (await officeApi.expenses({ pageSize: 500 })).rows.map(adapt)
  
}
onMounted(() => loadRows().catch((e) => toast(e.message, 'error')))
const status = ref('')
const keyword = ref('')
const type = ref('')

const columns = [
  { key: 'id', label: '费用单号' },
  { key: 'type', label: '费用类型', width: '104px' },
  { key: 'applicant', label: '申请人', width: '116px' },
  { key: 'dept', label: '所属部门', width: '116px' },
  { key: 'amount', label: '金额', width: '112px', align: 'right' },
  { key: 'bills', label: '票据', width: '68px', align: 'right' },
  { key: 'applyDate', label: '申请日期', width: '108px' },
  { key: 'status', label: '状态', width: '92px' },
  { key: 'ops', label: '操作', align: 'right', width: '116px' }
]

/** 一张单可能有多种类型，列表上取金额最大的那条代表 */
function mainType(row) {
  const list = row.items || []
  if (!list.length) return '—'
  return [...list].sort((a, b) => Number(b.amount) - Number(a.amount))[0].type
}

const rowsOf = (st) => expenses.value.filter((r) => (st ? r.status === st : true))

const tabs = computed(() => [
  { label: '全部', value: '', count: expenses.value.length },
  { label: '审批中', value: '审批中', count: rowsOf('审批中').length },
  { label: '已通过', value: '已通过', count: rowsOf('已通过').length },
  { label: '已驳回', value: '已驳回', count: rowsOf('已驳回').length }
])

const sumOf = (list) => list.reduce((s, r) => s + expenseTotal(r), 0)
const monthKey = TODAY_STR.slice(0, 7)
const monthRows = computed(() => expenses.value.filter((r) => (r.applyDate || '').startsWith(monthKey)))
const monthTotal = computed(() => sumOf(monthRows.value))
const monthCount = computed(() => monthRows.value.length)
const pendingTotal = computed(() => sumOf(rowsOf('审批中')))
const pendingCount = computed(() => rowsOf('审批中').length)
const approvedTotal = computed(() => sumOf(rowsOf('已通过')))
const approvedBills = computed(() => rowsOf('已通过').reduce((s, r) => s + expenseBills(r), 0))
const rejectedTotal = computed(() => sumOf(rowsOf('已驳回')))

const filtered = computed(() =>
  expenses.value.filter((r) => {
    if (status.value && r.status !== status.value) return false
    if (type.value && !(r.items || []).some((it) => it.type === type.value)) return false
    if (keyword.value) {
      const k = keyword.value.trim()
      const hay = [r.id, r.applicant, r.desc, r.project, ...(r.items || []).map((it) => it.note)].join(' ')
      if (!hay.includes(k)) return false
    }
    return true
  })
)

const total = computed(() => sumOf(filtered.value))

/* ------------------------------ 填写报销单 ------------------------------ */
const createOpen = ref(false)
const form = reactive({
  id: '',
  applicant: '宋江',
  dept: DEPTS[0],
  project: '',
  applyDate: '',
  items: [],
  trip: { from: '', to: '', start: '', end: '' },
  deductLoanId: '',
  deductAmount: 0,
  attachments: [],
  remark: ''
})

const blankLine = () => ({ date: TODAY_STR, type: EXPENSE_TYPES[0], amount: null, note: '', bills: 1 })

function nextExpenseId() {
  const n = expenses.value.reduce((m, r) => Math.max(m, Number(String(r.id).slice(-4)) || 0), 0)
  return `FY-2026-${String(n + 1).padStart(4, '0')}`
}

function openCreate() {
  requestId = newRequestId()
  officeApi.openLoans().then((data) => { availableLoans.value = data })
    .catch((e) => toast(e.message, 'error'))
  form.id = nextExpenseId()
  form.applicant = session.user.name
  form.dept = session.user.dept
  form.project = ''
  form.applyDate = TODAY_STR
  form.items = [blankLine()]
  form.trip = { from: '', to: '', start: '', end: '' }
  form.deductLoanId = ''
  form.deductAmount = 0
  form.attachments = []
  form.remark = ''
  createOpen.value = true
}

function addLine() {
  form.items.push(blankLine())
}
function removeLine(i) {
  if (form.items.length === 1) return toast('至少保留一条费用明细', 'error')
  form.items.splice(i, 1)
}

/** 明细里出现差旅才要求填行程 */
const needTrip = computed(() => form.items.some((it) => it.type === '差旅'))
/* 出差按自然日，周五走周日晚回算 3 天；请假扣额度才用工作日 */
const tripDays = computed(() => naturalDays(form.trip.start, form.trip.end))

const draftTotal = computed(() => form.items.reduce((s, it) => s + Number(it.amount || 0), 0))
const draftBills = computed(() => form.items.reduce((s, it) => s + Number(it.bills || 0), 0))
const loanOptions = computed(() => availableLoans.value)
const deductMax = computed(() => {
  const l = loanOptions.value.find((x) => x.id === form.deductLoanId)
  return l ? Number(l.openAmount) : 0
})
const payable = computed(() => draftTotal.value - Number(form.deductAmount || 0))
const overReview = computed(() => form.items.some((it) => Number(it.amount || 0) > REVIEW_LINE))

/** 选借款时把抵扣额预填成「合计与余额取小」，省得用户自己算 */
watch(
  () => [form.deductLoanId, form.applicant],
  () => {
    if (!form.deductLoanId) {
      form.deductAmount = 0
      return
    }
    form.deductAmount = Math.min(draftTotal.value, deductMax.value)
  }
)

function mockUpload() {
  const names = ['餐饮发票.pdf', '高铁行程单.pdf', '住宿水单.jpg', '滴滴行程截图.png', '展位合同.pdf']
  const pick = names[form.attachments.length % names.length]
  form.attachments.push(pick)
  toast(`已添加附件「${pick}」（演示，未真实上传）`)
}

async function submitCreate() {
  if (saving.value) return
  saving.value = true
  try {
    const saved = await officeApi.createExpense({ requestId, projectName: form.project, applyDate: form.applyDate || null, remark: form.remark,
      items: form.items, trip: needTrip.value ? form.trip : null,
      deduct: form.deductLoanId && form.deductAmount > 0 ? { loanId: form.deductLoanId, amount: form.deductAmount } : null })
    createOpen.value = false
    toast(saved.code + ' 已提交')
    await loadRows()
  } catch (e) { toast(e.message, 'error') }
  finally { saving.value = false }
}

/* ------------------------------ 详情与审批 ------------------------------ */
const detailOpen = ref(false)
const detail = ref({})

async function openDetail(row) {
  try {
    const data = await officeApi.expenseDetail(row.docId)
    detail.value = { ...adapt(data.expense), items: data.items, trip: data.trip, attachments: data.attachments.map((a) => a.name) }
    detailOpen.value = true
  } catch (e) { toast(e.message, 'error') }
}

async function audit(row, result) {
  try {
    await officeApi.approveExpense(row.docId, { result: result === '已通过' ? 'pass' : 'reject' })
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

/* ---------------------------- 报销单表单 ---------------------------- */
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
  color: var(--text);
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
.d-title .req {
  color: var(--danger);
}

/* 明细行：固定列宽 + 说明列自适应，保证多行输入框纵向对齐 */
.line-head,
.line-row {
  display: flex;
  align-items: center;
  gap: 8px;
}
.line-head {
  padding: 0 2px 2px;
  font-size: 11.5px;
  color: var(--faint);
}
.line-row .input,
.line-row .select {
  height: 34px;
  font-size: 12.5px;
}
.w-date {
  width: 132px;
  flex: none;
}
.w-type {
  width: 108px;
  flex: none;
}
.w-amt {
  width: 104px;
  flex: none;
  text-align: right;
}
.w-note {
  flex: 1;
  min-width: 0;
}
.w-bill {
  width: 60px;
  flex: none;
  text-align: right;
}
.w-del {
  width: 26px;
  flex: none;
}
.line-row .w-amt {
  text-align: right;
  font-variant-numeric: tabular-nums;
}
.line-del {
  width: 26px;
  height: 26px;
  flex: none;
  display: grid;
  place-items: center;
  border: none;
  border-radius: 6px;
  background: transparent;
  color: var(--faint);
  cursor: pointer;
}
.line-del:hover {
  background: #fdecea;
  color: var(--danger);
}
.line-add {
  align-self: flex-start;
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 6px 12px;
  border: 1px dashed var(--line);
  border-radius: 7px;
  background: transparent;
  color: var(--muted);
  font-size: 12px;
  cursor: pointer;
}
.line-add:hover {
  border-color: var(--brand);
  color: var(--brand);
}
.trip-days {
  font-size: 12.5px;
  color: var(--muted);
}
.trip-days b {
  color: var(--brand);
  font-size: 15px;
}
.trip-days em {
  font-style: normal;
  margin-left: 8px;
  color: var(--danger);
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

.files {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  align-items: center;
}
.file-chip {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  height: 28px;
  padding: 0 8px 0 10px;
  border-radius: 7px;
  background: #f5f7fa;
  color: var(--muted);
  font-size: 12px;
}
.file-chip button {
  display: grid;
  place-items: center;
  width: 16px;
  height: 16px;
  border: none;
  border-radius: 4px;
  background: transparent;
  color: var(--faint);
  cursor: pointer;
}
.file-chip button:hover {
  background: #e6eaf1;
  color: var(--danger);
}
.file-add {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  height: 28px;
  padding: 0 11px;
  border: 1px dashed var(--line);
  border-radius: 7px;
  background: transparent;
  color: var(--muted);
  font-size: 12px;
  cursor: pointer;
}
.file-add:hover {
  border-color: var(--brand);
  color: var(--brand);
}

.total-bar {
  display: flex;
  align-items: center;
  gap: 28px;
  margin-top: 8px;
  padding: 13px 16px;
  border-radius: 10px;
  background: #f7f9fc;
  border: 1px solid var(--line-soft);
  /* 表单比视口高，合计要一直看得见，否则边填边算得往上滚一遍。
     滚动区底部有 20px 内边距，所以往下压 20px 贴住底边，否则那条缝会露出表单内容 */
  position: sticky;
  bottom: -20px;
  z-index: 3;
  box-shadow: 0 -10px 18px -12px rgba(16, 32, 56, 0.28);
}

/* ---------------------------- 详情弹窗 ---------------------------- */
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
.trip-box {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 10px 14px;
  border-radius: 9px;
  background: #f7f9fc;
  font-size: 12.5px;
}
.trip-box em {
  font-style: normal;
  margin-left: auto;
  color: var(--faint);
  font-size: 12px;
}
.ellip {
  max-width: 260px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.num {
  font-variant-numeric: tabular-nums;
}
.text-danger {
  color: var(--danger) !important;
}
.faint-num {
  color: var(--faint);
  font-variant-numeric: tabular-nums;
}
@media (max-width: 1100px) {
  .summary {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
</style>

