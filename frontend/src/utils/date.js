/**
 * 日期工具
 *
 * 为什么单独抽出来：`new Date().toISOString().slice(0, 10)` 取的是 **UTC** 日期，
 * 东八区 00:00–08:00 之间会得到「昨天」。表单默认日期、今日筛选、单据日期都会跟着错一天，
 * 而且只在早上出错，最难复现。统一用本地日期。
 */

const pad = (n) => String(n).padStart(2, '0')

/** 任意 Date -> 本地 YYYY-MM-DD */
export function localDate(d = new Date()) {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

/** 今天（本地）YYYY-MM-DD */
export function todayStr() {
  return localDate()
}
