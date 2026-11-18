import { computed, reactive } from 'vue'
import { employeeApi, STATUS_TO_API, STATUS_TO_VIEW } from '@/api/employees'
import { flattenDepartments, loadDepartments } from '@/store/departments'

/**
 * 员工数据源（真实后端）
 * 对应后端 com.crm.employee：GET/POST/PUT/PATCH/DELETE /api/employees
 * 与「部门管理」一致：加载失败直接进入错误态并提供重试，不做演示数据兜底，
 * 避免接口异常时页面看起来是正常的假数据。
 */
export const employeeStore = reactive({
  list: [],
  loading: false,
  loaded: false,
  error: '',
  syncedAt: ''
})

let inflight = null

function stamp() {
  const d = new Date()
  return [d.getHours(), d.getMinutes(), d.getSeconds()]
    .map((n) => String(n).padStart(2, '0'))
    .join(':')
}

/** 后端行 -> 页面视图模型 */
function adaptEmployee(row, deptMap) {
  const roleText =
    row.roleNames ||
    (Array.isArray(row.roles) ? row.roles.map((r) => (typeof r === 'string' ? r : r?.name)).filter(Boolean).join('、') : '')

  return {
    rawId: row.id,
    id: row.employeeNo || String(row.id ?? ''),
    name: row.name || '',
    account: row.username || '',
    phone: row.phone || '—',
    email: row.email || '—',
    deptId: row.departmentId ?? null,
    dept: row.departmentName || deptMap.get(String(row.departmentId)) || '未分配',
    role: roleText || '未分配',
    joinDate: row.hireDate || '—',
    status: STATUS_TO_VIEW[row.status] || '在职'
  }
}

export function deptNameById() {
  const map = new Map()
  flattenDepartments().forEach((d) => map.set(String(d.id), d.name))
  return map
}

/**
 * 可指派候选：在职员工，带工号（employeeNo）与部门名。
 * 线索分配 / 转移等「选接收人」的地方统一用它，数据与「设置 › 员工管理」同源，
 * 不在业务页里另抄一份名单。
 */
export const assignableEmployees = computed(() =>
  employeeStore.list
    .filter((e) => e.status !== '停用')
    .map((e) => ({
      rawId: e.rawId,
      name: e.name,
      no: e.id,
      dept: e.dept,
      deptId: e.deptId == null ? '' : e.deptId,
      role: e.role
    }))
)

/** 可提交的部门（需要 id 才能填 department_id） */
export function serverDeptOptions() {
  return flattenDepartments().map((d) => ({ id: d.id, name: d.name, depth: d.depth }))
}

export async function loadEmployees({ force = false } = {}) {
  if (inflight) return inflight
  if (employeeStore.loaded && !force) return employeeStore.list

  employeeStore.loading = true
  employeeStore.error = ''

  inflight = (async () => {
    try {
      await loadDepartments().catch(() => {})
      const [data] = await Promise.all([employeeApi.list()])
      const deptMap = deptNameById()
      employeeStore.list = (Array.isArray(data) ? data : []).map((row) => adaptEmployee(row, deptMap))
      employeeStore.syncedAt = stamp()
      employeeStore.loaded = true
      return employeeStore.list
    } catch (e) {
      employeeStore.error = e?.message || '员工数据加载失败'
      employeeStore.list = []
      throw e
    } finally {
      employeeStore.loading = false
      inflight = null
    }
  })()

  return inflight
}

/* ---------------- 写操作（提交后重新拉取，保证与服务端一致） ---------------- */

export async function createEmployee(form) {
  const res = await employeeApi.create({
    username: form.account,
    name: form.name,
    departmentId: form.dept,
    phone: form.phone || null,
    email: form.email || null,
    hireDate: form.joinDate || null,
    status: STATUS_TO_API[form.status] || 'active'
  })
  await loadEmployees({ force: true })
  return res
}

/** 启用 / 停用，返回变更后的展示态 */
export async function toggleEmployeeStatus(row) {
  const next = row.status === '在职' ? '停用' : '在职'
  await employeeApi.setStatus(row.rawId, STATUS_TO_API[next])
  await loadEmployees({ force: true })
  return next
}

export async function removeEmployee(row) {
  await employeeApi.remove(row.rawId)
  await loadEmployees({ force: true })
}

