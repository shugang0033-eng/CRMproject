import { reactive } from 'vue'
import { request } from '@/api/http'

localStorage.removeItem('beichen-crm-session')
export const session = reactive({ user: null })

export function isLoggedIn() {
  return Boolean(session.user)
}

export async function refreshSession() {
  try {
    session.user = await request('/auth/me')
  } catch {
    session.user = null
  }
}

export async function login(payload) {
  session.user = await request('/auth/login', { method: 'POST', body: payload })
  return session.user
}

export async function logout() {
  await request('/auth/logout', { method: 'POST' })
  session.user = null
}
