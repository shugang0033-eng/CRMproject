import { ApiError, request } from './http'

/**
 * 个人中心接口（基于当前员工的服务端会话）
 *
 * 全部接口基于当前 HttpSession，不需要传 userId：
 *   1) GET    /api/profile
 *        -> Profile
 *   2) PUT    /api/profile              { name, phone, email }        -> 204
 *   3) POST   /api/profile/avatar       { dataUrl }                   -> { avatar }
 *      dataUrl 是前端压缩后的 240x240 JPEG base64，单张约 20–40KB，
 *      后端可直接存 longtext 字段 / 或落盘后回写 URL
 *   4) POST   /api/profile/password     { oldPassword, newPassword }  -> 204
 *      旧密码错误返回 400，未登录返回 401
 *   5) GET    /api/profile/logins
 *        -> LoginRecord[]  最近登录记录，按时间倒序，最多 10 条
 *
 * Profile 结构：
 *   {
 *     id, account, employeeNo, name, dept, deptId, role, roleCode,
 *     phone, email, avatar, hireDate, status,
 *     lastLoginAt, lastLoginIp, passwordUpdatedAt, mustChangePassword
 *   }
 *
 * LoginRecord 结构：
 *   { id, device, ip, location, at, current }
 */
export const profileApi = {
  get: () => request('/profile'),
  update: (body) => request('/profile', { method: 'PUT', body }),
  uploadAvatar: (dataUrl) => request('/profile/avatar', { method: 'POST', body: { dataUrl } }),
  changePassword: (body) => request('/profile/password', { method: 'POST', body }),
  logins: () => request('/profile/logins')
}

/**
 * 判断是不是「后端还没写这个接口」。
 * 404 / 405 / 501 / 连不上（status 0）都算未就绪，页面据此切到本地模式，
 * 避免把「接口没实现」误报成业务错误。
 */
export function isEndpointMissing(err) {
  if (!(err instanceof ApiError)) return false
  return err.status === 0 || err.status === 404 || err.status === 405 || err.status === 501
}

