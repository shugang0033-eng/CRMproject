<template>
  <div class="page">
    <PageHead
      title="请假申请"
      desc="年假、病假、事假与调休，按自然日扣减（周末不计），审批通过后自动记录在假；额度不足时提交会被拦住"
    >
      <button class="btn" type="button" @click="toast('已导出请假记录（演示）')">
        <AppIcon name="download" :size="14" />导出
      </button>
      <button v-can="'leave.create'" class="btn btn-primary" type="button" @click="openCreate">
        <AppIcon name="plus" :size="14" />发起请假
      </button>
    </PageHead>

    <div class="summary">
      <div class="kpi card">
        <span>本月请假</span>
        <b>{{ monthDays }}<i>天</i></b>
        <em>{{ monthCount }} 人次</em>
      </div>
      <div class="kpi card">
        <span>待审批</span>
        <b class="warn">{{ pendingList.length }}<i>人次</i></b>
        <em>未批不占额度</em>
      </div>
      <div class="kpi card">
        <span>今日在假</span>
        <b>{{ todayList.length }}<i>人</i></b>
        <em>{{ todayList.map((l) => l.applicant).join('、') || '全员在岗' }}</em>
      </div>
      <div class="kpi card">
        <span>我的年假余额</span>
        <b :class="{ danger: myAnnualLeft === 0 }">{{ myAnnualLeft }}<i>天</i></b>
        <em>额度 {{ LEAVE_QUOTA.年假 }} 天 / 年</em>
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
          <input v-model="keyword" class="input" type="text" placeholder="搜索单号 / 申请人 / 事由" />
        </div>
        <select v-model="type" class="select">
          <option value="">全部类型</option>
          <option v-for="t in LEAVE_TYPES" :key="t">{{ t }}</option>
        </select>
        <select v-model="month" class="select">
          <option value="">全部月份</option>
          <option v-for="m in months" :key="m">{{ m }}</option>
        </select>
        <div class="spacer" />
        <span class="faint sum">共 {{ filtered.length }} 条 · {{ filteredDays }} 天</span>
      </div>

      <AppTable
        :columns="columns"
        :rows="filtered"
        :page-size="8"
        empty-text="没有符合条件的请假记录，点右上「发起请假」提交一单"
      >
        <template #cell-id="{ row }">
          <div class="cell-main">{{ row.id }}</div>
          <div class="cell-sub">{{ row.reason }}</div>
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
          <span class="tag" :class="typeTone[row.type] || 'tag-gray'">{{ row.type }}</span>
        </template>
        <template #cell-range="{ row }">
          <div class="num nowrap">{{ row.start === row.end ? row.start : `${row.start} 至 ${row.end}` }}</div>
          <div class="cell-sub">申请于 {{ row.applyDate }}</div>
        </template>
        <template #cell-days="{ row }">
          <b class="num">{{ row.days }}</b><span class="faint"> 天</span>
        </template>
        <template #cell-handover="{ row }">
          <span class="tag tag-gray plain">{{ row.handover }}</span>
        </template>
        <template #cell-status="{ row }">
          <span class="tag" :class="LEAVE_TONE[row.status]">{{ row.status }}</span>
          <div v-if="row.status === '待审批' && isMine(row)" class="cell-sub">本人申请</div>
        </template>
        <template #cell-ops="{ row }">
          <div class="row-tight ops">
            <template v-if="row.status === '待审批' && canAudit('leave.approve', row)">
              <button class="btn-text" type="button" @click="audit(row, '已通过')">通过</button>
              <button class="btn-text danger" type="button" @click="audit(row, '已驳回')">驳回</button>
            </template>
            <button v-else class="btn-text" type="button" @click="openDetail(row)">明细</button>
          </div>
        </template>
      </AppTable>
    </div>

    <!-- 发起请假 -->
    <ModalDialog
      v-model="createOpen"
      title="发起请假"
      desc="按工作日计（周末不计入，暂不排除法定节假日）；额度只有审批通过后才扣减"
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
        <div class="field span-2">
          <label class="label">请假类型<span class="req">*</span></label>
          <div class="type-pick">
            <button
              v-for="t in LEAVE_TYPES"
              :key="t"
              type="button"
              class="tp"
              :class="{ on: form.type === t }"
              @click="form.type = t"
            >
              <span>{{ t }}</span>
              <em>{{ quotaText(t) }}</em>
            </button>
          </div>
        </div>
        <div class="field">
          <label class="label">开始日期<span class="req">*</span></label>
          <input v-model="form.start" class="input" type="date" />
        </div>
        <div class="field">
          <label class="label">结束日期<span class="req">*</span></label>
          <input v-model="form.end" class="input" type="date" />
        </div>
        <div class="field">
          <label class="label">请假天数</label>
          <div class="days-box">
            <b>{{ days }}</b><span>天</span>
            <em v-if="days === 0">
              {{ form.start && form.end && form.end < form.start ? '结束日期不能早于开始日期' : '所选区间内没有工作日（周末不计入）' }}
            </em>
          </div>
        </div>
        <div class="field">
          <label class="label">工作交接人</label>
          <select v-model="form.handover" class="select"><option value="">不指定</option>
            <option v-for="person in handovers" :key="person.id" :value="person.id">{{ person.name }}</option>
          </select>
        </div>
        <div class="field span-2">
          <label class="label">请假事由<span class="req">*</span></label>
          <input
            ref="reasonRef"
            v-model="form.reason"
            class="input"
            type="text"
            placeholder="如：陪家人出行，已安排好门店交接"
          />
        </div>
      </div>
      <div v-if="overQuota" class="warn-box danger">
        <AppIcon name="bell" :size="14" />
        <span>
          {{ form.applicant }} 的{{ form.type }}只剩 {{ balanceOf(form.applicant, form.type) }} 天，
          本次要请 {{ days }} 天，超出 {{ days - balanceOf(form.applicant, form.type) }} 天。请改类型或缩短日期。
        </span>
      </div>
      <p v-else class="hint-line">
        {{ form.type in LEAVE_QUOTA ? `${form.applicant} 的${form.type}还剩 ${balanceOf(form.applicant, form.type)} 天，可覆盖本次 ${days} 天` : '事假不设额度，只留痕，审批人按业务情况判断' }}
      </p>
    </ModalDialog>

    <!-- 请假明细 -->
    <ModalDialog v-model="detailOpen" title="请假明细" :desc="detail.id ? `${detail.id} · ${detail.applicant}` : ''" hide-footer>
      <div v-if="detail.id" class="doc">
        <div class="detail-top">
          <div class="dt"><span>类型</span><b>{{ detail.type }}</b></div>
          <div class="dt"><span>天数</span><b>{{ detail.days }} 天</b></div>
          <div class="dt"><span>交接人</span><b>{{ detail.handover }}</b></div>
          <div class="dt">
            <span>状态</span>
            <b><span class="tag" :class="LEAVE_TONE[detail.status]">{{ detail.status }}</span></b>
          </div>
        </div>
        <div class="kv-grid">
          <div class="kv"><span>起止</span><em>{{ detail.start }} 至 {{ detail.end }}</em></div>
          <div class="kv"><span>申请日期</span><em>{{ detail.applyDate }}</em></div>
          <div class="kv"><span>审批人</span><em>{{ detail.approver || '—' }}</em></div>
          <div class="kv"><span>事由</span><em>{{ detail.reason }}</em></div>
        </div>
        <div v-if="detail.status === '已驳回'" class="warn-box danger">
          <AppIcon name="bell" :size="14" />
          <span>驳回原因：{{ detail.rejectReason || '—' }}</span>
        </div>
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
import { toast } from '@/composables/useToast'
import { session } from '@/store/session'
import { canAudit, isMine } from '@/store/permissions'
import {
  leaveBalance,
  leaveUsed,
  workdays,
  onLeaveToday,
  LEAVE_QUOTA,
  LEAVE_TYPES,
  LEAVE_TONE,
  DEPTS,
  STAFF,
  TODAY_STR,
  localDate
} from '@/data/office'

import { officeApi } from '@/api/office'
import { employeeApi } from '@/api/employees'

const leaves = ref([])
const handovers = ref([])
const quotas = ref({})
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
  leaves.value = (await officeApi.leaves({ pageSize: 500 })).rows.map(adapt)
  quotas.value = await officeApi.leaveQuota({ year: form.start?.slice(0, 4) })
}
onMounted(() => loadRows().catch((e) => toast(e.message, 'error')))
const status = ref('')
const keyword = ref('')
const type = ref('')
const month = ref('')

const me = computed(() => session.user?.name || '宋江')

const columns = [
  { key: 'id', label: '请假单号' },
  { key: 'applicant', label: '申请人', width: '132px' },
  { key: 'type', label: '类型', width: '92px' },
  { key: 'range', label: '请假起止', width: '214px' },
  { key: 'days', label: '天数', width: '76px', align: 'right' },
  { key: 'handover', label: '交接人', width: '104px' },
  { key: 'status', label: '状态', width: '96px' },
  { key: 'ops', label: '操作', align: 'right', width: '110px' }
]

const typeTone = {
  年假: 'tag-brand',
  病假: 'tag-info',
  事假: 'tag-gray',
  调休: 'tag-warning'
}

const months = computed(() => [...new Set(leaves.value.map((l) => l.start.slice(0, 7)))].sort().reverse())
const pendingList = computed(() => leaves.value.filter((l) => l.status === '待审批'))
const todayList = computed(() => leaves.value.filter((row) => row.status === '已通过' && row.start <= TODAY_STR && row.end >= TODAY_STR))
const monthKey = TODAY_STR.slice(0, 7)
const monthRows = computed(() => leaves.value.filter((l) => l.start.startsWith(monthKey) && l.status !== '已驳回'))
const monthDays = computed(() => monthRows.value.reduce((s, l) => s + l.days, 0))
const monthCount = computed(() => monthRows.value.length)
const myAnnualLeft = computed(() => quotas.value['年假']?.left ?? 0)

const tabs = computed(() => [
  { label: '全部', value: '', count: leaves.value.length },
  { label: '待审批', value: '待审批', count: pendingList.value.length },
  { label: '已通过', value: '已通过', count: leaves.value.filter((l) => l.status === '已通过').length },
  { label: '已驳回', value: '已驳回', count: leaves.value.filter((l) => l.status === '已驳回').length }
])

const filtered = computed(() =>
  leaves.value.filter((l) => {
    if (status.value && l.status !== status.value) return false
    if (type.value && l.type !== type.value) return false
    if (month.value && !l.start.startsWith(month.value)) return false
    if (keyword.value) {
      const k = keyword.value.trim()
      if (![l.id, l.applicant, l.reason, l.handover].join(' ').includes(k)) return false
    }
    return true
  })
)
const filteredDays = computed(() => filtered.value.reduce((s, l) => s + l.days, 0))

/* ------------------------------ 发起请假 ------------------------------ */
const createOpen = ref(false)
const form = reactive({ applicant: '宋江', dept: DEPTS[0], type: '年假', start: '', end: '', handover: '', reason: '' })
const reasonRef = ref(null)

const days = computed(() => workdays(form.start, form.end))

/**
 * 可用额度。注意两边口径要对齐：
 *   /leaves/quota 只给「额度 − 已用」；
 *   后端创建校验（OfficeService.remaining）算的是「额度 − 已用 − 该年度待审批」。
 * 不把待审批扣掉，就会出现「弹窗说还剩 5 天可覆盖 4 天，一提交却报额度不足」。
 */
watch(() => form.start?.slice(0, 4), async (year, _, onCleanup) => {
  let current = true
  onCleanup(() => { current = false })
  try {
    const data = await officeApi.leaveQuota({ year })
    if (current) quotas.value = data
  } catch (e) { if (current) toast(e.message, 'error') }
})
const balanceOf = (_, type) => {
  if (type === '事假') return null
  const quota = quotas.value[type]
  return Math.max(0, (quota?.left ?? 0) - (quota?.pending ?? 0))
}
const quotaText = (t) => {
  if (!(t in LEAVE_QUOTA)) return '不限额'
  return `剩 ${balanceOf(form.applicant, t)} 天`
}
const overQuota = computed(() => {
  const left = balanceOf(form.applicant, form.type)
  return left !== null && days.value > left
})

/* 默认起止日期：从今天开始找第一个工作日。
   直接取今天的话，周末打开就是「0 天」，用户会以为表单坏了 */
function firstWorkday(from) {
  const d = new Date(from + 'T00:00:00')
  while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() + 1)
  return localDate(d) // 不能用 toISOString：那是 UTC，本地零点会退一天
}

function openCreate() {
  requestId = newRequestId()
  employeeApi.list({ status: 'active' }).then((data) => {
    handovers.value = data.filter((employee) => employee.id !== session.user.id)
  }).catch((e) => toast(e.message, 'error'))
  form.applicant = me.value
  form.dept = session.user.dept
  form.type = '年假'
  form.start = firstWorkday(TODAY_STR)
  form.end = form.start
  form.handover = ''
  form.reason = ''
  createOpen.value = true
}

/* 提交前先自查。以前什么都不查直接发，后端一个 400 被前端统一翻译成「请假天数为 0」，
   用户明明填了 4 天，看到这句话只会以为系统坏了。哪个字段有问题就说哪个 */
async function submitCreate() {
  if (saving.value) return
  if (!form.start || !form.end) return toast('请选择开始日期和结束日期', 'error')
  if (form.end < form.start) return toast('结束日期不能早于开始日期', 'error')
  if (days.value === 0) return toast('所选区间内没有工作日（周末不计入），请调整日期', 'error')
  if (!form.reason.trim()) { reasonRef.value?.focus(); return toast('请填写请假事由', 'error') }
  if (overQuota.value) {
    return toast(`${form.type}只剩 ${balanceOf(form.applicant, form.type)} 天，本次需要 ${days.value} 天`, 'error')
  }
  saving.value = true
  try {
    const saved = await officeApi.createLeave({ requestId, type: form.type, start: form.start || null, end: form.end || null, reason: form.reason, handoverId: form.handover || null })
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
    const data = await officeApi.leaveDetail(row.docId)
    detail.value = adapt(data)
    detailOpen.value = true
  } catch (e) { toast(e.message, 'error') }
}

async function audit(row, result) {
  try {
    await officeApi.approveLeave(row.docId, { result: result === '已通过' ? 'pass' : 'reject' })
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
.kpi b.warn {
  color: #b7791f;
}
.kpi b.danger {
  color: #b7791f;
}
.kpi em {
  font-style: normal;
  font-size: 11.5px;
  color: var(--faint);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
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
.num {
  font-variant-numeric: tabular-nums;
}
.nowrap {
  white-space: nowrap;
}
.tag-brand {
  background: var(--brand-soft);
  color: var(--brand);
}

/* 类型选择：四个并排的按钮，把额度直接写在上面，不用另开提示 */
.type-pick {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 8px;
}
.tp {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 8px 10px;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: #fff;
  text-align: left;
  cursor: pointer;
}
.tp span {
  font-size: 12.5px;
  color: var(--text);
}
.tp em {
  font-style: normal;
  font-size: 11px;
  color: var(--faint);
}
.tp:hover {
  border-color: #c9d4e3;
}
.tp.on {
  border-color: var(--brand);
  background: var(--brand-soft);
}
.tp.on span {
  color: var(--brand);
  font-weight: 600;
}
.tp.on em {
  color: var(--brand);
}
.days-box {
  display: flex;
  align-items: baseline;
  gap: 4px;
  height: 36px;
  align-items: center;
}
.days-box b {
  font-size: 20px;
  color: var(--brand);
  font-variant-numeric: tabular-nums;
}
.days-box span {
  font-size: 12px;
  color: var(--faint);
}
.days-box em {
  font-style: normal;
  font-size: 11.5px;
  color: var(--danger);
  margin-left: 6px;
}
.hint-line {
  margin: 14px 0 0;
  font-size: 12px;
  color: var(--faint);
  line-height: 1.6;
}
.warn-box {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin-top: 14px;
  padding: 10px 13px;
  border-radius: 9px;
  background: #fff8e8;
  border: 1px solid #f2e2c0;
  color: #8a6a1f;
  font-size: 12px;
  line-height: 1.65;
}
.warn-box.danger {
  background: #fdecea;
  border-color: #f5c6c0;
  color: #a83226;
  margin-top: 12px;
}
.doc {
  display: flex;
  flex-direction: column;
  gap: 12px;
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
}
@media (max-width: 1100px) {
  .summary {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
</style>



