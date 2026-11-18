/**
 * 头像与姓名展示的小工具
 * ------------------------------------------------------------
 * 以前颜色来自 `@/data/mock` 的 coworkers 名单：名单里没有的人一律灰色，
 * 真实员工（宋江、林致远…）全变成灰球，于是客户列表又按「名字长度 % 演示人数」
 * 随便借一个演示同事的颜色——纯属为了好看而造假数据。
 * 现在直接按姓名哈希取色：同一个人永远同一个颜色，跟任何名单无关。
 */

/** 12 色，深底白字，彼此区分度够用 */
const PALETTE = [
  '#2563eb', '#7c3aed', '#0891b2', '#059669',
  '#d97706', '#dc2626', '#db2777', '#4f46e5',
  '#0d9488', '#b45309', '#9333ea', '#0369a1'
]

const FALLBACK = '#64748b'

/** 姓名 → 稳定底色（空名回退中性灰） */
export function nameColor(name = '') {
  const s = String(name || '').trim()
  if (!s) return FALLBACK
  let h = 0
  for (let i = 0; i < s.length; i += 1) h = (h * 31 + s.charCodeAt(i)) % 100003
  return PALETTE[h % PALETTE.length]
}

/** 头像里显示的字：两个字以内全显，超过取后两字（中文名后两字更易辨认） */
export function initials(name = '') {
  const s = String(name || '').trim()
  if (!s) return '—'
  return s.length <= 2 ? s : s.slice(-2)
}
