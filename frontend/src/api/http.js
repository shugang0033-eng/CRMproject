/**
 * 统一请求层
 * - 走 Vite 代理到 Spring Boot（vite.config.js 中 /api -> http://localhost:8080）
 * - 后端错误体是 Spring 默认结构 { timestamp, status, error, message, path }，
 *   这里统一转成可直接展示的中文文案
 */

const BASE = (import.meta.env.VITE_API_BASE || '/api').replace(/\/+$/, '')

export class ApiError extends Error {
  constructor(message, { status = 0, raw = null } = {}) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.raw = raw
  }
}

/* 后端 ResponseStatusException 的 message 是英文/中文，
   但 Spring 默认 server.error.include-message=never，响应体里通常拿不到 message，
   所以主要靠状态码兜底；有 message 时优先用映射表 */
const MESSAGES = {
  'Department name must be 1 to 100 characters': '部门名称需为 1–100 个字符',
  'Parent department does not exist': '上级部门不存在，请刷新后重试',
  'Choose an active employee as leader': '负责人必须是在职员工',
  'Department does not exist': '该部门不存在，可能已被删除',
  登录账号或工号已存在: '登录账号已存在，请更换一个',
  员工不存在: '该员工不存在，可能已被删除'
}

function readError(status, data, errors) {
  const raw = data && typeof data === 'object' ? data.message : ''
  if (raw && MESSAGES[raw]) return MESSAGES[raw]

  // Vite 代理连不上后端时返回纯文本（ECONNREFUSED）
  const proxyDown =
    status >= 500 &&
    (!data || typeof data !== 'object')

  if (proxyDown) return '后端服务未响应，请确认 Spring Boot 已在 8080 端口启动'
  if (raw) return raw

  /* 同一个状态码在不同模块含义不同：409 在员工模块是「账号已存在」，
     在线索模块是「状态已变化」。调用方给的文案优先于默认文案 */
  if (errors && errors[status]) return errors[status]

  if (status === 400) return '提交的数据不符合要求，请检查账号格式与所属部门'
  if (status === 401) return '登录已失效，请重新登录'
  if (status === 403) return '没有权限执行该操作'
  if (status === 404) return '数据不存在，可能已被删除'
  if (status === 405) return '该操作的后端接口尚未实现'
  if (status === 409) return '登录账号已存在，请更换一个'
  if (status >= 500) return '服务端异常，请稍后重试'
  return `请求失败（HTTP ${status}）`
}

async function parseBody(res) {
  const text = await res.text()
  if (!text) return null
  try {
    return JSON.parse(text)
  } catch {
    return text
  }
}

export async function request(path, { method = 'GET', body, headers, errors, query, raw } = {}) {
  const init = {
    method,
    headers: { Accept: 'application/json', ...headers }
  }
  let url = `${BASE}${path}`
  if (query) {
    const qs = new URLSearchParams(
      Object.entries(query).filter(([, v]) => v !== undefined && v !== null && v !== '')
    ).toString()
    if (qs) url += `?${qs}`
  }

  if (body !== undefined) {
    if (typeof FormData !== 'undefined' && body instanceof FormData) {
      /* 文件上传：交给浏览器自己带 boundary，手写 Content-Type 会坏 */
      init.body = body
    } else if (raw) {
      init.body = body
    } else {
      init.headers['Content-Type'] = 'application/json'
      init.body = JSON.stringify(body)
    }
  }

  let res
  try {
    res = await fetch(url, init)
  } catch {
    throw new ApiError('无法连接后端服务，请确认 Spring Boot 已启动（默认 http://localhost:8080）')
  }

  if (raw && res.ok) return res.blob()

  const data = await parseBody(res)
  if (!res.ok) {
    throw new ApiError(readError(res.status, data, errors), { status: res.status, raw: data })
  }
  return data
}

export const apiBase = BASE
