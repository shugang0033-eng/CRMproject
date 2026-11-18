<template>
  <div class="page">
    <PageHead :title="headTitle" :desc="headDesc">
      <button class="btn" type="button" @click="toast('已导出当前筛选结果（演示）')">
        <AppIcon name="download" :size="14" />导出
      </button>
      <button
        v-can="'lead.pool.assign'"
        class="btn"
        type="button"
        :disabled="!assignableSelection.length"
        :title="
          assignableSelection.length
            ? `把勾选的 ${assignableSelection.length} 条待分配线索指派给销售`
            : '请先勾选没有负责人的线索'
        "
        @click="openBatchAssign"
      >
        <AppIcon name="layers" :size="14" />批量分配
      </button>
      <button
        v-can="'lead.transfer'"
        class="btn"
        type="button"
        :disabled="!selected.length"
        :title="selected.length ? '把勾选的线索一次性转给他人' : '请先在列表中勾选线索'"
        @click="openBatchTransfer"
      >
        <AppIcon name="arrow-right" :size="14" />批量转移
      </button>
      <button v-can="'lead.create'" class="btn btn-primary" type="button" @click="openCreate">
        <AppIcon name="plus" :size="14" />新建线索
      </button>
    </PageHead>

    <div v-if="canAllLeads" class="scope-bar">
      <div class="seg">
        <button
          type="button"
          class="seg-btn"
          :class="{ on: scope === 'mine' }"
          @click="setScope('mine')"
        >
          <AppIcon name="user" :size="13" />我的线索
          <b>{{ myLeads.length }}</b>
        </button>
        <button
          type="button"
          class="seg-btn"
          :class="{ on: scope === 'all' }"
          @click="setScope('all')"
        >
          <AppIcon name="users" :size="13" />全部线索
          <b>{{ rows.length }}</b>
        </button>
      </div>
      <span class="scope-hint">{{ scopeHint }}</span>
    </div>

    <div v-if="apiNote" class="api-note">
      <span class="an-ico"><AppIcon name="flag" :size="13" /></span>
      <div class="an-txt">
        <strong>{{ apiNote.title }}</strong>
        <p>{{ apiNote.text }}</p>
      </div>
      <button class="an-close" type="button" title="关闭提示" @click="apiNote = null">
        <AppIcon name="close" :size="13" />
      </button>
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
          {{ tab.label }}
          <span class="tab-count">{{ tab.count }}</span>
        </button>
      </div>

      <div class="toolbar">
        <div class="search">
          <AppIcon name="search" :size="15" />
          <input v-model="keyword" class="input" type="text" placeholder="搜索线索名称 / 联系人 / 手机号" />
        </div>
        <select v-model="source" class="select">
          <option value="">全部来源</option>
          <option v-for="s in sourceOptions" :key="s">{{ s }}</option>
        </select>
        <select v-model="level" class="select">
          <option value="">全部等级</option>
          <option>A 级</option>
          <option>B 级</option>
          <option>C 级</option>
        </select>
        <select v-if="scope === 'all'" v-model="owner" class="select">
          <option value="">全部负责人</option>
          <option v-for="o in owners" :key="o">{{ o }}</option>
        </select>
        <div class="spacer" />
        <template v-if="selected.length">
          <span class="picked">已选 <b>{{ selected.length }}</b> 条</span>
          <button class="btn-text" type="button" @click="selected = []">清空</button>
        </template>
        <span v-else class="faint row-count">共 {{ filtered.length }} 条</span>
        <button class="btn btn-sm" type="button" @click="resetFilters">重置筛选</button>
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
          <div class="cell-sub">{{ row.id }} · 创建于 {{ row.createdAt }}</div>
        </template>
        <template #cell-contact="{ row }">
          <div class="cell-main">{{ row.contact }}</div>
          <div class="cell-sub">{{ row.phone }}</div>
        </template>
        <template #cell-level="{ row }">
          <span class="tag" :class="levelTone[row.level]">{{ row.level }} 级</span>
        </template>
        <template #cell-owner="{ row }">
          <span class="row-tight">
            <UserAvatar :name="row.owner" size="sm" />
            <span>{{ row.owner }}</span>
          </span>
        </template>
        <template #cell-status="{ row }">
          <span class="tag" :class="statusTone[row.status]">{{ row.status }}</span>
        </template>
        <template #cell-ops="{ row }">
          <div class="row-tight ops">
            <button class="btn-text" type="button" @click="follow(row)">跟进</button>            <!-- 没有负责人的线索还谈不上「转移」，要先把人定下来 -->
            <button
              v-if="!row.ownerId"
              v-can="'lead.pool.assign'"
              class="btn-text"
              type="button"
              :disabled="!canFlow(row)"
              :title="canFlow(row) ? '把这条线索指派给销售' : '已转化或无效的线索不再分配'"
              @click="openAssign([row])"
            >
              分配
            </button>
            <!-- 改派是离职交接 / 组长调派的动作，一线销售不做；销售这里只留「转客户」 -->
            <button
              v-else
              v-can="'lead.transfer'"
              class="btn-text"
              type="button"
              :disabled="!canFlow(row)"
              :title="canFlow(row) ? '把线索转给其他销售' : '已转化的线索不可再转移'"
              @click="openTransfer(row)"
            >
              转移
            </button>
            <!-- 转客户只看角色权限（设置 › 角色管理 › 线索 › 转为客户），没负责人时没有可转的主体 -->
            <button
              v-if="row.ownerId"
              v-can="'lead.convert'"
              class="btn-text"
              type="button"
              :disabled="!canFlow(row)"
              :title="canFlow(row) ? '转为客户档案' : '已转化或无效的线索不可转换'"
              @click="convert(row)"
            >
              转客户
            </button>
          </div>
        </template>
        <template #empty>
          <div class="lead-empty">
            <strong>{{ emptyTitle }}</strong>
            <p>{{ emptyDesc }}</p>
            <button
              v-if="scope === 'mine' && can('lead.pool')"
              class="btn btn-sm"
              type="button"
              @click="router.push('/leads/pool')"
            >
              <AppIcon name="layers" :size="13" />去线索池看看
            </button>
            <button
              v-else-if="status === UNASSIGNED"
              class="btn btn-sm"
              type="button"
              @click="status = ''"
            >
              <AppIcon name="users" :size="13" />查看全部线索
            </button>
          </div>
        </template>
      </AppTable>
    </div>

    <!-- 新建线索 -->
    <ModalDialog v-model="createOpen" title="新建线索" desc="录入线索信息，保存后自动分配给所选负责人" ok-text="保存线索" @confirm="save">
      <div class="form-grid">
        <div class="field span-2">
          <label class="label">公司 / 线索名称<span class="req">*</span></label>
          <input v-model="form.company" class="input" :class="{ error: err.company }" placeholder="如：杭州驰远汽车服务连锁" />
          <span v-if="err.company" class="err-msg">{{ err.company }}</span>
        </div>
        <div class="field">
          <label class="label">联系人<span class="req">*</span></label>
          <input v-model="form.contact" class="input" :class="{ error: err.contact }" placeholder="请输入联系人姓名" />
          <span v-if="err.contact" class="err-msg">{{ err.contact }}</span>
        </div>
        <div class="field">
          <label class="label">联系电话</label>
          <input v-model="form.phone" class="input" placeholder="手机号或座机" />
        </div>
        <div class="field">
          <label class="label">线索来源</label>
          <select v-model="form.source" class="select">
            <option v-for="s in sourceOptions" :key="s">{{ s }}</option>
          </select>
        </div>
        <div class="field">
          <label class="label">线索等级</label>
          <select v-model="form.level" class="select">
            <option value="A">A 级（高意向）</option>
            <option value="B">B 级（中意向）</option>
            <option value="C">C 级（低意向）</option>
          </select>
        </div>

        <div class="field">
          <label class="label">客户类型</label>
          <input v-model="form.industry" class="input" placeholder="如：汽修连锁 / 汽配经销商" />
        </div>
        <div class="field span-2">
          <label class="label">备注</label>
          <textarea v-model="form.note" class="textarea" placeholder="补充线索背景、沟通要点等信息" />
        </div>
      </div>
    </ModalDialog>

    <!-- 分配线索（无负责人的新线索，单条 / 批量共用） -->
    <ModalDialog
      v-model="assignOpen"
      title="分配线索"
      :desc="assignDesc"
      :ok-text="assignRows.length > 1 ? `确认分配 ${assignRows.length} 条` : '确认分配'"
      :loading="assigning"
      @confirm="submitAssign"
    >
      <div class="lv-sheet">
        <div class="lv-sheet-head">
          <span>待分配线索</span>
          <b>{{ assignRows.length }} 条</b>
        </div>
        <ul class="lv-list">
          <li v-for="r in assignPreview" :key="r.id">
            <span class="lv-dot"><AppIcon name="target" :size="12" /></span>
            <strong>{{ r.company }}</strong>
            <span class="lv-meta">{{ r.level }} 级 · {{ r.source }}</span>
          </li>
          <li v-if="assignRows.length > 3" class="lv-more">
            还有 {{ assignRows.length - 3 }} 条，分配后可在「销售线索」中按负责人查看
          </li>
        </ul>
      </div>

      <div class="lv-pick">
        <div class="lv-pick-head">
          <label class="label">接收人<span class="req">*</span></label>
          <span class="lv-pick-hint">右侧是在跟线索 / 客户数，可按负载排序</span>
        </div>
        <AssigneePicker
          v-model="assignForm.empId"
          :employees="assignEmployeesWithLoad"
          :departments="deptOptions"
          :loading="employeeStore.loading && !assignableEmployees.length"
          :error="employeeStore.error"
          default-dept="销售部"
          hide-foot
          placeholder="搜索姓名 / 工号"
          @retry="reloadEmployees"
        />
      </div>

      <LeadConflictAlert
        v-model="assignForm.ack"
        :conflicts="assignConflicts"
        :target-name="assignTargetName"
        :source="conflictSource"
        action-label="分配"
      />

      <div class="lv-form">
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

    <!-- 转移线索（单条 / 批量共用） -->
    <ModalDialog
      v-model="transferOpen"
      :title="isBatch ? '批量转移线索' : '转移线索'"
      :desc="transferDesc"
      :ok-text="isBatch ? `确认转移 ${transferRows.length} 条` : '确认转移'"
      :loading="submitting"
      @confirm="submitTransfer"
    >
      <!-- 单条：摘要条 -->
      <div v-if="!isBatch" class="lv-lead">
        <span class="tag" :class="levelTone[firstRow.level]">{{ firstRow.level }} 级</span>
        <div class="lv-main">
          <strong>{{ firstRow.company }}</strong>
          <span>{{ firstRow.id }} · {{ firstRow.contact }} · {{ firstRow.phone }}</span>
        </div>
        <span class="tag" :class="statusTone[firstRow.status]">{{ firstRow.status }}</span>
      </div>

      <!-- 批量：待转移清单 -->
      <div v-else class="lv-sheet">
        <div class="lv-sheet-head">
          <span>待转移线索</span>
          <b>{{ transferRows.length }} 条</b>
        </div>
        <ul class="lv-list">
          <li v-for="r in transferPreview" :key="r.id">
            <span class="lv-dot"><AppIcon name="target" :size="12" /></span>
            <strong>{{ r.company }}</strong>
            <span class="lv-meta">{{ r.owner }} · {{ r.source }}</span>
          </li>
          <li v-if="transferRows.length > 4" class="lv-more">
            还有 {{ transferRows.length - 4 }} 条，转移后可在「销售线索」中按负责人查看
          </li>
        </ul>
      </div>

      <div class="lv-flow">
        <div class="lv-who">
          <span class="lv-who-label">当前负责人</span>
          <div class="lv-who-body">
            <template v-if="currentOwners.length > 1">
              <span class="lv-ico"><AppIcon name="users" :size="13" /></span>
              <strong>{{ currentOwners.length }} 位负责人</strong>
            </template>
            <template v-else-if="hasOwner">
              <UserAvatar :name="firstRow.owner" size="sm" />
              <strong>{{ firstRow.owner }}</strong>
            </template>
            <template v-else>
              <span class="lv-ph"><AppIcon name="user" :size="12" /></span>
              <strong class="pending">未分配</strong>
            </template>
          </div>
        </div>
        <span class="lv-arrow"><AppIcon name="arrow-right" :size="15" /></span>
        <div class="lv-who to">
          <span class="lv-who-label">转给</span>
          <div class="lv-who-body">
            <UserAvatar v-if="transferForm.owner" :name="transferTargetName" size="sm" />
            <span v-else class="lv-ph"><AppIcon name="user" :size="12" /></span>
            <strong :class="{ pending: !transferForm.owner }">{{ transferTargetName || '待选择' }}</strong>
          </div>
        </div>
      </div>

      <div class="lv-form">
        <div class="lv-pick">
          <div class="lv-pick-head">
            <label class="label">接收人<span class="req">*</span></label>
            <span class="lv-pick-hint">右侧是在跟线索 / 客户数，可按负载排序</span>
          </div>
          <AssigneePicker
            v-model="transferForm.owner"
            :employees="transferEmployeesWithLoad"
            :departments="deptOptions"
            :loading="employeeStore.loading && !transferEmployees.length"
            :error="employeeStore.error"
            default-dept="销售部"
            hide-foot
            placeholder="搜索姓名 / 工号"
            @retry="reloadEmployees"
          />
        </div>
        <LeadConflictAlert
          v-model="transferForm.ack"
          class="span-2"
          :conflicts="transferConflicts"
          :target-name="transferTargetName"
          :source="conflictSource"
          action-label="转移"
        />
        <div class="field span-2">
          <label class="label">转移原因</label>
          <select v-model="transferForm.reason" class="select">
            <option v-for="r in REASON_TRANSFER" :key="r">{{ r }}</option>
          </select>
        </div>
        <div class="field span-2">
          <label class="label">交接备注</label>
          <textarea
            v-model="transferForm.note"
            class="textarea"
            placeholder="补充交接说明，例如已沟通过的报价、客户在意的交期等"
          />
        </div>
      </div>

    </ModalDialog>
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import UserAvatar from '@/components/UserAvatar.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import AssigneePicker from '@/components/AssigneePicker.vue'
import LeadConflictAlert from '@/components/LeadConflictAlert.vue'
import { toast } from '@/composables/useToast'
import { leadApi, REASON_TRANSFER, REASON_ASSIGN } from '@/api/leads'
import { employeeStore, loadEmployees, assignableEmployees } from '@/store/employees'
import { flattenDepartments } from '@/store/departments'
import { withAssigneeLoad } from '@/composables/useAssigneeLoad'
import { checkLeadConflicts, filterActiveConflicts } from '@/composables/useLeadConflicts'
import { can } from '@/store/permissions'
import { session } from '@/store/session'

const router = useRouter()
const route = useRoute()

const rows = ref([])

/* ============================================================
 * 数据范围：我的线索 / 全部线索
 * ------------------------------------------------------------
 * 销售顾问（data_scope=self）登录后后端只会返回自己名下的线索，
 * 但页面上原本只有「全部线索」，看不出哪些是刚分过来的。
 * 能分配线索的角色（主管 / 运营）可以切到全部视角看池子与待分配。
 * ============================================================ */
/* 能分配线索的角色一定看全量；此外只要列表里出现了不属于自己的线索，
   也说明这个账号的数据范围不止本人（部门范围的市场/产品运营就没有分配权） */
const canAllLeads = computed(() => {
  if (can('lead.pool.assign')) return true
  const me = session.user?.id
  return rows.value.some((r) => r.ownerId && String(r.ownerId) !== String(me))
})
const scope = ref(canAllLeads.value ? 'all' : 'mine')

const myLeads = computed(() => {
  const me = session.user?.id
  if (!me) return []
  return rows.value.filter((r) => String(r.ownerId) === String(me))
})

const scopedRows = computed(() => (scope.value === 'mine' ? myLeads.value : rows.value))

const headTitle = computed(() => (scope.value === 'mine' ? '我的线索' : '销售线索'))
const headDesc = computed(() =>
  scope.value === 'mine'
    ? '分到你名下的询盘，按「待联系 → 已联系 → 已报样/报价 → 谈判中 → 成交」推进，48 小时内给出首次报价；7 天没有跟进记录会自动回到线索池'
    : '新线索由运营或主管分配给销售；超过 7 天没有跟进记录的线索自动回到线索池'
)
const scopeHint = computed(() => {
  if (scope.value === 'mine') {
    return `你名下共 ${myLeads.value.length} 条，其中待联系 ${myLeads.value.filter((r) => r.status === '待联系').length} 条`
  }
  const pending = rows.value.filter((r) => !r.ownerId && canFlow(r)).length
  return `共 ${rows.value.length} 条，待分配 ${pending} 条 · 7 天未跟进自动进线索池`
})

const emptyTitle = computed(() => {
  if (status.value === UNASSIGNED) return '当前没有待分配线索'
  if (scope.value === 'mine' && !myLeads.value.length) return '还没有线索分到你名下'
  return '没有符合条件的线索'
})
const emptyDesc = computed(() => {
  if (status.value === UNASSIGNED) {
    return '新线索进来会先落在这里，等运营或主管派给销售；已经分下去的可以在「全部线索」里按负责人查看。'
  }
  if (scope.value === 'mine' && !myLeads.value.length) {
    return '运营或主管分配后会出现在这里。如果线索被回收了，可以去线索池看看还有没有能领的。'
  }
  return '换个关键词，或点「重置筛选」看看全部线索。'
})
/* 线索池单独拉一份，只用于撞单核对：同名线索可能正在公海里挂着 */
const poolLeads = ref([])
/* 无归属线索分配接口尚未支持时的提示条，接口通了自然不再出现 */
const apiNote = ref(null)
/* 负责人名单与「设置 › 员工管理」同源，保证筛选、新建、转移看到的是同一批人 */
const owners = computed(() => {
  const set = new Set(assignableEmployees.value.map((e) => e.name))
  rows.value.forEach((r) => r.owner && r.owner !== '未分配' && set.add(r.owner))
  return [...set]
})
/* 线索六态：与数据模块的漏斗阶段一一对应，改这里要同步 analytics.js */
const statusLabels = {
  pending: '待联系',
  contacted: '已联系',
  quoted: '已报样报价',
  negotiating: '谈判中',
  won: '成交',
  /* 老数据里「转为客户」写的是 converted，展示上并入成交 */
  converted: '成交',
  invalid: '无效'
}

let rowsLoaded = false

async function loadRows() {
  rows.value = (await leadApi.list()).map((r) => ({
    ...r,
    owner: r.owner || '未分配',
    /* status 是给表格看的中文，statusRaw 留着算在跟线索——别拿展示文案做逻辑判断 */
    statusRaw: r.status,
    status: statusLabels[r.status],
    createdAt: r.createdAt.replace('T', ' ').slice(0, 16)
  }))
  /* 第一次加载完一条待分配的都没有，就别把运营卡在空列表上 */
  if (!rowsLoaded) {
    rowsLoaded = true
    if (status.value === UNASSIGNED && !hasPending()) status.value = ''
  }
}

/* 有没有还没派下去的线索——决定默认落在哪个 Tab */
function hasPending() {
  return rows.value.some((r) => !r.ownerId && canFlow(r))
}

onMounted(() => {
  loadRows().catch((e) => toast(e.message, 'error'))
  loadEmployees().catch(() => {})
  leadApi
    .list(true)
    .then((data) => {
      poolLeads.value = Array.isArray(data) ? data : []
    })
    .catch(() => {})
})
/* 汽配耗材的实际获客渠道：展会是主力，其次是 1688 店铺与汽配城跑店 */
const sourceOptions = ['汽配展', '1688 询盘', '官网询盘', '汽配城拜访', '客户转介绍', '电话外呼']

/* 「待分配」是流转状态，不是线索状态：新线索进来没有负责人，
   运营 / 主管先在销售线索页把它派下去，这条线索才算真正开工。
   它和「线索池」不是一件事——池子是 7 天没跟进被回收后才去的地方 */
const UNASSIGNED = '__unassigned'

/* 有分配权的人进来先看待办（待分配），销售才进「待联系」 */
const status = ref(canAllLeads.value ? UNASSIGNED : '待联系')
const keyword = ref('')
const source = ref('')
const level = ref('')
const owner = ref('')

const statusTone = {
  待联系: 'tag-warning',
  已联系: 'tag-info',
  已报样报价: 'tag-brand',
  谈判中: 'tag-warning',
  成交: 'tag-success',
  无效: 'tag-gray'
}
const levelTone = {
  A: 'tag-danger',
  B: 'tag-brand',
  C: 'tag-gray'
}

const columns = [
  { key: 'company', label: '线索名称' },
  { key: 'contact', label: '联系人' },
  { key: 'source', label: '来源' },
  { key: 'level', label: '等级', width: '92px' },
  { key: 'owner', label: '负责人', width: '112px' },
  { key: 'status', label: '状态', width: '112px' },
  { key: 'ops', label: '操作', align: 'right', width: '192px' }
]

/* 「待分配」是流程状态，不是线索状态：无负责人且还没进入终态，
   领导进这一页先看这里，把线索派下去，再谈跟进 */

const tabs = computed(() => {
  const src = scopedRows.value
  const count = (fn) => src.filter(fn).length
  const mineMode = scope.value === 'mine'

  /* 销售视角这张表就是自己名下的，再放「待分配」只会是 0 条；
     把它留给能分配线索的角色 */
  const list = []
  if (!mineMode) {
    list.push({ label: '全部线索', value: '', count: src.length })
    list.push({
      label: '待分配',
      value: UNASSIGNED,
      count: count((r) => !r.ownerId && canFlow(r))
    })
  }
  list.push({ label: '待联系', value: '待联系', count: count((r) => r.status === '待联系') })
  list.push({ label: '已联系', value: '已联系', count: count((r) => r.status === '已联系') })
  list.push({ label: '已报样/报价', value: '已报样报价', count: count((r) => r.status === '已报样报价') })
  list.push({ label: '谈判中', value: '谈判中', count: count((r) => r.status === '谈判中') })
  list.push({ label: '成交', value: '成交', count: count((r) => r.status === '成交') })
  list.push({ label: '无效线索', value: '无效', count: count((r) => r.status === '无效') })
  if (mineMode) {
    list.push({ label: '全部', value: '', count: src.length })
  }
  return list
})

const filtered = computed(() =>
  scopedRows.value.filter((r) => {
    if (status.value === UNASSIGNED) {
      if (r.ownerId || !canFlow(r)) return false
    } else if (status.value && r.status !== status.value) {
      return false
    }
    if (source.value && r.source !== source.value) return false
    if (level.value && `${r.level} 级` !== level.value) return false
    if (owner.value && r.owner !== owner.value) return false
    if (keyword.value) {
      const k = keyword.value.trim()
      if (![r.company, r.contact, r.phone, r.id].join(' ').includes(k)) return false
    }
    return true
  })
)

/* 从全局搜索跳过来时只留这一条：其它筛选一并清掉，
   否则命中的那条会被某个 tab 藏起来，看着像「搜到了又没搜到」 */
function applyQueryKeyword(v) {
  keyword.value = v ? String(v) : ''
  if (!v) return
  status.value = ''
  source.value = ''
  level.value = ''
  owner.value = ''
}
applyQueryKeyword(route.query.keyword)
watch(() => route.query.keyword, applyQueryKeyword)

function resetFilters() {
  keyword.value = ''
  source.value = ''
  level.value = ''
  owner.value = ''
  status.value = ''
}

function setScope(next) {
  if (scope.value === next) return
  scope.value = next
  /* 换视角后原来勾的行可能根本不在新范围里，批量操作会打歪 */
  selected.value = []
  /* 切回全部视角时，有待办就先看待办 */
  status.value = next === 'mine' ? '待联系' : hasPending() ? UNASSIGNED : ''
}

/* 权限是异步补上的（刷新页面时 session 先空后满），补好后要落到正确视角：
   有分配权的落「全部线索 › 待分配」，纯销售落「我的线索 › 待联系」 */
watch(canAllLeads, (yes) => {
  if (yes) {
    scope.value = 'all'
    status.value = hasPending() ? UNASSIGNED : ''
  } else {
    scope.value = 'mine'
    status.value = '待联系'
  }
})

/* ---------------- 多选 ---------------- */
const selected = ref([])

/* 选中项可能因筛选离开列表，行数据统一从 rows 里取 */
const selectedRows = computed(() => rows.value.filter((r) => selected.value.includes(r.id)))

/* 只有还没人认领的线索能分配，有主的要走转移 */
const assignableSelection = computed(() => selectedRows.value.filter((r) => !r.ownerId))

/* 换 tab 或改筛选后，看不见的行不该继续被批量操作，直接清空选择 */
watch([status, keyword, source, level, owner], () => {
  if (selected.value.length) selected.value = []
})

const createOpen = ref(false)
const form = reactive({
  company: '',
  contact: '',
  phone: '',
  source: '官网表单',
  level: 'B',

  industry: '',
  note: ''
})
const err = reactive({ company: '', contact: '' })

function openCreate() {
  Object.assign(form, {
    company: '',
    contact: '',
    phone: '',
    source: '官网表单',
    level: 'B',

    industry: '',
    note: ''
  })
  err.company = ''
  err.contact = ''
  createOpen.value = true
}

const savingLead = ref(false)
async function save() {
  if (savingLead.value) return
  err.company = form.company ? '' : '请输入公司名称'
  err.contact = form.contact ? '' : '请输入联系人'
  if (err.company || err.contact) return

  savingLead.value = true
  try {
    await leadApi.create({ ...form })
    createOpen.value = false
    status.value = ''
    toast('线索已创建，可在待分配列表中指派')
    await loadRows()
  } catch (e) {
    toast(e.message, 'error')
  } finally {
    savingLead.value = false
  }
}

function follow(row) {
  toast(`已打开「${row.company}」的跟进记录`)
}

async function convert(row) {
  try {
    await leadApi.convert(row.id)
    row.status = '成交'
    row.statusRaw = 'won'
    toast(`「${row.company}」已转为客户`)
  } catch (e) {
    toast(e.message, 'error')
  }
}

/* ============================================================
 * 转移线索（行内单条 / 顶部批量，同一个弹窗）
 * ------------------------------------------------------------
 * 接口：POST /api/leads/{id}/transfer   单条
 *       POST /api/leads/transfer        批量 { ids, ownerId, reason, note }
 * 接收人名单用 GET /api/employees（设置 › 员工管理），带工号与部门，
 * 便于按部门缩小范围或按姓名 / 工号搜索。
 * ============================================================ */
const transferOpen = ref(false)
const transferRows = ref([])
/* 入口决定弹窗形态：行内「转移」= single，顶部「批量转移」= batch（即使只剩 1 条也不退回单条样式） */
const transferMode = ref('single')
const submitting = ref(false)
const transferForm = reactive({
  owner: null,
  reason: REASON_TRANSFER[0],
  note: '',
  ack: false
})
const transferConflictsRaw = ref([])
const transferConflicts = computed(() =>
  filterActiveConflicts(transferConflictsRaw.value, {
    ownerId: transferForm.owner,
    ownerName: transferTargetName.value
  })
)

const isBatch = computed(() => transferMode.value === 'batch')
const transferDesc = computed(() => {
  if (!isBatch.value) return '转给他人后，原负责人将失去该线索的跟进权限，改为只读可见'
  const n = transferRows.value.length
  if (n > 1) return `勾选的 ${n} 条线索将统一转给同一位负责人，原负责人失去跟进权限`
  return '把这条线索转给他人后，原负责人将失去跟进权限'
})
const firstRow = computed(() => transferRows.value[0] || {})
const transferPreview = computed(() => transferRows.value.slice(0, 4))
/* 线索池里的线索没有负责人，显示成「未分配」而不是拿这个名字去生成头像 */
const hasOwner = computed(() => {
  const o = firstRow.value.owner
  return !!o && o !== '未分配'
})
/* 批量时涉及的现任负责人可能不同，接收人候选要同时排除这些人 */
const currentOwners = computed(() => [
  ...new Set(transferRows.value.map((r) => r.owner).filter((o) => o && o !== '未分配'))
])

/* 成交 / 无效的线索不再流转：既不能转给他人，也不能再转客户。
   statusRaw 是接口原值（pending / won / invalid…），拿它判断才不会
   因为改了展示文案而误判——新建的行还没有 statusRaw，退回看中文 */
const CLOSED_RAW = ['won', 'converted', 'invalid']
function canFlow(row) {
  if (row.statusRaw) return !CLOSED_RAW.includes(row.statusRaw)
  return row.status !== '成交' && row.status !== '无效'
}

/* ============================================================
 * 撞单核对（分配 / 转移共用）
 * ------------------------------------------------------------
 * 分配前先查两件事：这家店是不是已经是某个销售的客户档案，
 * 或者已经有一条同名线索在别人名下。汽配这行一个集团好几家门店，
 * 不问清楚就分下去，两个销售会各自去报一遍价。
 *
 * 优先 POST /api/leads/conflicts；后端没这个接口时退回本地核对
 * （客户档案 + 当前线索 + 线索池），所以现在就能用。
 * ============================================================ */
const conflictSource = ref('local')

function conflictContext() {
  const flat = (l) => ({
    id: l.id,
    company: l.company,
    phone: l.phone,
    owner: l.owner,
    ownerId: l.ownerId,
    statusRaw: l.statusRaw || l.status,
    source: l.source
  })
  return {
    allLeads: [...rows.value.map(flat), ...poolLeads.value.map(flat)],
  }
}

/* 接收人：用真实员工名单，并排除这批线索现在的负责人（转给自己没有意义） */
const deptOptions = computed(() => flattenDepartments())
const transferEmployees = computed(() => {
  const busy = new Set(
    transferRows.value
      .map((r) => r.ownerId)
      .filter((id) => id !== null && id !== undefined)
      .map(Number)
  )
  return assignableEmployees.value.filter((e) => !busy.has(Number(e.rawId)))
})
/* 转移时也要看接收人手里有多少：把在跟线索数挂在候选名单上一起传给选择器 */
const transferEmployeesWithLoad = computed(() =>
  withAssigneeLoad(transferEmployees.value, {
    leads: rows.value.map((r) => ({ ownerId: r.ownerId, status: r.statusRaw }))
  })
)
const transferTargetName = computed(
  () => assignableEmployees.value.find((e) => String(e.rawId) === String(transferForm.owner))?.name || ''
)

function reloadEmployees() {
  loadEmployees({ force: true }).catch(() => toast('员工数据加载失败，请稍后重试', 'error'))
}

async function openTransfer(row) {
  openTransferSheet([row], 'single')
}

function openBatchTransfer() {
  if (!selected.value.length) {
    toast('请先勾选要转移的线索', 'error')
    return
  }
  const picked = selectedRows.value
  /* 还没有负责人的线索谈不上「转移」，那是分配的事 */
  const owned = picked.filter((r) => r.ownerId)
  const flowable = owned.filter(canFlow)
  const unowned = picked.length - owned.length
  const skipped = owned.length - flowable.length
  if (!flowable.length) {
    toast(
      unowned
        ? '勾选的线索都还没有负责人，请用「批量分配」'
        : '勾选的线索都已转化或已标记无效，不能转移',
      'error'
    )
    return
  }
  if (unowned) toast(`已排除 ${unowned} 条待分配线索，请用「批量分配」`, 'info')
  if (skipped) toast(`已排除 ${skipped} 条已转化 / 无效的线索`, 'info')
  openTransferSheet(flowable, 'batch')
}

async function openTransferSheet(list, mode) {
  transferRows.value = list
  transferMode.value = mode
  Object.assign(transferForm, {
    owner: null,
    reason: REASON_TRANSFER[0],
    note: '',
    ack: false
  })
  transferConflictsRaw.value = []
  transferOpen.value = true
  if (!employeeStore.loaded) loadEmployees().catch(() => {})
  refreshTransferConflicts()
}

async function refreshTransferConflicts() {
  const list = transferRows.value
  const { items, source } = await checkLeadConflicts(list, conflictContext())
  if (!transferOpen.value) return
  transferConflictsRaw.value = items
  conflictSource.value = source
}

function doneTransfer(list, owner) {
  // 转移后若正在按原负责人筛选，这些行会自然移出列表，符合预期
  list.forEach((r) => {
    r.owner = owner
    r.ownerId = transferForm.owner
  })
  const moved = new Set(list.map((r) => r.id))
  selected.value = selected.value.filter((id) => !moved.has(id))
  transferOpen.value = false
}

async function submitTransfer() {
  if (!transferForm.owner) {
    toast('请先选择接收人', 'error')
    return
  }
  if (transferConflicts.value.length && !transferForm.ack) {
    toast('请先确认撞单提醒，或换一位接收人', 'error')
    return
  }
  const list = [...transferRows.value]
  const ids = list.map((r) => r.id)
  const body = {
    ids,
    ownerId: transferForm.owner,
    reason: transferForm.reason,
    note: transferForm.note,
  }
  submitting.value = true
  try {
    if (isBatch.value) await leadApi.transferBatch(body)
    else await leadApi.transfer(ids[0], body)
    doneTransfer(list, transferTargetName.value)
    await loadRows()
    toast(
      list.length === 1
        ? `「${list[0].company}」已转给 ${transferTargetName.value}`
        : `${list.length} 条线索已转给 ${transferTargetName.value}`
    )
  } catch (e) {
    toast(e.message || '转移失败，请稍后重试', 'error')
  } finally {
    submitting.value = false
  }
}

/* ============================================================
 * 分配线索（销售线索 › 待分配）
 * ------------------------------------------------------------
 * 流程：新线索进来是「无负责人」状态，就躺在销售线索列表里，
 * 由运营专员（销售运营）或销售主管按月 / 按区域直接派给销售，
 * 派下去才算开工。这跟线索池是两件事——池子是「超过 7 天没有
 * 跟进记录」被系统回收后的地方，销售在那里领取、主管在那里再分配。
 *
 * 接口：POST /api/leads/assign { ids, ownerId, reason, note }
 * 与线索池分配共用同一个「改负责人」动作，权限点 lead.pool.assign；
 * 后端不能要求线索必须已经在池里，否则新线索永远分不出去。
 * ============================================================ */
const assignOpen = ref(false)
const assignRows = ref([])
const assigning = ref(false)
const assignConflictRaw = ref([])
const assignForm = reactive({
  empId: null,
  reason: REASON_ASSIGN[0],
  note: '',
  ack: false
})

const assignPreview = computed(() => assignRows.value.slice(0, 3))
const assignDesc = computed(() => {
  const n = assignRows.value.length
  return n > 1
    ? `把勾选的 ${n} 条线索指派给同一位销售，48 小时内完成首次触达`
    : '指派后由销售在 48 小时内完成首次触达；超过 7 天没有跟进记录，线索会自动回到线索池'
})

/* 候选名单同样挂负载，分配的人先看谁接得住 */
const assignEmployeesWithLoad = computed(() =>
  withAssigneeLoad(assignableEmployees.value, {
    leads: rows.value.map((r) => ({ ownerId: r.ownerId, status: r.statusRaw }))
  })
)
const assignTargetName = computed(
  () => assignableEmployees.value.find((e) => String(e.rawId) === String(assignForm.empId))?.name || ''
)
const assignConflicts = computed(() =>
  filterActiveConflicts(assignConflictRaw.value, {
    ownerId: assignForm.empId,
    ownerName: assignTargetName.value
  })
)

function openAssign(list) {
  const clean = list.filter((r) => !r.ownerId)
  if (!clean.length) {
    toast('勾选的线索都已有负责人，请用「批量转移」', 'error')
    return
  }
  const skipped = list.length - clean.length
  if (skipped) toast(`已排除 ${skipped} 条已有负责人的线索，请用「批量转移」`, 'info')

  assignRows.value = clean
  Object.assign(assignForm, { empId: null, reason: REASON_ASSIGN[0], note: '', ack: false })
  assignConflictRaw.value = []
  assignOpen.value = true
  if (!employeeStore.loaded) loadEmployees().catch(() => {})
  refreshAssignConflicts()
}

function openBatchAssign() {
  if (!selected.value.length) {
    toast('请先勾选要分配的线索', 'error')
    return
  }
  openAssign(selectedRows.value)
}

async function refreshAssignConflicts() {
  const list = assignRows.value
  const { items, source } = await checkLeadConflicts(list, conflictContext())
  if (!assignOpen.value) return
  assignConflictRaw.value = items
  conflictSource.value = source
}

function finishAssign(list, ownerId, name) {
  list.forEach((r) => {
    r.owner = name
    r.ownerId = ownerId
  })
  const moved = new Set(list.map((r) => r.id))
  selected.value = selected.value.filter((id) => !moved.has(id))
  assignOpen.value = false
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

  const list = [...assignRows.value]
  const ids = list.map((r) => r.id)
  const ownerId = assignForm.empId
  const name = assignTargetName.value
  assigning.value = true
  try {
    await leadApi.assign({ ids, ownerId, reason: assignForm.reason, note: assignForm.note })
  } catch (e) {
    toast(e.message || '分配失败，请稍后重试', 'error')
    return
  } finally {
    assigning.value = false
  }
  finishAssign(list, ownerId, name)
  await loadRows().catch((e) => toast(e.message, 'error'))
  toast(`已分配 ${ids.length} 条线索给 ${name}`)
}
</script>

<style scoped>
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
  flex-wrap: nowrap;
}
/* 操作列窄的时候「分配」「转客户」会被折成两行，按钮永远不断行 */
.ops .btn-text {
  white-space: nowrap;
}
.ops .btn-text:disabled {
  color: var(--faint);
  cursor: not-allowed;
  text-decoration: none;
}

/* ---------------- 工具栏选中态 ---------------- */
.picked {
  font-size: 12.5px;
  color: var(--muted);
}
.picked b {
  color: var(--brand);
  font-variant-numeric: tabular-nums;
}
.row-count {
  font-size: 12px;
}

/* ---------------- 我的线索 / 全部线索 ---------------- */
.scope-bar {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 14px;
}
.seg {
  display: inline-flex;
  gap: 2px;
  padding: 3px;
  border: 1px solid var(--line-soft);
  border-radius: 8px;
  background: #f6f8fa;
}
.seg-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 5px 12px;
  border: 0;
  border-radius: 6px;
  background: none;
  color: var(--muted);
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease;
}
.seg-btn b {
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  color: var(--faint);
}
.seg-btn.on {
  background: #fff;
  color: var(--text);
  box-shadow: 0 1px 2px rgba(16, 24, 40, 0.08);
}
.seg-btn.on b {
  color: var(--brand);
}
.seg-btn:not(.on):hover {
  color: var(--text);
}
.scope-hint {
  font-size: 12.5px;
  color: var(--faint);
}

/* ---------------- 空态引导 ---------------- */
.lead-empty {
  display: grid;
  justify-items: center;
  gap: 6px;
}
.lead-empty strong {
  font-size: 13.5px;
  font-weight: 600;
  color: var(--text);
}
.lead-empty p {
  margin: 0;
  max-width: 340px;
  font-size: 12.5px;
  line-height: 1.65;
  color: var(--faint);
}
.lead-empty .btn {
  margin-top: 6px;
}

/* ---------------- 接口提示条 ---------------- */
.api-note {
  display: flex;
  gap: 10px;
  align-items: flex-start;
  padding: 12px 16px;
  margin-bottom: 16px;
  border: 1px solid #d8e3f3;
  border-radius: var(--radius-sm);
  background: #f7fafd;
}
.an-close {
  margin-left: auto;
  padding: 0;
  width: 20px;
  height: 20px;
  display: grid;
  place-items: center;
  border: 0;
  background: none;
  color: var(--faint);
  cursor: pointer;
  border-radius: 4px;
}
.an-close:hover {
  background: #eaf1fa;
  color: var(--muted);
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

/* ---------------- 转移弹窗 ---------------- */
.lv-lead {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  border: 1px solid var(--line-soft);
  border-radius: var(--radius-sm);
  background: #fafbfd;
}
.lv-lead .tag {
  flex-shrink: 0;
}
.lv-main {
  flex: 1;
  min-width: 0;
}
.lv-main strong {
  display: block;
  font-size: 13.5px;
  font-weight: 600;
  color: var(--ink);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.lv-main span {
  display: block;
  margin-top: 3px;
  font-size: 12px;
  color: var(--faint);
}

/* 批量：待转移清单 */
.lv-sheet {
  border: 1px solid var(--line-soft);
  border-radius: var(--radius-sm);
  overflow: hidden;
}
.lv-sheet-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 9px 13px;
  background: #f7f9fc;
  border-bottom: 1px solid var(--line-soft);
  font-size: 12.5px;
  color: var(--muted);
}
.lv-sheet-head b {
  color: var(--ink);
  font-variant-numeric: tabular-nums;
}
.lv-list {
  padding: 6px 0;
  margin: 0;
  list-style: none;
  max-height: 172px;
  overflow-y: auto;
}
.lv-list li {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 13px;
  font-size: 12.8px;
}
.lv-list li strong {
  font-weight: 550;
  color: var(--ink);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.lv-dot {
  width: 18px;
  height: 18px;
  border-radius: 5px;
  display: grid;
  place-items: center;
  background: var(--brand-soft);
  color: var(--brand);
  flex-shrink: 0;
}
.lv-meta {
  margin-left: auto;
  font-size: 11.5px;
  color: var(--faint);
  white-space: nowrap;
}
.lv-list li.lv-more {
  color: var(--faint);
  font-size: 11.8px;
  line-height: 1.6;
  padding-top: 4px;
}

.lv-flow {
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
  gap: 10px;
  margin: 14px 0;
}
.lv-who {
  padding: 10px 12px;
  border: 1px solid var(--line-soft);
  border-radius: var(--radius-sm);
  background: var(--surface);
}
.lv-who.to {
  border-color: #cfe0f2;
  background: #f7fafd;
}
.lv-who-label {
  display: block;
  margin-bottom: 6px;
  font-size: 11.5px;
  color: var(--faint);
}
.lv-who-body {
  display: flex;
  align-items: center;
  gap: 7px;
  font-size: 13px;
}
.lv-who-body strong {
  font-weight: 600;
  color: var(--ink);
}
.lv-who-body strong.pending {
  font-weight: 500;
  color: var(--faint);
}
.lv-ico {
  width: 24px;
  height: 24px;
  border-radius: 6px;
  display: grid;
  place-items: center;
  background: var(--brand-soft);
  color: var(--brand);
  flex-shrink: 0;
}
/* 未选择接收人时的占位头像 */
.lv-ph {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  border: 1px dashed #c6d0dc;
  color: var(--faint);
  flex-shrink: 0;
}
.lv-arrow {
  display: grid;
  place-items: center;
  color: #b6c0cd;
}

.lv-form {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px 14px;
}
.lv-form .span-2 {
  grid-column: span 2;
}
.lv-pick {
  grid-column: span 2;
}
.lv-pick-head {
  display: flex;
  align-items: baseline;
  gap: 10px;
  margin-bottom: 8px;
}
.lv-pick-head .label {
  margin-bottom: 0;
}
.lv-pick-hint {
  font-size: 11.8px;
  color: var(--faint);
  line-height: 1.5;
}

.lv-ack {
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
.lv-ack input {
  margin: 2px 0 0;
  accent-color: var(--brand);
}
</style>





