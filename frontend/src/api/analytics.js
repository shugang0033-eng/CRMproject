import { request } from './http'

/**
 * 数据模块接口（契约先行，后端尚未实现）
 * ------------------------------------------------------------
 * 页面当前用 src/data/analytics.js 的本地数据演示，后端就绪后把视图里的
 * 本地对象换成这些方法即可，参数与返回结构不用改。完整表结构与口径见
 * docs/analytics-api.md。
 *
 * 通用约定：
 *  - 全部 GET，只读。没有写接口。
 *  - 统一筛选参数：period（month|quarter|year|last12）、deptId、ownerId。
 *    三个参数都传空 = 按当前账号的数据范围（scope）取全部。
 *  - 金额单位「元」，整数；比率单位「%」，保留 1 位小数。
 *  - 后端必须按 data.scope 裁剪：self 只能查到自己，传别人的 ownerId 返回 403。
 *  - 「业绩」一律按签约额（合同签订金额），不按回款额。
 */

/** 时间与范围筛选，所有分析接口共用 */
const scope = (params = {}) => ({
  period: params.period || 'year',
  deptId: params.deptId,
  ownerId: params.ownerId
})

export const analyticsApi = {
  filters: () => request('/analytics/filters'),
  /** GET /api/analytics/summary  -> { kpis, monthly[], alerts[] } */
  summary: (params) => request('/analytics/summary', { query: scope(params) }),

  /** GET /api/analytics/funnel  -> { stages[], invalid, overallRate, lossReasons[], bySource[], trend[] } */
  funnel: (params) => request('/analytics/funnel', { query: scope(params) }),

  /** GET /api/analytics/customers  -> 复购、沉睡、跟进活跃度 */
  customers: (params) => request('/analytics/customers', { query: scope(params) }),

  /** GET /api/analytics/performance?dimension=dept|staff  -> { depts[], staff[], top10[], buckets[] } */
  performance: (params) =>
    request('/analytics/performance', { query: { ...scope(params), dimension: params?.dimension || 'dept' } }),

  /** GET /api/analytics/payments  -> 账龄、逾期明细、按销售回款率 */
  payments: (params) => request('/analytics/payments', { query: scope(params) }),

  /**
   * GET /api/analytics/products
   * 无 product.cost 权限时，后端要把 gross / margin / cost 字段整个删掉，
   * 不能返回 null——前端按字段是否存在决定是否渲染毛利列。
   */
  products: (params) => request('/analytics/products', { query: scope(params) }),

  /** GET /api/analytics/sources  -> 渠道 ROI 表 + 月度接入趋势 */
  sources: (params) => request('/analytics/sources', { query: scope(params) }),

  /** GET /api/analytics/export?type=summary|funnel|...  -> xlsx 文件流 */
  exportFile: (type, params) => request('/analytics/export', { query: { ...scope(params), type }, raw: true })
}

