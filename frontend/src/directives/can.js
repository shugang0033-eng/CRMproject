import { can } from '@/store/permissions'

/**
 * v-can="'lead.create'"        单权限
 * v-can="['a', 'b']"           任一命中即可
 * v-can="{ all: ['a','b'] }"   全部命中
 *
 * 用 display 控制而不是移除节点：权限在会话内可能变化（切角色、改角色权限），
 * 移除后 Vue 的 patch 会找不到节点而报错。
 */
function allowed(value) {
  if (!value) return true
  if (Array.isArray(value)) return value.some((v) => can(v))
  if (typeof value === 'object' && value.all) return value.all.every((v) => can(v))
  return can(value)
}

function apply(el, binding) {
  const ok = allowed(binding.value)
  if (ok) {
    if (el.dataset.canHidden === '1') {
      el.style.display = el.dataset.canDisplay || ''
      delete el.dataset.canHidden
      delete el.dataset.canDisplay
    }
    return
  }
  if (el.dataset.canHidden === '1') return
  el.dataset.canDisplay = el.style.display === 'none' ? '' : el.style.display
  el.dataset.canHidden = '1'
  el.style.display = 'none'
}

export const vCan = {
  mounted: apply,
  updated: apply
}

export default {
  install(app) {
    app.directive('can', vCan)
  }
}
