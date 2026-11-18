/**
 * 订单中心 · 演示数据
 * ------------------------------------------------------------
 * 业务：工贸一体，汽车美容耗材按箱批发，客户以月结为主。
 *
 * 单据链路（后端建模照这个顺序走，不要跳）：
 *   合同（年框承诺） → 订单（这次要多少货） → 发货 → 签收
 *                                    ↘ 退货（冲减应收与销量）
 *   月末：对账单（客户确认） → 开票 → 收款单 → 核销
 *
 * 三条建模约定：
 *  1. 金额一律「元」，保留 2 位小数，由明细行现算，不存汇总冗余（对账要用明细）。
 *  2. 订单分两类：合同订单（挂在年框下，走协议价）、备货订单（无合同现货补货，走阶梯价）。
 *  3. 收款单与应收是「多对多」：一笔到账可冲多张发票，一张发票也可被多笔到账冲，
 *     所以必须有 allocation 明细，不能只有一个 paid 标记。
 */

import { productItems, unitPrice, factorOf, money } from './productCatalog'

const round2 = (n) => Math.round(n * 100) / 100

/* ---------------- 客户取价与信用 ---------------- */

/** 协议折扣：合同里谈定的整体折扣（与产品模块 crm_customer_prices 同源） */
export const CUSTOMER_DISCOUNT = {
  '杭州驰远汽车服务连锁': 0.88,
  '南京依维柯配件部': 0.92,
  '上海嘉定安驰 4S 店': 1,
  '宁波甬安汽修厂': 0.96,
  '无锡运通物流车队': 1,
  '苏州车之翼汽车用品': 0.94,
  '嘉兴南方汽修': 0.98,
  '常州瑞虎汽车维修中心': 1,
  '合肥皖通汽配贸易': 1,
  '金华众诚汽车服务': 1
}

/** 信用额度：limit 总额度，used 已占用（未回款的发货 + 在途订单） */
export const CUSTOMER_CREDIT = {
  '杭州驰远汽车服务连锁': { limit: 1200000, used: 745600, term: 30 },
  '南京依维柯配件部': { limit: 2000000, used: 1343600, term: 60 },
  '上海嘉定安驰 4S 店': { limit: 600000, used: 186000, term: 30 },
  '宁波甬安汽修厂': { limit: 400000, used: 145800, term: 30 },
  '无锡运通物流车队': { limit: 800000, used: 128000, term: 45 },
  '苏州车之翼汽车用品': { limit: 300000, used: 93000, term: 30 },
  '嘉兴南方汽修': { limit: 200000, used: 68000, term: 30 },
  '常州瑞虎汽车维修中心': { limit: 150000, used: 0, term: 30 },
  '合肥皖通汽配贸易': { limit: 100000, used: 54000, term: 15 },
  '金华众诚汽车服务': { limit: 50000, used: 0, term: 15 }
}

/**
 * 取价顺序：协议价 → 阶梯价 → 经销价，三者取最低（批发行业惯例，客户不会接受比自己谈的更高的价）
 * 底价 = 成本价，低于底价必须走审批，否则毛利会被业务员私下让掉。
 */
export function resolvePrice(productId, customer, unit, qty = 1) {
  const p = productItems.find((x) => x.id === productId)
  if (!p) return { price: 0, source: '—', list: 0, floor: 0 }
  const u = unit || p.saleUnit
  const list = round2(unitPrice(p, u, 'standard'))
  const floor = round2(unitPrice(p, u, 'cost'))
  const disc = CUSTOMER_DISCOUNT[customer] ?? 1

  const candidates = [{ price: round2(list * disc), source: disc < 1 ? '协议价' : '标准价' }]

  const saleQty = (qty * factorOf(p, u)) / factorOf(p, p.saleUnit)
  let hit = null
  for (const t of p.tiers || []) if (saleQty >= t.min) hit = t
  if (hit) {
    candidates.push({
      price: round2((hit.price / factorOf(p, p.saleUnit)) * factorOf(p, u)),
      source: `阶梯价 ${hit.min}${p.saleUnit}起`
    })
  }
  const dealer = round2(unitPrice(p, u, 'dealer'))
  if (dealer < list) candidates.push({ price: dealer, source: '经销价' })

  candidates.sort((a, b) => a.price - b.price)
  return { price: candidates[0].price, source: candidates[0].source, list, floor, discount: disc }
}

/** 明细行单价：订单里存了成交价就用存的，否则现算 */
export function linePrice(order, item) {
  if (item.price != null) return item.price
  return resolvePrice(item.productId, order.customer, item.unit, item.qty).price
}

export function lineAmount(order, item) {
  return round2(linePrice(order, item) * item.qty)
}

export function orderAmount(order) {
  return round2(order.items.reduce((s, it) => s + lineAmount(order, it), 0))
}

/** 订单毛利：需要成本价，没有 product.cost 权限时前端不展示 */
export function orderMargin(order) {
  let sales = 0
  let cost = 0
  for (const it of order.items) {
    const p = productItems.find((x) => x.id === it.productId)
    if (!p) continue
    sales += lineAmount(order, it)
    cost += unitPrice(p, it.unit, 'cost') * it.qty
  }
  if (!sales) return 0
  return round2(((sales - cost) / sales) * 100)
}

/** 低于底价的明细，新建订单时用来拦审批 */
export function belowFloorLines(order) {
  return order.items.filter((it) => {
    const p = productItems.find((x) => x.id === it.productId)
    if (!p) return false
    return linePrice(order, it) < round2(unitPrice(p, it.unit, 'cost'))
  })
}

/* ---------------- 合同 ---------------- */

/**
 * 合同 = 年度/季度框架，约定总额、账期与覆盖的 SKU 及协议价。
 * amount 是框架承诺额，不等于明细合计，所以不现算。
 */
export const contracts = [
  {
    id: 'HT-2026-0187', name: '驰远连锁 · 2027 年度耗材集采', customer: '杭州驰远汽车服务连锁',
    amount: 1864000, signDate: '2026-10-28', owner: '林致远', status: '执行中',
    type: '年框', paymentTerm: '月结 30 天', discount: 0.88,
    items: [
      { productId: 'P001', unit: '箱', qty: 2400 },
      { productId: 'P002', unit: '箱', qty: 480 },
      { productId: 'P005', unit: '箱', qty: 900 }
    ],
    approvals: [
      { at: '2026-10-24 14:20', by: '顾晓', action: '提交', note: '客户已确认年度价格表' },
      { at: '2026-10-25 09:05', by: '陈默', action: '审核', note: '折扣 88 折，低于标准但高于底价' },
      { at: '2026-10-28 10:12', by: '宋江', action: '批准', note: '同意，按季度考核发货额' }
    ]
  },
  {
    id: 'HT-2026-0186', name: '依维柯配件部 · 紧固件年框', customer: '南京依维柯配件部',
    amount: 968000, signDate: '2026-11-02', owner: '苏晚', status: '执行中',
    type: '年框', paymentTerm: '月结 60 天', discount: 0.92,
    items: [
      { productId: 'P007', unit: '箱', qty: 1600 },
      { productId: 'P008', unit: '箱', qty: 1200 }
    ],
    approvals: [
      { at: '2026-10-30 16:40', by: '苏晚', action: '提交', note: '年框续签，价格与去年持平' },
      { at: '2026-11-02 09:30', by: '宋江', action: '批准', note: '同意，账期 60 天需财务备案' }
    ]
  },
  {
    id: 'HT-2026-0185', name: '甬安汽修厂 · 首单铺货协议', customer: '宁波甬安汽修厂',
    amount: 486000, signDate: '2026-11-05', owner: '周予安', status: '待审批',
    type: '单次', paymentTerm: '月结 30 天', discount: 0.96,
    items: [
      { productId: 'P001', unit: '箱', qty: 600 },
      { productId: 'P003', unit: '箱', qty: 200 }
    ],
    approvals: [
      { at: '2026-11-05 11:18', by: '周予安', action: '提交', note: '新客户首单，要求 96 折铺货' }
    ]
  },
  {
    id: 'HT-2026-0184', name: '运通物流 · 车队保养耗材年供', customer: '无锡运通物流车队',
    amount: 268000, signDate: '2026-09-18', owner: '许知远', status: '已完成',
    type: '年框', paymentTerm: '月结 45 天', discount: 1,
    items: [
      { productId: 'P001', unit: '箱', qty: 300 },
      { productId: 'P009', unit: '箱', qty: 180 }
    ],
    approvals: [
      { at: '2026-09-15 10:02', by: '许知远', action: '提交', note: '车队年度保养包' },
      { at: '2026-09-18 14:30', by: '宋江', action: '批准', note: '同意' }
    ]
  },
  {
    id: 'HT-2026-0183', name: '车之翼 · 洗美耗材季度供货', customer: '苏州车之翼汽车用品',
    amount: 328000, signDate: '2026-10-12', owner: '苏晚', status: '执行中',
    type: '季度', paymentTerm: '月结 30 天', discount: 0.94,
    items: [
      { productId: 'P002', unit: '箱', qty: 160 },
      { productId: 'P004', unit: '箱', qty: 120 }
    ],
    approvals: [
      { at: '2026-10-10 15:22', by: '苏晚', action: '提交', note: '季度供货，按实际要货下单' },
      { at: '2026-10-12 09:00', by: '陈默', action: '批准', note: '同意' }
    ]
  },
  {
    id: 'HT-2026-0182', name: '安驰 4S · 洗美耗材年度框架', customer: '上海嘉定安驰 4S 店',
    amount: 968000, signDate: '2026-08-20', owner: '陈默', status: '执行中',
    type: '年框', paymentTerm: '月结 30 天', discount: 1,
    items: [
      { productId: 'P001', unit: '箱', qty: 1200 },
      { productId: 'P005', unit: '箱', qty: 600 }
    ],
    approvals: [
      { at: '2026-08-16 11:00', by: '陈默', action: '提交', note: '集团统一采购，多店分送' },
      { at: '2026-08-20 10:15', by: '宋江', action: '批准', note: '同意，按单店结算' }
    ]
  },
  {
    id: 'HT-2026-0181', name: '南方汽修 · 补货协议', customer: '嘉兴南方汽修',
    amount: 268000, signDate: '2026-07-06', owner: '林致远', status: '执行中',
    type: '季度', paymentTerm: '月结 30 天', discount: 0.98,
    items: [
      { productId: 'P001', unit: '箱', qty: 420 },
      { productId: 'P006', unit: '箱', qty: 260 }
    ],
    approvals: [
      { at: '2026-07-04 09:40', by: '林致远', action: '提交', note: '老客户补货协议' },
      { at: '2026-07-06 16:10', by: '陈默', action: '批准', note: '同意' }
    ]
  },
  {
    id: 'HT-2026-0180', name: '瑞虎汽修 · 首单试销', customer: '常州瑞虎汽车维修中心',
    amount: 186000, signDate: '2026-11-13', owner: '郑南', status: '草稿',
    type: '单次', paymentTerm: '款到发货', discount: 1,
    items: [{ productId: 'P001', unit: '箱', qty: 200 }],
    approvals: []
  }
]

/* ---------------- 订单 ---------------- */

/**
 * type：合同订单（挂 contractId，走协议价） / 备货订单（无合同，现货补货）
 * status：待审批 / 待发货 / 部分发货 / 已发货 / 已签收 / 已退货 / 已取消
 */
export const orders = [
  {
    id: 'SO-2026-0412', customer: '杭州驰远汽车服务连锁', contractId: 'HT-2026-0187',
    type: '合同订单', date: '2026-11-12', expect: '2026-11-18', owner: '林致远',
    status: '待发货', creditCheck: '通过', remark: '11 月常规补货，分三个门店配送',
    items: [
      { productId: 'P001', unit: '箱', qty: 300 },
      { productId: 'P002', unit: '箱', qty: 60 },
      { productId: 'P005', unit: '箱', qty: 120 }
    ]
  },
  {
    id: 'SO-2026-0411', customer: '南京依维柯配件部', contractId: 'HT-2026-0186',
    type: '合同订单', date: '2026-11-10', expect: '2026-11-20', owner: '苏晚',
    status: '部分发货', creditCheck: '通过', remark: '紧固件年框第 4 批，分两次发',
    items: [
      { productId: 'P007', unit: '箱', qty: 240 },
      { productId: 'P008', unit: '箱', qty: 180 }
    ]
  },
  {
    id: 'SO-2026-0410', customer: '上海嘉定安驰 4S 店', contractId: 'HT-2026-0182',
    type: '合同订单', date: '2026-11-08', expect: '2026-11-14', owner: '陈默',
    status: '已签收', creditCheck: '通过', remark: '安亭、嘉定两个工位分送',
    items: [
      { productId: 'P001', unit: '箱', qty: 180 },
      { productId: 'P005', unit: '箱', qty: 90 }
    ]
  },
  {
    id: 'SO-2026-0409', customer: '无锡运通物流车队', contractId: '',
    type: '备货订单', date: '2026-11-06', expect: '2026-11-12', owner: '许知远',
    status: '已签收', creditCheck: '通过', remark: '车队临时补货，走经销价',
    items: [
      { productId: 'P001', unit: '箱', qty: 120 },
      { productId: 'P009', unit: '箱', qty: 60 }
    ]
  },
  {
    id: 'SO-2026-0408', customer: '宁波甬安汽修厂', contractId: '',
    type: '备货订单', date: '2026-11-13', expect: '2026-11-19', owner: '周予安',
    status: '待审批', creditCheck: '超额度', remark: '首单铺货前先补一批现货，超出可用额度 3.8 万',
    items: [
      { productId: 'P001', unit: '箱', qty: 100 },
      { productId: 'P003', unit: '箱', qty: 40 }
    ]
  },
  {
    id: 'SO-2026-0407', customer: '苏州车之翼汽车用品', contractId: 'HT-2026-0183',
    type: '合同订单', date: '2026-11-09', expect: '2026-11-16', owner: '苏晚',
    status: '已发货', creditCheck: '通过', remark: '季度供货第二批',
    items: [
      { productId: 'P002', unit: '箱', qty: 40 },
      { productId: 'P004', unit: '箱', qty: 30 }
    ]
  },
  {
    id: 'SO-2026-0406', customer: '嘉兴南方汽修', contractId: 'HT-2026-0181',
    type: '合同订单', date: '2026-11-05', expect: '2026-11-11', owner: '林致远',
    status: '已签收', creditCheck: '通过', remark: '月度补货',
    items: [
      { productId: 'P001', unit: '箱', qty: 80 },
      { productId: 'P006', unit: '箱', qty: 50 }
    ]
  },
  {
    id: 'SO-2026-0405', customer: '杭州驰远汽车服务连锁', contractId: 'HT-2026-0187',
    type: '合同订单', date: '2026-11-02', expect: '2026-11-08', owner: '林致远',
    status: '部分发货', creditCheck: '通过', remark: 'P005 库存不足，先发毛巾类',
    items: [
      { productId: 'P001', unit: '箱', qty: 200 },
      { productId: 'P005', unit: '箱', qty: 150 }
    ]
  },
  {
    id: 'SO-2026-0404', customer: '常州瑞虎汽车维修中心', contractId: '',
    type: '备货订单', date: '2026-10-30', expect: '2026-11-05', owner: '郑南',
    status: '已签收', creditCheck: '通过', remark: '试销首单，款到发货',
    items: [{ productId: 'P001', unit: '箱', qty: 60 }]
  },
  {
    id: 'SO-2026-0403', customer: '南京依维柯配件部', contractId: 'HT-2026-0186',
    type: '合同订单', date: '2026-10-28', expect: '2026-11-04', owner: '苏晚',
    status: '已签收', creditCheck: '通过', remark: '第 3 批',
    items: [
      { productId: 'P007', unit: '箱', qty: 200 },
      { productId: 'P008', unit: '箱', qty: 150 }
    ]
  },
  {
    id: 'SO-2026-0402', customer: '上海嘉定安驰 4S 店', contractId: '',
    type: '备货订单', date: '2026-10-26', expect: '2026-11-01', owner: '陈默',
    status: '已退货', creditCheck: '通过', remark: '整批退回：边角脱线',
    items: [
      { productId: 'P001', unit: '箱', qty: 40 },
      { productId: 'P002', unit: '箱', qty: 10 }
    ]
  },
  {
    id: 'SO-2026-0401', customer: '合肥皖通汽配贸易', contractId: '',
    type: '备货订单', date: '2026-10-22', expect: '2026-10-28', owner: '梁书',
    status: '已签收', creditCheck: '通过', remark: '小批量试单',
    items: [{ productId: 'P001', unit: '箱', qty: 30 }]
  },
  {
    id: 'SO-2026-0400', customer: '杭州驰远汽车服务连锁', contractId: 'HT-2026-0187',
    type: '合同订单', date: '2026-10-18', expect: '2026-10-24', owner: '林致远',
    status: '已签收', creditCheck: '通过', remark: '10 月集采',
    items: [
      { productId: 'P001', unit: '箱', qty: 260 },
      { productId: 'P002', unit: '箱', qty: 40 }
    ]
  },
  {
    id: 'SO-2026-0399', customer: '苏州车之翼汽车用品', contractId: '',
    type: '备货订单', date: '2026-10-15', expect: '2026-10-21', owner: '苏晚',
    status: '已取消', creditCheck: '通过', remark: '客户改用季度合同下单',
    items: [{ productId: 'P004', unit: '箱', qty: 20 }]
  },
  {
    id: 'SO-2026-0398', customer: '宁波甬安汽修厂', contractId: '',
    type: '备货订单', date: '2026-10-12', expect: '2026-10-18', owner: '周予安',
    status: '已签收', creditCheck: '通过', remark: '试单',
    items: [{ productId: 'P001', unit: '箱', qty: 45 }]
  }
]

/* ---------------- 发货 ---------------- */

export const shipments = [
  { id: 'FH-2026-0891', orderId: 'SO-2026-0411', at: '2026-11-11', amount: 96000, boxes: 180, logistics: '德邦物流', trackingNo: 'DB7741 2288 6610', status: '已签收' },
  { id: 'FH-2026-0892', orderId: 'SO-2026-0411', at: '2026-11-13', amount: 0, boxes: 120, logistics: '德邦物流', trackingNo: 'DB7741 2290 1188', status: '运输中' },
  { id: 'FH-2026-0888', orderId: 'SO-2026-0410', at: '2026-11-09', amount: 0, boxes: 270, logistics: '自有车队', trackingNo: '—', status: '已签收' },
  { id: 'FH-2026-0885', orderId: 'SO-2026-0409', at: '2026-11-07', amount: 0, boxes: 180, logistics: '安能物流', trackingNo: 'AN5540 8812 3367', status: '已签收' },
  { id: 'FH-2026-0882', orderId: 'SO-2026-0407', at: '2026-11-10', amount: 0, boxes: 70, logistics: '顺丰重货', trackingNo: 'SF9932 4410 7788', status: '运输中' },
  { id: 'FH-2026-0879', orderId: 'SO-2026-0406', at: '2026-11-06', amount: 0, boxes: 130, logistics: '自有车队', trackingNo: '—', status: '已签收' },
  { id: 'FH-2026-0875', orderId: 'SO-2026-0405', at: '2026-11-03', amount: 0, boxes: 200, logistics: '德邦物流', trackingNo: 'DB7740 9911 2203', status: '已签收' },
  { id: 'FH-2026-0871', orderId: 'SO-2026-0404', at: '2026-10-31', amount: 0, boxes: 60, logistics: '安能物流', trackingNo: 'AN5539 2210 4478', status: '已签收' },
  { id: 'FH-2026-0868', orderId: 'SO-2026-0403', at: '2026-10-29', amount: 0, boxes: 350, logistics: '德邦物流', trackingNo: 'DB7739 1180 5521', status: '已签收' },
  { id: 'FH-2026-0864', orderId: 'SO-2026-0402', at: '2026-10-27', amount: 0, boxes: 50, logistics: '顺丰重货', trackingNo: 'SF9930 7742 1180', status: '已签收' },
  { id: 'FH-2026-0860', orderId: 'SO-2026-0401', at: '2026-10-23', amount: 0, boxes: 30, logistics: '安能物流', trackingNo: 'AN5538 6604 1172', status: '已签收' },
  { id: 'FH-2026-0855', orderId: 'SO-2026-0400', at: '2026-10-19', amount: 0, boxes: 300, logistics: '自有车队', trackingNo: '—', status: '已签收' },
  { id: 'FH-2026-0851', orderId: 'SO-2026-0398', at: '2026-10-13', amount: 0, boxes: 45, logistics: '安能物流', trackingNo: 'AN5537 2288 9901', status: '已签收' }
]

/** 某订单已发货箱数（按已签收 + 运输中计算，取消的算 0） */
export function shippedBoxes(orderId) {
  return shipments
    .filter((s) => s.orderId === orderId)
    .reduce((sum, s) => sum + (s.boxes || 0), 0)
}

export function orderBoxes(order) {
  return order.items.reduce((s, it) => s + it.qty, 0)
}

/* ---------------- 退货 ---------------- */

export const returns = [
  {
    id: 'RT-2026-0006', orderId: 'SO-2026-0402', customer: '上海嘉定安驰 4S 店',
    at: '2026-10-30', amount: 41800, reason: '质量问题', status: '已退款',
    note: '毛巾边角脱线，整批退回，已补发新批次',
    items: [{ productId: 'P001', unit: '箱', qty: 40 }, { productId: 'P002', unit: '箱', qty: 10 }]
  },
  {
    id: 'RT-2026-0005', orderId: 'SO-2026-0399', customer: '苏州车之翼汽车用品',
    at: '2026-10-20', amount: 8600, reason: '发错规格', status: '已入库',
    note: '发成 40×40，客户要 60×160',
    items: [{ productId: 'P004', unit: '箱', qty: 20 }]
  },
  {
    id: 'RT-2026-0004', orderId: 'SO-2026-0401', customer: '合肥皖通汽配贸易',
    at: '2026-10-26', amount: 3200, reason: '包装破损', status: '待确认',
    note: '运输途中外箱受潮，客户要求折价',
    items: [{ productId: 'P001', unit: '箱', qty: 5 }]
  }
]

/* ---------------- 对账单 ---------------- */

/**
 * 对账单 = 某个客户在某个账期的应收结算凭证。
 * close(期末应收) = open(期初) + shipped(本期发货) - received(本期回款)
 * 这条恒等式必须成立，否则财务不会认。
 */
export const statements = [
  {
    id: 'DZ-2026-10-001', customer: '杭州驰远汽车服务连锁', period: '2026-10',
    start: '2026-10-01', end: '2026-10-31', open: 486000, shipped: 1039600, received: 778000,
    status: '已开票', orders: 2, createdAt: '2026-11-01', confirmedAt: '2026-11-03'
  },
  {
    id: 'DZ-2026-10-002', customer: '南京依维柯配件部', period: '2026-10',
    start: '2026-10-01', end: '2026-10-31', open: 338800, shipped: 902000, received: 260000,
    status: '已确认', orders: 1, createdAt: '2026-11-01', confirmedAt: '2026-11-04'
  },
  {
    id: 'DZ-2026-10-003', customer: '上海嘉定安驰 4S 店', period: '2026-10',
    start: '2026-10-01', end: '2026-10-31', open: 0, shipped: 186000, received: 186000,
    status: '已回款', orders: 2, createdAt: '2026-11-01', confirmedAt: '2026-11-02'
  },
  {
    id: 'DZ-2026-10-004', customer: '无锡运通物流车队', period: '2026-10',
    start: '2026-10-01', end: '2026-10-31', open: 68000, shipped: 128000, received: 128000,
    status: '待确认', orders: 1, createdAt: '2026-11-01', confirmedAt: ''
  },
  {
    id: 'DZ-2026-11-001', customer: '杭州驰远汽车服务连锁', period: '2026-11',
    start: '2026-11-01', end: '2026-11-30', open: 745600, shipped: 0, received: 0,
    status: '待确认', orders: 2, createdAt: '2026-11-14', confirmedAt: ''
  },
  {
    id: 'DZ-2026-09-002', customer: '南京依维柯配件部', period: '2026-09',
    start: '2026-09-01', end: '2026-09-30', open: 210000, shipped: 468800, received: 340000,
    status: '已回款', orders: 1, createdAt: '2026-10-01', confirmedAt: '2026-10-05'
  }
]

export function statementClose(s) {
  return round2(s.open + s.shipped - s.received)
}

/* ---------------- 收款单与核销 ---------------- */

/**
 * 收款单 = 银行一笔到账。allocations 是核销明细，指向发票或订单。
 * unallocated > 0 表示这笔钱还没认领到具体单据，需要财务处理。
 */
export const receipts = [
  {
    id: 'SK-2026-0231', customer: '杭州驰远汽车服务连锁', amount: 300000,
    payDate: '2026-11-12', method: '银行转账', bank: '招商银行杭州分行', remark: '11 月集采预付',
    allocations: [
      { type: '发票', targetId: 'FP-2026-0322', amount: 200000 },
      { type: '发票', targetId: 'FP-2026-0318', amount: 100000 }
    ]
  },
  {
    id: 'SK-2026-0230', customer: '南京依维柯配件部', amount: 200000,
    payDate: '2026-11-10', method: '银行承兑', bank: '工商银行南京分行', remark: '承兑汇票贴现后入账',
    allocations: [{ type: '发票', targetId: 'FP-2026-0321', amount: 170000 }]
  },
  {
    id: 'SK-2026-0229', customer: '上海嘉定安驰 4S 店', amount: 186000,
    payDate: '2026-11-08', method: '银行转账', bank: '建设银行嘉定支行', remark: '10 月对账结算',
    allocations: [{ type: '发票', targetId: 'FP-2026-0319', amount: 186000 }]
  },
  {
    id: 'SK-2026-0228', customer: '无锡运通物流车队', amount: 128000,
    payDate: '2026-11-06', method: '银行转账', bank: '交通银行无锡分行', remark: '车队月结',
    allocations: [{ type: '发票', targetId: 'FP-2026-0320', amount: 128000 }]
  },
  {
    id: 'SK-2026-0227', customer: '苏州车之翼汽车用品', amount: 93000,
    payDate: '2026-11-04', method: '对公转账', bank: '苏州银行', remark: '季度供货第一批',
    allocations: [{ type: '发票', targetId: 'FP-2026-0317', amount: 93000 }]
  },
  {
    id: 'SK-2026-0226', customer: '杭州驰远汽车服务连锁', amount: 445600,
    payDate: '2026-10-28', method: '银行转账', bank: '招商银行杭州分行', remark: '9 月对账尾款',
    allocations: [{ type: '发票', targetId: 'FP-2026-0314', amount: 445600 }]
  },
  {
    id: 'SK-2026-0225', customer: '嘉兴南方汽修', amount: 120000,
    payDate: '2026-10-22', method: '对公转账', bank: '嘉兴银行', remark: '10 月补货',
    allocations: [{ type: '发票', targetId: 'FP-2026-0315', amount: 120000 }]
  }
]

export function receiptAllocated(r) {
  return round2((r.allocations || []).reduce((s, a) => s + a.amount, 0))
}
export function receiptOpen(r) {
  return round2(r.amount - receiptAllocated(r))
}

/* ---------------- 发票 ---------------- */

/**
 * 税率：增值税专用 13%，普通 13%（小规模 3% 场景暂不做）。
 * 月结客户：先货后票后款；票到付款客户：先票后款，开票即挂应收。
 */
export const invoices = [
  { id: 'FP-2026-0322', no: '04412026 3388', customer: '杭州驰远汽车服务连锁', contractId: 'HT-2026-0187', statementId: 'DZ-2026-10-001', amount: 745600, taxRate: 0.13, type: '增值税专用', applyDate: '2026-11-06', issueDate: '2026-11-07', status: '已开票' },
  { id: 'FP-2026-0321', no: '04412026 3387', customer: '南京依维柯配件部', contractId: 'HT-2026-0186', statementId: 'DZ-2026-10-002', amount: 338800, taxRate: 0.13, type: '增值税专用', applyDate: '2026-11-04', issueDate: '2026-11-05', status: '已开票' },
  { id: 'FP-2026-0320', no: '04412026 3386', customer: '无锡运通物流车队', contractId: 'HT-2026-0184', statementId: 'DZ-2026-10-004', amount: 128000, taxRate: 0.13, type: '增值税普通', applyDate: '2026-11-02', issueDate: '2026-11-03', status: '已开票' },
  { id: 'FP-2026-0319', no: '04412026 3385', customer: '上海嘉定安驰 4S 店', contractId: 'HT-2026-0182', statementId: 'DZ-2026-10-003', amount: 186000, taxRate: 0.13, type: '增值税专用', applyDate: '2026-11-02', issueDate: '2026-11-03', status: '已开票' },
  { id: 'FP-2026-0318', no: '04412026 3384', customer: '杭州驰远汽车服务连锁', contractId: 'HT-2026-0187', statementId: 'DZ-2026-10-001', amount: 294000, taxRate: 0.13, type: '增值税专用', applyDate: '2026-11-01', issueDate: '2026-11-02', status: '已开票' },
  { id: 'FP-2026-0317', no: '04412026 3312', customer: '苏州车之翼汽车用品', contractId: 'HT-2026-0183', statementId: 'DZ-2026-10-005', amount: 93000, taxRate: 0.13, type: '增值税专用', applyDate: '2026-10-28', issueDate: '2026-10-29', status: '已开票' },
  { id: 'FP-2026-0316', no: '', customer: '嘉兴南方汽修', contractId: 'HT-2026-0181', statementId: 'DZ-2026-10-006', amount: 68000, taxRate: 0.13, type: '增值税普通', applyDate: '2026-11-13', issueDate: '', status: '待开票' },
  { id: 'FP-2026-0315', no: '04412026 3301', customer: '嘉兴南方汽修', contractId: 'HT-2026-0181', statementId: 'DZ-2026-09-006', amount: 120000, taxRate: 0.13, type: '增值税普通', applyDate: '2026-10-20', issueDate: '2026-10-21', status: '已开票' },
  { id: 'FP-2026-0314', no: '04412026 3298', customer: '杭州驰远汽车服务连锁', contractId: 'HT-2026-0187', statementId: 'DZ-2026-09-001', amount: 445600, taxRate: 0.13, type: '增值税专用', applyDate: '2026-10-24', issueDate: '2026-10-25', status: '已开票' },
  { id: 'FP-2026-0313', no: '', customer: '合肥皖通汽配贸易', contractId: '', statementId: '', amount: 3200, taxRate: 0.13, type: '增值税普通', applyDate: '2026-10-27', issueDate: '', status: '已驳回' }
]

export function invoiceTax(inv) {
  /* 价税合计口径：amount 是含税金额，税额倒算 */
  return round2((inv.amount * inv.taxRate) / (1 + inv.taxRate))
}

/** 发票已核销金额（所有收款单上指向这张票的 allocation 之和） */
export function invoiceSettled(invoiceId) {
  return round2(
    receipts.reduce(
      (s, r) => s + (r.allocations || []).filter((a) => a.targetId === invoiceId).reduce((x, a) => x + a.amount, 0),
      0
    )
  )
}

/* ---------------- 聚合指标 ---------------- */

export const orderSummary = () => {
  const month = orders.filter((o) => o.date.startsWith('2026-11') && o.status !== '已取消')
  const monthAmount = round2(month.reduce((s, o) => s + orderAmount(o), 0))
  const toShip = orders.filter((o) => o.status === '待发货' || o.status === '部分发货')
  const shippedMonth = round2(
    shipments.filter((s) => s.at.startsWith('2026-11')).reduce((s, x) => s + x.amount, 0)
  )
  return {
    monthAmount,
    monthCount: month.length,
    toShipCount: toShip.length,
    toShipAmount: round2(toShip.reduce((s, o) => s + orderAmount(o), 0)),
    pendingApproval: orders.filter((o) => o.status === '待审批').length,
    shippedMonth,
    receivable: round2(invoices.reduce((s, i) => s + (i.status === '已开票' ? i.amount - invoiceSettled(i.id) : 0), 0))
  }
}

export const ORDER_STATUS_TONE = {
  待审批: 'tag-warning',
  待发货: 'tag-info',
  部分发货: 'tag-brand',
  已发货: 'tag-brand',
  已签收: 'tag-success',
  已退货: 'tag-danger',
  已取消: 'tag-gray'
}

export const CONTRACT_STATUS_TONE = {
  草稿: 'tag-gray',
  待审批: 'tag-warning',
  执行中: 'tag-info',
  已完成: 'tag-success',
  已作废: 'tag-gray'
}

export const STATEMENT_STATUS_TONE = {
  待确认: 'tag-warning',
  已确认: 'tag-info',
  已开票: 'tag-brand',
  已回款: 'tag-success'
}

export { money }
