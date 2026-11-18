<template>
  <div class="pick">
    <div class="pick-tools">
      <select v-model="dept" class="select pick-dept" title="按部门筛选接收人">
        <option value="">全部部门</option>
        <option v-for="d in departments" :key="d.id" :value="String(d.id)">{{ d.name }}</option>
      </select>
      <div class="search pick-search">
        <AppIcon name="search" :size="15" />
        <input
          v-model="keyword"
          class="input"
          type="text"
          :placeholder="placeholder"
          @keydown.enter="chooseFirst"
        />
      </div>
    </div>

    <div class="pick-list">
      <div v-if="loading" class="pick-state">
        <span class="pick-spin"><AppIcon name="refresh" :size="13" /></span>正在加载员工…
      </div>
      <div v-else-if="error" class="pick-state">
        <span>{{ error }}</span>
        <button class="btn-text" type="button" @click="$emit('retry')">重试</button>
      </div>
      <div v-else-if="!visible.length" class="pick-state">
        <template v-if="keyword.trim()">没有匹配的在职员工，换个关键词试试</template>
        <template v-else-if="onlyFree && hasLoad">这个范围内的人都到在跟上限了，去掉「仅看可接」可以看全部</template>
        <template v-else>该部门下暂无在职员工</template>
      </div>
      <template v-else>
        <button
          v-for="e in visible"
          :key="e.rawId"
          class="pick-row"
          :class="{ on: isPicked(e) }"
          :title="loadTitle(e)"
          type="button"
          @click="choose(e)"
        >
          <UserAvatar :name="e.name" size="sm" />
          <span class="pick-main">
            <strong>{{ e.name }}</strong>
            <em>
              工号 {{ e.no }} · {{ e.dept }}<template v-if="e.role && e.role !== '未分配'"> · {{ e.role }}</template>
            </em>
          </span>
          <span v-if="e.load" class="pick-load" :class="e.load.band.key">
            <span class="ld">
              <b>{{ e.load.active }}</b>
              <em>在跟</em>
            </span>
            <span class="ld">
              <b>{{ e.load.customersKnown ? e.load.customers : '—' }}</b>
              <em>客户</em>
            </span>
          </span>
          <span class="pick-check"><AppIcon name="check" :size="13" /></span>
        </button>
      </template>
    </div>

    <div v-if="!hideFoot || hasLoad" class="pick-foot">
      <template v-if="picked && !hideFoot">
        <span class="foot-label">已选</span>
        <b>{{ picked.name }}</b>
        <span class="foot-picked">
          · {{ picked.dept }} · 工号 {{ picked.no }}
          <template v-if="picked.load"> · 在跟 {{ picked.load.active }} 条 / 客户 {{ picked.load.customers }} 家</template>
        </span>
      </template>
      <template v-else>
        <span class="foot-count">{{ scopeText }}</span>
        <div v-if="hasLoad" class="foot-tools">
          <button class="foot-btn" :class="{ on: byLoad }" type="button" @click="byLoad = !byLoad">
            <AppIcon name="arrow-down" :size="12" />负载从低到高
          </button>
          <label class="foot-chk">
            <input v-model="onlyFree" type="checkbox" />仅看可接
          </label>
        </div>
      </template>
    </div>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue'
import AppIcon from '@/components/AppIcon.vue'
import UserAvatar from '@/components/UserAvatar.vue'
import { loadTitle } from '@/composables/useAssigneeLoad'

/**
 * 接收人选择器（按部门缩小范围 + 姓名/工号搜索 + 负载参考）
 * 员工与部门都来自后端（与「设置 › 员工管理 / 部门管理」同一数据源），
 * 不在本地维护第二份名单，避免两边对不上。
 *
 * 行右侧的「在跟 / 客户」来自 useAssigneeLoad 挂上的 load 字段。
 * 主管分配时真正要判断的是「他还接不接得住」，光有名字和工号不够。
 */
const props = defineProps({
  /** 已选员工的 rawId（后端 employees.id） */
  modelValue: { type: [Number, String], default: null },
  /** [{ rawId, name, no, dept, deptId, role, load? }]，只传在职员工 */
  employees: { type: Array, default: () => [] },
  /** 部门树展平结果 [{ id, name, depth, parentId }] */
  departments: { type: Array, default: () => [] },
  /** 打开时默认选中的部门名，如「销售部」 */
  defaultDept: { type: String, default: '' },
  placeholder: { type: String, default: '搜索姓名 / 工号' },
  loading: { type: Boolean, default: false },
  error: { type: String, default: '' },
  /** 弹窗内已有别处展示已选人时（例如转移的「→ 转给」栏），可关掉底部那行 */
  hideFoot: { type: Boolean, default: false }
})

const emit = defineEmits(['update:modelValue', 'pick', 'retry'])

const dept = ref('')
const keyword = ref('')
/* 负载只在拿到数据时才有意义：没挂 load 的名单不显示排序和筛选，避免点了个假开关 */
const byLoad = ref(false)
const onlyFree = ref(false)

const hasLoad = computed(() => props.employees.some((e) => !!e.load))

/* 两种找人的方式互斥，避免「选了销售部又搜一个人却搜不到」的错觉：
   开始输入关键词 → 部门回到全部；选了具体部门 → 清掉关键词。 */
watch(keyword, (v) => {
  if (v.trim() && dept.value) dept.value = ''
})
watch(dept, (v) => {
  if (v && keyword.value) keyword.value = ''
})
/* 关掉「仅看可接」时不必保留排序状态；反过来也一样，两者是一组动作 */
watch(onlyFree, (v) => {
  if (v) byLoad.value = true
})

/* 部门默认选中：优先 defaultDept，找不到就留「全部部门」。只在首次拿到部门数据时应用一次 */
let deptInited = false
watch(
  () => props.departments,
  (list) => {
    if (deptInited || !list.length) return
    const hit = props.defaultDept ? list.find((d) => d.name === props.defaultDept) : null
    dept.value = hit ? String(hit.id) : ''
    deptInited = true
  },
  { immediate: true }
)

/* 选中部门时把下辖子部门的人一起带上：分给「销售部」应当能看到「销售一组」的人 */
const scopeIds = computed(() => {
  if (!dept.value) return null
  const childrenOf = new Map()
  props.departments.forEach((d) => {
    const p = d.parentId ?? null
    if (!childrenOf.has(p)) childrenOf.set(p, [])
    childrenOf.get(p).push(d.id)
  })
  const out = new Set([Number(dept.value)])
  const walk = (id) => childrenOf.get(id)?.forEach((c) => { if (!out.has(c)) { out.add(c); walk(c) } })
  walk(Number(dept.value))
  return out
})

/**
 * 有关键词时跨部门搜：名字 / 工号往往是明确目标，
 * 再被「销售部」这类默认范围挡掉会让人以为查无此人。
 */
const scoped = computed(() => {
  const k = keyword.value.trim().toLowerCase()
  return props.employees.filter((e) => {
    if (k) return [e.name, e.no, e.dept].join(' ').toLowerCase().includes(k)
    if (scopeIds.value && !scopeIds.value.has(Number(e.deptId))) return false
    return true
  })
})

const visible = computed(() => {
  let list = scoped.value
  if (onlyFree.value) list = list.filter((e) => !e.load || e.load.free > 0)
  if (byLoad.value) {
    list = [...list].sort((a, b) => {
      const pa = a.load ? a.load.active / a.load.capacity : 0
      const pb = b.load ? b.load.active / b.load.capacity : 0
      return pa - pb || a.name.localeCompare(b.name, 'zh-Hans-CN')
    })
  }
  return list
})

const picked = computed(() => props.employees.find((e) => String(e.rawId) === String(props.modelValue)) || null)

const freeCount = computed(() => scoped.value.filter((e) => !e.load || e.load.free > 0).length)

const scopeText = computed(() => {
  if (!props.employees.length) return '未加载到在职员工'
  const k = keyword.value.trim()
  if (k) return `匹配「${k}」${scoped.value.length} 人`
  const d = props.departments.find((x) => String(x.id) === dept.value)
  const where = d ? d.name : '全部部门'
  const base = `${where} ${scoped.value.length} 人`
  return hasLoad.value ? `${base} · 可接 ${freeCount.value} 人` : base
})

function isPicked(e) {
  return String(e.rawId) === String(props.modelValue)
}

function choose(e) {
  emit('update:modelValue', e.rawId)
  emit('pick', e)
}

/* 搜索后只剩一个人时，回车直接选中，省一次点击 */
function chooseFirst() {
  if (visible.value.length === 1) choose(visible.value[0])
}
</script>

<style scoped>
.pick-tools {
  display: flex;
  gap: 10px;
}
.pick-dept {
  width: 152px;
  height: 36px;
  flex-shrink: 0;
}
.pick-search {
  flex: 1;
  max-width: none;
}

.pick-list {
  margin-top: 10px;
  border: 1px solid var(--line-soft);
  border-radius: var(--radius-sm);
  background: var(--surface);
  max-height: 198px;
  overflow-y: auto;
  scrollbar-gutter: stable;
}
.pick-state {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 22px 14px;
  font-size: 12.5px;
  color: var(--muted);
  text-align: center;
}
.pick-spin {
  display: inline-grid;
  place-items: center;
  color: var(--faint);
}
.pick-spin svg {
  animation: spin 0.9s linear infinite;
}
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.pick-row {
  display: flex;
  align-items: center;
  gap: 9px;
  width: 100%;
  padding: 8px 12px;
  border: none;
  border-bottom: 1px solid var(--line-soft);
  background: transparent;
  text-align: left;
  cursor: pointer;
  transition: background 0.12s ease;
}
.pick-row:last-child {
  border-bottom: none;
}
.pick-row:hover {
  background: #f7f9fc;
}
.pick-row.on {
  background: #eef4fb;
}
.pick-main {
  min-width: 0;
  flex: 1;
}
.pick-main strong {
  display: block;
  font-size: 13px;
  font-weight: 550;
  color: var(--ink);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pick-main em {
  display: block;
  margin-top: 2px;
  font-style: normal;
  font-size: 11.5px;
  color: var(--faint);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* 两列数字右对齐，方便十几行里竖着扫：谁的在跟最多一眼就看出来 */
.pick-load {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-shrink: 0;
  padding-right: 2px;
}
.pick-load .ld {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  line-height: 1.1;
  min-width: 26px;
}
.pick-load b {
  font-size: 12.5px;
  font-weight: 600;
  color: var(--text);
  font-variant-numeric: tabular-nums;
}
.pick-load em {
  margin-top: 1px;
  font-style: normal;
  font-size: 10px;
  color: var(--faint);
}
/* 只有快到上限才上色：一片彩色等于没有重点 */
.pick-load.busy b {
  color: var(--warning);
}
.pick-load.full b {
  color: var(--danger);
}

.pick-check {
  width: 16px;
  flex-shrink: 0;
  display: grid;
  place-items: center;
  color: var(--brand);
  opacity: 0;
}
.pick-row.on .pick-check {
  opacity: 1;
}

.pick-foot {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 8px;
  min-height: 18px;
  font-size: 12px;
  color: var(--muted);
}
.pick-foot b {
  font-weight: 600;
  color: var(--ink);
}
.foot-label {
  color: var(--faint);
}
.foot-picked {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.foot-count {
  white-space: nowrap;
}
.foot-tools {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-left: auto;
}
.foot-btn {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 0;
  border: none;
  background: none;
  font: inherit;
  font-size: 12px;
  color: var(--faint);
  cursor: pointer;
  white-space: nowrap;
}
.foot-btn:hover {
  color: var(--text);
}
.foot-btn.on {
  color: var(--brand);
  font-weight: 500;
}
.foot-chk {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  white-space: nowrap;
  cursor: pointer;
}
.foot-chk input {
  width: 13px;
  height: 13px;
  margin: 0;
  accent-color: var(--brand);
  cursor: pointer;
}
</style>
