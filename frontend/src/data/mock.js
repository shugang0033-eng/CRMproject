/* ==========================================================================
   北辰装配科技有限公司 · 汽车配件小耗材 CRM 演示数据
   业务：紧固件 / 密封件 / 线束辅料 / 化学品类 / 车身辅料，供货给 4S 店、
   汽修连锁、汽配经销商、主机厂配套与车队。
   后端接入后可整体替换为 api 请求，字段名与后端保持一一对应。
   ========================================================================== */

export const coworkers = [
  { name: '林致远', color: '#2b6cb0' },
  { name: '苏晚', color: '#0f766e' },
  { name: '陈默', color: '#7c3aed' },
  { name: '周予安', color: '#b45309' },
  { name: '许知远', color: '#be123c' },
  { name: '梁书', color: '#1d4ed8' },
  { name: '郑南', color: '#0e7490' },
  { name: '何思', color: '#4d7c0f' }
]

const owners = coworkers.map((c) => c.name)

/* ------------------------------ 工作台 ------------------------------ */
export const overview = {
  kpi: [
    { key: 'leads', label: '本月新增询盘', value: 286, unit: '条', delta: 12.4, hint: '较上月' },
    { key: 'customers', label: '新增门店客户', value: 74, unit: '家', delta: 8.1, hint: '较上月' },
    { key: 'deals', label: '耗材出货金额', value: 1286400, unit: '元', delta: -3.6, hint: '较上月', money: true },
    { key: 'rate', label: '报价成交率', value: 27.8, unit: '%', delta: 2.2, hint: '较上月' }
  ],
  todos: [
    { key: 'lead', label: '待首次联系线索', count: 12, desc: '48 小时内需给出首次报价', path: '/leads', perm: 'lead.view' },
    { key: 'customer', label: '待回访门店', count: 8, desc: '账期到期前完成进货回访', path: '/customers', perm: 'customer.view' },
    { key: 'opportunity', label: '待跟进报价', count: 5, desc: '报价单即将过有效期', path: '/customers/followups', perm: 'followup.view' },
    /* 审批统一到行政财务的审批中心：原来只跳合同页，报销和请假找不到入口 */
    { key: 'approval', label: '待处理审批', count: 4, desc: '报销、借款与请假', path: '/finance/approvals', perm: 'approval.view' },
    { key: 'payment', label: '待处理回款', count: 6, desc: '含 2 笔月结已逾期', path: '/orders/payments', danger: true, perm: 'payment.view' }
  ],
  /* 近 7 日出货金额（万元） */
  trend: [
    { day: '周一', value: 18.6 },
    { day: '周二', value: 24.2 },
    { day: '周三', value: 21.5 },
    { day: '周四', value: 32.8 },
    { day: '周五', value: 29.4 },
    { day: '周六', value: 12.6 },
    { day: '周日', value: 9.2 }
  ],
  /* 询盘漏斗 */
  funnel: [
    { stage: '询盘', count: 286, rate: 100 },
    { stage: '已联系', count: 198, rate: 69 },
    { stage: '已报价', count: 96, rate: 34 },
    { stage: '试样中', count: 54, rate: 19 },
    { stage: '成交', count: 32, rate: 11 }
  ],
  /* 日历上的标记（日期 -> 事项数） */
  marks: {
    3: 2, 6: 1, 9: 3, 12: 1, 17: 2, 20: 1, 24: 2, 27: 1, 30: 2
  },
  schedule: [
    { time: '09:30', title: '晨会 · 渠道组周复盘', place: '三楼会议室', tag: '内部' },
    { time: '11:00', title: '驰远汽修连锁 · 年度供货协议', place: '线上腾讯会议', tag: '客户' },
    { time: '14:30', title: '甬安汽修厂 · 密封件试样铺货', place: '客户现场', tag: '商机' },
    { time: '16:00', title: '回款跟进：运通物流月结尾款', place: '电话', tag: '回款' }
  ]
}

/* ------------------------------ 线索 ------------------------------ */
/* industry = 客户类型（4S 店 / 汽修连锁 / 汽配经销商 / 主机厂配套 / 车队物流 / 二类汽修厂） */
export const leads = [
  { id: 'LD-2605', company: '杭州驰远汽车服务连锁', contact: '沈立', phone: '138****6621', source: '官网询盘', industry: '汽修连锁', level: 'A', owner: '苏晚', status: '待联系', createdAt: '2026-11-09 10:12' },
  { id: 'LD-2604', company: '上海嘉定安驰 4S 店', contact: '高彤', phone: '139****3382', source: '汽配展', industry: '4S 店', level: 'A', owner: '林致远', status: '已联系', createdAt: '2026-11-09 09:04' },
  { id: 'LD-2603', company: '无锡运通物流车队', contact: '柳志强', phone: '137****7719', source: '客户转介绍', industry: '车队物流', level: 'B', owner: '陈默', status: '谈判中', createdAt: '2026-11-08 17:36' },
  { id: 'LD-2602', company: '苏州车之翼汽车用品', contact: '闫雪', phone: '135****2208', source: '1688 询盘', industry: '汽配经销商', level: 'B', owner: '周予安', status: '已联系', createdAt: '2026-11-08 14:20' },
  { id: 'LD-2601', company: '南京依维柯配件部', contact: '关鹏', phone: '186****5510', source: '电话外呼', industry: '主机厂配套', level: 'C', owner: '许知远', status: '待联系', createdAt: '2026-11-08 11:02' },
  { id: 'LD-2600', company: '常州瑞虎汽车维修中心', contact: '钟慧', phone: '133****9044', source: '官网询盘', industry: '二类汽修厂', level: 'C', owner: '梁书', status: '待联系', createdAt: '2026-11-07 16:45' },
  { id: 'LD-2599', company: '合肥皖通汽配贸易', contact: '傅晨', phone: '158****1188', source: '汽配展', industry: '汽配经销商', level: 'B', owner: '郑南', status: '已联系', createdAt: '2026-11-07 10:30' },
  { id: 'LD-2598', company: '嘉兴南方汽修', contact: '陆瑶', phone: '188****6620', source: '汽配城拜访', industry: '二类汽修厂', level: 'C', owner: '何思', status: '无效', createdAt: '2026-11-06 15:12' },
  { id: 'LD-2597', company: '金华众诚汽车服务', contact: '武斌', phone: '189****3355', source: '客户转介绍', industry: '汽修连锁', level: 'A', owner: '苏晚', status: '成交', createdAt: '2026-11-06 09:48' },
  { id: 'LD-2596', company: '宁波甬安汽修厂', contact: '席磊', phone: '150****7781', source: '电话外呼', industry: '二类汽修厂', level: 'B', owner: '林致远', status: '待联系', createdAt: '2026-11-05 14:06' }
]

export const leadPool = [
  { id: 'LD-2590', company: '台州宏运汽配商行', contact: '夏铭', phone: '137****2214', source: '官网询盘', region: '浙江 · 台州', createdAt: '2026-11-05 09:20', reason: '超 7 天未跟进' },
  { id: 'LD-2588', company: '东莞寮步汽车养护中心', contact: '潘宇', phone: '139****8890', source: '汽配展', region: '广东 · 东莞', createdAt: '2026-11-04 16:10', reason: '员工离职回收' },
  { id: 'LD-2585', company: '青岛恒达汽修设备', contact: '骆琳', phone: '135****4432', source: '客户转介绍', region: '山东 · 青岛', createdAt: '2026-11-03 11:35', reason: '线索重复清理' },
  { id: 'LD-2581', company: '成都鑫源汽配城商户', contact: '倪昊', phone: '186****9901', source: '电话外呼', region: '四川 · 成都', createdAt: '2026-11-02 15:48', reason: '超 30 天未跟进' },
  { id: 'LD-2577', company: '厦门路达汽车快修', contact: '钟启', phone: '188****3302', source: '官网询盘', region: '福建 · 厦门', createdAt: '2026-11-01 10:05', reason: '客户主动退回' },
  { id: 'LD-2574', company: '济南泉城汽修连锁', contact: '范黎', phone: '133****5567', source: '1688 询盘', region: '山东 · 济南', createdAt: '2026-10-31 14:26', reason: '超 7 天未跟进' }
]

/* ------------------------------ 客户 ------------------------------ */
export const customers = [
  { id: 'CU-1024', name: '杭州驰远汽车服务连锁', industry: '汽修连锁', level: '战略客户', owner: '林致远', contacts: 6, amount: 1864000, lastFollow: '今天 11:00', status: '合作中', createdAt: '2023-04-18' },
  { id: 'CU-1023', name: '南京依维柯配件部', industry: '主机厂配套', level: '战略客户', owner: '苏晚', contacts: 5, amount: 2860000, lastFollow: '4 天前', status: '合作中', createdAt: '2023-01-09' },
  { id: 'CU-1022', name: '上海嘉定安驰 4S 店', industry: '4S 店', level: 'A 类', owner: '陈默', contacts: 4, amount: 968000, lastFollow: '昨天 16:20', status: '跟进中', createdAt: '2024-01-09' },
  { id: 'CU-1021', name: '宁波甬安汽修厂', industry: '二类汽修厂', level: 'A 类', owner: '周予安', contacts: 3, amount: 642000, lastFollow: '3 天前', status: '待回款', createdAt: '2024-03-22' },
  { id: 'CU-1020', name: '苏州车之翼汽车用品', industry: '汽配经销商', level: 'B 类', owner: '苏晚', contacts: 2, amount: 328000, lastFollow: '5 天前', status: '跟进中', createdAt: '2024-06-11' },
  { id: 'CU-1019', name: '无锡运通物流车队', industry: '车队物流', level: 'A 类', owner: '许知远', contacts: 5, amount: 1240000, lastFollow: '今天 09:40', status: '合作中', createdAt: '2023-11-02' },
  { id: 'CU-1018', name: '常州瑞虎汽车维修中心', industry: '二类汽修厂', level: 'B 类', owner: '郑南', contacts: 2, amount: 186000, lastFollow: '2 天前', status: '跟进中', createdAt: '2024-08-30' },
  { id: 'CU-1017', name: '合肥皖通汽配贸易', industry: '汽配经销商', level: 'C 类', owner: '梁书', contacts: 1, amount: 54000, lastFollow: '12 天前', status: '流失风险', createdAt: '2025-02-14' },
  { id: 'CU-1016', name: '嘉兴南方汽修', industry: '二类汽修厂', level: 'B 类', owner: '林致远', contacts: 3, amount: 268000, lastFollow: '1 天前', status: '跟进中', createdAt: '2025-01-20' },
  { id: 'CU-1015', name: '金华众诚汽车服务', industry: '汽修连锁', level: 'C 类', owner: '何思', contacts: 1, amount: 0, lastFollow: '21 天前', status: '流失风险', createdAt: '2025-06-03' }
]

export const publicCustomers = [
  { id: 'CU-0987', name: '台州宏运汽配商行', industry: '汽配经销商', region: '浙江 · 台州', prevOwner: '（无）', amount: 0, orders: 0, lastFollow: '—', releasedAt: '2026-11-05', reason: '长期未跟进' },
  { id: 'CU-0976', name: '东莞寮步汽车养护中心', industry: '汽修连锁', region: '广东 · 东莞', prevOwner: '苏晚', amount: 86000, orders: 2, lastFollow: '2026-09-18', releasedAt: '2026-11-02', reason: '员工离职' },
  { id: 'CU-0961', name: '青岛恒达汽修设备', industry: '汽配经销商', region: '山东 · 青岛', prevOwner: '陈默', amount: 0, orders: 0, lastFollow: '2026-10-12', releasedAt: '2026-10-28', reason: '30 天无跟进' },
  { id: 'CU-0954', name: '成都鑫源汽配城商户', industry: '汽配经销商', region: '四川 · 成都', prevOwner: '周予安', amount: 320000, orders: 5, lastFollow: '2026-09-06', releasedAt: '2026-10-21', reason: '长期未跟进' },
  { id: 'CU-0940', name: '厦门路达汽车快修', industry: '二类汽修厂', region: '福建 · 厦门', prevOwner: '许知远', amount: 42000, orders: 1, lastFollow: '2026-10-02', releasedAt: '2026-10-15', reason: '主动退回客户池' }
]

export const contacts = [
  { id: 'CT-501', name: '高彤', customer: '上海嘉定安驰 4S 店', title: '配件部经理', phone: '139****3382', email: 'gaotong@anchiauto.com', owner: '陈默', primary: true },
  { id: 'CT-500', name: '柳志强', customer: '无锡运通物流车队', title: '车管部主管', phone: '137****7719', email: 'liuzq@yuntong56.com', owner: '许知远', primary: true },
  { id: 'CT-499', name: '闫雪', customer: '苏州车之翼汽车用品', title: '采购负责人', phone: '135****2208', email: 'yanxue@chezy.cn', owner: '苏晚', primary: true },
  { id: 'CT-498', name: '关鹏', customer: '南京依维柯配件部', title: '耗材采购工程师', phone: '186****5510', email: 'guanpeng@iveco-parts.com', owner: '苏晚', primary: true },
  { id: 'CT-497', name: '沈立', customer: '杭州驰远汽车服务连锁', title: '供应链总监', phone: '138****6621', email: 'shenli@chiyuan-auto.com', owner: '林致远', primary: false },
  { id: 'CT-496', name: '武斌', customer: '金华众诚汽车服务', title: '店长', phone: '189****3355', email: 'wubin@zhongcheng.cn', owner: '何思', primary: true },
  { id: 'CT-495', name: '席磊', customer: '宁波甬安汽修厂', title: '技术主管', phone: '150****7781', email: 'xilei@yongan-repair.cn', owner: '周予安', primary: true },
  { id: 'CT-494', name: '傅晨', customer: '合肥皖通汽配贸易', title: '仓储主管', phone: '158****1188', email: 'fuchen@wantong-parts.com', owner: '梁书', primary: false }
]

export const followUps = [
  { id: 'FU-901', time: '2026-11-10 11:00', customer: '杭州驰远汽车服务连锁', type: '线上会议', content: '确认 2027 年度紧固件集采框架，价格按季度联动钢材指数，等待对方采购中心回签。', next: '2026-11-12', owner: '林致远', result: '推进' },
  { id: 'FU-900', time: '2026-11-10 09:40', customer: '无锡运通物流车队', type: '电话', content: '车队 46 台车保养耗材改按月配送到场，需确认油封与滤芯规格清单。', next: '2026-11-13', owner: '许知远', result: '推进' },
  { id: 'FU-899', time: '2026-11-09 16:20', customer: '上海嘉定安驰 4S 店', type: '客户拜访', content: '现场清点线束波纹管与扎带库存，客户希望增加黑色款与 φ10 规格。', next: '2026-11-14', owner: '陈默', result: '推进' },
  { id: 'FU-898', time: '2026-11-09 10:15', customer: '宁波甬安汽修厂', type: '微信', content: '财务确认上月月结货款 6.8 万将于 11 月 20 日前结清。', next: '2026-11-20', owner: '周予安', result: '待回款' },
  { id: 'FU-897', time: '2026-11-08 15:05', customer: '苏州车之翼汽车用品', type: '邮件', content: '发送密封件与厌氧胶报价单，附 NBR 材质报告，等待技术评估。', next: '2026-11-11', owner: '苏晚', result: '待反馈' },
  { id: 'FU-896', time: '2026-11-08 09:30', customer: '合肥皖通汽配贸易', type: '电话', content: '客户转向低价渠道，本月暂无采购计划，标记流失风险。', next: '', owner: '梁书', result: '暂缓' }
]

/* ------------------------------ 订单 ------------------------------ */
/* 配件目录：小耗材 SKU，code 使用物料 / 国标编号 */
export const products = [
  { id: 'PD-01', name: '法兰面螺栓 M8×25 镀锌', code: 'GB5789 M8×25', category: '紧固件', price: 0.42, unit: '件 · 1000/箱', status: '在售', desc: '8.8 级碳钢镀锌，配尼龙自锁螺母，底盘护板与支架装配通用' },
  { id: 'PD-02', name: '不锈钢喉箍 16–25mm', code: 'BC-HG1625', category: '紧固件', price: 1.8, unit: '个 · 100/盒', status: '在售', desc: '304 不锈钢蜗杆，冷却水管与进气管通用，耐振动不松脱' },
  { id: 'PD-03', name: 'O 型密封圈 NBR 70A', code: 'φ25×2.65 NBR', category: '密封件', price: 0.85, unit: '件 · 500/袋', status: '在售', desc: '丁腈橡胶耐矿物油，油底壳、油路与水泵密封，-40~120℃' },
  { id: 'PD-04', name: '骨架油封 TC 30×47×7', code: 'TC304707 NBR', category: '密封件', price: 3.6, unit: '件 · 200/盒', status: '在售', desc: '双唇带副唇防尘，曲轴前后油封与变速箱输入轴通用' },
  { id: 'PD-05', name: '线束波纹管 φ8 阻燃开口', code: 'PA66-V0 φ8', category: '线束辅料', price: 1.1, unit: '米 · 200/卷', status: '在售', desc: '阻燃 PA66，耐温 -40~120℃，开口型便于后期加装线束' },
  { id: 'PD-06', name: '尼龙扎带 4×150 黑色', code: 'BC-ZD4150', category: '线束辅料', price: 12.5, unit: '包 · 100 条', status: '在售', desc: '耐候抗 UV，发动机舱与门线束固定，拉力≥18kg' },
  { id: 'PD-07', name: '螺纹锁固厌氧胶 243 中强度', code: 'BC-243 50ml', category: '化学品类', price: 26, unit: '支 · 12/盒', status: '在售', desc: 'M6–M20 螺纹防松，可拆卸，替代弹垫用于底盘与悬架螺栓' },
  { id: 'PD-08', name: '丁基橡胶阻尼片 2mm', code: 'BC-DZ2.0', category: '车身辅料', price: 18, unit: '张 · 20/包', status: '停售', desc: '止震降噪贴片，已由 3mm 加厚规格替代，库存售完即止' }
]

/* 合同：年度供货协议 / 框架合同 / 单次采购订单 */
export const contracts = [
  { id: 'HT-2026-0187', name: '驰远连锁 · 2027 年度耗材集采', customer: '杭州驰远汽车服务连锁', amount: 1864000, signDate: '2026-10-28', status: '执行中', owner: '林致远', paid: 60 },
  { id: 'HT-2026-0186', name: '依维柯配件部 · 紧固件年框', customer: '南京依维柯配件部', amount: 968000, signDate: '2026-11-02', status: '执行中', owner: '苏晚', paid: 35 },
  { id: 'HT-2026-0185', name: '甬安汽修厂 · 首单铺货订单', customer: '宁波甬安汽修厂', amount: 486000, signDate: '2026-11-05', status: '待审批', owner: '周予安', paid: 0 },
  { id: 'HT-2026-0184', name: '运通物流 · 车队保养耗材年供', customer: '无锡运通物流车队', amount: 268000, signDate: '2026-09-18', status: '已完成', owner: '许知远', paid: 90 },
  { id: 'HT-2026-0183', name: '车之翼 · 密封件专供协议', customer: '苏州车之翼汽车用品', amount: 186000, signDate: '2026-10-11', status: '执行中', owner: '陈默', paid: 50 },
  { id: 'HT-2026-0182', name: '南方汽修 · 线束辅料补货', customer: '嘉兴南方汽修', amount: 128000, signDate: '2026-08-26', status: '已完成', owner: '郑南', paid: 100 }
]

/* 回款：月结 30/60 天、票到付款、银行承兑 */
export const payments = [
  { id: 'HK-2026-0451', contract: 'HT-2026-0187', customer: '杭州驰远汽车服务连锁', amount: 745600, dueDate: '2026-11-15', paidDate: '', method: '月结 30 天', status: '待回款' },
  { id: 'HK-2026-0450', contract: 'HT-2026-0186', customer: '南京依维柯配件部', amount: 338800, dueDate: '2026-11-08', paidDate: '', method: '月结 60 天', status: '已逾期' },
  { id: 'HK-2026-0449', contract: 'HT-2026-0185', customer: '宁波甬安汽修厂', amount: 145800, dueDate: '2026-11-20', paidDate: '', method: '银行承兑', status: '待回款' },
  { id: 'HK-2026-0448', contract: 'HT-2026-0184', customer: '无锡运通物流车队', amount: 128000, dueDate: '2026-11-20', paidDate: '', method: '票到付款', status: '待回款' },
  { id: 'HK-2026-0447', contract: 'HT-2026-0183', customer: '苏州车之翼汽车用品', amount: 93000, dueDate: '2026-10-30', paidDate: '2026-10-29', method: '对公转账', status: '已回款' },
  { id: 'HK-2026-0446', contract: 'HT-2026-0182', customer: '嘉兴南方汽修', amount: 128000, dueDate: '2026-10-15', paidDate: '2026-10-14', method: '对公转账', status: '已回款' }
]

export const invoices = [
  { id: 'FP-2026-0322', contract: 'HT-2026-0187', customer: '杭州驰远汽车服务连锁', amount: 745600, type: '增值税专用', applyDate: '2026-11-06', status: '已开票', no: '04412026 3388' },
  { id: 'FP-2026-0321', contract: 'HT-2026-0186', customer: '南京依维柯配件部', amount: 338800, type: '增值税专用', applyDate: '2026-11-04', status: '待开票', no: '' },
  { id: 'FP-2026-0320', contract: 'HT-2026-0184', customer: '无锡运通物流车队', amount: 128000, type: '增值税普通', applyDate: '2026-11-01', status: '待开票', no: '' },
  { id: 'FP-2026-0319', contract: 'HT-2026-0183', customer: '苏州车之翼汽车用品', amount: 93000, type: '增值税专用', applyDate: '2026-10-28', status: '已开票', no: '04412026 3312' },
  { id: 'FP-2026-0318', contract: 'HT-2026-0182', customer: '嘉兴南方汽修', amount: 128000, type: '增值税专用', applyDate: '2026-10-12', status: '已开票', no: '04412026 3248' },
  { id: 'FP-2026-0317', contract: 'HT-2026-0181', customer: '合肥皖通汽配贸易', amount: 54000, type: '增值税普通', applyDate: '2026-10-08', status: '驳回', no: '' }
]

/* 费用 / 借款 / 请假已迁到 src/data/office.js —— 报销单要带明细行与借款抵扣，
   单条记录撑不起这些字段。行政财务板块四个页面共用那份数据。 */

/* ------------------------------ 设置 ------------------------------ */
export const departmentTree = [
  {
    id: 'D100',
    name: '北辰装配科技（总部）',
    leader: '林致远',
    count: 42,
    children: [
      { id: 'D110', name: '汽配渠道部', leader: '陈默', count: 14, children: [] },
      { id: 'D120', name: '主机厂配套部', leader: '苏晚', count: 9, children: [] },
      {
        id: 'D130',
        name: '区域销售部',
        leader: '许知远',
        count: 8,
        children: [
          { id: 'D131', name: '华东组', leader: '周予安', count: 4, children: [] },
          { id: 'D132', name: '华南组', leader: '郑南', count: 4, children: [] }
        ]
      },
      { id: 'D140', name: '电商运营部', leader: '何思', count: 5, children: [] },
      { id: 'D150', name: '仓储物流部', leader: '梁书', count: 4, children: [] },
      { id: 'D160', name: '财务部', leader: '梁书', count: 2, children: [] }
    ]
  }
]

export const employeeSeed = [
  { id: 'E001', name: '林致远', account: 'linzhiyuan', phone: '13800138001', email: 'linzy@beichen-assembly.com', dept: '汽配渠道部', role: '销售总监', status: '在职', joinDate: '2021-03-15' },
  { id: 'E002', name: '苏晚', account: 'suwan', phone: '13800138002', email: 'suwan@beichen-assembly.com', dept: '主机厂配套部', role: '部门负责人', status: '在职', joinDate: '2021-07-01' },
  { id: 'E003', name: '陈默', account: 'chenmo', phone: '13800138003', email: 'chenmo@beichen-assembly.com', dept: '汽配渠道部', role: '销售主管', status: '在职', joinDate: '2022-02-18' },
  { id: 'E004', name: '周予安', account: 'zhouyuan', phone: '13800138004', email: 'zhouya@beichen-assembly.com', dept: '华东组', role: '客户经理', status: '在职', joinDate: '2022-09-06' },
  { id: 'E005', name: '许知远', account: 'xuzhiyuan', phone: '13800138005', email: 'xuzy@beichen-assembly.com', dept: '区域销售部', role: '销售主管', status: '在职', joinDate: '2022-11-21' },
  { id: 'E006', name: '梁书', account: 'liangshu', phone: '13800138006', email: 'liangshu@beichen-assembly.com', dept: '仓储物流部', role: '财务经理', status: '在职', joinDate: '2023-01-09' },
  { id: 'E007', name: '郑南', account: 'zhengnan', phone: '13800138007', email: 'zhengnan@beichen-assembly.com', dept: '华南组', role: '客户经理', status: '停用', joinDate: '2023-05-16' },
  { id: 'E008', name: '何思', account: 'hesi', phone: '13800138008', email: 'hesi@beichen-assembly.com', dept: '电商运营部', role: '市场专员', status: '在职', joinDate: '2024-03-04' }
]

export const roleSeed = [
  { id: 'R01', name: '超级管理员', code: 'admin', members: 1, builtin: true, desc: '拥有系统全部权限，可配置组织架构与角色', perms: ['*'], createdAt: '2021-03-01' },
  { id: 'R02', name: '销售总监', code: 'sales_director', members: 2, builtin: false, desc: '统管全公司销售：询盘分配、供货协议与费用终审、业绩目标制定', perms: ['dashboard.view', 'lead.view', 'lead.create', 'lead.edit', 'lead.transfer', 'lead.convert', 'lead.pool', 'lead.pool.claim', 'lead.pool.assign', 'customer.view', 'customer.create', 'customer.edit', 'customer.merge', 'customer.public', 'customer.public.claim', 'contact.view', 'contact.edit', 'followup.view', 'followup.create', 'followup.board', 'product.view', 'order.view', 'order.create', 'order.approve', 'order.ship', 'order.return', 'contract.view', 'contract.create', 'contract.approve', 'statement.view', 'statement.create', 'statement.confirm', 'payment.view', 'payment.create', 'invoice.view', 'invoice.create', 'invoice.redflush', 'expense.view', 'expense.create', 'expense.approve', 'loan.view', 'loan.create', 'loan.approve', 'leave.view', 'leave.create', 'leave.approve', 'approval.view', 'target.view', 'target.manage'], createdAt: '2021-03-02' },
  { id: 'R03', name: '销售主管', code: 'sales_manager', members: 3, builtin: false, desc: '带团队跑渠道：分配询盘、审批组内协议、拆解区域出货目标', perms: ['dashboard.view', 'lead.view', 'lead.create', 'lead.edit', 'lead.transfer', 'lead.convert', 'lead.pool', 'lead.pool.claim', 'lead.pool.assign', 'customer.view', 'customer.create', 'customer.edit', 'customer.merge', 'customer.public', 'customer.public.claim', 'contact.view', 'contact.edit', 'followup.view', 'followup.create', 'followup.board', 'product.view', 'order.view', 'order.create', 'order.approve', 'order.ship', 'order.return', 'contract.view', 'contract.create', 'statement.view', 'statement.create', 'payment.view', 'payment.create', 'invoice.view', 'invoice.create', 'expense.view', 'expense.create', 'loan.view', 'loan.create', 'loan.approve', 'leave.view', 'leave.create', 'leave.approve', 'approval.view', 'target.view', 'target.manage'], createdAt: '2021-06-18' },
  { id: 'R04', name: '客户经理', code: 'account_manager', members: 18, builtin: false, desc: '一线跑店：跟进名下门店与经销商，发起订单、回款与开票申请', perms: ['dashboard.view', 'lead.view', 'lead.create', 'lead.edit', 'lead.pool', 'lead.pool.claim', 'customer.view', 'customer.create', 'customer.edit', 'customer.public', 'customer.public.claim', 'contact.view', 'contact.edit', 'followup.view', 'followup.create', 'product.view', 'order.view', 'order.create', 'order.ship', 'order.return', 'contract.view', 'contract.create', 'statement.view', 'payment.view', 'payment.create', 'invoice.view', 'invoice.create', 'expense.view', 'expense.create', 'loan.view', 'loan.create', 'leave.view', 'leave.create', 'approval.view', 'target.view'], createdAt: '2021-06-18' },
  { id: 'R05', name: '财务专员', code: 'finance', members: 4, builtin: false, desc: '核销月结回款、开具发票、审核运费与样品费用，不接触询盘经营', perms: ['dashboard.view', 'customer.view', 'contact.view', 'product.view', 'order.view', 'contract.view', 'statement.view', 'statement.create', 'statement.confirm', 'payment.view', 'payment.confirm', 'invoice.view', 'invoice.create', 'invoice.redflush', 'expense.view', 'expense.create', 'expense.approve', 'loan.view', 'loan.approve', 'leave.view', 'approval.view', 'target.view'], createdAt: '2021-08-09' },
  { id: 'R06', name: '市场专员', code: 'marketing', members: 5, builtin: false, desc: '负责汽配展与 1688 店铺询盘获取，初筛后转交销售跟进', perms: ['dashboard.view', 'lead.view', 'lead.create', 'lead.edit', 'lead.transfer', 'lead.pool', 'lead.pool.claim', 'customer.view', 'contact.view', 'followup.view', 'followup.create', 'product.view'], createdAt: '2022-04-11' },
  { id: 'R07', name: '销售运营专员', code: 'sales_operations', members: 4, builtin: false, desc: '盯线索流转：新线索按区域与负载分给销售，超时未跟进的回收进池，成交后确认转客户', perms: ['dashboard.view', 'lead.view', 'lead.create', 'lead.edit', 'lead.transfer', 'lead.convert', 'lead.pool', 'lead.pool.assign', 'customer.view', 'customer.merge', 'contact.view', 'followup.view', 'followup.board', 'order.view', 'order.approve', 'order.ship', 'statement.view', 'statement.create', 'expense.view', 'expense.approve', 'loan.view', 'loan.approve', 'leave.view', 'leave.create', 'leave.approve', 'approval.view', 'target.view', 'target.manage'], createdAt: '2023-09-06' }
]

export const targetSeed = [
  { id: 'T01', scope: '汽配渠道部', owner: '陈默', quarter: '2026 Q4', target: 3200000, achieved: 2148000, deals: 12 },
  { id: 'T02', scope: '主机厂配套部', owner: '苏晚', quarter: '2026 Q4', target: 2800000, achieved: 1862000, deals: 9 },
  { id: 'T03', scope: '区域销售部', owner: '许知远', quarter: '2026 Q4', target: 4200000, achieved: 3126000, deals: 7 },
  { id: 'T04', scope: '电商运营部', owner: '何思', quarter: '2026 Q4', target: 1200000, achieved: 486000, deals: 4 }
]

export function ownerColor(name) {
  const found = coworkers.find((c) => c.name === name)
  return found ? found.color : '#64748b'
}

export function initials(name = '') {
  if (!name) return '—'
  return name.length <= 2 ? name : name.slice(-2)
}
