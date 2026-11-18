/**
 * 行政财务 · 演示数据
 * ------------------------------------------------------------
 * 这个板块把「费用报销 / 借款预支 / 请假申请 / 审批中心」放在一起，因为它们是同一件事：
 * 员工发起 → 主管审批 → 财务留痕。拆成三个互不相干的页面，审批人每天要在三个列表里找待办，
 * 员工也说不清「我上周那笔钱走到哪了」。
 *
 * 两条业务约定（后端建模照这个走）：
 *  1. 借款与报销是「一对多抵扣」：一笔预支可以分多次报销冲掉，报销单上记 deductLoanId + deductAmount。
 *     抵扣不是提交即生效，而是**审批通过才生效** —— 提交就冲会让被驳回的单子白占额度。
 *  2. 借款余额 = 借款金额 − Σ 已生效抵扣，不存字段，现算。存了就会和报销单打架。
 */

import { ref, computed } from 'vue'
import { todayStr, localDate } from '@/utils/date'

const round2 = (n) => Math.round(n * 100) / 100

const TODAY = todayStr()
export { localDate }

/* ============================ 费用报销 ============================ */

/**
 * items 是唯一事实，amount 由 items 现算 —— 一张报销单可以是「高铁 1240 + 住宿 3000 + 市内交通 1000」，
 * 只剩一个总额的话财务审不了，员工也说不清钱花在哪。
 */
export const expenses = ref([
  {
    id: 'FY-2026-0613',
    applicant: '宋江',
    dept: '总经办',
    project: '合肥皖通汽配贸易',
    applyDate: '2026-11-10',
    desc: '合肥皖通年度合作洽谈，往返 3 天',
    trip: { from: '杭州', to: '合肥', start: '2026-11-06', end: '2026-11-08', days: 3 },
    items: [
      { date: '2026-11-06', type: '差旅', amount: 1180, note: '杭州东—合肥南 高铁往返', bills: 2 },
      { date: '2026-11-06', type: '差旅', amount: 1600, note: '合肥住宿 2 晚 × ¥800', bills: 1 },
      { date: '2026-11-08', type: '客户招待', amount: 500, note: '皖通采购部便餐 4 人', bills: 1 }
    ],
    deductLoanId: '',
    deductAmount: 0,
    attachments: ['高铁行程单.pdf'],
    status: '已通过',
    approver: '顾晓'
  },
  {
    id: 'FY-2026-0612',
    applicant: '陈默',
    dept: '汽配渠道部',
    project: '上海嘉定安驰 4S 店',
    applyDate: '2026-11-09',
    desc: '安驰 4S 店配件部年度合作宴请',
    trip: null,
    items: [
      { date: '2026-11-08', type: '客户招待', amount: 3860, note: '配件部年度合作宴请 6 人', bills: 2 }
    ],
    deductLoanId: '',
    deductAmount: 0,
    attachments: ['餐饮发票 2 张.pdf'],
    status: '审批中',
    approver: '顾晓'
  },
  {
    id: 'FY-2026-0611',
    applicant: '许知远',
    dept: '主机厂配套部',
    project: '南京依维柯配件部',
    applyDate: '2026-11-08',
    desc: '南京往返高铁及住宿 3 晚，依维柯年框对接',
    /* 差旅必须带行程：财务要判断住宿天数与出差天数是否对得上 */
    trip: { from: '杭州', to: '南京', start: '2026-11-05', end: '2026-11-07', days: 3 },
    items: [
      { date: '2026-11-05', type: '差旅', amount: 1240, note: '杭州东—南京南 高铁往返', bills: 2 },
      { date: '2026-11-05', type: '差旅', amount: 3000, note: '南京住宿 3 晚 × ¥1,000', bills: 1 },
      { date: '2026-11-07', type: '差旅', amount: 1000, note: '市内交通与停车', bills: 4 }
    ],
    deductLoanId: 'JK-2026-0033',
    deductAmount: 3000,
    attachments: ['高铁行程单.pdf', '住宿水单.jpg'],
    status: '已通过',
    approver: '顾晓'
  },
  {
    id: 'FY-2026-0610',
    applicant: '何思',
    dept: '电商运营部',
    project: '上海国际汽配展',
    applyDate: '2026-11-06',
    desc: '上海国际汽配展展位与易拉宝物料',
    trip: null,
    items: [
      { date: '2026-11-03', type: '市场活动', amount: 24000, note: '展位费 9 ㎡ 标准展位', bills: 1 },
      { date: '2026-11-04', type: '市场活动', amount: 4600, note: '易拉宝 4 套与宣传单页 2000 份', bills: 2 }
    ],
    deductLoanId: 'JK-2026-0031',
    deductAmount: 6000,
    attachments: ['展位合同.pdf'],
    status: '审批中',
    approver: '顾晓'
  },
  {
    id: 'FY-2026-0609',
    applicant: '梁书',
    dept: '仓储物流部',
    project: '杭州驰远汽车服务连锁',
    applyDate: '2026-11-04',
    desc: '驰远连锁三季度集采配送运费',
    trip: null,
    items: [
      { date: '2026-11-02', type: '物流运费', amount: 4860, note: '杭州仓—宁波 6 车次干线运输', bills: 6 }
    ],
    deductLoanId: '',
    deductAmount: 0,
    attachments: ['德邦对账单.pdf'],
    status: '已通过',
    approver: '顾晓'
  },
  {
    id: 'FY-2026-0608',
    applicant: '周予安',
    dept: '汽配渠道部',
    project: '宁波甬安汽修厂',
    applyDate: '2026-11-02',
    desc: '甬安汽修厂密封件试样，缺少寄样单',
    trip: null,
    items: [
      { date: '2026-11-01', type: '样品费', amount: 1280, note: '密封件试样 20 套，顺丰到付', bills: 1 }
    ],
    deductLoanId: '',
    deductAmount: 0,
    attachments: [],
    status: '驳回',
    approver: '顾晓'
  },
  {
    id: 'FY-2026-0607',
    applicant: '郑南',
    dept: '汽配渠道部',
    project: '台州汽配城',
    applyDate: '2026-10-31',
    desc: '宁波、台州汽配城跑店 2 天',
    trip: { from: '杭州', to: '台州', start: '2026-10-28', end: '2026-10-30', days: 3 },
    items: [
      { date: '2026-10-28', type: '差旅', amount: 620, note: '杭州—台州 高铁往返', bills: 2 },
      { date: '2026-10-28', type: '差旅', amount: 1560, note: '台州住宿 2 晚 × ¥780', bills: 1 },
      { date: '2026-10-29', type: '差旅', amount: 500, note: '市内交通与餐饮补贴', bills: 3 }
    ],
    deductLoanId: 'JK-2026-0029',
    deductAmount: 2500,
    attachments: ['差旅明细.xlsx'],
    status: '已通过',
    approver: '顾晓'
  }
])

/** 报销单合计：明细金额之和，不接受手填 */
export function expenseTotal(e) {
  return round2((e?.items || []).reduce((s, it) => s + Number(it.amount || 0), 0))
}
/** 票据张数：财务归档要按张数核对，缺票要退 */
export function expenseBills(e) {
  return (e?.items || []).reduce((s, it) => s + Number(it.bills || 0), 0)
}
/** 明细条数 */
export function expenseLines(e) {
  return (e?.items || []).length
}
/** 差旅类型：有一个明细是差旅就要求填行程 */
export function isTrip(e) {
  return (e?.items || []).some((it) => it.type === '差旅')
}

/* ============================ 借款预支 ============================ */

/**
 * 借款场景：出差前先领钱、展位先垫付、仓库零采备用金。
 * 不记这笔，财务就只能靠 Excel 记「谁还欠公司多少」。
 */
export const loans = ref([
  {
    id: 'JK-2026-0034',
    applicant: '周予安',
    dept: '汽配渠道部',
    type: '差旅预支',
    amount: 5000,
    purpose: '宁波甬安汽修厂首单铺货跟车，往返 3 天',
    applyDate: '2026-11-12',
    payDate: '',
    dueDate: '2026-12-12',
    writeOffs: [],
    status: '待审批',
    approver: '顾晓'
  },
  {
    id: 'JK-2026-0033',
    applicant: '许知远',
    dept: '主机厂配套部',
    type: '差旅预支',
    amount: 3000,
    purpose: '南京依维柯年框对接，高铁 + 住宿 3 天',
    applyDate: '2026-11-04',
    payDate: '2026-11-06',
    dueDate: '2026-12-06',
    writeOffs: [{ docId: 'FY-2026-0611', at: '2026-11-08', amount: 3000 }],
    status: '已通过',
    approver: '顾晓'
  },
  {
    id: 'JK-2026-0032',
    applicant: '陈默',
    dept: '汽配渠道部',
    type: '备用金',
    amount: 8000,
    purpose: '上海嘉定安驰门店驻场两周日常开支',
    applyDate: '2026-10-26',
    payDate: '2026-10-28',
    dueDate: '2026-11-28',
    writeOffs: [],
    status: '已通过',
    approver: '顾晓'
  },
  {
    id: 'JK-2026-0031',
    applicant: '何思',
    dept: '电商运营部',
    type: '采购垫付',
    amount: 12000,
    purpose: '上海国际汽配展易拉宝与样品物料代付',
    applyDate: '2026-10-18',
    payDate: '2026-10-20',
    dueDate: '2026-11-20',
    /* FY-2026-0610 还在审批中，抵扣不能提前挂账 —— 审批中心点通过时才生成 writeOff */
    writeOffs: [],
    status: '已通过',
    approver: '顾晓'
  },
  {
    id: 'JK-2026-0030',
    applicant: '梁书',
    dept: '仓储物流部',
    type: '备用金',
    amount: 2000,
    purpose: '仓库打包耗材零采（缠绕膜、胶带）',
    applyDate: '2026-09-13',
    payDate: '2026-09-15',
    dueDate: '2026-10-15',
    writeOffs: [],
    status: '已通过',
    approver: '顾晓'
  },
  {
    id: 'JK-2026-0029',
    applicant: '郑南',
    dept: '汽配渠道部',
    type: '差旅预支',
    amount: 2500,
    purpose: '台州汽配城跑店，2 晚住宿',
    applyDate: '2026-10-08',
    payDate: '2026-10-10',
    dueDate: '2026-11-10',
    writeOffs: [{ docId: 'FY-2026-0607', at: '2026-10-31', amount: 2500 }],
    status: '已通过',
    approver: '顾晓'
  },
  {
    id: 'JK-2026-0028',
    applicant: '周予安',
    dept: '汽配渠道部',
    type: '差旅预支',
    amount: 4000,
    purpose: '宁波区域门店巡检',
    applyDate: '2026-10-08',
    payDate: '',
    dueDate: '2026-11-08',
    writeOffs: [],
    status: '已驳回',
    approver: '顾晓',
    rejectReason: '同期出差已有备用金未清，本次不重复预支'
  }
])

/** 已核销金额：所有生效抵扣之和 */
export function loanCleared(l) {
  return round2((l?.writeOffs || []).reduce((s, w) => s + Number(w.amount || 0), 0))
}
/**
 * 未还余额。只有审批通过（钱已打出去）才有余额 ——
 * 待审批和已驳回的单子一分钱没出，算进「在借」会让财务白紧张。
 */
export function loanOpen(l) {
  if (!l || l.status !== '已通过') return 0
  return round2(Math.max(0, (l?.amount || 0) - loanCleared(l)))
}
/**
 * 展示状态由余额与到期日现算，不存字段。
 * 存了 status 之后，只要有一处漏更新就会和余额对不上，财务会拿着两套数字来问你。
 */
export function loanStatus(l) {
  if (l.status === '待审批' || l.status === '已驳回') return l.status
  const open = loanOpen(l)
  if (open <= 0) return '已核销'
  if (l.dueDate && l.dueDate < TODAY) return '已超期'
  return loanCleared(l) > 0 ? '部分核销' : '待还'
}
/** 还有多少天到期，负数表示已超期 */
export function loanDaysLeft(l) {
  if (!l.dueDate) return null
  const a = new Date(l.dueDate)
  const b = new Date(TODAY)
  return Math.round((a - b) / 86400000)
}

/** 把一笔报销单挂到借款上冲减（审批通过时调用） */
export function applyWriteOff(loanId, docId, amount) {
  const l = loans.value.find((x) => x.id === loanId)
  if (!l || !amount) return
  if (l.writeOffs.some((w) => w.docId === docId)) return
  l.writeOffs.push({ docId, at: TODAY, amount: round2(amount) })
}

/** 某人的未清借款（报销单抵扣时选） */
export function openLoansOf(applicant) {
  return loans.value.filter(
    (l) => l.applicant === applicant && l.status === '已通过' && loanOpen(l) > 0
  )
}

/* ============================ 请假申请 ============================ */

/** 全公司统一额度，年初重置。事假不限额，只留痕 */
export const LEAVE_QUOTA = { 年假: 5, 病假: 10, 调休: 3 }

export const leaves = ref([
  {
    id: 'QJ-2026-0093',
    applicant: '宋江',
    dept: '总经办',
    type: '年假',
    start: '2026-11-23',
    end: '2026-11-23',
    days: 1,
    reason: '调休一天处理家事',
    handover: '顾晓',
    applyDate: '2026-11-11',
    status: '已通过',
    approver: '顾晓'
  },
  {
    id: 'QJ-2026-0092',
    applicant: '陈默',
    dept: '汽配渠道部',
    type: '年假',
    start: '2026-11-18',
    end: '2026-11-20',
    days: 3,
    reason: '陪家人出行，已安排好门店交接',
    handover: '周予安',
    applyDate: '2026-11-13',
    status: '待审批',
    approver: '顾晓'
  },
  {
    id: 'QJ-2026-0091',
    applicant: '何思',
    dept: '电商运营部',
    type: '病假',
    start: '2026-11-16',
    end: '2026-11-16',
    days: 1,
    reason: '感冒发烧，已就诊，附门诊病历',
    handover: '梁书',
    applyDate: '2026-11-13',
    status: '待审批',
    approver: '顾晓'
  },
  {
    id: 'QJ-2026-0090',
    applicant: '苏晚',
    dept: '汽配渠道部',
    type: '调休',
    start: '2026-11-12',
    end: '2026-11-12',
    days: 1,
    reason: '双十一值班调休',
    handover: '陈默',
    applyDate: '2026-11-10',
    status: '已通过',
    approver: '顾晓'
  },
  {
    id: 'QJ-2026-0089',
    applicant: '许知远',
    dept: '主机厂配套部',
    type: '事假',
    start: '2026-11-10',
    end: '2026-11-11',
    days: 2,
    reason: '家里办房产过户手续',
    handover: '林致远',
    applyDate: '2026-11-07',
    status: '已通过',
    approver: '顾晓'
  },
  {
    id: 'QJ-2026-0088',
    applicant: '梁书',
    dept: '仓储物流部',
    type: '年假',
    start: '2026-11-05',
    end: '2026-11-07',
    days: 3,
    reason: '返老家',
    handover: '郑南',
    applyDate: '2026-11-02',
    status: '已通过',
    approver: '顾晓'
  },
  {
    id: 'QJ-2026-0087',
    applicant: '周予安',
    dept: '汽配渠道部',
    type: '病假',
    start: '2026-10-29',
    end: '2026-10-30',
    days: 2,
    reason: '急性肠胃炎，门诊输液 2 天',
    handover: '陈默',
    applyDate: '2026-10-28',
    status: '已通过',
    approver: '顾晓'
  },
  {
    id: 'QJ-2026-0086',
    applicant: '郑南',
    dept: '汽配渠道部',
    type: '事假',
    start: '2026-10-26',
    end: '2026-10-26',
    days: 1,
    reason: '孩子家长会',
    handover: '周予安',
    applyDate: '2026-10-24',
    status: '已驳回',
    approver: '顾晓',
    rejectReason: '当日有台州区域巡检，建议改期'
  },
  {
    id: 'QJ-2026-0085',
    applicant: '林致远',
    dept: '主机厂配套部',
    type: '年假',
    start: '2026-10-19',
    end: '2026-10-23',
    days: 5,
    reason: '年假连休，工作已移交',
    handover: '许知远',
    applyDate: '2026-10-15',
    status: '已通过',
    approver: '宋江'
  }
])

/** 某人某类型已用天数（只算已通过的，待审批不占额度） */
export function leaveUsed(applicant, type) {
  return leaves.value
    .filter((l) => l.applicant === applicant && l.type === type && l.status === '已通过')
    .reduce((s, l) => s + l.days, 0)
}

/** 剩余额度。事假不限额，返回 null */
export function leaveBalance(applicant, type) {
  if (!(type in LEAVE_QUOTA)) return null
  return Math.max(0, LEAVE_QUOTA[type] - leaveUsed(applicant, type))
}

/** 请假天数：跳过周六周日，法定节假日不在演示范围 */
export function workdays(start, end) {
  if (!start || !end) return 0
  const d = new Date(start)
  const e = new Date(end)
  if (Number.isNaN(d.getTime()) || Number.isNaN(e.getTime()) || e < d) return 0
  let n = 0
  while (d <= e) {
    const w = d.getDay()
    if (w !== 0 && w !== 6) n += 1
    d.setDate(d.getDate() + 1)
  }
  return n
}

/**
 * 出差天数：按自然日，不跳周末 —— 周五走周日晚回就是 3 天，住宿 2 晚。
 * 请假扣额度才用工作日，两者不能混用，不然报销单上的天数永远比实际少。
 */
export function naturalDays(start, end) {
  if (!start || !end) return 0
  const d = new Date(start)
  const e = new Date(end)
  if (Number.isNaN(d.getTime()) || Number.isNaN(e.getTime()) || e < d) return 0
  return Math.round((e - d) / 86400000) + 1
}

/** 今天在假的人 */
export function onLeaveToday() {
  return leaves.value.filter(
    (l) => l.status === '已通过' && l.start <= TODAY && l.end >= TODAY
  )
}

/* ============================ 审批流 ============================ */

/**
 * 审批中心不另建一张表，直接从三类单据派生。
 * 派生而不是复制，才不会出现「审批中心点通过了，报销页还是审批中」这种鬼故事。
 */
export const approvalFeed = computed(() => {
  const out = []

  for (const e of expenses.value) {
    out.push({
      kind: '费用报销',
      docId: e.id,
      title: e.desc,
      applicant: e.applicant,
      dept: e.dept,
      amount: expenseTotal(e),
      meta: `${expenseLines(e)} 项明细 · ${expenseBills(e)} 张票据${e.deductLoanId ? ' · 含借款抵扣' : ''}`,
      submittedAt: e.applyDate,
      status: e.status === '审批中' ? '待审批' : e.status,
      approver: e.approver
    })
  }
  for (const l of loans.value) {
    out.push({
      kind: '借款预支',
      docId: l.id,
      title: l.purpose,
      applicant: l.applicant,
      dept: l.dept,
      amount: l.amount,
      meta: `${l.type} · 应清账 ${l.dueDate || '—'}`,
      submittedAt: l.applyDate,
      status: l.status === '已通过' ? '已通过' : l.status,
      approver: l.approver
    })
  }
  for (const v of leaves.value) {
    out.push({
      kind: '请假申请',
      docId: v.id,
      title: v.reason,
      applicant: v.applicant,
      dept: v.dept,
      amount: null,
      duration: `${v.days} 天`,
      /* 审批中心是速览，日期省掉年份，一行放得下就行 */
      meta: `${v.type} · ${v.start.slice(5)} 至 ${v.end.slice(5)} · 交接 ${v.handover}`,
      submittedAt: v.applyDate,
      status: v.status,
      approver: v.approver
    })
  }

  return out.sort((a, b) => (a.submittedAt < b.submittedAt ? 1 : -1))
})

/** 统一审批：改源单据状态，报销通过时把借款抵扣真正生效 */
export function decide(kind, docId, pass) {
  if (kind === '费用报销') {
    const e = expenses.value.find((x) => x.id === docId)
    if (!e) return
    e.status = pass ? '已通过' : '驳回'
    if (pass && e.deductLoanId && e.deductAmount > 0) {
      applyWriteOff(e.deductLoanId, e.id, e.deductAmount)
    }
    return
  }
  if (kind === '借款预支') {
    const l = loans.value.find((x) => x.id === docId)
    if (!l) return
    l.status = pass ? '已通过' : '已驳回'
    return
  }
  const v = leaves.value.find((x) => x.id === docId)
  if (!v) return
  v.status = pass ? '已通过' : '已驳回'
}

/* ============================ 公共常量 ============================ */

export const EXPENSE_TYPES = ['差旅', '客户招待', '市场活动', '物流运费', '样品费', '办公用品', '其他']
export const LOAN_TYPES = ['差旅预支', '备用金', '采购垫付']
export const LEAVE_TYPES = ['年假', '病假', '事假', '调休']
export const DEPTS = ['总经办', '汽配渠道部', '主机厂配套部', '电商运营部', '仓储物流部', '市场部']
export const STAFF = ['宋江', '顾晓', '陈默', '许知远', '何思', '梁书', '周予安', '郑南', '苏晚', '林致远']

/** 单笔超过这个金额要财务复核，不是不能报，是要多看一张单 */
export const REVIEW_LINE = 5000

export const EXPENSE_TONE = { 审批中: 'tag-warning', 已通过: 'tag-success', 驳回: 'tag-danger' }
export const LOAN_TONE = {
  待审批: 'tag-warning',
  待还: 'tag-info',
  部分核销: 'tag-info',
  已超期: 'tag-danger',
  已核销: 'tag-success',
  已驳回: 'tag-danger'
}
export const LEAVE_TONE = { 待审批: 'tag-warning', 已通过: 'tag-success', 已驳回: 'tag-danger' }
export const TODAY_STR = TODAY
