import { computed, reactive } from 'vue'
import { ApiError } from '@/api/http'
import { isEndpointMissing, profileApi } from '@/api/profile'
import { session } from '@/store/session'

/**
 * 个人资料 store
 *
 * 后端已实现 /api/profile 系列接口，这里仍保留「接口优先、本地兜底」：
 *   - 接口可用 -> 用后端数据，改动用接口提交
 *   - 接口 404/连不上 -> apiReady=false，页面顶部提示，改动落 localStorage
 * 兜底只为「后端没起 / 接口被临时下线」时不白屏，正常情况走接口。
 */

const AVATAR_KEY = (id) => `crm-avatar-${id}`
const PWD_KEY = (id) => `crm-password-updated-${id}`
const LAST_LOGIN_KEY = 'crm-last-login'

export const profileState = reactive({
  data: null,
  loading: false,
  /** null = 还没探测；true = 接口可用；false = 待后端实现 */
  apiReady: null,
  avatar: '',
  passwordUpdatedAt: ''
})

/** 头像地址：本地缓存的压缩图 > 后端返回的地址 */
export const avatarSrc = computed(() => profileState.avatar || profileState.data?.avatar || '')

/** 是否还在用初始密码（后端给了 mustChangePassword 就听后端的） */
export const usingInitialPassword = computed(() => {
  const d = profileState.data
  if (!d) return false
  if (d.mustChangePassword === true) return true
  if (d.mustChangePassword === false) return false
  if (d.passwordUpdatedAt) return false
  const id = session.user?.id
  return id ? !localStorage.getItem(PWD_KEY(id)) : false
})

function fallbackProfile(user) {
  return {
    id: user.id,
    account: user.account || '',
    employeeNo: user.employeeNo || '',
    name: user.name || '',
    dept: user.dept || '',
    deptId: user.deptId ?? null,
    role: user.role || '',
    roleCode: user.roleCode || '',
    phone: user.phone || '',
    email: user.email || '',
    avatar: '',
    hireDate: user.hireDate || '',
    status: 'active',
    lastLoginAt: localStorage.getItem('crm-prev-login') || localStorage.getItem(LAST_LOGIN_KEY) || '',
    lastLoginIp: '',
    passwordUpdatedAt: '',
    mustChangePassword: undefined
  }
}

/** 接口未实现时，本地改过的字段要能活过刷新 */
function readCache(id) {
  try {
    return JSON.parse(localStorage.getItem(`crm-profile-${id}`) || 'null') || {}
  } catch {
    return {}
  }
}

export async function loadProfile(force = false) {
  const user = session.user
  if (!user) return null
  if (!force && profileState.data && profileState.data.id === user.id) return profileState.data

  profileState.loading = true
  let data
  try {
    const res = await profileApi.get()
    profileState.apiReady = true
    data = { ...fallbackProfile(user), ...readCache(user.id), ...res }
  } catch (err) {
    // 接口未就绪、后端没起、500 —— 一律退到本地，页面不能因为缺接口就白屏
    profileState.apiReady = false
    data = { ...fallbackProfile(user), ...readCache(user.id) }
    if (!isEndpointMissing(err)) data._warn = err.message
  } finally {
    profileState.loading = false
  }

  const id = user.id
  profileState.data = data
  profileState.avatar = (profileState.apiReady ? data.avatar : localStorage.getItem(AVATAR_KEY(id))) || ''
  profileState.passwordUpdatedAt = (profileState.apiReady ? data.passwordUpdatedAt : localStorage.getItem(PWD_KEY(id))) || ''
  return profileState.data
}

/** 保存基本信息：接口不通时先存本地，返回 synced=false 让页面如实提示 */
export async function saveBasic(form) {
  const next = { ...profileState.data, ...form }
  try {
    await profileApi.update(form)
    profileState.apiReady = true
    profileState.data = next
    // 后端通常只回 204，本地同步一份，避免刷新后回到旧值
    localStorage.setItem(`crm-profile-${next.id}`, JSON.stringify(form))
    return { synced: true }
  } catch (err) {
    if (!isEndpointMissing(err)) throw err
    profileState.data = next
    localStorage.setItem(`crm-profile-${next.id}`, JSON.stringify(form))
    return { synced: false }
  }
}

/** 头像：先本地生效（秒回显），再尝试上传 */
export async function saveAvatar(dataUrl) {
  const id = session.user?.id
  if (!id) return { synced: false }
  localStorage.setItem(AVATAR_KEY(id), dataUrl)
  profileState.avatar = dataUrl
  try {
    const res = await profileApi.uploadAvatar(dataUrl)
    if (res?.avatar) {
      profileState.avatar = res.avatar
      localStorage.setItem(AVATAR_KEY(id), res.avatar)
    }
    return { synced: true }
  } catch (err) {
    if (!isEndpointMissing(err)) throw err
    return { synced: false }
  }
}

export async function changePassword({ oldPassword, newPassword }) {
  try {
    await profileApi.changePassword({ oldPassword, newPassword })
    profileState.apiReady = true
    await loadProfile(true)
    return { synced: true }
  } catch (err) {
    if (isEndpointMissing(err)) return { synced: false }
    // 后端错误体不带 message（Spring 默认隐藏），只能按状态码翻译
    if (err instanceof ApiError) {
      if (err.status === 400) throw new ApiError('当前密码不正确，请重新输入', { status: 400 })
      if (err.status === 422) throw new ApiError('新密码不符合要求：至少 8 位，且不能与当前密码相同', { status: 422 })
      if (err.status === 409) throw new ApiError('密码刚刚已被修改，请重新登录后再试', { status: 409 })
    }
    throw err
  }
}

export async function loadLogins() {
  try {
    const list = await profileApi.logins()
    return { list: Array.isArray(list) ? list : [], synced: true }
  } catch (err) {
    if (!isEndpointMissing(err)) throw err
    return { list: [], synced: false }
  }
}

export function markPasswordUpdated() {
  const id = session.user?.id
  if (!id) return
  const at = new Date().toISOString()
  localStorage.setItem(PWD_KEY(id), at)
  profileState.passwordUpdatedAt = at
}

/** 记住登录时间：把上一次挪到 prev，"上次登录"才不会显示成本次 */
export function touchLastLogin() {
  const prev = localStorage.getItem(LAST_LOGIN_KEY)
  if (prev) localStorage.setItem('crm-prev-login', prev)
  localStorage.setItem(LAST_LOGIN_KEY, new Date().toISOString())
}

export function resetProfile() {
  profileState.data = null
  profileState.avatar = ''
  profileState.apiReady = null
  profileState.passwordUpdatedAt = ''
}

