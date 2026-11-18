import { computed } from 'vue'
import { session } from '@/store/session'
import { ALL_PERMISSIONS } from '@/config/permissions'

/** 当前登录账号对应的角色对象（未登录为 null） */
export const currentRole = computed(() => session.user && ({
  name: session.user.role,
  perms: session.user.permissions
}))

export const currentPerms = computed(() => new Set(currentRole.value?.perms || []))
/**
 * 超管判定不能只看「是否拥有全部权限码」——每新增一个权限点，
 * 库里还没发这个码，超管就会瞬间掉级、新按钮全部消失。
 * 角色名兜底，配合权限码全量的判断一起用。
 */
export const isSuperAdmin = computed(
  () =>
    session.user?.role === '超级管理员' ||
    (!!currentPerms.value.size && ALL_PERMISSIONS.every((perm) => currentPerms.value.has(perm)))
)
/**
 * 单点鉴权。超管直接放行，避免新增权限点时忘了给超管补
 */
export function can(perm) {
  if (!perm) return true
  if (isSuperAdmin.value) return true
  if (!currentPerms.value.size) return false
  return currentPerms.value.has(perm)
}

/** 这条单据是不是「我本人」提的 */
export function isMine(row) {
  if (row == null || row.applicantId == null || session.user?.id == null) return false
  return Number(row.applicantId) === Number(session.user.id)
}

/**
 * 审批按钮该不该出现。两个条件缺一不可：
 *   1. 有这类单据的审批权限（expense.approve / loan.approve / leave.approve）
 *   2. 不是本人提交的 —— 后端 OfficeService.decide 明确禁止自审
 *      （applicant == 审批人 直接 403），前端把按钮摆出来，
 *      用户点一下只会看到「没有权限」，然后去查角色配置，永远查不到问题。
 *
 * 部门范围不用前端判断：列表接口已经按 canRead 过滤过，
 * 能出现在列表里的单据，要么是本人的，要么就在管辖范围内。
 */
export function canAudit(perm, row) {
  if (!can(perm)) return false
  return !isMine(row)
}

/** 任一命中 */
export function canAny(perms = []) {
  if (!perms.length) return true
  return perms.some((p) => can(p))
}

/** 全部命中 */
export function canAll(perms = []) {
  return perms.every((p) => can(p))
}

/** 按权限过滤路由菜单（保留原有顺序与层级） */
export function filterNav(items = []) {
  return items
    .map((item) => {
      if (item.children) {
        return { ...item, children: item.children.filter((c) => can(c.perm)) }
      }
      return item
    })
    .filter((item) => (item.children ? item.children.length > 0 : can(item.perm)))
}

/**
 * 登录后落地页：按菜单顺序找第一个有权限的页面。
 * 财务、市场这类没有工作台权限的账号不会被扔到 403
 */
const LANDING = [
  ['/dashboard', 'dashboard.view'],
  ['/leads', 'lead.view'],
  ['/leads/pool', 'lead.pool'],
  ['/customers', 'customer.view'],
  ['/customers/public', 'customer.public'],
  /* 联系人与跟进记录已收进客户详情，不再单独做落地页 */
  ['/customers/follow-board', 'followup.board'],
  ['/products', 'product.view'],
  ['/orders', 'order.view'],
  ['/orders/contracts', 'contract.view'],
  ['/orders/statements', 'statement.view'],
  ['/orders/payments', 'payment.view'],
  ['/orders/invoices', 'invoice.view'],
  ['/finance/expenses', 'expense.view'],
  ['/finance/loans', 'loan.view'],
  ['/finance/leaves', 'leave.view'],
  ['/finance/approvals', 'approval.view'],
  ['/settings/employees', 'employee.view'],
  ['/settings/departments', 'dept.view'],
  ['/settings/roles', 'role.view'],
  ['/settings/targets', 'target.view'],
  /* 兜底：个人中心不需要任何功能权限，保证再窄的角色也有落脚点 */
  ['/settings/profile', null]
]

export function firstAllowedPath() {
  const hit = LANDING.find(([, perm]) => can(perm))
  return hit ? hit[0] : '/forbidden'
}

/** 判断某个路径是否可访问（用于登录后的 redirect 校验） */
export function canVisit(path) {
  const hit = LANDING.find(([p]) => p === path)
  return hit ? can(hit[1]) : true
}

/** 当前角色能看到的全部权限点（调试 / 权限卡片用） */
export function grantedList() {
  if (isSuperAdmin.value) return [...ALL_PERMISSIONS]
  return ALL_PERMISSIONS.filter((p) => can(p))
}

