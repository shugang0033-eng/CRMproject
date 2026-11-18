<template>
  <div class="page">
    <PageHead title="业绩目标" desc="部门按季度承诺，个人按月拆解；完成额取真实已签合同（不含待审批、作废、终止）">
      <div class="seg">
        <button type="button" :class="{ on: view === 'dept' }" @click="switchView('dept')">部门季度</button>
        <button type="button" :class="{ on: view === 'employee' }" @click="switchView('employee')">个人月度</button>
      </div>

      <div v-if="view === 'dept'" class="period-switch">
        <button class="ps-btn" type="button" title="上一季度" @click="shiftPeriod(-1)">
          <AppIcon name="chevron-left" :size="14" />
        </button>
        <select v-model="periodState.label" class="ps-select">
          <option v-for="p in periodOptions" :key="p" :value="p">{{ p }}</option>
        </select>
        <button class="ps-btn" type="button" title="下一季度" @click="shiftPeriod(1)">
          <AppIcon name="chevron-right" :size="14" />
        </button>
        <button v-if="!isCurrentQuarter" class="btn-text" type="button" @click="setPeriod(QUARTER.label)">
          回本季度
        </button>
      </div>

      <div v-else class="period-switch">
        <button class="ps-btn" type="button" title="上个月" @click="shiftMonth(-1)">
          <AppIcon name="chevron-left" :size="14" />
        </button>
        <select v-model="monthState.label" class="ps-select">
          <option v-for="m in monthOptions" :key="m" :value="m">{{ periodLabel(m) }}</option>
        </select>
        <button class="ps-btn" type="button" title="下个月" @click="shiftMonth(1)">
          <AppIcon name="chevron-right" :size="14" />
        </button>
        <button v-if="!isCurrentMonth" class="btn-text" type="button" @click="setMonth(currentMonth())">
          回本月
        </button>
      </div>

      <button v-can="'target.manage'" class="btn btn-primary" type="button" @click="openBatch()">
        <AppIcon name="plus" :size="14" />{{ view === 'dept' ? '设置部门目标' : '设置个人目标' }}
      </button>
    </PageHead>

    <div v-if="error" class="api-note">
      <AppIcon name="flag" :size="13" />
      <span>{{ error }}。下面只显示目标金额，完成额留空，不拿 0 冒充。</span>
    </div>

    <!-- 部门负责人只能改自己这一摊，先把范围说清，免得以为系统坏了 -->
    <div v-if="!targetScope.all && canSeeAllPeople" class="api-note scope-note">
      <AppIcon name="shield" :size="13" />
      <span>
        你的管理范围：<b>{{ scopeDeptNames.join('、') || '还未分配部门' }}</b>。
        只能调整这些部门（含下级）的季度目标、以及这些部门成员的月度目标，其它部门不显示。
      </span>
    </div>
    <div v-else-if="!targetScope.all" class="api-note scope-note">
      <AppIcon name="eye-off" :size="13" />
      <span>
        你只能查看 <b>{{ scopeDeptNames.join('、') || '本部门' }}</b> 的目标，不能修改；
        要调整找部门负责人或管理员。
      </span>
    </div>

    <template v-if="view === 'dept'">
    <div v-if="!summary.configured && !loading" class="api-note">
      <AppIcon name="flag" :size="13" />
      <span>
        {{ summary.label }} 还没给{{ targetScope.all ? '任何部门' : '你管理的部门' }}设目标，所以没有完成率可算。
        点右上角「设置业绩目标」一次填完整张表；完成额会自动取该季度已签合同。
      </span>
    </div>

    <!-- 上级目标小于子部门目标之和时，完成率会虚高，必须当面说清 -->
    <div v-if="targetConflicts.length" class="api-note warn">
      <AppIcon name="flag" :size="13" />
      <span>
        <b>目标层级对不上：</b>
        <template v-for="(c, i) in targetConflicts" :key="c.parent">
          <template v-if="i">；</template>
          「{{ c.parent }}」目标 ¥{{ wan(c.parentTarget) }} 万，但下属部门合计 ¥{{ wan(c.childSum) }} 万
        </template>
        。上级的「已完成」已经含下属部门，上级目标小于子部门之和会算出超过 100% 的完成率——
        要么把上级目标调到不低于子部门之和，要么只给一层设目标。
      </span>
    </div>

    <div class="summary">
      <div class="sm card">
        <span>{{ targetScope.all ? '季度总目标' : '本部门季度目标' }}</span>
        <b>¥{{ wan(summary.target) }} <i>万</i></b>
        <span class="faint tiny">{{ summary.rows }} 个部门已设 · 父部门目标含下属</span>
      </div>
      <div class="sm card">
        <span>已完成</span>
        <b class="ok">{{ summary.achieved == null ? '—' : `¥${wan(summary.achieved)} 万` }}</b>
        <span class="faint tiny">{{ summary.label }} 已签合同金额</span>
      </div>
      <div class="sm card">
        <span>整体完成率</span>
        <b>{{ summary.pct == null ? '—' : `${summary.pct}%` }}</b>
        <div class="bar"><i :style="{ width: Math.min(100, summary.pct || 0) + '%', background: barColor(summary.pct) }" /></div>
        <span class="faint tiny">
          {{ summary.diff == null ? '还没有目标' : summary.diff <= 0 ? `已超额 ¥${wan(-summary.diff)} 万` : `还差 ¥${wan(summary.diff)} 万` }}
        </span>
      </div>
      <div class="sm card">
        <span>节奏</span>
        <b class="pace-num" :class="paceClass">{{ summary.configured ? summary.pace.text : '—' }}</b>
        <span class="faint tiny">
          {{ summary.pct != null ? `时间已过 ${summary.timePct}%，完成 ${summary.pct}%` : '设了目标才能判断快慢' }}
        </span>
      </div>
    </div>

    <div class="card">
      <div class="card-head">
        <div class="card-title"><span class="dot" />部门目标明细</div>
        <span class="card-sub">
          {{ rows.length }} 个部门 · 上级部门的已完成含下属部门
          <template v-if="isCurrentQuarter"> · 剩余 {{ daysLeft }} 天</template>
        </span>
      </div>

      <AppTable :columns="columns" :rows="rows" :page-size="20" :show-pager="false">
        <template #cell-name="{ row }">
          <div class="cell-main" :style="{ paddingLeft: row.depth * 14 + 'px' }">
            <span v-if="row.depth" class="tree-line">└</span>{{ row.name }}
          </div>
          <div v-if="row.note" class="cell-sub">{{ row.note }}</div>
        </template>
        <template #cell-leader="{ row }">
          <span v-if="row.leader && row.leader !== '—'" class="row-tight">
            <UserAvatar :name="row.leader" size="sm" />
            {{ row.leader }}
          </span>
          <span v-else class="faint">未指定</span>
        </template>
        <template #cell-target="{ row }">
          <span v-if="row.target" class="num">¥{{ row.target.toLocaleString() }}</span>
          <span v-else class="faint">未设目标</span>
        </template>
        <template #cell-achieved="{ row }">
          <span v-if="row.achieved == null" class="faint">—</span>
          <span v-else class="num">
            ¥{{ Math.round(row.achieved).toLocaleString() }}
            <em v-if="row.children && row.achieved > 0" class="rollup">含子部门</em>
          </span>
        </template>
        <template #cell-progress="{ row }">
          <div v-if="row.pct != null" class="prog">
            <div class="bar">
              <i :style="{ width: Math.min(100, row.pct) + '%', background: barColor(row.pct) }" />
            </div>
            <span :class="{ done: row.pct >= 100 }">{{ row.pct }}%</span>
          </div>
          <span v-else class="faint">—</span>
        </template>
        <template #cell-gap="{ row }">
          <span v-if="!row.configured || row.achieved == null" class="faint">—</span>
          <span v-else class="num" :class="{ pos: row.gapAmount <= 0 }">
            {{ row.gapAmount <= 0 ? '已达成' : `¥${Math.round(row.gapAmount).toLocaleString()}` }}
          </span>
        </template>
        <template #cell-pace="{ row }">
          <span v-if="row.pace.tone === 'none'" class="faint">—</span>
          <span v-else class="pace" :class="row.pace.tone">{{ row.pace.text }}</span>
        </template>
        <template #cell-ops="{ row }">
          <div class="row-tight ops">
            <button v-can="'target.manage'" class="btn-text" type="button" @click="openBatch(row.id)">
              {{ row.configured ? '调整目标' : '设置目标' }}
            </button>
          </div>
        </template>
      </AppTable>
    </div>
    </template>

    <!-- ==================== 个人月度目标 ==================== -->
    <template v-else>
      <div v-if="!individual.configured && !loading" class="api-note">
        <AppIcon name="flag" :size="13" />
        <span v-if="canSeeAllPeople">
          {{ periodLabel(monthState.label) }} 还没给任何人设个人目标，所以每个人的「本月还差多少」算不出来。
          点右上角「设置个人目标」按人填一遍；部门季度目标照常在「部门季度」里维护。
        </span>
        <span v-else>
          {{ periodLabel(monthState.label) }} 还没给你设个人目标，所以「本月还差多少」算不出来。
          找部门负责人或管理员在「业绩目标 › 设置个人目标」里填一下。
        </span>
      </div>

      <!-- 部门设了季度目标却没拆到人：月底没法判断谁完成谁没完成 -->
      <div v-if="unsplitDepts.length && !loading" class="api-note warn">
        <AppIcon name="flag" :size="13" />
        <span>
          <b>目标还没拆到人：</b>
          <template v-for="(d, i) in unsplitDepts" :key="d.id">
            <template v-if="i">；</template>「{{ d.name }}」
          </template>
          ：
          {{ periodState.label }} 有部门目标，但 {{ periodLabel(monthState.label) }} 没有任何个人目标。
          不拆到人，月底只能看到部门总数，看不出谁差多少。
        </span>
      </div>

      <div class="summary">
        <div class="sm card">
          <span>{{ canSeeAllPeople ? '本月个人目标合计' : '我的本月目标' }}</span>
          <b>¥{{ wan(individual.target) }} <i>万</i></b>
          <span class="faint tiny">
            {{ canSeeAllPeople ? `${individual.setCount} / ${goalRows.length} 人已设` : (individual.configured ? '已设本月目标' : '本月还没设目标') }}
          </span>
        </div>
        <div class="sm card">
          <span>本月已完成</span>
          <b class="ok">{{ individual.achieved == null ? '—' : `¥${wan(individual.achieved)} 万` }}</b>
          <span class="faint tiny">
            <template v-if="!canSeeAllPeople">{{ periodLabel(monthState.label) }} 我名下已签合同金额</template>
            <template v-else>
              {{ individual.setCount }} 人合计
              <template v-if="individual.unsetCount">
                · {{ individual.unsetCount }} 人未设目标<template v-if="individual.unsetAchieved > 0">，已签 ¥{{ wan(individual.unsetAchieved) }} 万</template>
              </template>
            </template>
          </span>
        </div>
        <div class="sm card">
          <span>本月完成率</span>
          <b>{{ individual.pct == null ? '—' : `${individual.pct}%` }}</b>
          <div class="bar">
            <i :style="{ width: Math.min(100, individual.pct || 0) + '%', background: barColor(individual.pct) }" />
          </div>
          <span class="faint tiny">
            {{ individual.diff == null
              ? (individual.configured ? '完成额暂不可见，所以算不出差距' : '还没有个人目标')
              : individual.diff <= 0 ? `已超额 ¥${wan(-individual.diff)} 万` : `还差 ¥${wan(individual.diff)} 万` }}
          </span>
        </div>
        <div class="sm card">
          <span>本月节奏</span>
          <b class="pace-num" :class="paceClass">{{ individual.configured ? individual.pace.text : '—' }}</b>
          <span class="faint tiny">
            {{ individual.configured && individual.pct != null ? `时间已过 ${individual.timePct}%，完成 ${individual.pct}%` : '设了目标、且能看到完成额才能判断快慢' }}
          </span>
        </div>
      </div>

      <div class="card">
        <div class="card-head">
          <div class="card-title"><span class="dot" />个人目标明细</div>
          <span class="card-sub">
            <template v-if="canSeeAllPeople">
              {{ goalRows.length }} 名在职员工 · 完成额按合同负责人归集
              <template v-if="isCurrentMonth"> · 本月剩余 {{ daysLeftInMonth(monthState.label) }} 天</template>
            </template>
            <template v-else>
              我的目标 · 完成额按我名下合同的签订日归集
              <template v-if="isCurrentMonth"> · 本月剩余 {{ daysLeftInMonth(monthState.label) }} 天</template>
            </template>
          </span>
        </div>

        <AppTable :columns="personColumns" :rows="goalRows" :page-size="20" :show-pager="false">
          <template #cell-name="{ row }">
            <div class="cell-main">{{ row.name }}</div>
            <div class="cell-sub">{{ row.dept }}</div>
          </template>
          <template #cell-target="{ row }">
            <span v-if="row.configured" class="num">¥{{ row.target.toLocaleString() }}</span>
            <span v-else class="faint">未设目标</span>
          </template>
          <template #cell-achieved="{ row }">
            <span v-if="row.achieved == null" class="faint">—</span>
            <span v-else class="num">¥{{ Math.round(row.achieved).toLocaleString() }}</span>
          </template>
          <template #cell-progress="{ row }">
            <div v-if="row.pct != null" class="prog">
              <div class="bar">
                <i :style="{ width: Math.min(100, row.pct) + '%', background: barColor(row.pct) }" />
              </div>
              <span :class="{ done: row.pct >= 100 }">{{ row.pct }}%</span>
            </div>
            <span v-else class="faint">—</span>
          </template>
          <template #cell-gap="{ row }">
            <span v-if="!row.configured || row.achieved == null" class="faint">—</span>
            <span v-else class="num" :class="{ pos: row.target - row.achieved <= 0 }">
              {{ row.target - row.achieved <= 0 ? '已达成' : `¥${Math.round(row.target - row.achieved).toLocaleString()}` }}
            </span>
          </template>
          <template #cell-note="{ row }">
            <span v-if="row.note" class="note-cell">{{ row.note }}</span>
            <span v-else class="faint">—</span>
          </template>
          <template #cell-ops="{ row }">
            <div class="row-tight ops">
              <button v-can="'target.manage'" class="btn-text" type="button" @click="openBatch(row.id)">
                {{ row.configured ? '调整目标' : '设置目标' }}
              </button>
            </div>
          </template>
        </AppTable>
      </div>
    </template>

    <!-- 一次填完整张表：季度规划本来就是一次性动作，逐行弹窗点 5 次没人受得了 -->
    <ModalDialog
      v-model="batchOpen"
      width="wide"
      :title="editTitle"
      :desc="editDesc"
      :ok-text="changedCount ? `保存 ${changedCount} 项` : '保存'"
      @confirm="saveBatch"
    >
      <div class="batch">
        <table v-if="editScope === 'dept'" class="mini">
          <thead>
            <tr>
              <th>部门</th>
              <th>负责人</th>
              <th class="r">当前完成</th>
              <th class="r w-amt">目标金额</th>
              <th class="w-note">备注</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="d in editableDepts" :key="d.id">
              <td>
                <span class="dept-name" :style="{ paddingLeft: d.depth * 14 + 'px' }">
                  <span v-if="d.depth" class="tree-line">└</span>{{ d.name }}
                </span>
                <div class="cell-sub">{{ d.count || 0 }} 人</div>
              </td>
              <td class="ellip">{{ d.leader || '未指定' }}</td>
              <td class="r num faint">
                {{ d.achieved == null ? '—' : `¥${Math.round(d.achieved).toLocaleString()}` }}
              </td>
              <td class="r">
                <input
                  :ref="(el) => setInputRef(d.id, el)"
                  v-model.number="batch[d.id]"
                  class="input w-amt"
                  type="number"
                  min="0"
                  step="10000"
                  placeholder="0"
                  @keydown.enter.prevent="saveBatch"
                />
              </td>
              <td>
                <input v-model.trim="batchNote[d.id]" class="input" type="text" placeholder="如：含新签 60%" />
              </td>
            </tr>
            <tr v-if="!editableDepts.length">
              <td colspan="5" class="empty-line">还没有部门，先去「设置 › 部门管理」建一个</td>
            </tr>
          </tbody>
        </table>

        <table v-else class="mini">
          <thead>
            <tr>
              <th>员工</th>
              <th class="r">本月已完成</th>
              <th class="r w-amt">本月目标</th>
              <th class="w-note">备注</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in editablePeople" :key="p.id">
              <td>
                <span class="dept-name">{{ p.name }}</span>
                <div class="cell-sub">{{ p.dept }}</div>
              </td>
              <td class="r num faint">
                {{ p.achieved == null ? '—' : `¥${Math.round(p.achieved).toLocaleString()}` }}
              </td>
              <td class="r">
                <input
                  :ref="(el) => setInputRef(p.id, el)"
                  v-model.number="batch[p.id]"
                  class="input w-amt"
                  type="number"
                  min="0"
                  step="5000"
                  placeholder="0"
                  @keydown.enter.prevent="saveBatch"
                />
              </td>
              <td>
                <input v-model.trim="batchNote[p.id]" class="input" type="text" placeholder="如：含新签 30 万" />
              </td>
            </tr>
            <tr v-if="!editablePeople.length">
              <td colspan="4" class="empty-line">还没有员工，先去「设置 › 员工管理」建一个</td>
            </tr>
          </tbody>
        </table>

        <p class="alloc-note">{{ editNote }}</p>
      </div>
    </ModalDialog>
  </div>
</template>

<script setup>
import { computed, nextTick, onMounted, reactive, ref } from 'vue'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import UserAvatar from '@/components/UserAvatar.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import { toast } from '@/composables/useToast'
import { employeeStore } from '@/store/employees'
import { session } from '@/store/session'
import { targetOf, targetOfEmployee, targetState, saveTargets, periodLabel, targetScope } from '@/store/targets'
import {
  QUARTER, periodState, periodOptions, isCurrentQuarter, setPeriod, shiftPeriod,
  targetProgress, targetSummary, progressState, daysLeft, loadTargetBase,
  monthState, monthOptions, setMonth, shiftMonth, currentMonth, isCurrentMonth,
  goalRows, canSeeAllPeople, daysLeftInMonth, monthSummary,
  scopeDepts, scopeDeptNames, goalOfEmployee
} from '@/composables/useTargetProgress'

const loading = computed(() => targetState.loading || progressState.loading)
const error = computed(() => targetState.error || progressState.error)
const summary = computed(() => targetSummary.value)
const rows = computed(() => targetProgress.value)

const columns = [
  { key: 'name', label: '部门' },
  { key: 'leader', label: '负责人', width: '120px' },
  { key: 'headcount', label: '人数', width: '64px' },
  { key: 'target', label: '目标金额', width: '132px' },
  { key: 'achieved', label: '已完成', width: '164px' },
  { key: 'progress', label: '完成率', width: '156px' },
  { key: 'gap', label: '差距', width: '124px' },
  { key: 'pace', label: '节奏', width: '116px' },
  { key: 'ops', label: '操作', align: 'right', width: '96px' }
]

const personColumns = [
  { key: 'name', label: '员工' },
  { key: 'target', label: '本月目标', width: '132px', align: 'right' },
  { key: 'achieved', label: '本月已完成', width: '150px', align: 'right' },
  { key: 'progress', label: '完成率', width: '156px' },
  { key: 'gap', label: '差距', width: '124px', align: 'right' },
  { key: 'note', label: '备注', width: '220px' },
  { key: 'ops', label: '操作', align: 'right', width: '96px' }
]

/* 部门季度 / 个人月度 两个视角。切视角不动数据，只换看哪张表。
   只能看自己目标的人默认落在个人视图，省得先看到一张全是部门汇总的表却改不了 */
const view = ref(canSeeAllPeople.value ? 'dept' : 'employee')
function switchView(v) {
  view.value = v
}

function wan(n) {
  if (n == null) return '—'
  return (n / 10000).toLocaleString('zh-CN', { maximumFractionDigits: 1 })
}

function barColor(p) {
  if (p == null) return '#c8ced8'
  if (p >= 100) return '#12805c'
  if (p >= 60) return '#2b6cb0'
  return '#c98a2e'
}

const paceClass = computed(() => {
  const tone = view.value === 'dept' ? summary.value.pace.tone : individual.value.pace.tone
  return tone === 'ahead' ? 'pos' : tone === 'behind' ? 'neg' : ''
})

/* ---------------- 个人月度汇总 ---------------- */

/* 管目标的人看本部门合计；只有自己那一行的人必须看自己的，
   否则会把同事的完成额算成「我的」，页面直接说假话 */
const individual = computed(() => (canSeeAllPeople.value
  ? monthSummary.value
  : goalOfEmployee(session.user?.id, monthState.label)))

/**
 * 设了季度目标、但本月没有任何人设目标的部门。
 * 不提示的话，季度末会有人问「销售部完成率怎么只有 3%」——因为目标从来没拆到人。
 */
const unsplitDepts = computed(() => {
  /* 「有没有拆到人」是管理视角的判断；只有自己那一行的人看到这条只会误以为全公司都没设目标 */
  if (!canSeeAllPeople.value) return []
  const flat = scopeDepts.value
  const children = new Map()
  flat.forEach((d) => {
    if (d.parentId == null) return
    const k = String(d.parentId)
    if (!children.has(k)) children.set(k, [])
    children.get(k).push(d)
  })
  const deptOfEmp = new Map(employeeStore.list.map((e) => [String(e.rawId), String(e.deptId)]))
  const monthTargetOf = new Map(goalRows.value.map((p) => [String(p.id), p.target]))
  const sumUnder = (d, guard = 0) => {
    if (guard > 8) return 0
    let sum = 0
    for (const [empId, deptId] of deptOfEmp) {
      if (deptId === String(d.id)) sum += monthTargetOf.get(empId) || 0
    }
    for (const c of children.get(String(d.id)) || []) sum += sumUnder(c, guard + 1)
    return sum
  }
  return flat
    .filter((d) => Number(targetOf(d.id, periodState.label)?.target || 0) > 0)
    .filter((d) => sumUnder(d) === 0)
    .map((d) => ({ id: d.id, name: d.name }))
})

/**
 * 上级目标 < 子部门目标之和 → 完成率会超过 100%，先提示再让人保存。
 * 这是「上级完成额含子部门」这个口径必然带来的坑，不提示的话每到季度末
 * 都会有人问「为什么销售部完成率 130%」。
 */
const targetConflicts = computed(() => {
  const flat = scopeDepts.value
  const byId = new Map(flat.map((d) => [String(d.id), d]))
  const children = new Map()
  flat.forEach((d) => {
    if (d.parentId == null) return
    const k = String(d.parentId)
    if (!children.has(k)) children.set(k, [])
    children.get(k).push(d)
  })
  const out = []
  for (const [pid, list] of children) {
    const parent = byId.get(pid)
    if (!parent) continue
    const pTarget = Number(targetOf(parent.id, periodState.label)?.target || 0)
    if (pTarget <= 0) continue
    const childSum = list.reduce((s, c) => s + Number(targetOf(c.id, periodState.label)?.target || 0), 0)
    if (childSum > pTarget) out.push({ parent: parent.name, parentTarget: pTarget, childSum })
  }
  return out
})

/* ---------------- 批量设置 ---------------- */

const batchOpen = ref(false)
/** 弹窗当前编辑的是哪种范围：部门季度目标 / 个人月度目标 */
const editScope = ref('dept')
const batch = reactive({})
const batchNote = reactive({})
const baseline = reactive({})
const baselineNote = reactive({})
const inputRefs = new Map()

const setInputRef = (id, el) => {
  if (el) inputRefs.set(String(id), el)
  else inputRefs.delete(String(id))
}

/** 弹窗里顺便显示「当前已完成」，否则目标定多少全靠猜 */
const editableDepts = computed(() => {
  const flat = scopeDepts.value
  const done = new Map(rows.value.map((r) => [String(r.id), r.achieved]))
  return flat.map((d) => ({ ...d, achieved: done.get(String(d.id)) ?? null }))
})

/** 个人视图弹窗的行：在职员工 + 本月已完成 + 本月目标 */
const editablePeople = computed(() => goalRows.value.map((p) => ({
  id: p.id,
  name: p.name,
  dept: p.dept,
  achieved: p.achieved
})))

function isChanged(id) {
  const t = Number(batch[id] || 0)
  return t !== Number(baseline[id] || 0) || (batchNote[id] || '') !== (baselineNote[id] || '')
}

const changedCount = computed(() =>
  (editScope.value === 'dept' ? editableDepts.value : editablePeople.value).filter((x) => isChanged(x.id)).length
)

const editTitle = computed(() => editScope.value === 'dept'
  ? `设置 ${periodState.label} 部门目标`
  : `设置 ${periodLabel(monthState.label)} 个人目标`)

const editDesc = computed(() => editScope.value === 'dept'
  ? '按部门填季度目标；留空或填 0 表示该部门本季度不设目标。上级部门的完成额含下属部门'
  : '按人填本月目标；留空或填 0 表示本月不给他设目标。完成额取他本人负责、本月签订的有效合同')

const editNote = computed(() => editScope.value === 'dept'
  ? '完成额按合同签订日归季：本季度内签订、且状态不是「待审批 / 已作废 / 已终止」的合同金额，按合同负责人所在部门归集，并逐级累加给上级部门。目标留 0 并保存会清掉该部门本季度目标（不是设成 0 元）。'
  : '个人目标按月存，季度数由该季度三个月相加得到，所以改某个月不会牵动整张季度表。完成额只算他本人负责的合同（按合同负责人 id 精确匹配，不按姓名），本月签订、状态有效才算。')

function openBatch(focusId, scope = view.value) {
  editScope.value = scope
  inputRefs.clear()
  Object.keys(batch).forEach((k) => delete batch[k])
  Object.keys(batchNote).forEach((k) => delete batchNote[k])
  Object.keys(baseline).forEach((k) => delete baseline[k])
  Object.keys(baselineNote).forEach((k) => delete baselineNote[k])

  const rowsSrc = scope === 'dept'
    ? scopeDepts.value.map((d) => ({ id: d.id, row: targetOf(d.id, periodState.label) }))
    : goalRows.value.map((p) => ({ id: p.id, row: targetOfEmployee(p.id, monthState.label) }))

  rowsSrc.forEach(({ id, row }) => {
    batch[id] = row?.target || 0
    batchNote[id] = row?.note || ''
    baseline[id] = row?.target || 0
    baselineNote[id] = row?.note || ''
  })
  batchOpen.value = true

  if (focusId != null) {
    /* 行内「调整目标」进来：滚到那一行并选中，省得在长表里找 */
    nextTick(() => {
      const el = inputRefs.get(String(focusId))
      if (el) {
        el.scrollIntoView({ block: 'center' })
        el.focus()
        el.select?.()
      }
    })
  }
}

async function saveBatch() {
  const list = []
  if (editScope.value === 'dept') {
    for (const d of scopeDepts.value) {
      if (!isChanged(d.id)) continue
      const target = Number(batch[d.id] || 0)
      if (target < 0) return toast(`「${d.name}」目标不能为负数`, 'error')
      list.push({ scope: 'dept', scopeId: d.id, period: periodState.label, target, note: batchNote[d.id] || '' })
    }
  } else {
    for (const p of goalRows.value) {
      if (!isChanged(p.id)) continue
      const target = Number(batch[p.id] || 0)
      if (target < 0) return toast(`「${p.name}」目标不能为负数`, 'error')
      list.push({ scope: 'employee', scopeId: p.id, period: monthState.label, target, note: batchNote[p.id] || '' })
    }
  }
  if (!list.length) {
    batchOpen.value = false
    return toast('没有改动')
  }
  try {
    await saveTargets(list)
    await loadTargetBase({ force: true })
  } catch (e) {
    /* 失败不动本地：表里还是用户刚填的值，可以改完再存 */
    return toast(e.message || '保存失败，请重试', 'error')
  }
  batchOpen.value = false
  const label = editScope.value === 'dept' ? periodState.label : periodLabel(monthState.label)
  toast(`「${label}」已保存 ${list.length} 项目标`)
}

onMounted(async () => {
  /* 加载失败由页面顶部的 api-note 说明；这里绝不能把异常抛出去——
     onMounted 里抛错会让 Vue 中断 post 钩子，v-can、弹窗事件全挂上不了，
     表现就是「按钮能看见但点不动」。 */
  try {
    await loadTargetBase()
  } catch {
    /* 已经记在 progressState.error / targetState.error 里 */
  }
})
</script>

<style scoped>
/* 部门季度 / 个人月度 切换 —— 两个视角看同一套目标，不是两套数据 */
.seg {
  display: inline-flex;
  align-items: center;
  gap: 2px;
  height: 36px;
  padding: 3px;
  background: #f2f4f7;
  border-radius: var(--radius-sm);
}
.seg button {
  height: 28px;
  padding: 0 12px;
  border: 0;
  border-radius: 6px;
  background: transparent;
  font-size: 12.5px;
  color: var(--muted);
  cursor: pointer;
  white-space: nowrap;
}
.seg button:hover {
  color: var(--ink);
}
.seg button.on {
  background: #fff;
  color: var(--ink);
  font-weight: 600;
  box-shadow: 0 1px 2px rgba(16, 24, 40, 0.08);
}

.period-switch {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  height: 36px;
  padding: 0 4px;
  border: 1px solid var(--line);
  border-radius: var(--radius-sm);
  background: #fff;
}
.ps-btn {
  width: 26px;
  height: 26px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 0;
  border-radius: 5px;
  background: transparent;
  color: var(--muted);
  cursor: pointer;
}
.ps-btn:hover {
  background: #f3f5f8;
  color: var(--ink);
}
.ps-select {
  height: 26px;
  border: 0;
  background: transparent;
  font-size: 12.5px;
  font-weight: 550;
  color: var(--text);
  font-variant-numeric: tabular-nums;
  cursor: pointer;
  outline: none;
  padding: 0 2px;
}

.summary {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 16px;
  margin-bottom: 16px;
}
.sm {
  padding: 14px 18px;
  display: flex;
  flex-direction: column;
  gap: 5px;
}
.sm span {
  font-size: 12.5px;
  color: var(--muted);
}
.sm b {
  font-size: 21px;
  font-weight: 650;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.2px;
}
.sm b.ok {
  color: var(--success);
}
/* 节奏是一个短句不是金额，字号收一点否则「落后 43 个点」会把卡撑满 */
.sm b.pace-num {
  font-size: 17px;
  letter-spacing: 0;
}
.sm i {
  font-style: normal;
  font-size: 12px;
  font-weight: 500;
  color: var(--faint);
}
.sm .bar {
  margin-top: 2px;
}
.tiny {
  font-size: 11px;
}

.api-note.warn {
  border-color: #f0d9a8;
  background: #fffbf0;
}
.api-note.warn b {
  color: #8a5a00;
}

.tree-line {
  color: var(--faint);
  margin-right: 2px;
}

/* 上级部门的完成额包含下属部门，标一下免得以为重复计数 */
.rollup {
  font-style: normal;
  font-size: 11px;
  color: var(--faint);
  margin-left: 5px;
  white-space: nowrap;
}

.prog {
  display: flex;
  align-items: center;
  gap: 9px;
}
.prog .bar {
  flex: 1;
  min-width: 68px;
}
.prog span {
  width: auto;
  min-width: 34px;
  text-align: left;
  font-size: 12px;
  color: var(--muted);
  font-variant-numeric: tabular-nums;
}
.prog span.done {
  color: var(--success);
  font-weight: 600;
}

.pace {
  font-size: 12px;
}
.pace.ahead,
.pos {
  color: var(--success);
}
.pace.behind,
.neg {
  color: var(--danger);
}
.pace.ontrack {
  color: var(--muted);
}

.row-tight {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}
.ops {
  justify-content: flex-end;
}

/* 批量设置弹窗 */
.batch {
  max-height: 62vh;
  overflow: auto;
}
.mini {
  width: 100%;
  border-collapse: collapse;
  font-size: 12.5px;
}
.mini th {
  text-align: left;
  font-weight: 550;
  color: var(--muted);
  font-size: 11.5px;
  padding: 6px 8px;
  border-bottom: 1px solid var(--line);
  position: sticky;
  top: 0;
  background: #fff;
  z-index: 1;
}
.mini td {
  padding: 5px 8px;
  border-bottom: 1px solid #f2f4f7;
  vertical-align: middle;
}
.mini .r {
  text-align: right;
}
.mini .num {
  font-variant-numeric: tabular-nums;
}
.mini .input {
  height: 28px;
  font-size: 12.5px;
  width: 100%;
}
.mini .w-amt {
  width: 132px;
  text-align: right;
}
.mini .w-note {
  width: 200px;
}
.dept-name {
  display: inline-block;
  color: var(--ink);
}
.cell-sub {
  font-size: 11px;
  color: var(--faint);
  margin-top: 1px;
}
/* 个人目标的备注列常被写满一句话，别把行撑成两行 */
.note-cell {
  display: inline-block;
  max-width: 220px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  vertical-align: bottom;
  color: var(--muted);
  font-size: 12px;
}
.empty-line {
  text-align: center;
  color: var(--faint);
  padding: 18px 0;
}
.alloc-note {
  margin: 14px 0 0;
  padding: 9px 12px;
  border-radius: 8px;
  background: #f6f8fa;
  font-size: 11.5px;
  line-height: 1.7;
  color: var(--muted);
}

@media (max-width: 900px) {
  .summary {
    grid-template-columns: 1fr 1fr;
  }
}
</style>
