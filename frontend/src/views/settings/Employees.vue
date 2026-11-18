<template>
  <div class="page">
    <PageHead title="员工管理" desc="维护组织成员与账号，配置所属部门与在职状态">
      <button class="btn" type="button" @click="toast('批量导入模板已下载（演示）')">
        <AppIcon name="download" :size="14" />导入
      </button>
      <button v-can="'employee.manage'" class="btn btn-primary" type="button" @click="openCreate">
        <AppIcon name="plus" :size="14" />新建员工
      </button>
    </PageHead>

    <div class="summary">
      <div class="sm card">
        <span>员工总数</span>
        <b>{{ rows.length }} <i>人</i></b>
      </div>
      <div class="sm card">
        <span>在职</span>
        <b class="ok">{{ countOf('在职') }} <i>人</i></b>
      </div>
      <div class="sm card">
        <span>停用账号</span>
        <b>{{ countOf('停用') }} <i>人</i></b>
      </div>
      <div class="sm card">
        <span>部门数量</span>
        <b>{{ deptCount }} <i>个</i></b>
      </div>
    </div>

    <div class="card">
      <div class="card-head">
        <div class="card-title">
          <span class="dot" />组织成员
          <span v-if="syncedAt" class="card-sub">已同步 {{ syncedAt }}</span>
        </div>
        <div class="row-tight">
          <button class="btn btn-sm" type="button" :disabled="loading" @click="refresh">
            <AppIcon name="refresh" :size="13" :class="{ spinning: loading }" />刷新
          </button>
        </div>
      </div>

      <!-- 加载失败 -->
      <div v-if="error && !loading" class="state-box">
        <span class="state-ico"><AppIcon name="close" :size="16" /></span>
        <div class="state-main">
          <div class="state-title">员工数据加载失败</div>
          <div class="state-desc">{{ error }}</div>
        </div>
        <button class="btn btn-sm" type="button" @click="refresh">重试</button>
      </div>

      <template v-else>
        <div class="toolbar">
          <div class="search">
            <AppIcon name="search" :size="15" />
            <input v-model="keyword" class="input" type="text" placeholder="搜索姓名 / 工号 / 手机号" />
          </div>
          <select v-model="dept" class="select">
            <option value="">全部部门</option>
            <option v-for="d in deptOptions" :key="d.id" :value="d.id">{{ d.name }}</option>
          </select>
          <select v-model="status" class="select">
            <option value="">全部状态</option>
            <option>在职</option>
            <option>停用</option>
          </select>
          <div class="spacer" />
          <button class="btn btn-sm" type="button" @click="reset">重置</button>
        </div>

        <AppTable
          :columns="columns"
          :rows="filtered"
          :page-size="8"
          :empty-text="loading ? '正在加载…' : '没有符合条件的员工'"
        >
          <template #cell-name="{ row }">
            <div class="row-tight">
              <UserAvatar :name="row.name" />
              <div>
                <div class="cell-main">{{ row.name }}</div>
                <div class="cell-sub" :title="row.id ? `工号 ${row.id}` : ''">
                  {{ row.rawId ? `#${row.rawId}` : row.id }} · {{ row.account }}
                </div>
              </div>
            </div>
          </template>
          <template #cell-role="{ row }">
            <span v-if="row.role === '未分配'" class="cell-sub">未分配</span>
            <span v-else class="tag tag-brand plain">{{ row.role }}</span>
          </template>
          <template #cell-status="{ row }">
            <span class="tag" :class="row.status === '在职' ? 'tag-success' : 'tag-gray'">{{ row.status }}</span>
          </template>
          <template #cell-ops="{ row }">
            <div class="row-tight ops">
              <button v-can="'employee.manage'" class="btn-text" type="button" @click="openDepartment(row)">调部门</button>
              <button v-can="'employee.manage'" class="btn-text" type="button" @click="openRoles(row)">分配角色</button>
              <button v-can="'employee.manage'" class="btn-text" type="button" :disabled="busyId === row.id" @click="toggleStatus(row)">
                {{ row.status === '在职' ? '停用' : '启用' }}
              </button>
              <button v-can="'employee.manage'" class="btn-text danger" type="button" @click="askDelete(row)">删除</button>
            </div>
          </template>
        </AppTable>
      </template>
    </div>

    <ModalDialog v-model="rolesOpen" title="分配角色" ok-text="保存" :loading="assigning" @confirm="saveRoles">
      <div v-if="!roleOptions.length">请先在角色管理中创建角色。</div>
      <div v-for="role in roleOptions" :key="role.id">
        <label><input v-model="selectedRoleIds" type="checkbox" :value="role.id" /> {{ role.name }}</label>
      </div>
    </ModalDialog>

    <ModalDialog v-model="departmentOpen" title="调整所属部门" ok-text="保存"
                 :loading="changingDepartment" @confirm="saveDepartment">
      <div class="field">
        <label for="employee-department" class="label">{{ departmentEmployee?.name }}的所属部门</label>
        <select id="employee-department" v-model="nextDepartment" class="select">
          <option v-for="d in deptOptions" :key="d.id" :value="d.id">{{ '　'.repeat(d.depth || 0) }}{{ d.name }}</option>
        </select>
      </div>
    </ModalDialog>

    <!-- 新建员工 -->
    <ModalDialog
      v-model="createOpen"
      title="新建员工"
      desc="填写员工信息及所属部门"
      ok-text="创建员工"
      :loading="saving"
      @confirm="save"
    >
      <div class="form-grid">
        <div class="field">
          <label class="label">姓名<span class="req">*</span></label>
          <input v-model.trim="form.name" class="input" :class="{ error: err.name }" placeholder="请输入真实姓名" />
          <span v-if="err.name" class="err-msg">{{ err.name }}</span>
        </div>
        <div class="field">
          <label class="label">登录账号<span class="req">*</span></label>
          <input v-model.trim="form.account" class="input" :class="{ error: err.account }" placeholder="字母或数字，唯一" />
          <span v-if="err.account" class="err-msg">{{ err.account }}</span>
        </div>
        <div class="field">
          <label class="label">手机号</label>
          <input v-model.trim="form.phone" type="tel" maxlength="11" class="input" :class="{ error: err.phone }" placeholder="用于接收通知" />
          <span v-if="err.phone" class="err-msg">{{ err.phone }}</span>
        </div>
        <div class="field">
          <label class="label">邮箱</label>
          <input v-model.trim="form.email" type="email" maxlength="254" class="input" :class="{ error: err.email }" placeholder="name@beichen.com" />
          <span v-if="err.email" class="err-msg">{{ err.email }}</span>
        </div>
        <div class="field">
          <label class="label">所属部门<span class="req">*</span></label>
          <select v-model="form.dept" class="select" :class="{ error: err.dept }">
            <option v-for="d in deptOptions" :key="d.id" :value="d.id">{{ d.name }}</option>
          </select>
          <span v-if="err.dept" class="err-msg">{{ err.dept }}</span>
        </div>
        <div class="field">
          <label class="label">角色</label>
          <div class="field-note">创建后可在员工列表中分配角色</div>
        </div>
        <div class="field">
          <label class="label">入职日期</label>
          <input v-model="form.joinDate" class="input" type="date" />
        </div>
        <div class="field">
          <label class="label">账号状态</label>
          <select v-model="form.status" class="select">
            <option>在职</option>
            <option>停用</option>
          </select>
        </div>
      </div>
    </ModalDialog>

    <!-- 删除确认 -->
    <ModalDialog
      v-model="delOpen"
      title="删除员工"
      width="normal"
      ok-text="确认删除"
      :loading="saving"
      @confirm="doDelete"
    >
      <div class="del-box">
        <span class="del-ico"><AppIcon name="trash" :size="18" /></span>
        <div>
          <p class="del-title">确定要删除员工「{{ target?.name }}」吗？</p>
          <p class="del-desc">
            删除后，该员工将从员工列表中移除。
          </p>
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
import UserAvatar from '@/components/UserAvatar.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import { flattenDepartments as flattenServerDepartments } from '@/store/departments'
import {
  employeeStore,
  loadEmployees,
  createEmployee,
  toggleEmployeeStatus,
  removeEmployee
} from '@/store/employees'
import { toast } from '@/composables/useToast'
import { employeeApi } from '@/api/employees'
import { refreshSession, session } from '@/store/session'
import { roleApi } from '@/api/roles'
import { todayStr } from '@/utils/date'

const keyword = ref('')
const dept = ref('')
const status = ref('')

const rows = computed(() => employeeStore.list)
const error = computed(() => employeeStore.error)
const syncedAt = computed(() => employeeStore.syncedAt)
const loading = computed(() => employeeStore.loading)

/**
 * 部门下拉只用后端部门：员工表 department_id 有外键，必须是真实存在的部门。
 */
const deptOptions = computed(() => flattenServerDepartments())

/** 部门数量统计组织架构里的全部部门，与下拉可选范围不同 */
const deptCount = computed(() => flattenServerDepartments().length)

onMounted(() => {
  loadEmployees().catch(() => toast('员工数据加载失败，请稍后重试'))
})

async function refresh() {
  try {
    await loadEmployees({ force: true })
  } catch (e) {
    toast(e?.message || '刷新失败')
  }
}

const columns = [
  { key: 'name', label: '员工' },
  { key: 'dept', label: '所属部门', width: '130px' },
  { key: 'role', label: '角色', width: '128px' },
  { key: 'phone', label: '手机号', width: '128px' },
  { key: 'email', label: '邮箱' },
  { key: 'joinDate', label: '入职日期', width: '112px' },
  { key: 'status', label: '状态', width: '92px' },
  { key: 'ops', label: '操作', align: 'right', width: '248px' }
]

const filtered = computed(() =>
  rows.value.filter((e) => {
    if (dept.value && String(e.deptId) !== String(dept.value)) return false
    if (status.value && e.status !== status.value) return false
    if (keyword.value) {
      const k = keyword.value.trim()
      if (![e.name, e.id, e.account, e.phone].join(' ').includes(k)) return false
    }
    return true
  })
)

const countOf = (s) => rows.value.filter((e) => e.status === s).length

function reset() {
  keyword.value = ''
  dept.value = ''
  status.value = ''
}

const rolesOpen = ref(false)
const assigning = ref(false)
const roleOptions = ref([])
const selectedRoleIds = ref([])
const roleEmployeeId = ref(null)

async function openRoles(row) {
  try {
    const [options, assigned] = await Promise.all([
      roleApi.list(),
      roleApi.employeeRoles(row.rawId)
    ])
    roleOptions.value = options
    selectedRoleIds.value = assigned
    roleEmployeeId.value = row.rawId
    rolesOpen.value = true
  } catch (e) {
    toast(e.message, 'error')
  }
}

async function saveRoles() {
  assigning.value = true
  try {
    await roleApi.assign(roleEmployeeId.value, selectedRoleIds.value)
    rolesOpen.value = false
    await loadEmployees({ force: true })
    toast('角色分配已保存')
  } catch (e) {
    toast(e.message, 'error')
  } finally {
    assigning.value = false
  }
}

const departmentOpen = ref(false)
const departmentEmployee = ref(null)
const nextDepartment = ref(null)
const changingDepartment = ref(false)

function openDepartment(row) {
  departmentEmployee.value = row
  nextDepartment.value = row.deptId
  departmentOpen.value = true
}

async function saveDepartment() {
  if (changingDepartment.value || !nextDepartment.value) return
  const row = departmentEmployee.value
  changingDepartment.value = true
  try {
    await employeeApi.moveDepartment(row.rawId, nextDepartment.value)
    await loadEmployees({ force: true })
    if (String(row.rawId) === String(session.user?.id)) await refreshSession()
    departmentOpen.value = false
    toast('所属部门已更新')
  } catch (e) {
    toast(e.message, 'error')
  } finally {
    changingDepartment.value = false
  }
}

/* ---------------- 新建 ---------------- */
const createOpen = ref(false)
const saving = ref(false)
const form = reactive({
  name: '',
  account: '',
  phone: '',
  email: '',
  dept: '',
  joinDate: todayStr(),
  status: '在职'
})
const err = reactive({ name: '', account: '', dept: '', phone: '', email: '' })

function openCreate() {
  Object.assign(form, {
    name: '',
    account: '',
    phone: '',
    email: '',
    dept: deptOptions.value[0]?.id || '',
    joinDate: todayStr(),
    status: '在职'
  })
  err.name = ''
  err.account = ''
  err.dept = ''
  err.phone = ''
  err.email = ''
  createOpen.value = true
}

async function save() {
  const ACCOUNT = /^[A-Za-z0-9]{1,64}$/
  err.name = !form.name ? '请输入员工姓名' : form.name.length > 100 ? '姓名不能超过 100 字' : ''
  err.dept = form.dept ? '' : '请选择所属部门'
  if (!form.account) err.account = '请输入登录账号'
  else if (!ACCOUNT.test(form.account)) err.account = '账号需为 1–64 位字母或数字'
  else if (rows.value.some((e) => e.account === form.account)) err.account = '该账号已存在'
  else err.account = ''
  err.phone = form.phone && !/^1[3-9][0-9]{9}$/.test(form.phone) ? '请输入有效的11位手机号' : ''
  err.email = form.email && (form.email.length > 254 || !/^[A-Za-z0-9_%+.-]+@[A-Za-z0-9-]+(?:[.][A-Za-z0-9-]+)*[.][A-Za-z]{2,}$/.test(form.email))
    ? '请输入有效的邮箱地址' : ''
  if (err.name || err.account || err.dept || err.phone || err.email) return

  saving.value = true
  try {
    await createEmployee(form)
    createOpen.value = false
    toast(`员工「${form.name}」创建成功`)
  } catch (e) {
    toast(e?.message || '创建失败，请稍后重试')
  } finally {
    saving.value = false
  }
}

/* ---------------- 状态 / 删除 ---------------- */
const busyId = ref('')

async function toggleStatus(row) {
  busyId.value = row.id
  try {
    const next = await toggleEmployeeStatus(row)
    toast(`「${row.name}」已${next === '在职' ? '启用' : '停用'}`)
  } catch (e) {
    toast(e?.message || '操作失败')
  } finally {
    busyId.value = ''
  }
}

const delOpen = ref(false)
const target = ref(null)

function askDelete(row) {
  target.value = row
  delOpen.value = true
}

async function doDelete() {
  saving.value = true
  try {
    const name = target.value?.name
    await removeEmployee(target.value)
    toast(`员工「${name}」已删除`)
    delOpen.value = false
  } catch (e) {
    toast(e?.message || '删除失败，请稍后重试')
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
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
  gap: 4px;
}
.sm span {
  font-size: 12.5px;
  color: var(--muted);
}
.sm b {
  font-size: 20px;
  font-weight: 650;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
}
.sm b.ok {
  color: var(--success);
}
.sm i {
  font-style: normal;
  font-size: 12px;
  font-weight: 500;
  color: var(--faint);
}
.ops {
  justify-content: flex-end;
}

/* 加载失败 */
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
.field-note {
  display: flex;
  align-items: center;
  height: 38px;
  padding: 0 12px;
  border: 1px dashed var(--line);
  border-radius: var(--radius-sm);
  background: var(--bg);
  color: var(--faint);
  font-size: 12.5px;
}
.spinning {
  animation: spin 0.9s linear infinite;
}
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.del-box {
  display: flex;
  gap: 14px;
  align-items: flex-start;
}
.del-ico {
  width: 38px;
  height: 38px;
  border-radius: 10px;
  display: grid;
  place-items: center;
  background: var(--danger-bg);
  color: var(--danger);
  flex-shrink: 0;
}
.del-title {
  font-size: 13.5px;
  color: var(--ink);
  font-weight: 550;
}
.del-desc {
  margin-top: 6px;
  font-size: 12.5px;
  color: var(--muted);
  line-height: 1.7;
}

@media (max-width: 900px) {
  .summary {
    grid-template-columns: 1fr 1fr;
  }
}
</style>


