<template>
  <div class="page">
    <PageHead title="角色管理" desc="按岗位职责配置功能权限，调整后立即影响该角色下所有成员的菜单与操作">
      <button v-can="'role.manage'" class="btn btn-primary" type="button" @click="openCreate">
        <AppIcon name="plus" :size="14" />新建角色
      </button>
    </PageHead>

    <div v-if="apiMissing" class="api-note">
      <span class="an-ico"><AppIcon name="dot" :size="14" /></span>
      <div class="an-txt">
        <strong>删除接口尚未接入后端</strong>
        <p>
          前端已按契约调用 <code>DELETE /api/roles/{id}</code>（成功 204、角色仍有成员或为内置角色返回 409）。
          后端实现后删除按钮直接生效，页面不用再改。
        </p>
      </div>
    </div>

    <div class="role-summary">
      <span class="rs-ico"><AppIcon name="shield" :size="15" /></span>
      <div class="rs-txt">
        <strong>当前登录身份：{{ myRoleName }}</strong>
        <span>共 {{ totalPerms }} 个权限点，{{ cards.length }} 个角色。权限点最小到「按钮」，看得到页面 ≠ 点得动按钮。</span>
      </div>
      <span class="tag tag-brand plain">{{ myPermCount }} 项已授权</span>
    </div>

    <div class="role-grid">
      <article v-for="r in cards" :key="r.id" class="role card" :class="{ current: r.code === myRoleCode }">
        <div class="role-head">
          <span class="role-ico" :class="{ super: r.superAdmin }">
            <AppIcon :name="r.superAdmin ? 'star' : 'shield'" :size="16" />
          </span>
          <div class="role-title">
            <strong>{{ r.name }}</strong>
            <em>{{ r.code }}</em>
          </div>
          <span v-if="r.code === myRoleCode" class="tag tag-brand">当前</span>
          <span v-else-if="r.builtin" class="tag tag-gray plain">内置</span>
        </div>

        <p class="role-desc" :class="{ 'is-empty': !r.desc }">{{ r.desc || '暂无角色说明' }}</p>

        <div class="perm-meta">
          <span class="pm-count">
            <b>{{ r.superAdmin ? totalPerms : r.perms.length }}</b> / {{ totalPerms }} 项权限
          </span>
          <div class="pm-bar"><i :style="{ width: pct(r) + '%' }" /></div>
        </div>

        <div class="perm-list">
          <span v-if="r.superAdmin" class="tag tag-brand plain">全部功能</span>
          <template v-else>
            <span v-for="m in permModules(r.perms)" :key="m" class="tag tag-brand plain">{{ m }}</span>
            <span v-if="!permModules(r.perms).length" class="tag tag-gray plain">未分配权限</span>
          </template>
        </div>

        <div class="role-foot">
          <span class="row-tight">
            <AppIcon name="users" :size="13" />
            {{ r.members }} 名成员
          </span>
          <div class="role-acts">
            <button v-can="'role.manage'" class="btn-text" type="button" @click="openEdit(r)">
              {{ r.superAdmin ? '查看权限' : '编辑' }}
            </button>
            <i v-can="'role.manage'" class="act-sep" />
            <button
              v-can="'role.manage'"
              class="btn-text danger"
              type="button"
              :disabled="blockReason(r) !== ''"
              :title="blockReason(r) || '删除该角色'"
              @click="openDelete(r)"
            >
              删除
            </button>
          </div>
        </div>
      </article>

      <button v-can="'role.manage'" class="role-add" type="button" @click="openCreate">
        <span class="add-ico"><AppIcon name="plus" :size="18" /></span>
        <strong>新建角色</strong>
        <span>按岗位定义权限范围</span>
      </button>
    </div>

    <ModalDialog
      v-model="dialogOpen"
      :title="editing ? (form.superAdmin ? `查看「${form.name}」权限` : `编辑「${form.name}」`) : '新建角色'"
      :desc="editing ? '调整后立即生效，该角色成员下次进入页面时按新权限显示' : '先定义角色，再到员工管理中把成员关联到该角色'"
      width="wide"
      :ok-text="editing ? '保存权限' : '创建角色'"
      @confirm="save"
    >
      <div class="form-grid">
        <div class="field">
          <label class="label">角色名称<span class="req">*</span></label>
          <input v-model.trim="form.name" class="input" :class="{ error: err.name }" placeholder="如：区域销售经理" />
          <span v-if="err.name" class="err-msg">{{ err.name }}</span>
        </div>
        <div class="field">
          <label class="label">角色标识<span class="req">*</span></label>
          <input
            v-model.trim="form.code"
            class="input"
            :class="{ error: err.code }"
            :disabled="editing"
            placeholder="英文，如 sales_region"
          />
          <span v-if="err.code" class="err-msg">{{ err.code }}</span>
          <span v-else-if="editing" class="hint">角色标识创建后不可修改</span>
        </div>
        <div class="field span-2">
          <label class="label">角色描述</label>
          <input v-model.trim="form.desc" class="input" placeholder="简要说明该岗位的职责边界" />
        </div>

        <div class="field span-2">
          <div class="perm-head">
            <label class="label">功能权限</label>
            <div class="perm-tools">
              <span class="perm-total">已选 <b>{{ form.perms.length }}</b> / {{ totalPerms }}</span>
              <button class="btn-text" type="button" @click="selectAll">全选</button>
              <button class="btn-text" type="button" @click="clearAll">清空</button>
            </div>
          </div>

          <div v-if="form.superAdmin" class="super-note">
            超级管理员固定拥有全部权限，不可编辑。如需限制，请为该成员分配其他角色。
          </div>

          <div v-else class="perm-scroll">
            <div v-for="g in groups" :key="g.key" class="perm-group">
              <div class="pg-head">
                <span class="pg-ico"><AppIcon :name="g.icon" :size="13" /></span>
                <span class="pg-label">{{ g.label }}</span>
                <span class="pg-desc">{{ g.desc }}</span>
                <button class="btn-text pg-all" type="button" @click="toggleGroup(g)">
                  {{ allPicked(g) ? '取消全选' : '全选' }}
                </button>
                <span class="pg-count">{{ pickedCount(g) }}/{{ g.items.length }}</span>
              </div>
              <div class="perm-box">
                <label
                  v-for="item in g.items"
                  :key="item.key"
                  class="perm-item"
                  :class="{ on: form.perms.includes(item.key) }"
                >
                  <input v-model="form.perms" type="checkbox" :value="item.key" />
                  <span>{{ item.label }}</span>
                </label>
              </div>
            </div>
          </div>
          <span v-if="!form.superAdmin" class="scroll-hint">
            共 {{ groups.length }} 个模块 · {{ totalPerms }} 项权限，可上下滚动查看
          </span>
        </div>
      </div>
    </ModalDialog>

    <!-- 删除确认 -->
    <ModalDialog
      v-model="delOpen"
      title="删除角色"
      desc="权限配置会一并清除，删除后不可恢复"
      :close-on-mask="!deleting"
    >
      <div v-if="delTarget" class="del-box">
        <div class="del-target">
          <span class="del-ico"><AppIcon name="trash" :size="15" /></span>
          <div class="del-info">
            <strong>{{ delTarget.name }}</strong>
            <span>{{ delTarget.code }} · {{ delTarget.members }} 名成员 · {{ delTarget.perms.length }} 项权限</span>
          </div>
        </div>

        <p v-if="delTarget.members > 0" class="del-warn">
          <AppIcon name="flag" :size="14" />
          <span>
            请先在员工管理里解除成员与该角色的关联。
          </span>
        </p>
        <p v-else class="del-safe">
          <AppIcon name="check-circle" :size="14" />
          <span>该角色暂无成员，可以安全删除。</span>
        </p>

      </div>

      <template #footer>
        <button class="btn" type="button" :disabled="deleting" @click="delOpen = false">取消</button>
        <button
          class="btn btn-danger"
          type="button"
          :disabled="deleting || delTarget?.members > 0"
          @click="confirmDelete"
        >
          {{ deleting ? '删除中…' : '确认删除' }}
        </button>
      </template>
    </ModalDialog>
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import { roleApi } from '@/api/roles'
import { session, refreshSession } from '@/store/session'
import { currentRole } from '@/store/permissions'
import {
  PERMISSION_GROUPS,
  ALL_PERMISSIONS,
  normalizeRole,
  permModules
} from '@/config/permissions'
import { toast } from '@/composables/useToast'

const groups = PERMISSION_GROUPS
const totalPerms = ALL_PERMISSIONS.length

const roles = ref([])
const cards = computed(() => roles.value.map(normalizeRole))

async function loadRoles() {
  roles.value = (await roleApi.list()).map((role) => ({
    ...role,
    desc: role.description || '',
    perms: role.permissionCodes || []
  }))
}

onMounted(() => loadRoles().catch((e) => toast(e.message, 'error')))

const myRoleCode = computed(() => session.user?.roleCode || '')
const myRoleName = computed(() => currentRole.value?.name || session.user?.role || '—')
const myPermCount = computed(() => currentRole.value?.perms.length || 0)

function pct(r) {
  const n = r.superAdmin ? totalPerms : r.perms.length
  return Math.round((n / totalPerms) * 100)
}

/* ---------------- 弹窗 ---------------- */
const dialogOpen = ref(false)
const editing = ref(false)
const form = reactive({ id: '', name: '', code: '', desc: '', perms: [], superAdmin: false })
const err = reactive({ name: '', code: '' })

function resetForm() {
  form.id = ''
  form.name = ''
  form.code = ''
  form.desc = ''
  form.perms = ['dashboard.view']
  form.superAdmin = false
  err.name = ''
  err.code = ''
}

function openCreate() {
  editing.value = false
  resetForm()
  dialogOpen.value = true
}

function openEdit(r) {
  editing.value = true
  form.id = r.id
  form.name = r.name
  form.code = r.code
  form.desc = r.desc
  form.perms = [...r.perms]
  form.superAdmin = !!r.superAdmin
  err.name = ''
  err.code = ''
  dialogOpen.value = true
}

function pickedCount(g) {
  return g.items.filter((i) => form.perms.includes(i.key)).length
}
function allPicked(g) {
  return pickedCount(g) === g.items.length
}

function toggleGroup(g) {
  const keys = g.items.map((i) => i.key)
  if (allPicked(g)) {
    form.perms = form.perms.filter((p) => !keys.includes(p))
  } else {
    form.perms = [...new Set([...form.perms, ...keys])]
  }
}

function selectAll() {
  form.perms = [...ALL_PERMISSIONS]
}
function clearAll() {
  form.perms = []
}

async function save() {
  if (form.superAdmin) {
    dialogOpen.value = false
    return
  }
  err.name = form.name ? '' : '请输入角色名称'
  err.code = form.code ? '' : '请输入角色标识'
  if (!editing.value && form.code && roles.value.some((r) => r.code === form.code)) {
    err.code = '该标识已被占用'
  }
  if (err.name || err.code) return

  if (!form.perms.length) {
    toast('请至少选择一个功能权限', 'error')
    return
  }

  try {
    const payload = { name: form.name, code: form.code, desc: form.desc, perms: form.perms }
    if (editing.value) await roleApi.update(form.id, payload)
    else await roleApi.create(payload)
    dialogOpen.value = false
    await loadRoles()
    /* 改的可能就是自己所属的角色：立刻拉一次 /auth/me，
       否则当前页面上的按钮要等刷新才跟上新权限 */
    if (editing.value && form.code === myRoleCode.value) await refreshSession()
    toast('角色已保存')
  } catch (e) {
    toast(e.status === 409 ? '角色标识已被占用' : e.message, 'error')
  }
}

/* ---------------- 删除 ---------------- */
const delOpen = ref(false)
const delTarget = ref(null)
const deleting = ref(false)
const apiMissing = ref(false)

/** 返回不可删除的原因，空串表示可删 */
function blockReason(r) {
  if (r.superAdmin || r.builtin) return '内置角色不可删除'
  if (r.code === myRoleCode.value) return '不能删除当前登录身份所属的角色'
  return ''
}

function openDelete(r) {
  if (blockReason(r)) return
  delTarget.value = r
  delOpen.value = true
}

async function confirmDelete() {
  if (!delTarget.value || deleting.value) return
  if (delTarget.value.members > 0) return

  const target = delTarget.value
  deleting.value = true
  try {
    await roleApi.remove(target.id)
    delOpen.value = false
    await loadRoles()
    toast(`角色「${target.name}」已删除`)
  } catch (e) {
    if (e.status === 405) {
      apiMissing.value = true
      delOpen.value = false
      toast('删除接口尚未接入后端（DELETE /api/roles/{id}），本次删除未生效', 'error')
    } else if (e.status === 409) {
      toast('该角色仍有成员在使用，请先在员工管理中解除关联', 'error')
    } else if (e.status === 404) {
      delOpen.value = false
      await loadRoles().catch(() => {})
      toast('该角色已不存在，列表已刷新', 'error')
    } else {
      toast(e.message || '删除失败，请稍后重试', 'error')
    }
  } finally {
    deleting.value = false
  }
}
</script>

<style scoped>
.role-summary {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  margin-bottom: 16px;
  border: 1px solid var(--line);
  border-radius: var(--radius);
  background: #fbfcfe;
}
.rs-ico {
  width: 30px;
  height: 30px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  background: var(--brand-soft);
  color: var(--brand);
  flex-shrink: 0;
}
.rs-txt {
  display: flex;
  flex-direction: column;
  gap: 2px;
  flex: 1;
  min-width: 0;
}
.rs-txt strong {
  font-size: 12.8px;
  color: var(--ink);
  font-weight: 550;
}
.rs-txt span {
  font-size: 11.8px;
  color: var(--muted);
  line-height: 1.6;
}

.role-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(310px, 1fr));
  gap: 16px;
}

.role {
  padding: 18px;
  display: flex;
  flex-direction: column;
  transition: box-shadow 0.2s, border-color 0.2s;
}
.role:hover {
  border-color: #d3dce8;
  box-shadow: var(--shadow-sm);
}
.role.current {
  border-color: #bcd4ec;
  box-shadow: inset 3px 0 0 var(--brand), 0 1px 2px rgba(16, 24, 40, 0.04);
}

.role-head {
  display: flex;
  align-items: flex-start;
  gap: 10px;
}
.role-ico {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  background: linear-gradient(150deg, #eef4fb, #e2ecf8);
  border: 1px solid #e1eaf5;
  color: var(--brand);
  flex-shrink: 0;
}
.role-ico.super {
  background: linear-gradient(150deg, #fdf6e7, #f8e9c9);
  border-color: #f0e0be;
  color: #a9762c;
}
.role-title {
  display: flex;
  flex-direction: column;
  line-height: 1.4;
  flex: 1;
  min-width: 0;
}
.role-title strong {
  font-size: 14px;
  font-weight: 600;
  color: var(--ink);
}
.role-title em {
  font-style: normal;
  font-size: 11px;
  color: var(--faint);
  letter-spacing: 0.3px;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}

.role-desc {
  margin: 12px 0 14px;
  font-size: 12.5px;
  line-height: 1.7;
  color: var(--muted);
  min-height: 42px;
}
.role-desc.is-empty {
  color: var(--faint);
}

.perm-meta {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 12px;
}
.pm-count {
  font-size: 11.5px;
  color: var(--faint);
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}
.pm-count b {
  font-size: 13px;
  color: var(--ink);
  font-weight: 600;
}
.pm-bar {
  flex: 1;
  height: 4px;
  border-radius: 99px;
  background: #eef1f5;
  overflow: hidden;
}
.pm-bar i {
  display: block;
  height: 100%;
  border-radius: 99px;
  background: linear-gradient(90deg, #4b8ac9, #7fb3e8);
}

.perm-list {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-bottom: 16px;
  min-height: 22px;
}

.role-foot {
  margin-top: auto;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-top: 13px;
  border-top: 1px solid var(--line-soft);
  font-size: 12px;
  color: var(--muted);
}

.role-acts {
  display: inline-flex;
  align-items: center;
  gap: 10px;
}
.act-sep {
  width: 1px;
  height: 11px;
  background: var(--line);
}
.role-acts .btn-text[disabled] {
  color: var(--faint);
  opacity: 0.55;
  cursor: not-allowed;
  text-decoration: none;
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

.role-add {
  border: 1px dashed #d5dce6;
  border-radius: var(--radius);
  background: #fcfdfe;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 30px 18px;
  cursor: pointer;
  color: var(--faint);
  transition: all 0.18s;
  min-height: 190px;
}
.role-add:hover {
  border-color: var(--brand);
  background: #f8fbff;
  color: var(--brand);
}
.add-ico {
  width: 38px;
  height: 38px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: #f1f5fa;
  color: inherit;
  margin-bottom: 2px;
}
.role-add strong {
  font-size: 13px;
  font-weight: 550;
  color: var(--text);
}
.role-add:hover strong {
  color: var(--brand);
}
.role-add span:last-child {
  font-size: 11.5px;
}

/* ---------------- 权限矩阵 ---------------- */
.perm-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 8px;
}
.perm-tools {
  display: flex;
  align-items: center;
  gap: 12px;
}
.perm-total {
  font-size: 11.5px;
  color: var(--faint);
  font-variant-numeric: tabular-nums;
}
.perm-total b {
  color: var(--brand);
  font-size: 12.5px;
}

.super-note {
  padding: 12px 14px;
  border: 1px dashed #e3d3ad;
  border-radius: var(--radius-sm);
  background: #fffcf4;
  font-size: 12.3px;
  line-height: 1.7;
  color: #8a6a24;
}

.perm-scroll {
  max-height: 46vh;
  overflow-y: auto;
  padding-right: 4px;
  border: 1px solid var(--line);
  border-radius: var(--radius-sm);
  background: #fcfcfd;
}
.perm-scroll::-webkit-scrollbar {
  width: 6px;
}
.perm-scroll::-webkit-scrollbar-thumb {
  background: #dfe5ec;
  border-radius: 3px;
}

.scroll-hint {
  display: block;
  margin-top: 7px;
  font-size: 11px;
  color: var(--faint);
  text-align: right;
}

.perm-group {
  padding: 12px 13px;
  border-bottom: 1px solid var(--line-soft);
}
.perm-group:last-child {
  border-bottom: none;
}

.pg-head {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 9px;
}
.pg-ico {
  width: 22px;
  height: 22px;
  border-radius: 6px;
  display: grid;
  place-items: center;
  background: #eef3f9;
  color: var(--brand);
  flex-shrink: 0;
}
.pg-label {
  font-size: 12.8px;
  font-weight: 600;
  color: var(--ink);
}
.pg-desc {
  font-size: 11px;
  color: var(--faint);
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pg-all {
  font-size: 11.5px;
}
.pg-count {
  font-size: 11px;
  color: var(--faint);
  font-variant-numeric: tabular-nums;
  min-width: 34px;
  text-align: right;
}

.perm-box {
  display: flex;
  flex-wrap: wrap;
  gap: 7px;
}
.perm-item {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 5px 10px;
  border: 1px solid var(--line);
  border-radius: 7px;
  background: #fff;
  font-size: 12.3px;
  color: var(--text);
  cursor: pointer;
  transition: all 0.15s;
  user-select: none;
}
.perm-item:hover {
  border-color: #c8d4e2;
}
.perm-item.on {
  border-color: var(--brand);
  background: var(--brand-soft);
  color: var(--brand);
}
.perm-item input {
  accent-color: var(--brand);
  width: 13px;
  height: 13px;
  margin: 0;
}
</style>



