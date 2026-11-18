<template>
  <div class="page">
    <PageHead title="部门管理" desc="维护组织架构与部门负责人，部门层级影响数据权限范围">
      <button v-can="'dept.manage'" class="btn btn-primary" type="button" @click="openCreate(null)">
        <AppIcon name="plus" :size="14" />新建部门
      </button>
    </PageHead>

    <div v-if="apiMissing" class="api-note">
      <span class="an-ico"><AppIcon name="dot" :size="14" /></span>
      <div class="an-txt">
        <strong>删除接口尚未接入后端</strong>
        <p>
          前端已按契约调用 <code>DELETE /api/departments/{id}</code>（成功 204、部门下有子部门或员工返回 409）。
          后端实现后删除按钮直接生效，页面不用再改。
        </p>
      </div>
    </div>

    <div class="card">
      <div class="card-head">
        <div class="card-title">
          <span class="dot" />组织架构
          <span v-if="syncedAt" class="card-sub">已同步 {{ syncedAt }}</span>
        </div>
        <div class="row-tight">
          <button class="btn btn-sm" type="button" :disabled="loading" @click="refresh">
            <AppIcon name="refresh" :size="13" :class="{ spinning: loading }" />刷新
          </button>
          <button class="btn btn-sm" type="button" @click="expandAll">展开全部</button>
          <button class="btn btn-sm" type="button" @click="collapseAll">收起全部</button>
        </div>
      </div>

      <!-- 加载失败 -->
      <div v-if="error && !loading" class="state-box">
        <span class="state-ico is-error"><AppIcon name="close" :size="16" /></span>
        <div class="state-main">
          <div class="state-title">部门数据加载失败</div>
          <div class="state-desc">{{ error }}</div>
        </div>
        <button class="btn btn-sm" type="button" @click="refresh">重试</button>
      </div>

      <!-- 首次加载骨架 -->
      <div v-else-if="loading && !loaded" class="sk-list">
        <div v-for="i in 5" :key="i" class="sk-row" :style="{ paddingLeft: `${16 + (i === 1 ? 0 : 22)}px` }">
          <span class="sk-bar" :style="{ width: `${110 + ((i * 37) % 90)}px` }" />
          <span class="sk-bar sm" />
          <span class="sk-bar xs" />
        </div>
      </div>

      <!-- 空数据 -->
      <div v-else-if="!rows.length" class="empty">
        <span class="empty-icon"><AppIcon name="building-2" :size="20" /></span>
        <div>{{ deptStore.loaded ? '还没有任何部门' : '暂无数据' }}</div>
        <button class="btn btn-sm" type="button" @click="openCreate(null)">创建第一个部门</button>
      </div>

      <!-- 部门树 -->
      <div v-else class="tree">
        <div class="tree-head">
          <span>部门名称</span>
          <span>负责人</span>
          <span>人数</span>
          <span class="th-ops">操作</span>
        </div>

        <div
          v-for="row in rows"
          :key="row.node.id"
          class="tree-row"
          :class="{ root: row.depth === 0 }"
        >
          <div class="tr-name" :style="{ paddingLeft: `${row.depth * 22 + 16}px` }">
            <button
              v-if="row.hasChildren"
              class="tr-toggle"
              type="button"
              @click="toggle(row.node.id)"
            >
              <AppIcon :name="row.expanded ? 'chevron-down' : 'chevron-right'" :size="13" />
            </button>
            <span v-else class="tr-toggle ph" />
            <span class="dept-ico" :class="{ root: row.depth === 0 }">
              <AppIcon :name="row.depth === 0 ? 'building-2' : 'building'" :size="14" />
            </span>
            <span class="dept-name">{{ row.node.name }}</span>
            <span v-if="row.depth === 0" class="tag tag-brand plain">一级</span>
          </div>

          <div class="tr-leader">
            <template v-if="row.node.leader">
              <UserAvatar :name="row.node.leader" size="sm" />
              {{ row.node.leader }}
            </template>
            <span v-else class="tr-empty">未指定</span>
          </div>

          <div class="tr-count mono-num">{{ row.node.count }} 人</div>

          <div class="tr-ops">
            <button v-can="'dept.manage'" class="btn-text" type="button" @click="openCreate(row.node)">添加子部门</button>
            <button v-can="'dept.manage'" class="btn-text" type="button" @click="openEdit(row.node)">编辑</button>
            <button
              v-can="'dept.manage'"
              class="btn-text danger"
              type="button"
              :disabled="blockReason(row) !== ''"
              :title="blockReason(row) || '删除该部门'"
              @click="openDelete(row.node)"
            >
              删除
            </button>
          </div>
        </div>
      </div>

      <div v-if="rows.length" class="tree-foot">
        <AppIcon name="layers" :size="13" />
        共 {{ deptCount }} 个部门 · 组织成员 {{ memberCount }} 人
      </div>
    </div>

    <ModalDialog
      v-model="open"
      :title="dialogTitle"
      :desc="dialogDesc"
      :ok-text="mode === 'edit' ? '保存' : '创建'"
      :loading="saving"
      :close-on-mask="!saving"
      @confirm="save"
    >
      <div class="form-grid">
        <div class="field span-2">
          <label class="label">部门名称<span class="req">*</span></label>
          <input
            v-model.trim="form.name"
            class="input"
            :class="{ error: err.name }"
            maxlength="100"
            placeholder="如：华东销售组"
            @keyup.enter="save"
          />
          <span v-if="err.name" class="err-msg">{{ err.name }}</span>
        </div>

        <div class="field">
          <label class="label">负责人</label>
          <select v-model="form.leaderId" class="select">
            <option :value="null">暂不指定</option>
            <option v-for="o in deptStore.leaders" :key="o.id" :value="o.id">
              {{ o.name }}{{ o.employeeNo ? ` · ${o.employeeNo}` : '' }}
            </option>
          </select>
          <span v-if="deptStore.loaded && !deptStore.leaders.length" class="hint-msg">
            后端暂无在职员工，可先不指定
          </span>
        </div>

        <div class="field">
          <label class="label">排序</label>
          <input v-model.number="form.sortOrder" class="input" type="number" min="0" step="1" placeholder="0" />
        </div>

        <div class="field span-2">
          <label class="label">上级部门</label>
          <div class="readonly-box">
            {{ form.parentName || '无（创建为一级部门）' }}
            <span v-if="mode === 'edit'" class="readonly-tip">当前后端更新接口仅支持修改名称、负责人与排序</span>
          </div>
        </div>
      </div>
    </ModalDialog>

    <!-- 删除确认 -->
    <ModalDialog
      v-model="delOpen"
      title="删除部门"
      desc="部门记录会被移除，删除后不可恢复"
      :close-on-mask="!deleting"
    >
      <div v-if="delTarget" class="del-box">
        <div class="del-target">
          <span class="del-ico"><AppIcon name="trash" :size="15" /></span>
          <div class="del-info">
            <strong>{{ delTarget.name }}</strong>
            <span>{{ delPath }} · {{ delTarget.count }} 名在职成员</span>
          </div>
        </div>

        <p v-if="delTarget.count > 0" class="del-warn">
          <AppIcon name="flag" :size="14" />
          <span>
            请先在员工管理里将该部门的员工调到其他部门。
          </span>
        </p>
        <p v-else class="del-safe">
          <AppIcon name="check-circle" :size="14" />
          <span>删除时会检查是否仍有关联的员工记录。</span>
        </p>

      </div>

      <template #footer>
        <button class="btn" type="button" :disabled="deleting" @click="delOpen = false">取消</button>
        <button
          class="btn btn-danger"
          type="button"
          :disabled="deleting || delTarget?.count > 0"
          @click="confirmDelete"
        >
          {{ deleting ? '删除中…' : '确认删除' }}
        </button>
      </template>
    </ModalDialog>
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import UserAvatar from '@/components/UserAvatar.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import { deptStore, flattenDepartments, loadDepartments } from '@/store/departments'
import { departmentApi } from '@/api/departments'
import { toast } from '@/composables/useToast'

const loading = computed(() => deptStore.loading)
const loaded = computed(() => deptStore.loaded)
const error = computed(() => deptStore.error)
const syncedAt = ref('')

const expanded = ref({})
const autoExpanded = ref(false)

/* ---------------- 展开 / 收起 ---------------- */
function toggle(id) {
  expanded.value = { ...expanded.value, [id]: !expanded.value[id] }
}

function walkNodes(nodes, fn, depth = 0) {
  nodes.forEach((n) => {
    fn(n, depth)
    if (n.children?.length) walkNodes(n.children, fn, depth + 1)
  })
}

function expandAll() {
  const map = {}
  walkNodes(deptStore.tree, (n) => {
    map[n.id] = true
  })
  expanded.value = map
}

function collapseAll() {
  expanded.value = {}
}

/* 首次拿到数据时自动展开所有带子部门的节点 */
watch(
  () => deptStore.tree,
  (tree) => {
    if (autoExpanded.value || !tree.length) return
    const map = {}
    walkNodes(tree, (n) => {
      if (n.children?.length) map[n.id] = true
    })
    expanded.value = map
    autoExpanded.value = true
  }
)

const rows = computed(() => {
  const out = []
  const walk = (nodes, depth) => {
    nodes.forEach((node) => {
      const hasChildren = Boolean(node.children?.length)
      const isOpen = Boolean(expanded.value[node.id])
      out.push({ node, depth, hasChildren, expanded: isOpen })
      if (hasChildren && isOpen) walk(node.children, depth + 1)
    })
  }
  walk(deptStore.tree, 0)
  return out
})

/* 部门数 / 成员数：后端 count 是各部门在职人数，直接求和 */
const flat = computed(() => flattenDepartments())
const deptCount = computed(() => flat.value.length)
const memberCount = computed(() => flat.value.reduce((s, d) => s + Number(d.count || 0), 0))

/* ---------------- 加载 ---------------- */
function stamp() {
  const d = new Date()
  const p = (n) => String(n).padStart(2, '0')
  return `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`
}

async function refresh() {
  try {
    await loadDepartments({ force: true })
    syncedAt.value = stamp()
  } catch {
    /* 错误已写入 store.error，由页面展示 */
    syncedAt.value = ''
  }
}

onMounted(refresh)

/* ---------------- 新建 / 编辑 ---------------- */
const open = ref(false)
const mode = ref('create')
const editingId = ref(null)
const saving = ref(false)
const form = reactive({
  name: '',
  leaderId: null,
  sortOrder: 0,
  parentId: null,
  parentName: ''
})
const err = reactive({ name: '' })

const dialogTitle = computed(() => {
  if (mode.value === 'edit') return '编辑部门'
  return form.parentName ? '新建子部门' : '新建部门'
})

const dialogDesc = computed(() => {
  if (mode.value === 'edit') return '修改部门名称、负责人与排序'
  return form.parentName ? `上级部门：${form.parentName}` : '不选择上级部门时，将创建为一级部门'
})

function openCreate(parentNode) {
  mode.value = 'create'
  editingId.value = null
  form.name = ''
  form.leaderId = null
  form.sortOrder = 0
  form.parentId = parentNode?.id ?? null
  form.parentName = parentNode?.name || ''
  err.name = ''
  open.value = true
}

function openEdit(node) {
  mode.value = 'edit'
  editingId.value = node.id
  form.name = node.name || ''
  form.leaderId = node.leaderId ?? null
  form.sortOrder = node.sortOrder ?? 0
  form.parentId = node.parentId ?? null
  form.parentName = parentOf(node.parentId)?.name || (node.parentId ? '' : '')
  err.name = ''
  open.value = true
}

function parentOf(id) {
  if (id === null || id === undefined) return null
  return flat.value.find((d) => d.id === id) || null
}

async function save() {
  if (saving.value) return

  const name = form.name.trim()
  if (!name) {
    err.name = '请输入部门名称'
    return
  }
  if (name.length > 100) {
    err.name = '部门名称不能超过 100 个字符'
    return
  }
  err.name = ''
  saving.value = true

  const payload = {
    name,
    parentId: form.parentId,
    leaderId: form.leaderId,
    sortOrder: Number(form.sortOrder) || 0
  }

  try {
    if (mode.value === 'edit') {
      await departmentApi.update(editingId.value, payload)
      await loadDepartments({ force: true })
      syncedAt.value = stamp()
      toast(`部门「${name}」已更新`)
    } else {
      await departmentApi.create(payload)
      await loadDepartments({ force: true })
      if (form.parentId) expanded.value = { ...expanded.value, [form.parentId]: true }
      syncedAt.value = stamp()
      toast(`部门「${name}」已创建`)
    }
    open.value = false
  } catch (e) {
    toast(e?.message || '保存失败，请稍后重试', 'error')
  } finally {
    saving.value = false
  }
}

/* ---------------- 删除 ---------------- */
const delOpen = ref(false)
const delTarget = ref(null)
const deleting = ref(false)
const apiMissing = ref(false)

/** 返回不可删除的原因，空串表示可删 */
function blockReason(row) {
  if (row.hasChildren) return '请先删除或移出下级部门'
  return ''
}

const delPath = computed(() => {
  const node = delTarget.value
  if (!node) return ''
  const parent = parentOf(node.parentId)
  return parent ? `${parent.name} › ${node.name}` : `${node.name} · 一级部门`
})

function openDelete(node) {
  delTarget.value = node
  delOpen.value = true
}

async function confirmDelete() {
  if (!delTarget.value || deleting.value) return
  if (delTarget.value.count > 0) return

  const target = delTarget.value
  deleting.value = true
  try {
    await departmentApi.remove(target.id)
    delOpen.value = false
    await loadDepartments({ force: true })
    syncedAt.value = stamp()
    toast(`部门「${target.name}」已删除`)
  } catch (e) {
    if (e.status === 405) {
      apiMissing.value = true
      delOpen.value = false
      toast('删除接口尚未接入后端（DELETE /api/departments/{id}），本次删除未生效', 'error')
    } else if (e.status === 409) {
      toast('该部门仍有子部门或员工记录，无法删除', 'error')
    } else if (e.status === 404) {
      delOpen.value = false
      await refresh()
      toast('该部门已不存在，列表已刷新', 'error')
    } else {
      toast(e?.message || '删除失败，请稍后重试', 'error')
    }
  } finally {
    deleting.value = false
  }
}
</script>

<style scoped>
.tree {
  padding: 0 0 4px;
}
.tree-head {
  display: grid;
  grid-template-columns: 1fr 140px 88px 216px;
  align-items: center;
  padding: 10px 16px;
  background: #fafbfc;
  border-bottom: 1px solid var(--line);
  font-size: 12.5px;
  font-weight: 600;
  color: var(--muted);
}
.th-ops {
  text-align: right;
  padding-right: 4px;
}

.tree-row {
  display: grid;
  grid-template-columns: 1fr 140px 88px 216px;
  align-items: center;
  padding: 11px 16px;
  border-bottom: 1px solid var(--line-soft);
  transition: background 0.14s;
}
.tree-row:hover {
  background: #fbfcfe;
}
.tree-row.root {
  background: #fdfefe;
}

.tr-name {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}
.tr-toggle {
  width: 18px;
  height: 18px;
  display: grid;
  place-items: center;
  border: none;
  background: transparent;
  color: var(--faint);
  border-radius: 4px;
  cursor: pointer;
  flex-shrink: 0;
}
.tr-toggle:hover {
  background: #eef1f5;
  color: var(--ink);
}
.tr-toggle.ph {
  cursor: default;
}
.dept-ico {
  width: 24px;
  height: 24px;
  border-radius: 6px;
  display: grid;
  place-items: center;
  background: #f2f5f9;
  color: var(--muted);
  flex-shrink: 0;
}
.dept-ico.root {
  background: var(--brand-soft);
  color: var(--brand);
}
.dept-name {
  font-size: 13.5px;
  color: var(--ink);
  font-weight: 500;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.tr-leader {
  display: flex;
  align-items: center;
  gap: 7px;
  font-size: 13px;
  color: var(--text);
  min-width: 0;
}
.tr-empty {
  color: var(--faint);
  font-size: 12.5px;
}
.tr-count {
  font-size: 13px;
  color: var(--muted);
}
.tr-ops {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 13px;
  opacity: 0.8;
  transition: opacity 0.15s;
}
.tr-ops .btn-text[disabled] {
  color: var(--faint);
  opacity: 0.55;
  cursor: not-allowed;
  text-decoration: none;
}
.tree-row:hover .tr-ops {
  opacity: 1;
}

.tree-foot {
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 12px 20px;
  font-size: 11.5px;
  color: var(--faint);
  border-top: 1px solid var(--line-soft);
}

/* ---------------- 状态区 ---------------- */
.state-box {
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 16px 20px;
  padding: 14px 16px;
  border: 1px solid #f4d3cf;
  background: #fef7f6;
  border-radius: var(--radius-sm);
}
.state-ico {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  flex-shrink: 0;
  background: var(--danger-bg);
  color: var(--danger);
}
.state-main {
  flex: 1;
  min-width: 0;
}
.state-title {
  font-size: 13px;
  font-weight: 600;
  color: var(--ink);
}
.state-desc {
  margin-top: 2px;
  font-size: 12px;
  color: var(--muted);
  line-height: 1.6;
}

/* 骨架 */
.sk-list {
  padding: 6px 0 10px;
}
.sk-row {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 13px 16px;
  border-bottom: 1px solid var(--line-soft);
}
.sk-bar {
  height: 11px;
  border-radius: 5px;
  background: linear-gradient(90deg, #eef1f5 25%, #f6f8fa 37%, #eef1f5 63%);
  background-size: 400% 100%;
  animation: sk-shine 1.4s ease infinite;
}
.sk-bar.sm {
  width: 66px;
  margin-left: auto;
}
.sk-bar.xs {
  width: 34px;
}
@keyframes sk-shine {
  0% {
    background-position: 100% 50%;
  }
  100% {
    background-position: 0 50%;
  }
}

.spinning {
  animation: spin 0.9s linear infinite;
}
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

/* 表单补充 */
.readonly-box {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
  min-height: 38px;
  padding: 8px 12px;
  border: 1px dashed var(--line);
  border-radius: var(--radius-xs);
  background: #fafbfc;
  font-size: 13px;
  color: var(--muted);
}
.readonly-tip {
  font-size: 11.5px;
  color: var(--faint);
}
.hint-msg {
  font-size: 11.5px;
  color: var(--faint);
  margin-top: 4px;
}

/* ---------------- 删除确认 ---------------- */
.del-box {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.del-target {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 12px 14px;
  border: 1px solid var(--line);
  border-radius: var(--radius-sm);
  background: #fbfcfe;
}
.del-ico {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  background: var(--danger-bg);
  color: var(--danger);
  flex-shrink: 0;
}
.del-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.del-info strong {
  font-size: 13.5px;
  font-weight: 600;
  color: var(--ink);
}
.del-info span {
  font-size: 11.8px;
  color: var(--faint);
}
.del-warn {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin: 0;
  padding: 10px 12px;
  border: 1px solid #f0dfc0;
  border-radius: var(--radius-xs);
  background: #fffbf2;
  font-size: 12.5px;
  line-height: 1.7;
  color: #8a6a24;
}
.del-warn b {
  color: #7a5a12;
}
.del-safe {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 0;
  padding: 10px 12px;
  border: 1px solid #d9e8dd;
  border-radius: var(--radius-xs);
  background: #f6fbf7;
  font-size: 12.5px;
  color: #3f7350;
}
.del-ack {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  font-size: 12.3px;
  line-height: 1.6;
  color: var(--muted);
  cursor: pointer;
  user-select: none;
}
.del-ack input {
  margin: 2px 0 0;
  accent-color: var(--danger);
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
  background: #eef3f9;
  font-size: 11.5px;
  color: #2b5d8f;
}

@media (max-width: 900px) {
  .tree-head,
  .tree-row {
    grid-template-columns: 1fr 92px;
  }
  .tr-leader,
  .tr-count {
    display: none;
  }
  .tr-ops {
    opacity: 1;
  }
}
</style>

