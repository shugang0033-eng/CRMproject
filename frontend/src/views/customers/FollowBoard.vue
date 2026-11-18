<template>
  <div class="page">
    <PageHead title="团队跟进看板" desc="按人看今天该跟谁、谁漏了跟进、谁在拖；勾掉一条等于记一条跟进记录">
      <button class="btn" type="button" @click="toast('已导出待跟进清单（演示）')">
        <AppIcon name="download" :size="14" />导出
      </button>
      <button v-can="'followup.create'" class="btn btn-primary" type="button" @click="openFollow(null)">
        <AppIcon name="plus" :size="14" />写跟进
      </button>
    </PageHead>

    <div class="grid-4 kpis">
      <StatTile label="今日该跟" :value="counts.due" unit="条" icon="clock" hint="含已超期" :tone="counts.due ? 'warning' : 'success'" />
      <StatTile label="已超期" :value="counts.overdue" unit="条" icon="flag" tone="danger" hint="超过约定跟进日" />
      <StatTile label="本周计划" :value="counts.plan" unit="条" icon="calendar" hint="未来 3 天" />
      <StatTile
        label="完成率"
        :value="counts.rate"
        unit="%"
        icon="check-circle"
        :tone="counts.rate >= 80 ? 'success' : 'warning'"
        :hint="`已勾掉 ${counts.done} / ${counts.total} 条`"
      />
    </div>

    <div class="card board">
      <div class="toolbar">
        <div class="search">
          <AppIcon name="search" :size="15" />
          <input v-model="keyword" class="input" type="text" placeholder="搜索客户 / 跟进内容" />
        </div>
        <select v-model="dept" class="select">
          <option value="">全部部门</option>
          <option v-for="d in depts" :key="d">{{ d }}</option>
        </select>
        <select v-model="owner" class="select">
          <option value="">全部负责人</option>
          <option v-for="o in owners" :key="o">{{ o }}</option>
        </select>
        <div class="seg">
          <button type="button" :class="{ on: view === 'all' }" @click="view = 'all'">全部</button>
          <button type="button" :class="{ on: view === 'overdue' }" @click="view = 'overdue'">只看超期</button>
          <button type="button" :class="{ on: view === 'done' }" @click="view = 'done'">已完成</button>
        </div>
        <div class="spacer" />
        <span class="faint tip">
          <AppIcon name="flag" :size="11" />逾期条目按超期天数排序
        </span>
      </div>

      <div class="board-grid">
        <section v-for="g in groups" :key="g.name" class="member">
          <header class="member-head">
            <UserAvatar :name="g.name" />
            <div class="member-id">
              <div class="member-name">{{ g.name }}</div>
              <div class="faint fs">{{ g.dept }} · {{ g.role }}</div>
            </div>
            <div class="member-stat">
              <b :class="{ neg: g.overdue && !g.doneAll }">{{ g.done }}/{{ g.total }}</b>
              <span class="faint fs">完成</span>
            </div>
          </header>
          <div class="member-bar">
            <div class="member-fill" :style="{ width: g.rate + '%' }" :class="{ full: g.rate === 100 }" />
          </div>

          <div v-if="g.tasks.length" class="tasks">
            <article
              v-for="t in g.tasks"
              :key="t.id"
              class="task"
              :class="[t.state, { done: t.done }]"
            >
              <label class="tick" :title="t.done ? '取消完成' : '标记完成'">
                <input type="checkbox" :checked="t.done" @change="toggleDone(t)" />
              </label>
              <div class="t-main">
                <div class="t-top">
                  <button class="t-cust" type="button" @click="goCustomer(t)">
                    {{ t.customer }}
                  </button>
                  <span class="tag tiny" :class="stateTone(t)">{{ stateText(t) }}</span>
                </div>
                <p class="t-content">{{ t.content }}</p>
                <div class="t-meta">
                  <span class="faint">上次 {{ t.last }}</span>
                  <span class="faint">·</span>
                  <span class="faint">{{ t.result }}</span>
                </div>
              </div>
              <div class="t-ops">
                <button v-can="'followup.create'" class="btn-text" type="button" @click="openFollow(t)">
                  写跟进
                </button>
              </div>
            </article>
          </div>
          <div v-else class="empty-mini">
            <AppIcon name="check-circle" :size="14" />
            {{ view === 'done' ? '还没有已完成的条目' : '这个人名下没有待跟进' }}
          </div>
        </section>
      </div>
    </div>

    <!-- 写跟进：勾掉条目 = 一条跟进记录 -->
    <ModalDialog
      v-model="followOpen"
      :title="current ? `跟进 · ${current.customer}` : '写跟进'"
      desc="保存后这条待办从看板移除，同时写入客户动态"
      ok-text="保存并完成"
      @confirm="submitFollow"
    >
      <div class="who-box" v-if="current">
        <UserAvatar :name="current.owner" size="sm" />
        <span>{{ current.owner }}</span>
        <span class="faint">上次跟进 {{ current.last }}</span>
        <span class="tag tiny" :class="stateTone(current)">{{ stateText(current) }}</span>
      </div>
      <div class="form-grid">
        <div class="field">
          <label class="label">跟进方式</label>
          <select v-model="form.type" class="select">
            <option v-for="t in types" :key="t">{{ t }}</option>
          </select>
        </div>
        <div class="field">
          <label class="label">本次结果</label>
          <select v-model="form.result" class="select">
            <option v-for="r in results" :key="r">{{ r }}</option>
          </select>
        </div>
      </div>
      <div class="field">
        <label class="label">跟进内容<span class="req">*</span></label>
        <textarea
          v-model="form.content"
          class="input area"
          rows="4"
          :placeholder="current ? current.content : '聊了什么、客户什么态度、下一步做什么'"
        />
      </div>
      <div class="field">
        <label class="label">下次跟进</label>
        <input v-model="form.next" class="input" type="date" />
      </div>
    </ModalDialog>
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import UserAvatar from '@/components/UserAvatar.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import StatTile from '@/components/analytics/StatTile.vue'
import { toast } from '@/composables/useToast'
import { customerApi } from '@/api/customers'


const router = useRouter()

/* 「今天」以演示数据的时间锚点算，保证超期天数稳定。
   后端接入后由服务器下发 serverDate，前端不再需要这个常量 */
const serverDate = ref('')
const members = ref([])
const tasks = ref([])
async function loadBoard() {
  const data = await customerApi.followBoard({ range: 'week' })
  serverDate.value = data.serverDate
  members.value = data.members
  tasks.value = data.members.flatMap((m) => m.tasks.map((t) => ({
    ...t, ownerId: m.id, owner: m.name, done: t.state === 'done'
  })))
}
onMounted(() => loadBoard().catch((e) => toast(e.message, 'error')))

const keyword = ref('')
const dept = ref('')
const owner = ref('')
const view = ref('all')

const depts = computed(() => [...new Set(members.value.map((m) => m.dept))])
const owners = computed(() => members.value.map((m) => m.name))

function daysBetween(a, b) {
  return Math.round((new Date(b) - new Date(a)) / 86400000)
}

function overDays(t) {
  return daysBetween(t.due, serverDate.value)
}

function stateText(t) {
  if (t.done) return '已完成'
  if (t.state === 'overdue') return `超期 ${overDays(t)} 天`
  if (t.state === 'due') return '今日到期'
  return `${t.due.slice(5).replace('-', '/')} 计划`
}

function stateTone(t) {
  if (t.done) return 'tag-success'
  if (t.state === 'overdue') return 'tag-danger'
  if (t.state === 'due') return 'tag-warning'
  return 'tag-info'
}

/* 过滤：搜索命中客户或内容；状态视图三选一 */
const filtered = computed(() =>
  tasks.value.filter((t) => {
    if (keyword.value) {
      const k = keyword.value.trim()
      if (!`${t.customer}${t.content}`.includes(k)) return false
    }
    if (view.value === 'overdue') {
      if (t.done || t.state !== 'overdue') return false
    } else if (view.value === 'done') {
      if (!t.done) return false
    }
    return true
  })
)

const counts = computed(() => {
  const active = tasks.value.filter((t) => !t.done)
  const due = active.filter((t) => t.state === 'due' || t.state === 'overdue').length
  const overdue = active.filter((t) => t.state === 'overdue').length
  const plan = active.filter((t) => t.state === 'plan').length
  const done = tasks.value.filter((t) => t.done).length
  return {
    due,
    overdue,
    plan,
    done,
    total: tasks.value.length,
    rate: tasks.value.length ? Math.round((done / tasks.value.length) * 100) : 0
  }
})

/* 按人分组：没有待办的人也保留卡片，主管要看「这周谁没排计划」 */
const groups = computed(() => {
  const visible = members.value.filter((m) => {
    if (dept.value && m.dept !== dept.value) return false
    if (owner.value && m.name !== owner.value) return false
    return true
  })

  return visible.map((m) => {
    const mine = tasks.value.filter((t) => t.ownerId === m.id)
    const list = filtered.value
      .filter((t) => t.ownerId === m.id)
      .slice()
      .sort((a, b) => {
        /* 超期越久越靠前，其次是今日到期，最后是计划；勾掉的沉到最底下 */
        const w = (x) => {
          if (x.done) return -1
          if (x.state === 'overdue') return overDays(x) + 100
          if (x.state === 'due') return 50
          return 0
        }
        return w(b) - w(a)
      })
    const done = mine.filter((t) => t.done).length
    return {
      ...m,
      tasks: list,
      done,
      total: mine.length,
      overdue: mine.filter((t) => !t.done && t.state === 'overdue').length,
      doneAll: mine.length > 0 && done === mine.length,
      rate: mine.length ? Math.round((done / mine.length) * 100) : 0
    }
  })
})

async function toggleDone(t) {
  try {
    await customerApi.updateTask(t.id, { done: !t.done })
    await loadBoard()
  } catch (e) { toast(e.message, 'error') }
}

function goCustomer(t) {
  if (!t.customerId) {
    toast('该客户还没有档案')
    return
  }
  router.push(`/customers/${t.customerId}`)
}

/* ---------------- 写跟进 ---------------- */
const followOpen = ref(false)
const current = ref(null)
const types = ['电话', '微信', '客户拜访', '线上会议', '邮件']
const results = ['推进', '待反馈', '待回款', '暂缓']
const form = reactive({ type: '电话', result: '推进', content: '', next: '' })

function openFollow(t) {
  current.value = t
  form.type = '电话'
  form.result = t?.result === '待回款' ? '待回款' : '推进'
  form.content = ''
  form.next = ''
  followOpen.value = true
}

async function submitFollow() {
  if (!form.content.trim()) return toast('请填写跟进内容')
  try {
    await customerApi.addFollowUp(current.value.customerId, { ...form, next: form.next || null })
    followOpen.value = false
    await loadBoard()
    toast('跟进已记录')
  } catch (e) { toast(e.message, 'error') }
}
</script>

<style scoped>
.kpis {
  margin-bottom: 16px;
}
.toolbar .seg {
  margin-left: 2px;
}
.seg {
  display: flex;
  padding: 2px;
  background: #f2f4f7;
  border-radius: 7px;
}
.seg button {
  height: 28px;
  padding: 0 12px;
  border: none;
  background: transparent;
  border-radius: 5px;
  font-size: 12.5px;
  color: var(--muted);
  cursor: pointer;
}
.seg button.on {
  background: #fff;
  color: var(--ink);
  font-weight: 550;
  box-shadow: var(--shadow-xs);
}
.tip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 11.5px;
}

.board-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
  padding: 16px 20px 20px;
  align-items: start;
}
.member {
  border: 1px solid var(--line-soft);
  border-radius: 11px;
  padding: 13px 14px 14px;
  background: #fcfdfe;
}
.member-head {
  display: flex;
  align-items: center;
  gap: 9px;
}
.member-id {
  flex: 1;
  min-width: 0;
}
.member-name {
  font-size: 13.5px;
  font-weight: 600;
  color: var(--ink);
}
.member-stat {
  display: flex;
  align-items: baseline;
  gap: 4px;
  white-space: nowrap;
}
.member-stat b {
  font-size: 16px;
  font-weight: 650;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
}
.member-bar {
  height: 4px;
  border-radius: 3px;
  background: #e4e7ec;
  margin: 10px 0 12px;
  overflow: hidden;
}
.member-fill {
  height: 100%;
  border-radius: 3px;
  background: var(--brand);
  transition: width 0.3s;
}
.member-fill.full {
  background: var(--success);
}

.tasks {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.task {
  display: flex;
  gap: 9px;
  padding: 10px 11px;
  border-radius: 9px;
  border: 1px solid var(--line-soft);
  background: #fff;
  border-left: 2px solid var(--line);
  transition: box-shadow 0.15s;
  min-width: 0;
}
.task:hover {
  box-shadow: var(--shadow-xs);
}
.task.overdue {
  border-left-color: var(--danger);
}
.task.due {
  border-left-color: var(--warning);
}
.task.plan {
  border-left-color: var(--info);
}
.task.done {
  opacity: 0.62;
  background: #fafbfc;
}
.task.done .t-content {
  text-decoration: line-through;
  color: var(--faint);
}
.tick {
  display: flex;
  padding-top: 2px;
}
.tick input {
  width: 14px;
  height: 14px;
  accent-color: var(--brand);
  cursor: pointer;
}
.t-main {
  flex: 1;
  min-width: 0;
}
.t-top {
  display: flex;
  align-items: center;
  gap: 7px;
  min-width: 0;
}
.t-cust {
  padding: 0;
  border: none;
  background: transparent;
  font-size: 12.5px;
  font-weight: 550;
  color: var(--ink);
  text-align: left;
  cursor: pointer;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.t-cust:hover {
  color: var(--brand);
}
.tiny {
  font-size: 10.5px;
  padding: 1px 5px;
  flex-shrink: 0;
}
.t-content {
  margin: 4px 0 5px;
  font-size: 12px;
  line-height: 1.6;
  color: #4a5568;
}
.t-meta {
  display: flex;
  gap: 4px;
  font-size: 11px;
}
.t-ops {
  display: flex;
  align-items: flex-start;
  flex-shrink: 0;
}
.empty-mini {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 14px 4px 6px;
  font-size: 12px;
  color: var(--faint);
}

.who-box {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  margin-bottom: 14px;
  border-radius: 9px;
  background: #f7f9fc;
  font-size: 12.5px;
}
.who-box .faint {
  margin-left: auto;
  font-size: 11.5px;
}
.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}
.area {
  height: auto;
  padding: 9px 11px;
  line-height: 1.65;
  resize: vertical;
  font-family: inherit;
}

@media (max-width: 1180px) {
  .board-grid {
    grid-template-columns: 1fr;
  }
  .kpis {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
</style>
