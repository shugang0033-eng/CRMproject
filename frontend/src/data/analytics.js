/**
 * 数据模块演示数据
 * ==========================================================================
 * 口径先定死，后端照这个实现，页面上的数字才不会互相打脸：
 *
 *  1. 业绩 = 发货额（订单实际发出的金额）。已取消订单不计入，退货冲减。
 *     之所以不用签约额：年框一签就是几百万，但全年是否真发货不确定，
 *     用签约额考核会虚高，业务员也会靠签约冲量。
 *     回款额只做「回款质量」指标，不参与完成度计算。
 *  2. 金额单位一律「元」，展示时再折成万，避免前后端两套精度。
 *  3. 时间按自然月归集，发货日落在哪个月就算哪个月；季度 = 该季 3 个月合计。
 *  4. 线索阶段固定六态：待联系 → 已联系 → 已报样报价 → 谈判中 → 成交 / 无效。
 *     漏斗只看「已进入」的线索，无效单独统计，不参与阶段转化率。
 *  5. 数据范围（scope）由后端按角色裁剪：self 只看自己、dept 看本部门及下级、
 *     all 看全公司。前端只负责展示，不自己过滤。
 *
 * 下面是确定性生成的演示数据（无随机数），改日期也不用重新造数。
 * ========================================================================== */

/* 近 12 个自然月，最后一个月是当前月 */
export const MONTHS = [
  '2025-12', '2026-01', '2026-02', '2026-03', '2026-04', '2026-05',
  '2026-06', '2026-07', '2026-08', '2026-09', '2026-10', '2026-11'
]
export const MONTH_LABELS = MONTHS.map((m) => `${Number(m.slice(5))}月`)

/* 耗材生意的季节节奏：1-2 月春节停工，9-11 月门店备货冲量 */
const SEASON = [1.05, 0.68, 0.8, 0.95, 1.02, 0.97, 0.92, 0.99, 1.08, 1.15, 1.2, 1.26]
const SEASON_YTD = SEASON.slice(1).reduce((s, v) => s + v, 0) // 2026 年 1-11 月

/* 时间范围选项：前后端统一用 period 参数 */
export const PERIODS = [
  { value: 'month', label: '本月' },
  { value: 'quarter', label: '本季度' },
  { value: 'year', label: '本年度' },
  { value: 'last12', label: '近 12 个月' }
]

/* ---------------- 人员与目标 ----------------
 * 年度目标 = 「设置 › 业绩目标」里 Q4 目标 × 4，保证两个页面口径一致。
 * perf 是个人发挥系数（1 = 按目标节奏走），用来演示完成度的差异。 */
export const STAFF_SEED = [
  { name: '许知远', dept: '区域销售部', role: '销售主管', target: 8400000, avgDeal: 210000, perf: 1.12 },
  { name: '陈默', dept: '汽配渠道部', role: '销售主管', target: 6400000, avgDeal: 165000, perf: 1.06 },
  { name: '苏晚', dept: '主机厂配套部', role: '客户经理', target: 6400000, avgDeal: 320000, perf: 0.9 },
  { name: '唐棠', dept: '主机厂配套部', role: '客户经理', target: 4800000, avgDeal: 260000, perf: 1.02 },
  { name: '何思', dept: '电商运营部', role: '市场专员', target: 4800000, avgDeal: 26000, perf: 1.06 },
  { name: '林致远', dept: '汽配渠道部', role: '销售总监', target: 4400000, avgDeal: 420000, perf: 0.95 },
  { name: '罗一鸣', dept: '区域销售部', role: '客户经理', target: 4400000, avgDeal: 120000, perf: 0.88 },
  { name: '周予安', dept: '华东组', role: '客户经理', target: 2400000, avgDeal: 96000, perf: 0.84 },
  { name: '沈亦', dept: '汽配渠道部', role: '客户经理', target: 2000000, avgDeal: 88000, perf: 0.78 },
  { name: '郑南', dept: '华南组', role: '客户经理', target: 1600000, avgDeal: 88000, perf: 0.82 }
]

/* 二级部门归到一级部门，和「设置 › 部门管理」的树保持一致 */
const DEPT_PARENT = { 华东组: '区域销售部', 华南组: '区域销售部' }
export const deptOf = (d) => DEPT_PARENT[d] || d

export const DEPTS = ['汽配渠道部', '主机厂配套部', '区域销售部', '电商运营部']

/* ---------------- 人员 × 月份 明细（一切汇总的源头） ---------------- */
const staffMonthly = STAFF_SEED.flatMap((s, si) =>
  MONTHS.map((m, mi) => {
    /* 微扰让曲线不像一条平滑的假线，但保持确定性 */
    const wobble = 0.9 + 0.16 * Math.abs(Math.sin((si + 1) * 3.7 + mi * 2.3))
    const signed = Math.round((s.target / 12) * SEASON[mi] * s.perf * wobble)
    return {
      month: m,
      name: s.name,
      dept: s.dept,
      deals: Math.max(1, Math.round(signed / s.avgDeal)),
      signed
    }
  })
)

/* ---------------- 月度汇总 ---------------- */
export const monthly = MONTHS.map((m, mi) => {
  const rows = staffMonthly.filter((r) => r.month === m)
  const signed = rows.reduce((s, r) => s + r.signed, 0)
  const deals = rows.reduce((s, r) => s + r.deals, 0)
  /* 回款滞后一个月：上月发货本月收；collectRate 让每月回款率有起伏，
     否则两条曲线会完全平行，看不出账期松紧的变化 */
  const prev = mi > 0 ? staffMonthly.filter((r) => r.month === MONTHS[mi - 1]).reduce((s, r) => s + r.signed, 0) : signed
  const collectRate = 0.72 + 0.18 * Math.abs(Math.sin(mi * 1.9))
  const received = Math.round(prev * collectRate + signed * 0.12)
  return {
    month: m,
    label: MONTH_LABELS[mi],
    signed,
    received,
    deals,
    leads: 68 + Math.round(SEASON[mi] * 34),
    customers: Math.max(3, Math.round(deals * 0.38))
  }
})

/* 2026 年（1-11 月）的累计，业绩口径按发货额 */
const YTD = monthly.slice(1)
const PREV_YTD = monthly.slice(0, 11)

const sum = (list, key) => list.reduce((s, r) => s + (r[key] || 0), 0)

function delta(cur, prev) {
  if (!prev) return 0
  return Number((((cur - prev) / prev) * 100).toFixed(1))
}

const ytdSigned = sum(YTD, 'signed')
const ytdReceived = sum(YTD, 'received')
const ytdDeals = sum(YTD, 'deals')
const ytdLeads = sum(YTD, 'leads')
const ytdCustomers = sum(YTD, 'customers')
const annualTarget = STAFF_SEED.reduce((s, r) => s + r.target, 0)

/* ---------------- 概况 KPI ---------------- */
export const summary = {
  ytdSigned,
  ytdReceived,
  ytdDeals,
  ytdLeads,
  ytdCustomers,
  annualTarget,
  completion: Number(((ytdSigned / annualTarget) * 100).toFixed(1)),
  /* 时间进度：11 / 12 个月，完成度低于它就算掉队 */
  timeProgress: 91.7,
  avgDeal: Math.round(ytdSigned / ytdDeals),
  winRate: 12.6,
  signedDelta: delta(ytdSigned, sum(PREV_YTD, 'signed')),
  receivedDelta: delta(ytdReceived, sum(PREV_YTD, 'received')),
  dealsDelta: delta(ytdDeals, sum(PREV_YTD, 'deals')),
  leadsDelta: delta(ytdLeads, sum(PREV_YTD, 'leads')),
  customersDelta: delta(ytdCustomers, sum(PREV_YTD, 'customers')),
  avgDealDelta: delta(ytdSigned / ytdDeals, sum(PREV_YTD, 'signed') / sum(PREV_YTD, 'deals')),
  /* 本月 vs 上月 */
  monthSigned: monthly[11].signed,
  monthSignedDelta: delta(monthly[11].signed, monthly[10].signed),
  monthReceived: monthly[11].received,
  monthDeals: monthly[11].deals
}

/* ---------------- 漏斗 ---------------- */
export const funnelStages = [
  { key: 'new', label: '线索接入', count: 1240, fromPrev: 100, avgDays: 0, desc: '来自展会、1688、官网与转介绍' },
  { key: 'contacted', label: '已联系', count: 872, fromPrev: 70.3, avgDays: 1.8, desc: '48 小时内完成首次触达' },
  { key: 'quoted', label: '已报样 / 报价', count: 503, fromPrev: 57.7, avgDays: 4.2, desc: '寄样或出具正式报价单' },
  { key: 'negotiating', label: '谈判中', count: 271, fromPrev: 53.9, avgDays: 11.6, desc: '价格、账期、起订量谈判' },
  { key: 'won', label: '成交', count: 156, fromPrev: 57.6, avgDays: 18.4, desc: '签订供货协议或首批订单' }
]

export const funnel = {
  stages: funnelStages,
  invalid: 168,
  overallRate: 12.6,
  overallRateDelta: 1.4,
  /* 阶段流失原因，用于漏斗页右侧的归因 */
  lossReasons: [
    { label: '价格高于心理预期', count: 214, ratio: 34.1 },
    { label: '已有稳定供应商', count: 158, ratio: 25.2 },
    { label: '起订量谈不拢', count: 96, ratio: 15.3 },
    { label: '账期要求超授信', count: 74, ratio: 11.8 },
    { label: '需求延后 / 项目暂停', count: 52, ratio: 8.3 },
    { label: '联系不上', count: 33, ratio: 5.3 }
  ],
  /* 分来源的阶段转化，用来判断哪类线索值得多投 */
  bySource: [
    { source: '汽配展', count: 386, contacted: 302, quoted: 186, negotiating: 108, won: 62, rate: 16.1 },
    { source: '1688 询盘', count: 312, contacted: 214, quoted: 104, negotiating: 52, won: 34, rate: 10.9 },
    { source: '官网询盘', count: 228, contacted: 168, quoted: 86, negotiating: 41, won: 21, rate: 9.2 },
    { source: '汽配城拜访', count: 174, contacted: 128, quoted: 82, negotiating: 44, won: 26, rate: 14.9 },
    { source: '客户转介绍', count: 86, contacted: 74, quoted: 52, negotiating: 28, won: 11, rate: 12.8 },
    { source: '电话外呼', count: 54, contacted: 22, quoted: 9, negotiating: 4, won: 2, rate: 3.7 }
  ],
  /* 近 6 个月整体转化率 */
  trend: [
    { label: '6月', value: 10.4 }, { label: '7月', value: 11.2 }, { label: '8月', value: 11.8 },
    { label: '9月', value: 12.1 }, { label: '10月', value: 12.4 }, { label: '11月', value: 13.2 }
  ]
}

/* ---------------- 来源 ROI ---------------- */
export const sourceRoi = [
  { source: '汽配展', leads: 386, won: 62, amount: 17200000, cost: 286000, cycle: 46, note: '上海 / 广州两场，展位加物料' },
  { source: '1688 询盘', leads: 312, won: 34, amount: 5900000, cost: 96000, cycle: 28, note: '店铺推广费与客服人力' },
  { source: '官网询盘', leads: 228, won: 21, amount: 3800000, cost: 42000, cycle: 31, note: 'SEO 与落地页投放' },
  { source: '汽配城拜访', leads: 174, won: 26, amount: 7400000, cost: 138000, cycle: 24, note: '跑店差旅与样品寄送' },
  { source: '客户转介绍', leads: 86, won: 11, amount: 3400000, cost: 12000, cycle: 19, note: '老客返点与答谢' },
  { source: '电话外呼', leads: 54, won: 2, amount: 660000, cost: 68000, cycle: 12, note: '外呼系统与名单采购' }
].map((r) => ({
  ...r,
  rate: Number(((r.won / r.leads) * 100).toFixed(1)),
  cac: Math.round(r.cost / r.won),
  roi: Number((r.amount / r.cost).toFixed(1)),
  avgDeal: Math.round(r.amount / r.won)
}))

/* 各来源月度接入量，堆叠柱用 */
export const sourceTrend = MONTH_LABELS.map((label, mi) => ({
  label,
  汽配展: 18 + Math.round(SEASON[mi] * 12),
  '1688 询盘': 16 + Math.round(SEASON[mi] * 10),
  官网询盘: 12 + Math.round(SEASON[mi] * 7),
  汽配城拜访: 9 + Math.round(SEASON[mi] * 6),
  客户转介绍: 4 + Math.round(SEASON[mi] * 3),
  电话外呼: 3 + Math.round(SEASON[mi] * 2)
}))

/* ---------------- 客户与跟进 ---------------- */
export const customerAnalysis = {
  total: 386,
  active: 214,
  following: 168,
  sleeping: 96,
  churnRisk: 42,
  churned: 34,
  /* 复购：近 12 个月下过 2 单及以上的客户占比 */
  repeatRate: 62.4,
  repeatRateDelta: 3.8,
  avgCycle: 38,
  avgCycleDelta: -2.4,
  newRate: 21.6,
  /* 复购周期分布 */
  cycleBuckets: [
    { label: '20 天以内', count: 84, ratio: 21.8 },
    { label: '20–30 天', count: 118, ratio: 30.6 },
    { label: '30–45 天', count: 96, ratio: 24.9 },
    { label: '45–60 天', count: 48, ratio: 12.4 },
    { label: '60 天以上', count: 40, ratio: 10.4 }
  ],
  /* 沉睡客户：超过 60 天没有出货，按历史金额排序 */
  sleepingList: [
    { id: 'CU-1017', name: '合肥皖通汽配贸易', owner: '梁书', level: 'C 类', lastOrder: '2026-08-26', days: 80, amount: 54000, cycle: 45 },
    { id: 'CU-1015', name: '金华众诚汽车服务', owner: '何思', level: 'C 类', lastOrder: '2026-09-02', days: 73, amount: 186000, cycle: 30 },
    { id: 'CU-1018', name: '常州瑞虎汽车维修中心', owner: '郑南', level: 'B 类', lastOrder: '2026-09-08', days: 67, amount: 186000, cycle: 38 },
    { id: 'CU-1020', name: '苏州车之翼汽车用品', owner: '苏晚', level: 'B 类', lastOrder: '2026-09-14', days: 61, amount: 328000, cycle: 30 },
    { id: 'CU-1024', name: '东莞寮步汽车养护中心', owner: '陈默', level: 'B 类', lastOrder: '2026-09-15', days: 60, amount: 86000, cycle: 45 },
    { id: 'CU-0998', name: '青岛恒达汽修设备', owner: '周予安', level: 'C 类', lastOrder: '2026-09-16', days: 59, amount: 42000, cycle: 60 }
  ],
  /* 跟进活跃度 */
  follow: {
    total: 2860,
    perPerson: 286,
    overdue: 38,
    overdueRate: 13.3,
    avgPerDay: 9.5,
    resultDist: [
      { label: '推进', count: 1659, ratio: 58, tone: 'success' },
      { label: '待反馈', count: 601, ratio: 21, tone: 'info' },
      { label: '待回款', count: 343, ratio: 12, tone: 'warning' },
      { label: '暂缓', count: 257, ratio: 9, tone: 'gray' }
    ],
    typeDist: [
      { label: '微信', count: 1042, ratio: 36.4 },
      { label: '电话', count: 886, ratio: 31 },
      { label: '客户拜访', count: 512, ratio: 17.9 },
      { label: '线上会议', count: 246, ratio: 8.6 },
      { label: '邮件', count: 174, ratio: 6.1 }
    ]
  },
  /* 客户状态流转，月初 → 月末 */
  statusFlow: [
    { label: '跟进中', from: 186, to: 168, moved: -18 },
    { label: '合作中', from: 202, to: 214, moved: 12 },
    { label: '流失风险', from: 36, to: 42, moved: 6 },
    { label: '已流失', from: 30, to: 34, moved: 4 }
  ]
}

/* ---------------- 业绩 ---------------- */
export const staffPerf = STAFF_SEED.map((s) => {
  const rows = staffMonthly.filter((r) => r.name === s.name && r.month !== '2025-12')
  const signed = rows.reduce((a, r) => a + r.signed, 0)
  const deals = rows.reduce((a, r) => a + r.deals, 0)
  return {
    name: s.name,
    dept: s.dept,
    deptTop: deptOf(s.dept),
    role: s.role,
    target: s.target,
    signed,
    deals,
    completion: Number(((signed / s.target) * 100).toFixed(1)),
    avgDeal: Math.round(signed / deals),
    gap: s.target - signed
  }
}).sort((a, b) => b.signed - a.signed)

export const deptPerf = DEPTS.map((d) => {
  const rows = staffPerf.filter((r) => r.deptTop === d)
  const target = rows.reduce((s, r) => s + r.target, 0)
  const signed = rows.reduce((s, r) => s + r.signed, 0)
  const deals = rows.reduce((s, r) => s + r.deals, 0)
  return {
    dept: d,
    headcount: rows.length,
    target,
    signed,
    deals,
    completion: Number(((signed / target) * 100).toFixed(1)),
    avgDeal: Math.round(signed / deals),
    /* 部门内人均发货，看的是人效而不是人数 */
    perHead: Math.round(signed / rows.length)
  }
}).sort((a, b) => b.signed - a.signed)

export const performanceAnalysis = {
  staff: staffPerf,
  depts: deptPerf,
  top10: staffPerf.slice(0, 10),
  /* 完成度分层，用于「有多少人掉队」 */
  buckets: [
    { label: '超 100%', count: staffPerf.filter((r) => r.completion >= 100).length, tone: 'success' },
    { label: '80–100%', count: staffPerf.filter((r) => r.completion >= 80 && r.completion < 100).length, tone: 'brand' },
    { label: '60–80%', count: staffPerf.filter((r) => r.completion >= 60 && r.completion < 80).length, tone: 'warning' },
    { label: '低于 60%', count: staffPerf.filter((r) => r.completion < 60).length, tone: 'danger' }
  ],
  /* 季度完成情况：Q4 只过了两个月，目标按季度全额算 */
  quarters: [
    { label: 'Q1', target: annualTarget / 4, signed: Math.round(ytdSigned * 0.24) },
    { label: 'Q2', target: annualTarget / 4, signed: Math.round(ytdSigned * 0.26) },
    { label: 'Q3', target: annualTarget / 4, signed: Math.round(ytdSigned * 0.29) },
    { label: 'Q4', target: annualTarget / 4, signed: Math.round(ytdSigned * 0.21) }
  ].map((q) => ({ ...q, completion: Number(((q.signed / q.target) * 100).toFixed(1)) }))
}

/* ---------------- 回款 ---------------- */
export const paymentAnalysis = {
  /* 应收余额 = 已发货未收回（累计应收 2,460 万 − 已回款 1,820 万），
     和账龄五项合计对齐，三个数放在一屏上不能互相打架 */
  receivable: 6400000,
  received: 18204000,
  overdue: 2360000,
  rate: 74,
  rateDelta: 2.6,
  avgDays: 41,
  /* 账龄：余额落在哪个区间，五项合计 = 应收余额 640 万 */
  aging: [
    { label: '未到期', amount: 4040000, ratio: 63.1, tone: 'success' },
    { label: '逾期 1–30 天', amount: 1420000, ratio: 22.2, tone: 'warning' },
    { label: '逾期 31–60 天', amount: 680000, ratio: 10.6, tone: 'warning' },
    { label: '逾期 61–90 天', amount: 190000, ratio: 3, tone: 'danger' },
    { label: '逾期 90 天以上', amount: 70000, ratio: 1.1, tone: 'danger' }
  ],
  /* 逾期明细 */
  overdueList: [
    { contract: 'HT-2026-0186', customer: '南京依维柯配件部', owner: '苏晚', amount: 338800, dueDate: '2026-11-08', days: 6, method: '月结 60 天' },
    { contract: 'HT-2026-0179', customer: '合肥皖通汽配贸易', owner: '梁书', amount: 128000, dueDate: '2026-10-28', days: 17, method: '票到付款' },
    { contract: 'HT-2026-0171', customer: '青岛恒达汽修设备', owner: '周予安', amount: 96000, dueDate: '2026-10-15', days: 30, method: '月结 30 天' },
    { contract: 'HT-2026-0165', customer: '成都鑫源汽配城商户', owner: '陈默', amount: 246000, dueDate: '2026-09-22', days: 53, method: '银行承兑' },
    { contract: 'HT-2026-0158', customer: '厦门路达汽车快修', owner: '郑南', amount: 68000, dueDate: '2026-08-30', days: 76, method: '月结 30 天' },
    { contract: 'HT-2026-0142', customer: '台州宏运汽配商行', owner: '何思', amount: 42000, dueDate: '2026-07-18', days: 119, method: '票到付款' }
  ],
  /* 按销售的应收与回款率 */
  byOwner: [
    { owner: '许知远', dept: '区域销售部', receivable: 5860000, received: 3210000, rate: 54.8 },
    { owner: '陈默', dept: '汽配渠道部', receivable: 4620000, received: 3480000, rate: 75.3 },
    { owner: '苏晚', dept: '主机厂配套部', receivable: 4980000, received: 4120000, rate: 82.7 },
    { owner: '唐棠', dept: '主机厂配套部', receivable: 3240000, received: 2860000, rate: 88.3 },
    { owner: '何思', dept: '电商运营部', receivable: 1620000, received: 1480000, rate: 91.4 },
    { owner: '林致远', dept: '汽配渠道部', receivable: 2480000, received: 1620000, rate: 65.3 },
    { owner: '罗一鸣', dept: '区域销售部', receivable: 1800000, received: 1434000, rate: 79.7 }
  ]
}

/* ---------------- 产品 ---------------- */
export const productAnalysis = {
  categories: [
    { name: '洗车毛巾', sales: 12860000, qty: 186000, gross: 4120000, margin: 32, ratio: 33.6, delta: 8.4 },
    { name: '清洁工具', sales: 9820000, qty: 142000, gross: 3540000, margin: 36.1, ratio: 25.6, delta: 12.6 },
    { name: '清洁剂', sales: 7460000, qty: 96000, gross: 2680000, margin: 35.9, ratio: 19.5, delta: -3.2 },
    { name: '抛光耗材', sales: 5180000, qty: 74000, gross: 1760000, margin: 34, ratio: 13.5, delta: 4.8 },
    { name: '擦拭纸', sales: 2980000, qty: 52000, gross: 894000, margin: 30, ratio: 7.8, delta: 1.6 }
  ],
  topSku: [
    { code: 'BC-TW4060-380', name: '超细纤维擦车巾 40×60 380g', category: '洗车毛巾', qty: 62000, amount: 3180000, margin: 30.2, owner: '汽配展' },
    { code: 'BC-TW60160-400', name: '珊瑚绒擦车巾 60×160 400g', category: '洗车毛巾', qty: 41000, amount: 2960000, margin: 34.2, owner: '1688 询盘' },
    { code: 'BC-BR-LH01', name: '长柄轮毂刷 硬毛', category: '清洁工具', qty: 36000, amount: 2480000, margin: 37.8, owner: '汽配展' },
    { code: 'BC-CL-FOAM1L', name: '泡沫洗车液 1L 浓缩', category: '清洁剂', qty: 28000, amount: 2140000, margin: 39.3, owner: '1688 询盘' },
    { code: 'BC-BR-SET5', name: '细节刷 5 件套', category: '清洁工具', qty: 24000, amount: 1860000, margin: 38.6, owner: '汽配城拜访' },
    { code: 'BC-PL-5IN', name: '抛光还原盘 5 寸', category: '抛光耗材', qty: 21000, amount: 1420000, margin: 42.7, owner: '客户转介绍' },
    { code: 'BC-BR-TR02', name: '弧形轮胎刷 中硬毛', category: '清洁工具', qty: 19000, amount: 1280000, margin: 37.5, owner: '汽配展' },
    { code: 'BC-CL-WHEEL500', name: '轮毂清洗剂 500ml', category: '清洁剂', qty: 17000, amount: 1160000, margin: 36.8, owner: '汽配城拜访' },
    { code: 'BC-PVA4332', name: 'PVA 吸水巾 43×32', category: '洗车毛巾', qty: 12000, amount: 920000, margin: 32.9, owner: '1688 询盘' },
    { code: 'BC-SP-8ZI', name: '洗车海绵 8 字大孔', category: '清洁工具', qty: 15000, amount: 680000, margin: 39.2, owner: '汽配展' }
  ],
  /* 滞销：60 天没有出货，压的是仓库和现金 */
  slowMoving: [
    { code: 'BC-LP4060', name: '真皮鹿皮巾 40×60', category: '洗车毛巾', stock: 1860, amount: 232500, days: 96, cost: 880 },
    { code: 'BC-PL-3IN', name: '抛光还原盘 3 寸', category: '抛光耗材', stock: 2400, amount: 168000, days: 78, cost: 210 },
    { code: 'BC-CL-INT500', name: '内饰清洁剂 500ml', category: '清洁剂', stock: 1580, amount: 126400, days: 72, cost: 240 },
    { code: 'BC-TW3030-300', name: '超细纤维小方巾 30×30', category: '洗车毛巾', stock: 4200, amount: 92400, days: 65, cost: 66 },
    { code: 'BC-WP-01', name: '一次性擦拭纸 卷装', category: '擦拭纸', stock: 960, amount: 62400, days: 61, cost: 195 }
  ],
  /* 品类月度销售额（万元），三条线足够看结构变化 */
  trend: MONTH_LABELS.map((label, mi) => ({
    label,
    洗车毛巾: Number((68 * SEASON[mi]).toFixed(1)),
    清洁工具: Number((52 * SEASON[mi]).toFixed(1)),
    清洁剂: Number((31 * SEASON[mi]).toFixed(1)),
    抛光耗材: Number((24 * SEASON[mi]).toFixed(1))
  }))
}

/* ---------------- 预警（概况页底部，点击可下钻） ---------------- */
export const alerts = [
  { key: 'overdue', level: 'danger', title: '回款已逾期', count: 6, amount: 2360000, desc: '其中 2 笔超过 60 天，建议本周内出催收函', path: '/analytics/payments', perm: 'data.payments' },
  { key: 'stale', level: 'warning', title: '超期未跟进客户', count: 38, desc: '超过承诺日期还没回访，占在跟客户的 13.3%', path: '/analytics/customers', perm: 'data.customers' },
  { key: 'target', level: 'warning', title: '业绩进度落后', count: 4, desc: '4 人完成度低于时间进度（91.7%），缺口合计 ¥486 万', path: '/analytics/performance', perm: 'data.performance' },
  { key: 'slow', level: 'info', title: '滞销 SKU 占压', count: 5, desc: '60 天零出货，库存金额 ¥68.2 万', path: '/analytics/products', perm: 'data.products' }
]

/* ---------------- 展示格式化 ---------------- */
/** 元 → 万元，保留 1 位；用于图表轴与卡片 */
export function wan(v, digits = 1) {
  /* 接口没返回或字段为 null 时给 —，不要让 NaN 传到图表和文案里 */
  const n = Number(v)
  if (v == null || Number.isNaN(n)) return '—'
  return (n / 10000).toFixed(digits)
}

/** 千分位金额，用于表格 */
export function money(v) {
  if (v === null || v === undefined) return '—'
  return `¥${Math.round(v).toLocaleString('zh-CN')}`
}

export function pct(v, digits = 1) {
  return `${Number(v).toFixed(digits)}%`
}

/** 完成度色：低于时间进度算掉队，超过 100% 算达标 */
export function completionTone(v, baseline = 91.7) {
  if (v >= 100) return 'success'
  if (v >= baseline) return 'brand'
  if (v >= baseline * 0.8) return 'warning'
  return 'danger'
}
