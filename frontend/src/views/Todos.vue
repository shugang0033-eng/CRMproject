<template>
  <div class="page">
    <PageHead title="待办" desc="横跨审批、合同、发货、对账、退货、跟进与线索的所有待处理事项。已按「逾期 → 今天 → 本周」排序，能就地处理的就不用再点进去">
      <span v-if="loadedAt" class="faint sync">更新于 {{ syncTime }}</span>
      <button class="btn" type="button" :disabled="loading" @click="reload">
        <AppIcon name="refresh" :size="14" :class="{ spin: loading }" />
        刷新
      </button>
    </PageHead>

    <div class="summary">
      <div class="kpi card">
        <span>待处理</span>
        <b>{{ counts.total }}<i>项</i></b>
        <em>全部来源合计</em>
      </div>
      <div class="kpi card">
        <span>已逾期</span>
        <b :class="{ danger: counts.overdue }">{{ counts.overdue }}<i>项</i></b>
        <em>超过处理时限，先做这些</em>
      </div>
      <div class="kpi card">
        <span>今天到期</span>
        <b>{{ counts.today }}<i>项</i></b>
        <em>今天必须处理完</em>
      </div>
      <div class="kpi card">
        <span>本周内</span>
        <b>{{ counts.week }}<i>项</i></b>
        <em>7 天内到期</em>
      </div>
    </div>

    <div v-if="error" class="warn-line">
      <AppIcon name="flag" :size="13" />
      <span>{{ error }}</span>
    </div>

    <div class="card">
      <div class="tabs">
        <button class="tab" :class="{ active: kind === '' }" type="button" @click="kind = ''">
          全部<span class="tab-count">{{ counts.total }}</span>
        </button>
        <button
          v-for="k in KINDS"
          :key="k"
          class="tab"
          :class="{ active: kind === k }"
          type="button"
          @click="kind = k"
        >
          {{ k }}<span class="tab-count">{{ counts.byKind[k] || 0 }}</span>
        </button>
      </div>

      <div v-if="loading && !items.length" class="loading-box">
        <AppIcon name="refresh" :size="16" class="spin" />
        正在汇总各模块的待办…
      </div>

      <div v-else-if="!visible.length" class="empty">
        <div class="empty-icon"><AppIcon name="check-circle" :size="22" /></div>
        <strong>{{ kind ? `没有待处理的${kind}事项` : '待办已清空' }}</strong>
        <span>新单据提交后会出现在这里</span>
      </div>

      <div v-else class="groups">
        <section v-for="b in BUCKETS" :key="b.key" class="group">
          <template v-if="visibleByBucket[b.key]?.length">
            <div class="group-head">
              <span class="group-label" :class="b.key">{{ b.label }}</span>
              <span class="group-count">{{ visibleByBucket[b.key].length }}</span>
              <span class="group-hint">{{ b.hint }}</span>
            </div>

            <div class="todo-list">
              <article
                v-for="t in visibleByBucket[b.key]"
                :key="t.key"
                class="todo"
                :class="[t.bucket, { done: doneKeys.includes(t.key) }]"
              >
                <span class="t-ico" :class="`t-${t.tone}`">
                  <AppIcon :name="t.icon" :size="15" />
                </span>

                <div class="t-body">
                  <div class="t-top">
                    <span class="t-kind">{{ t.kind }}</span>
                    <strong class="t-title">{{ t.title }}</strong>
                  </div>
                  <p v-if="t.desc" class="t-desc">{{ t.desc }}</p>
                  <div class="t-meta">
                    <span class="tag" :class="`tag-${t.tone}`">{{ t.dueText }}</span>
                    <span class="faint">到期 {{ t.due }}</span>
                    <span v-if="t.waitDays > 0 && t.bucket !== 'overdue'" class="faint">
                      已等待 {{ t.waitDays }} 天
                    </span>
                  </div>
                </div>

                <div class="t-ops">
                  <button
                    v-if="t.action"
                    class="btn btn-sm btn-primary"
                    type="button"
                    :disabled="busy === t.key || doneKeys.includes(t.key)"
                    @click="askAction(t)"
                  >
                    {{ actionLabel(t.action.type) }}
                  </button>
                  <button
                    class="btn btn-sm"
                    type="button"
                    :class="{ 'btn-primary': !t.action }"
                    @click="go(t.path)"
                  >
                    去处理
                  </button>
                </div>
              </article>
            </div>
          </template>
        </section>
      </div>
    </div>

    <!-- 行内处理：二次确认 -->
    <ModalDialog
      v-model="confirmOpen"
      :title="pending ? actionTitle(pending.action.type) : ''"
      :ok-text="pending ? actionLabel(pending.action.type) : '确认'"
      :loading="Boolean(pending) && busy === pending.key"
      @confirm="runAction"
    >
      <template v-if="pending">
        <div class="confirm-box">
          <div class="cf-row">
            <span>事项</span>
            <b>{{ pending.title }}</b>
          </div>
          <div v-if="pending.desc" class="cf-row">
            <span>说明</span>
            <b>{{ pending.desc }}</b>
          </div>
          <div class="cf-row">
            <span>类别</span>
            <b>{{ pending.kind }}</b>
          </div>
          <div class="cf-row">
            <span>到期</span>
            <b>{{ pending.due }}（{{ pending.dueText }}）</b>
          </div>
        </div>
        <p class="field-note">{{ actionNote(pending.action) }}</p>
      </template>
    </ModalDialog>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import { toast } from '@/composables/useToast'
import { useTodos, dropTodo, BUCKETS, KINDS, SLA } from '@/composables/useTodos'
import { officeApi } from '@/api/office'
import { orderApi } from '@/api/orders'
import { customerApi } from '@/api/customers'

const router = useRouter()
const { items, counts, loading, error, loadedAt, refresh } = useTodos()

const kind = ref('')
const busy = ref('')
const doneKeys = ref([])

const visible = computed(() => (kind.value ? items.value.filter((t) => t.kind === kind.value) : items.value))

const visibleByBucket = computed(() => {
  const map = {}
  BUCKETS.forEach((b) => {
    map[b.key] = visible.value.filter((t) => t.bucket === b.key)
  })
  return map
})

const syncTime = computed(() => {
  if (!loadedAt.value) return ''
  const d = new Date(loadedAt.value)
  const p = (n) => String(n).padStart(2, '0')
  return `${p(d.getHours())}:${p(d.getMinutes())}`
})

function reload() {
  refresh().catch((e) => toast(e.message, 'error'))
}

function go(path) {
  if (path) router.push(path)
}

/* ---------------- 行内处理 ---------------- */
const ACTION_LABEL = {
  decide: '通过',
  confirmReturn: '确认入库',
  confirmStatement: '确认对账',
  finishTask: '标记完成'
}
const ACTION_TITLE = {
  decide: '确认通过这条审批？',
  confirmReturn: '确认退货入库？',
  confirmStatement: '确认这份对账单？',
  finishTask: '标记这条跟进已完成？'
}

const actionLabel = (type) => ACTION_LABEL[type] || '处理'
const actionTitle = (type) => ACTION_TITLE[type] || '确认处理'

function actionNote(action) {
  if (!action) return ''
  if (action.type === 'decide') {
    return `通过后由 ${action.applicant || '申请人'} 的申请继续流转，不可撤销。驳回请到审批中心填写意见。`
  }
  if (action.type === 'confirmReturn') {
    return `确认后按「质量问题 / 破损」入库回补可用库存，金额 ${Number(action.amount || 0).toLocaleString()} 元。需要驳回或换货请进订单详情。`
  }
  if (action.type === 'confirmStatement') {
    return '确认后该账期不能再修改，客户可据此开票。'
  }
  if (action.type === 'finishTask') {
    return '标记完成后会从团队跟进看板移出，可在客户详情里补写跟进记录。'
  }
  return ''
}

const confirmOpen = ref(false)
const pending = ref(null)

function askAction(t) {
  pending.value = t
  confirmOpen.value = true
}

async function runAction() {
  const t = pending.value
  if (!t || busy.value) return
  busy.value = t.key
  try {
    if (t.action.type === 'decide') {
      await officeApi.decide({
        kind: t.action.kind,
        docId: t.action.docId,
        result: 'pass',
        note: ''
      })
    } else if (t.action.type === 'confirmReturn') {
      await orderApi.confirmReturn(t.action.id, { result: 'pass', restock: true })
    } else if (t.action.type === 'confirmStatement') {
      await orderApi.confirmStatement(t.action.id)
    } else if (t.action.type === 'finishTask') {
      await customerApi.updateTask(t.action.id, { done: true })
    }
    doneKeys.value.push(t.key)
    dropTodo(t.key)
    confirmOpen.value = false
    toast(`${actionLabel(t.action.type)}成功：${t.title}`)
  } catch (e) {
    /* 失败不改本地状态：不能出现「界面没了但库里还在」 */
    toast(e.message, 'error')
  } finally {
    busy.value = ''
    pending.value = null
  }
}

onMounted(reload)
</script>

<style scoped>
.sync {
  font-size: 12px;
  margin-right: 2px;
}
.spin {
  animation: spin 0.9s linear infinite;
}
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

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
  font-size: 22px;
  font-weight: 650;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.3px;
}
.kpi b.danger {
  color: var(--danger);
}
.kpi i {
  font-style: normal;
  font-size: 12px;
  font-weight: 500;
  color: var(--faint);
  margin-left: 2px;
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

.loading-box {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 48px 0;
  font-size: 12.5px;
  color: var(--muted);
}

.groups {
  padding: 4px 0 8px;
}
.group + .group {
  margin-top: 6px;
}
.group-head {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 14px 16px 7px;
}
.group-label {
  font-size: 12.5px;
  font-weight: 600;
  color: var(--ink);
  position: relative;
  padding-left: 9px;
}
.group-label::before {
  content: '';
  position: absolute;
  left: 0;
  top: 50%;
  transform: translateY(-50%);
  width: 3px;
  height: 12px;
  border-radius: 2px;
  background: var(--faint);
}
.group-label.overdue::before {
  background: var(--danger);
}
.group-label.today::before {
  background: var(--warning);
}
.group-label.week::before {
  background: var(--brand);
}
.group-count {
  font-size: 11px;
  color: var(--muted);
  background: #f2f4f7;
  border-radius: 4px;
  padding: 0 5px;
  height: 17px;
  line-height: 17px;
}
.group-hint {
  font-size: 11.5px;
  color: var(--faint);
  margin-left: auto;
}

.todo-list {
  display: flex;
  flex-direction: column;
}
.todo {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 11px 16px;
  border-top: 1px solid var(--line-soft);
  transition: background 0.14s;
}
.todo:hover {
  background: #fafbfc;
}
.todo.done {
  opacity: 0.55;
}

.t-ico {
  width: 30px;
  height: 30px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  flex-shrink: 0;
  margin-top: 1px;
}
.t-danger {
  background: #fef3f2;
  color: var(--danger);
}
.t-warning {
  background: #fffaeb;
  color: var(--warning);
}
.t-info {
  background: var(--brand-soft);
  color: var(--brand);
}

.t-body {
  flex: 1;
  min-width: 0;
}
.t-top {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}
.t-kind {
  flex-shrink: 0;
  font-size: 10.5px;
  color: var(--muted);
  background: #f2f4f7;
  border-radius: 4px;
  padding: 1px 5px;
}
.t-title {
  font-size: 13px;
  font-weight: 550;
  color: var(--ink);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.t-desc {
  margin: 3px 0 0;
  font-size: 12px;
  color: var(--muted);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.t-meta {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: 5px;
  font-size: 11.5px;
}

.t-ops {
  display: flex;
  align-items: center;
  gap: 7px;
  flex-shrink: 0;
  padding-top: 3px;
}

.confirm-box {
  display: flex;
  flex-direction: column;
  gap: 9px;
  padding: 13px 15px;
  background: #fafbfc;
  border-radius: 10px;
}
.cf-row {
  display: flex;
  gap: 12px;
  font-size: 12.5px;
  line-height: 1.5;
}
.cf-row span {
  width: 46px;
  flex-shrink: 0;
  color: var(--muted);
}
.cf-row b {
  font-weight: 500;
  color: var(--ink);
  min-width: 0;
}

@media (max-width: 900px) {
  .summary {
    grid-template-columns: 1fr 1fr;
  }
  .todo {
    flex-wrap: wrap;
  }
}
</style>
