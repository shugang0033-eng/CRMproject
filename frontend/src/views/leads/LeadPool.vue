<template>
  <div class="page">
    <PageHead
      title="线索池"
      desc="超过 7 天没有跟进记录而被回收的线索，销售可主动领取，运营或主管可再分配"
    >
      <button class="btn" type="button" @click="toast('已导出线索池数据（演示）')">
        <AppIcon name="download" :size="14" />导出
      </button>
      <button v-can="'lead.pool.claim'" class="btn" type="button" @click="claimSelected">
        <AppIcon name="inbox" :size="14" />批量领取
      </button>
      <button v-can="'lead.pool.assign'" class="btn btn-primary" type="button" @click="assignSelected">
        <AppIcon name="layers" :size="14" />批量分配
      </button>
    </PageHead>


    <div class="pool-tip">
      <span class="tip-ico"><AppIcon name="inbox" :size="15" /></span>
      <p>
        这里放的是<b>超过 7 天没有跟进记录</b>、或者被负责人主动放弃的线索，入池原因见列表。员工可主动领取跟进，
        也可由运营或主管再分配；领取后 <b>7 天</b> 内仍未产生有效跟进会再次退回。单账号每日最多领取 <b>20 条</b>。
      </p>
      <div class="tip-stat">
        <span>今日已领取 <b>{{ claimedToday }}</b> / 20</span>
      </div>
    </div>

    <div class="card">
      <div class="toolbar">
        <div class="search">
          <AppIcon name="search" :size="15" />
          <input v-model="keyword" class="input" type="text" placeholder="搜索线索名称 / 联系人" />
        </div>
        <select v-model="source" class="select">
          <option value="">全部来源</option>
          <option v-for="s in sources" :key="s">{{ s }}</option>
        </select>
        <select v-model="region" class="select">
          <option value="">全部区域</option>
          <option v-for="r in regions" :key="r">{{ r }}</option>
        </select>
        <div class="spacer" />
        <template v-if="selected.length">
          <span class="picked">
            已选 <b>{{ selected.length }}</b> 条
          </span>
          <button class="btn-text" type="button" @click="selected = []">清空</button>
        </template>
        <span v-else class="faint pool-count">共 {{ filtered.length }} 条可领取</span>
      </div>

      <AppTable
        v-model:selected="selected"
        :columns="columns"
        :rows="filtered"
        :page-size="8"
        selectable
      >
        <template #cell-company="{ row }">
          <div class="cell-main">{{ row.company }}</div>
          <div class="cell-sub">{{ row.id }} · 入池 {{ row.createdAt }}</div>
        </template>
        <template #cell-contact="{ row }">
          <div class="cell-main">{{ row.contact }}</div>
          <div class="cell-sub">{{ row.phone }}</div>
        </template>
        <template #cell-reason="{ row }">
          <span class="tag tag-gray">{{ row.reason }}</span>
        </template>
        <template #cell-ops="{ row }">
          <div class="row-tight ops">
            <button v-can="'lead.pool.claim'" class="btn-text" type="button" @click="claim(row)">领取</button>
            <button v-can="'lead.pool.assign'" class="btn-text" type="button" @click="openAssign([row])">
              分配
            </button>
          </div>
        </template>
      </AppTable>
    </div>

    <!-- 分配线索 -->
    <ModalDialog
      v-model="assignOpen"
      title="分配线索"
      :desc="`把 ${assignRows.length} 条线索指派给指定员工，分配后立即从线索池移出并计入对方名下`"
      ok-text="确认分配"
      :loading="submitting"
      @confirm="submitAssign"
    >
      <div class="as-sheet">
        <div class="as-sheet-head">
          <span>待分配线索</span>
          <b>{{ assignRows.length }} 条</b>
        </div>
        <ul class="as-list">
          <li v-for="r in assignPreview" :key="r.id">
            <span class="as-dot"><AppIcon name="target" :size="12" /></span>
            <strong>{{ r.company }}</strong>
            <span class="as-meta">{{ r.region.split(' · ')[1] || r.region }} · {{ r.source }}</span>
          </li>
          <li v-if="assignRows.length > 4" class="as-more">
            还有 {{ assignRows.length - 4 }} 条，分配后可在「销售线索」中按负责人查看
          </li>
        </ul>
      </div>

      <div class="as-pick">
        <div class="as-pick-head">
          <label class="label">接收人<span class="req">*</span></label>
          <span class="as-pick-hint">右侧是在跟线索 / 客户数，可按负载排序，只挑还能接的人</span>
        </div>
        <AssigneePicker
          v-model="assignForm.empId"
          :employees="poolAssignees"
          :departments="deptOptions"
          :loading="employeeStore.loading && !assignableEmployees.length"
          :error="employeeStore.error"
          default-dept="销售部"
          placeholder="搜索姓名 / 工号"
          @retry="reloadEmployees"
        />
      </div>

      <LeadConflictAlert
        v-model="assignForm.ack"
        :conflicts="assignConflicts"
        :target-name="pickedName(assignForm.empId)"
        :source="conflictSource"
        action-label="分配"
      />

      <div class="as-form">
        <div class="field span-2">
          <label class="label">分配依据</label>
          <select v-model="assignForm.reason" class="select">
            <option v-for="r in REASON_ASSIGN" :key="r">{{ r }}</option>
          </select>
        </div>
        <div class="field span-2">
          <label class="label">指派说明</label>
          <textarea
            v-model="assignForm.note"
            class="textarea"
            placeholder="例如：这家在临平，离你负责片区近，本周内先电话确认补货频次"
          />
        </div>
      </div>

    </ModalDialog>
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import AssigneePicker from '@/components/AssigneePicker.vue'
import LeadConflictAlert from '@/components/LeadConflictAlert.vue'
import { toast } from '@/composables/useToast'
import { leadApi, REASON_ASSIGN } from '@/api/leads'
import { employeeStore, loadEmployees, assignableEmployees } from '@/store/employees'
import { flattenDepartments } from '@/store/departments'
import { withAssigneeLoad } from '@/composables/useAssigneeLoad'
import { checkLeadConflicts, filterActiveConflicts } from '@/composables/useLeadConflicts'
import { session } from '@/store/session'

const rows = ref([])
/* 非池线索单独拉一份，只用来统计每个人手上还有多少在跟线索（池里的线索没有负责人，不计入负载） */
const allLeads = ref([])
onMounted(async () => {
  try {
    rows.value = (await leadApi.list(true)).map((r) => ({
      ...r,
      createdAt: r.createdAt.replace('T', ' ').slice(0, 16)
    }))
  } catch (e) {
    toast(e.message, 'error')
  }
  leadApi
    .list(false)
    .then((data) => {
      allLeads.value = Array.isArray(data) ? data : []
    })
    .catch(() => {})
  /* 接收人名单与「设置 › 员工管理」共用一份数据，进页面就预取，打开弹窗时不再等 */
  loadEmployees().catch(() => {})
})
const keyword = ref('')
const source = ref('')
const region = ref('')
const claimedToday = ref(2)
const selected = ref([])

const sources = computed(() => [...new Set(rows.value.map((r) => r.source))])
const regions = computed(() => [...new Set(rows.value.map((r) => r.region.split(' · ')[0]).filter(Boolean))])

const columns = [
  { key: 'company', label: '线索名称' },
  { key: 'contact', label: '联系人' },
  { key: 'source', label: '来源' },
  { key: 'region', label: '区域' },
  { key: 'reason', label: '退回原因' },
  { key: 'ops', label: '操作', align: 'right', width: '140px' }
]

const filtered = computed(() =>
  rows.value.filter((r) => {
    if (source.value && r.source !== source.value) return false
    if (region.value && !r.region.startsWith(region.value)) return false
    if (keyword.value) {
      const k = keyword.value.trim()
      if (![r.company, r.contact, r.phone].join(' ').includes(k)) return false
    }
    return true
  })
)

/* 选中项可能因为筛选、领取而离开当前列表，取行数据时统一从 rows 里找 */
const selectedRows = computed(() => rows.value.filter((r) => selected.value.includes(r.id)))

function removeRows(ids) {
  rows.value = rows.value.filter((r) => !ids.includes(r.id))
  const gone = new Set(ids)
  selected.value = selected.value.filter((id) => !gone.has(id))
}

function claim(row) {
  recordOwner([row.id], session.user?.id)
  removeRows([row.id])
  claimedToday.value += 1
  toast(`已领取「${row.company}」，请在 7 天内完成首次跟进`)
}

function claimSelected() {
  if (!selected.value.length) {
    toast('请先勾选要领取的线索', 'error')
    return
  }
  const picked = selectedRows.value
  const over = claimedToday.value + picked.length - 20
  if (over > 0) {
    toast(`今日领取上限 20 条，最多还能领取 ${20 - claimedToday.value} 条`, 'error')
    return
  }
  const ids = picked.map((r) => r.id)
  recordOwner(ids, session.user?.id)
  removeRows(ids)
  claimedToday.value += picked.length
  toast(`已领取 ${picked.length} 条线索，请在 7 天内完成首次跟进`)
}

/* ============================================================
 * 分配线索
 * ------------------------------------------------------------
 * 接口：POST /api/leads/assign  { ids, ownerId, reason, note }
 * 接收人名单不走 /api/leads/assignees，直接用「设置 › 员工管理」
 * 的 GET /api/employees：那份数据带工号与部门，且能和设置页对得上。
 * ============================================================ */
const assignOpen = ref(false)
const assignRows = ref([])
const submitting = ref(false)
const assignForm = reactive({
  empId: null,
  reason: REASON_ASSIGN[0],
  note: '',
  ack: false
})
/* 撞单核对结果：分配前先看这家店是不是已经在别人名下 */
const assignConflictRaw = ref([])
const conflictSource = ref('local')
const assignConflicts = computed(() =>
  filterActiveConflicts(assignConflictRaw.value, {
    ownerId: assignForm.empId,
    ownerName: pickedName(assignForm.empId)
  })
)

/* 部门下拉取后端部门树（与「设置 › 部门管理」同源），只用于筛选，不提交 */
const deptOptions = computed(() => flattenDepartments())

/* 接收人名单挂上负载：分配的人要先看出谁手里已经压了一堆线索 */
const poolAssignees = computed(() =>
  withAssigneeLoad(assignableEmployees.value, { leads: allLeads.value })
)

/**
 * 领取 / 分配之后立刻把这批线索记到新负责人名下，
 * 否则弹窗关掉再打开，负载数字还是分配前的，等于白做。
 * 后端返回后会整体刷新，这里只是让当前页面先对上。
 */
function recordOwner(ids, ownerId) {
  if (!ownerId) return
  const set = new Set(ids)
  const seen = new Set()
  allLeads.value.forEach((l) => {
    if (!set.has(l.id)) return
    l.ownerId = ownerId
    seen.add(l.id)
  })
  rows.value.forEach((r) => {
    if (!set.has(r.id) || seen.has(r.id)) return
    allLeads.value.push({ id: r.id, ownerId, status: 'pending' })
    seen.add(r.id)
  })
}

const assignPreview = computed(() => assignRows.value.slice(0, 4))

function pickedName(id) {
  return assignableEmployees.value.find((e) => String(e.rawId) === String(id))?.name || ''
}

function reloadEmployees() {
  loadEmployees({ force: true }).catch(() => toast('员工数据加载失败，请稍后重试', 'error'))
}

async function openAssign(list) {
  assignRows.value = list.map((r) => ({ ...r }))
  Object.assign(assignForm, { empId: null, reason: REASON_ASSIGN[0], note: '', ack: false })
  assignConflictRaw.value = []
  assignOpen.value = true
  // 弹窗先开，名单在后台补；没加载过才拉一次，避免每次打开都请求
  if (!employeeStore.loaded) loadEmployees().catch(() => {})
  refreshAssignConflicts()
}

/**
 * 撞单核对：这家店是不是已经是别人的客户，或已经有一条同名线索在跟进。
 * 优先走 /api/leads/conflicts，后端没有就本地比对（客户档案 + 线索 + 线索池）。
 */
async function refreshAssignConflicts() {
  const list = assignRows.value
  const { items, source } = await checkLeadConflicts(list, {
    allLeads: [...allLeads.value, ...rows.value.map((r) => ({ ...r, statusRaw: r.status }))],
  })
  if (!assignOpen.value) return
  assignConflictRaw.value = items
  conflictSource.value = source
}

function assignSelected() {
  if (!selected.value.length) {
    toast('请先勾选要分配的线索', 'error')
    return
  }
  openAssign(selectedRows.value)
}

async function submitAssign() {
  if (!assignForm.empId) {
    toast('请先选择接收人', 'error')
    return
  }
  if (assignConflicts.value.length && !assignForm.ack) {
    toast('请先确认撞单提醒，或换一位接收人', 'error')
    return
  }
  const ids = assignRows.value.map((r) => r.id)
  const name = pickedName(assignForm.empId)
  submitting.value = true
  try {
    await leadApi.assign({
      ids,
      ownerId: assignForm.empId,
      reason: assignForm.reason,
      note: assignForm.note,
    })
    doneAssign(ids, assignForm.empId)
    toast(`${ids.length} 条线索已分配给 ${name}`)
  } catch (e) {
    toast(e.message || '分配失败，请稍后重试', 'error')
  } finally {
    submitting.value = false
  }
}

function doneAssign(ids, ownerId) {
  recordOwner(ids, ownerId)
  removeRows(ids)
  assignOpen.value = false
}
</script>

<style scoped>
.pool-tip {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 13px 16px;
  margin-bottom: 16px;
  border: 1px solid #dbe6f3;
  background: linear-gradient(180deg, #f7fafd, #f2f7fc);
  border-radius: var(--radius);
}
.tip-ico {
  width: 30px;
  height: 30px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  background: #fff;
  border: 1px solid #dbe6f3;
  color: var(--brand);
  flex-shrink: 0;
}
.pool-tip p {
  flex: 1;
  font-size: 12.5px;
  color: #4a5a70;
  line-height: 1.65;
}
.pool-tip b {
  color: var(--ink);
  font-weight: 600;
}
.tip-stat {
  font-size: 12px;
  color: var(--muted);
  padding-left: 12px;
  border-left: 1px solid #dbe6f3;
  white-space: nowrap;
}
.tip-stat b {
  color: var(--brand);
  font-size: 14px;
  font-variant-numeric: tabular-nums;
}
.pool-count {
  font-size: 12px;
}
.picked {
  font-size: 12.5px;
  color: var(--muted);
}
.picked b {
  color: var(--brand);
  font-variant-numeric: tabular-nums;
}
.ops {
  justify-content: flex-end;
  gap: 13px;
}

/* ---------------- 接口提示条 ---------------- */
.api-note {
  display: flex;
  gap: 10px;
  padding: 12px 16px;
  margin-bottom: 16px;
  border: 1px solid #d8e3f3;
  border-radius: var(--radius-sm);
  background: #f7fafd;
}
.an-ico {
  width: 24px;
  height: 24px;
  border-radius: 6px;
  display: grid;
  place-items: center;
  background: #e8f0fa;
  color: var(--brand);
  flex-shrink: 0;
}
.an-txt {
  min-width: 0;
}
.an-txt strong {
  display: block;
  font-size: 12.8px;
  font-weight: 550;
  color: var(--ink);
}
.an-txt p {
  margin: 3px 0 0;
  font-size: 12px;
  line-height: 1.7;
  color: var(--muted);
}
.an-txt code {
  padding: 1px 5px;
  border-radius: 4px;
  background: rgba(43, 108, 176, 0.1);
  font-size: 11.5px;
  color: var(--brand-700);
}

/* ---------------- 分配弹窗 ---------------- */
.as-sheet {
  border: 1px solid var(--line-soft);
  border-radius: var(--radius-sm);
  overflow: hidden;
}
.as-sheet-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 9px 13px;
  background: #f7f9fc;
  border-bottom: 1px solid var(--line-soft);
  font-size: 12.5px;
  color: var(--muted);
}
.as-sheet-head b {
  color: var(--ink);
  font-variant-numeric: tabular-nums;
}
.as-list {
  padding: 6px 0;
  margin: 0;
  list-style: none;
  max-height: 168px;
  overflow-y: auto;
}
.as-list li {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 13px;
  font-size: 12.8px;
}
.as-list li strong {
  font-weight: 550;
  color: var(--ink);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.as-dot {
  width: 18px;
  height: 18px;
  border-radius: 5px;
  display: grid;
  place-items: center;
  background: var(--brand-soft);
  color: var(--brand);
  flex-shrink: 0;
}
.as-meta {
  margin-left: auto;
  font-size: 11.5px;
  color: var(--faint);
  white-space: nowrap;
}
.as-list li.as-more {
  color: var(--faint);
  font-size: 11.8px;
  line-height: 1.6;
  padding-top: 4px;
}

.as-form {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px 14px;
  margin-top: 14px;
}
.as-form .span-2 {
  grid-column: span 2;
}

/* ---------------- 接收人选择 ---------------- */
.as-pick {
  margin-top: 14px;
}
.as-pick-head {
  display: flex;
  align-items: baseline;
  gap: 10px;
  margin-bottom: 8px;
}
.as-pick-head .label {
  margin-bottom: 0;
}
.as-pick-hint {
  font-size: 11.8px;
  color: var(--faint);
  line-height: 1.5;
}

.as-ack {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin-top: 14px;
  padding-top: 13px;
  border-top: 1px solid var(--line-soft);
  font-size: 12.3px;
  line-height: 1.6;
  color: var(--muted);
  cursor: pointer;
  user-select: none;
}
.as-ack input {
  margin: 2px 0 0;
  accent-color: var(--brand);
}
</style>

