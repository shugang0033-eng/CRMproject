<template>
  <div class="page">
    <PageHead
      title="审批中心"
      desc="报销、借款、请假三类的待办集中在这里。工作台上的「待处理审批」也指到这里，不用再逐个页面翻"
    >
      <button class="btn" type="button" @click="toast('已导出审批流水（演示）')">
        <AppIcon name="download" :size="14" />导出
      </button>
    </PageHead>

    <div class="summary">
      <div class="kpi card">
        <span>待我审批</span>
        <b class="warn">{{ pendingList.length }}<i>张</i></b>
        <em>合计 ¥{{ pendingAmount.toLocaleString() }}</em>
      </div>
      <div class="kpi card">
        <span>我发起的</span>
        <b>{{ mineList.length }}<i>张</i></b>
        <em>含审批中与已办结</em>
      </div>
      <div class="kpi card">
        <span>已办结</span>
        <b class="ok">{{ doneList.length }}<i>张</i></b>
        <em>本月通过 {{ passedThisMonth }} 张</em>
      </div>
      <div class="kpi card">
        <span>超过 3 天未处理</span>
        <b class="danger">{{ staleList.length }}<i>张</i></b>
        <em>催一下，别压单</em>
      </div>
    </div>

    <div class="card">
      <div class="tabs">
        <button
          v-for="t in tabs"
          :key="t.value"
          class="tab"
          :class="{ active: tab === t.value }"
          type="button"
          @click="tab = t.value"
        >
          {{ t.label }}<span class="tab-count">{{ t.count }}</span>
        </button>
      </div>

      <div class="toolbar">
        <div class="search">
          <AppIcon name="search" :size="15" />
          <input v-model="keyword" class="input" type="text" placeholder="搜索单号 / 申请人 / 摘要" />
        </div>
        <select v-model="kind" class="select">
          <option value="">全部类型</option>
          <option v-for="k in KINDS" :key="k">{{ k }}</option>
        </select>
        <div class="spacer" />
        <span class="faint sum">{{ filtered.length }} 张待处理</span>
      </div>

      <AppTable
        :columns="columns"
        :rows="filtered"
        :page-size="8"
        empty-text="这里很干净，没有需要你处理的单据"
      >
        <template #cell-docId="{ row }">
          <div class="cell-main">{{ row.docId }}</div>
          <div class="cell-sub">{{ row.title }}</div>
        </template>
        <template #cell-kind="{ row }">
          <span class="tag" :class="kindTone[row.kind]">{{ row.kind }}</span>
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
        <template #cell-amount="{ row }">
          <b v-if="row.amount !== null" class="num">¥{{ row.amount.toLocaleString() }}</b>
          <span v-else class="tag tag-gray plain">{{ row.duration }}</span>
        </template>
        <template #cell-meta="{ row }">
          <span class="meta">{{ row.meta }}</span>
        </template>
        <template #cell-submittedAt="{ row }">
          <div class="num">{{ row.submittedAt }}</div>
          <div class="cell-sub" :class="{ late: waited(row) > 3 }">{{ waitedText(row) }}</div>
        </template>
        <template #cell-status="{ row }">
          <span class="tag" :class="feedTone[row.status]">{{ row.status }}</span>
        </template>
        <template #cell-ops="{ row }">
          <div class="row-tight ops">
            <template v-if="row.status === '待审批' && canReview(row)">
              <button class="btn-text" type="button" @click="pass(row)">同意</button>
              <button class="btn-text danger" type="button" @click="reject(row)">驳回</button>
            </template>
            <button v-else class="btn-text" type="button" @click="toast(`查看「${row.docId}」审批流水`)">流水</button>
          </div>
        </template>
      </AppTable>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import UserAvatar from '@/components/UserAvatar.vue'
import { toast } from '@/composables/useToast'
import { session } from '@/store/session'
import { canAudit } from '@/store/permissions'
import { TODAY_STR } from '@/data/office'
import { officeApi } from '@/api/office'

const boxes = ref({ pending: [], mine: [], done: [] })
/* 后端的 created_at 是 `2026-11-14T16:46:06`，直接渲染会带个 T，很刺眼 */
const fmtTime = (v) => {
  const s = String(v || '')
  return s.length >= 16 ? s.slice(0, 16).replace('T', ' ') : s
}
async function loadApprovals() {
  const results = await Promise.all(['pending', 'mine', 'done'].map((box) => officeApi.approvals({ box, pageSize: 500 })))
  boxes.value = Object.fromEntries(['pending', 'mine', 'done'].map((box, index) => [box,
    results[index].rows.map((r) => ({
      ...r, id: r.kind + ':' + r.docId, docId: r.code, rawId: r.docId,
      submittedAt: fmtTime(r.created_at), submittedAtRaw: r.created_at,
      /* 请假单没有金额，金额列改显示天数；以前这里取 duration，接口没这个字段，列是空的 */
      duration: r.days ? `${r.days} 天` : '',
      status: r.status === '审批中' ? '待审批' : r.status,
      meta: r.projectName || r.purpose || r.reason || ''
    }))]))
}
onMounted(() => loadApprovals().catch((e) => toast(e.message, 'error')))

const tab = ref('pending')
const kind = ref('')
const keyword = ref('')

const me = computed(() => session.user?.name || '宋江')
const KINDS = ['费用报销', '借款预支', '请假申请']

/**
 * 按钮权限按单据类型走。以前统一写 expense.approve，
 * 结果销售经理（只有 leave.approve）在审批中心看不到请假单的「同意/驳回」，
 * 就算点下去后端也会按单据类型再查一次权限，直接 403。
 */
const APPROVE_PERM = { 费用报销: 'expense.approve', 借款预支: 'loan.approve', 请假申请: 'leave.approve' }
const canReview = (row) => canAudit(APPROVE_PERM[row.kind], row)

const pendingList = computed(() => boxes.value.pending)
const mineList = computed(() => boxes.value.mine)
const doneList = computed(() => boxes.value.done)
const passedThisMonth = computed(
  () =>
    doneList.value.filter(
      (f) => f.status === '已通过' && (f.submittedAt || '').startsWith(TODAY_STR.slice(0, 7))
    ).length
)
/** 提交超过 3 天还挂着的，压单比做错更伤，单拎出来催 */
const staleList = computed(() => pendingList.value.filter((f) => waited(f) > 3))
const pendingAmount = computed(() => pendingList.value.reduce((s, f) => s + (f.amount || 0), 0))

const tabs = computed(() => [
  { label: '待我审批', value: 'pending', count: pendingList.value.length },
  { label: '我发起的', value: 'mine', count: mineList.value.length },
  { label: '已办结', value: 'done', count: doneList.value.length }
])

const base = computed(() => {
  if (tab.value === 'pending') return pendingList.value
  if (tab.value === 'mine') return mineList.value
  return doneList.value
})

const filtered = computed(() =>
  base.value.filter((f) => {
    if (kind.value && f.kind !== kind.value) return false
    if (keyword.value) {
      const k = keyword.value.trim()
      if (![f.docId, f.applicant, f.title, f.dept].join(' ').includes(k)) return false
    }
    return true
  })
)

const columns = [
  { key: 'docId', label: '单据' },
  { key: 'kind', label: '类型', width: '100px' },
  { key: 'applicant', label: '申请人', width: '132px' },
  { key: 'amount', label: '金额 / 时长', width: '120px', align: 'right' },
  { key: 'meta', label: '说明', width: '200px' },
  { key: 'submittedAt', label: '提交时间', width: '116px' },
  { key: 'status', label: '状态', width: '92px' },
  { key: 'ops', label: '操作', align: 'right', width: '120px' }
]

const kindTone = {
  费用报销: 'tag-brand',
  借款预支: 'tag-info',
  请假申请: 'tag-gray'
}
const feedTone = { 待审批: 'tag-warning', 已通过: 'tag-success', 已驳回: 'tag-danger' }

function waited(f) {
  const at = f.submittedAtRaw || f.submittedAt
  if (!at) return 0
  return Math.max(0, Math.round((new Date(TODAY_STR) - new Date(at)) / 86400000))
}
function waitedText(f) {
  if (f.status !== '待审批') return `已办结`
  const d = waited(f)
  if (d === 0) return '今天提交'
  return `已等 ${d} 天`
}

function pass(row) { return decide(row, 'pass') }
function reject(row) { return decide(row, 'reject') }
async function decide(row, result) {
  try {
    await officeApi.decide({ kind: row.kind, docId: row.rawId, result })
    await loadApprovals()
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
.meta {
  display: block;
  font-size: 12px;
  color: var(--muted);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cell-sub.late {
  color: var(--danger);
}
.tag-brand {
  background: var(--brand-soft);
  color: var(--brand);
}
@media (max-width: 1100px) {
  .summary {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
</style>
