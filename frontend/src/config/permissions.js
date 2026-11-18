/**
 * 权限字典 —— 前端单一事实来源
 *
 * 设计原则：
 *  1. 权限点用「模块.对象.动作」三段式命名，与后端将来返回的权限码可直接对齐
 *     （Spring Security 常见形式：lead:create / crm:lead:create，届时只改 key）
 *  2. 分组用于角色管理页的勾选矩阵，也用于菜单排序
 *  3. 查看权与操作权分离：能看到页面 ≠ 能点按钮
 */

export const PERMISSION_GROUPS = [
  {
    key: 'dashboard',
    label: '工作台',
    icon: 'grid',
    desc: '概览与实时数据',
    items: [
      { key: 'dashboard.view', label: '查看工作台', desc: '实时概况、待办、日历' }
    ]
  },
  {
    key: 'lead',
    label: '线索',
    icon: 'target',
    desc: '线索获取、流转与分配',
    items: [
      { key: 'lead.view', label: '查看销售线索', desc: '' },
      { key: 'lead.create', label: '新建线索', desc: '' },
      { key: 'lead.edit', label: '编辑线索', desc: '改联系人、等级、备注等信息' },
      { key: 'lead.transfer', label: '转移负责人', desc: '把线索 / 客户改派给他人（离职交接、组长调派）' },
      { key: 'lead.convert', label: '转为客户', desc: '勾选后该角色可在销售线索里把线索转为客户档案' },
      { key: 'lead.pool', label: '查看线索池', desc: '' },
      { key: 'lead.pool.claim', label: '领取线索', desc: '从线索池领取到名下' },
      { key: 'lead.pool.assign', label: '分配线索', desc: '把线索池线索指派给他人' }
    ]
  },
  {
    key: 'customer',
    label: '客户',
    icon: 'users',
    desc: '客户档案、联系人与跟进',
    items: [
      { key: 'customer.view', label: '查看客户', desc: '' },
      { key: 'customer.create', label: '新建客户', desc: '' },
      { key: 'customer.edit', label: '编辑客户', desc: '含档案、标签、协议价与信用额度' },
      { key: 'customer.merge', label: '合并重复客户', desc: '把重复档案并入主客户，联系人跟进一起迁移' },
      { key: 'customer.public', label: '查看客户池', desc: '' },
      { key: 'customer.public.claim', label: '领取 / 退回客户池', desc: '' },
      { key: 'contact.view', label: '查看联系人', desc: '客户详情里的联系人与决策链' },
      { key: 'contact.edit', label: '维护联系人', desc: '' },
      { key: 'followup.view', label: '查看跟进记录', desc: '' },
      { key: 'followup.create', label: '新增跟进', desc: '' },
      { key: 'followup.board', label: '团队跟进看板', desc: '按人看全组待跟进与超期，一般给主管和运营' }
    ]
  },
  {
    key: 'product',
    label: '产品',
    icon: 'box',
    desc: '产品主数据、品类与价格',
    items: [
      { key: 'product.view', label: '查看产品', desc: '产品列表、品类与价格档位' },
      { key: 'product.edit', label: '新建 / 编辑产品', desc: '含上下架、品类属性模板维护' },
      { key: 'product.price', label: '调整价格', desc: '改标准价、经销价与阶梯价' },
      { key: 'product.cost', label: '查看成本价', desc: '成本与毛利率，一般只给管理员和财务' },
      { key: 'product.import', label: '导入 / 导出', desc: 'Excel 批量维护产品' }
    ]
  },
  {
    key: 'order',
    label: '订单',
    icon: 'briefcase',
    desc: '订单、合同、对账、发票与回款',
    items: [
      { key: 'order.view', label: '查看订单', desc: '订单列表与详情' },
      { key: 'order.create', label: '新建订单', desc: '合同订单与备货订单' },
      { key: 'order.approve', label: '审批订单', desc: '超信用额度或低于成本价的订单' },
      { key: 'order.ship', label: '登记发货', desc: '分批发货与物流单号' },
      { key: 'order.return', label: '申请退货', desc: '退货同时冲减应收与销量' },
      { key: 'contract.view', label: '查看合同', desc: '' },
      { key: 'contract.create', label: '新建合同', desc: '' },
      { key: 'contract.approve', label: '审批合同', desc: '合同生效审批' },
      { key: 'statement.view', label: '查看对账单', desc: '' },
      { key: 'statement.create', label: '生成对账单', desc: '按客户与账期生成' },
      { key: 'statement.confirm', label: '确认对账单', desc: '确认后才允许开票' },
      { key: 'invoice.view', label: '查看发票', desc: '' },
      { key: 'invoice.create', label: '申请 / 开具发票', desc: '' },
      { key: 'invoice.redflush', label: '红冲发票', desc: '作废重开，必须留原票号' },
      { key: 'payment.view', label: '查看回款', desc: '' },
      { key: 'payment.create', label: '登记收款', desc: '录入银行到账' },
      { key: 'payment.confirm', label: '核销回款', desc: '把到账金额核销到发票' },
      { key: 'payment.revoke', label: '反核销回款', desc: '撤销核销并记录原因' }
    ]
  },
  {
    key: 'finance',
    label: '行政财务',
    icon: 'wallet',
    desc: '报销、借款、请假与统一审批',
    items: [
      { key: 'expense.view', label: '查看费用报销', desc: '' },
      { key: 'expense.create', label: '提交报销单', desc: '含费用明细、差旅行程与借款抵扣' },
      { key: 'expense.approve', label: '审批费用', desc: '' },
      { key: 'loan.view', label: '查看借款预支', desc: '含在借余额与抵扣记录' },
      { key: 'loan.create', label: '申请借款', desc: '差旅预支、备用金、采购垫付' },
      { key: 'loan.approve', label: '审批借款', desc: '通过后登记打款' },
      { key: 'leave.view', label: '查看请假', desc: '' },
      { key: 'leave.create', label: '发起请假', desc: '年假、病假、事假与调休' },
      { key: 'leave.approve', label: '审批请假', desc: '' },
      { key: 'approval.view', label: '查看审批中心', desc: '报销、借款、请假的统一待办' }
    ]
  },
  {
    key: 'data',
    label: '数据',
    icon: 'chart',
    desc: '经营分析看板（只读）',
    items: [
      { key: 'data.overview', label: '销售概况', desc: '签约、回款、客户与转化的总览' },
      { key: 'data.funnel', label: '销售漏斗', desc: '线索六态流转与阶段转化' },
      { key: 'data.customers', label: '客户分析', desc: '跟进活跃度、复购与沉睡客户' },
      { key: 'data.performance', label: '业绩分析', desc: '部门 / 员工 / 完成度与成交排行' },
      { key: 'data.payments', label: '回款分析', desc: '账龄、逾期明细与回款率' },
      { key: 'data.products', label: '产品分析', desc: '品类结构、毛利与滞销' },
      { key: 'data.sources', label: '来源 ROI', desc: '渠道投入产出与获客成本' },
      { key: 'data.scope.dept', label: '查看本部门数据', desc: '不勾只能看本人；勾了看本部门及下级' },
      { key: 'data.scope.all', label: '查看全公司数据', desc: '含所有部门与员工，一般只给总监、运营与财务' }
    ]
  },
  {
    key: 'setting',
    label: '设置',
    icon: 'settings',
    desc: '组织、角色与业绩目标',
    items: [
      { key: 'employee.view', label: '查看员工', desc: '' },
      { key: 'employee.manage', label: '新建 / 停用 / 删除员工', desc: '' },
      { key: 'dept.view', label: '查看部门', desc: '' },
      { key: 'dept.manage', label: '维护部门', desc: '' },
      { key: 'role.view', label: '查看角色', desc: '' },
      { key: 'role.manage', label: '配置角色与权限', desc: '' },
      { key: 'target.view', label: '查看业绩目标', desc: '' },
      { key: 'target.manage', label: '设置业绩目标', desc: '' }
    ]
  }
]

/** 全量权限点（扁平） */
export const ALL_PERMISSIONS = PERMISSION_GROUPS.flatMap((g) => g.items.map((i) => i.key))

/** 权限点 -> 中文名 */
export const PERMISSION_LABELS = PERMISSION_GROUPS.reduce((map, g) => {
  g.items.forEach((i) => {
    map[i.key] = i.label
  })
  return map
}, {})

/** 权限点 -> 所属分组 */
export const PERMISSION_GROUP_OF = PERMISSION_GROUPS.reduce((map, g) => {
  g.items.forEach((i) => {
    map[i.key] = g.key
  })
  return map
}, {})

export function groupItems(groupKey) {
  return PERMISSION_GROUPS.find((g) => g.key === groupKey)?.items.map((i) => i.key) || []
}

/**
 * 老演示数据（roles 里存的是「工作台/线索/客户/订单/设置」这种模块名）
 * 迁移映射：模块名 -> 该模块下的权限点
 */
const LEGACY_MODULE_MAP = {
  工作台: ['dashboard.view'],
  线索: [
    'lead.view', 'lead.create', 'lead.edit', 'lead.convert',
    'lead.pool', 'lead.pool.claim', 'lead.pool.assign'
  ],
  客户: [
    'customer.view', 'customer.create', 'customer.edit', 'customer.public',
    'customer.public.claim', 'contact.view', 'contact.edit',
    'followup.view', 'followup.create'
  ],
  订单: [
    'product.view', 'product.edit', 'contract.view', 'contract.create', 'contract.approve',
    'payment.view', 'payment.create', 'payment.confirm',
    'invoice.view', 'invoice.create', 'expense.view', 'expense.create', 'expense.approve'
  ],
  财务: [
    'expense.view', 'expense.create', 'expense.approve',
    'loan.view', 'loan.create', 'loan.approve',
    'leave.view', 'leave.create', 'leave.approve',
    'approval.view'
  ],
  行政财务: [
    'expense.view', 'expense.create', 'expense.approve',
    'loan.view', 'loan.create', 'loan.approve',
    'leave.view', 'leave.create', 'leave.approve',
    'approval.view'
  ],
  设置: ['employee.view', 'dept.view', 'role.view', 'target.view']
}

/**
 * 把角色上存的 perms 展开成合法权限点数组。
 * 兼容：'*'（超管通配）、老的模块名、无效值直接丢弃
 */
export function expandPerms(list = []) {
  if (!Array.isArray(list)) return []
  const out = new Set()
  list.forEach((p) => {
    if (p === '*' || p === 'all') {
      ALL_PERMISSIONS.forEach((k) => out.add(k))
      return
    }
    if (LEGACY_MODULE_MAP[p]) {
      LEGACY_MODULE_MAP[p].forEach((k) => out.add(k))
      return
    }
    if (PERMISSION_LABELS[p]) out.add(p)
  })
  return ALL_PERMISSIONS.filter((k) => out.has(k))
}

/** 归一化角色对象：超管固定全量，其余展开权限点 */
export function normalizeRole(role) {
  if (!role) return role
  const isSuper =
    role.code === 'admin' || role.code === 'super_admin' || role.superAdmin === true
  return {
    ...role,
    superAdmin: isSuper,
    perms: isSuper ? [...ALL_PERMISSIONS] : expandPerms(role.perms)
  }
}

/** 角色摘要：返回命中的模块名列表，用于卡片上的标签 */
export function permModules(perms = []) {
  const set = new Set(perms.map((p) => PERMISSION_GROUP_OF[p]).filter(Boolean))
  return PERMISSION_GROUPS.filter((g) => set.has(g.key)).map((g) => g.label)
}

/* ============================================================
 * 岗位角色预设
 * 按「谁负责什么」分配，而不是按「能看多少」平均切
 * ============================================================ */
const DIRECTOR = [
  'dashboard.view',
  'lead.view', 'lead.create', 'lead.edit', 'lead.transfer', 'lead.convert',
  'lead.pool', 'lead.pool.claim', 'lead.pool.assign',
  'customer.view', 'customer.create', 'customer.edit', 'customer.merge',
  'customer.public', 'customer.public.claim',
  'contact.view', 'contact.edit', 'followup.view', 'followup.create', 'followup.board',
  'product.view',
  'product.price',
  'order.view', 'order.create', 'order.approve', 'order.ship', 'order.return',
  'contract.view', 'contract.create', 'contract.approve',
  'statement.view', 'statement.create', 'statement.confirm',
  'payment.view', 'payment.create', 'payment.confirm',
  'invoice.view', 'invoice.create', 'invoice.redflush',
  'expense.view', 'expense.create', 'expense.approve',
  'loan.view', 'loan.create', 'loan.approve',
  'leave.view', 'leave.create', 'leave.approve',
  'approval.view',
  'data.overview', 'data.funnel', 'data.customers', 'data.performance',
  'data.payments', 'data.products', 'data.sources',
  'data.scope.dept', 'data.scope.all',
  'target.view', 'target.manage'
]

const MANAGER = [
  'dashboard.view',
  'lead.view', 'lead.create', 'lead.edit', 'lead.transfer', 'lead.convert',
  'lead.pool', 'lead.pool.claim', 'lead.pool.assign',
  'customer.view', 'customer.create', 'customer.edit', 'customer.merge',
  'customer.public', 'customer.public.claim',
  'contact.view', 'contact.edit', 'followup.view', 'followup.create', 'followup.board',
  'product.view',
  'product.price',
  'order.view', 'order.create', 'order.approve', 'order.ship', 'order.return',
  'contract.view', 'contract.create',
  'statement.view', 'statement.create',
  'payment.view', 'payment.create',
  'invoice.view', 'invoice.create',
  'expense.view', 'expense.create',
  'loan.view', 'loan.create', 'loan.approve',
  'leave.view', 'leave.create', 'leave.approve',
  'approval.view',
  'data.overview', 'data.funnel', 'data.customers', 'data.performance',
  'data.payments', 'data.products', 'data.scope.dept',
  'target.view', 'target.manage'
]

/* 一线销售：只负责跟进自己名下的线索。
   「转为客户」不写进默认清单——它是业务开关，勾不勾由管理员在
   设置 › 角色管理里决定；含在默认预设里等于替客户拍板。
   「把线索/客户改派给别人」属于离职交接或组长调派，也不在销售手上 */
const ACCOUNT_MANAGER = [
  'dashboard.view',
  'lead.view', 'lead.create', 'lead.edit',
  'lead.pool', 'lead.pool.claim',
  'customer.view', 'customer.create', 'customer.edit', 'customer.public', 'customer.public.claim',
  'contact.view', 'contact.edit', 'followup.view', 'followup.create',
  'product.view',
  'order.view', 'order.create', 'order.ship', 'order.return',
  'contract.view', 'contract.create',
  'statement.view',
  'payment.view', 'payment.create',
  'invoice.view', 'invoice.create',
  'expense.view', 'expense.create',
  'loan.view', 'loan.create',
  'leave.view', 'leave.create',
  'approval.view',
  /* 销售只看自己的：不勾 data.scope.*，口径天然是 self */
  'data.overview', 'data.funnel', 'data.customers', 'data.performance', 'data.payments',
  'target.view'
]

const FINANCE = [
  'dashboard.view',
  'customer.view', 'contact.view',
  'product.view',
  'product.cost',
  'order.view',
  'contract.view',
  'statement.view', 'statement.create', 'statement.confirm',
  'payment.view', 'payment.confirm',
  'invoice.view', 'invoice.create', 'invoice.redflush',
  'expense.view', 'expense.create', 'expense.approve',
  'loan.view', 'loan.approve',
  'leave.view',
  'approval.view',
  'data.overview', 'data.payments', 'data.products', 'data.scope.dept', 'data.scope.all',
  'target.view'
]

const MARKETING = [
  'dashboard.view',
  'lead.view', 'lead.create', 'lead.edit', 'lead.transfer',
  'lead.pool', 'lead.pool.claim',
  'customer.view',
  'contact.view',
  'followup.view', 'followup.create',
  'product.view',
  /* 市场盯渠道 ROI：线索从哪来、转化多少，是他最关心的 */
  'data.overview', 'data.funnel', 'data.sources', 'data.scope.all',
  /* 只看自己的业绩目标，不参与制定 —— 与「销售顾问」一致 */
  'target.view'
]

/**
 * 销售运营：新线索进来先落在他这里，按区域 / 负载分给销售；
 * 超时没跟进的线索收进池子，成交确认后由他转为客户档案；
 * 销售离职时由他接手把线索改派给同事。
 * 注意没有 lead.pool.claim —— 运营不自己领线索跟单。
 */
const SALES_OPS = [
  'dashboard.view',
  'lead.view', 'lead.create', 'lead.edit', 'lead.transfer', 'lead.convert',
  'lead.pool', 'lead.pool.assign',
  'customer.view', 'customer.merge', 'contact.view',
  'customer.public', 'customer.public.claim',
  'followup.view', 'followup.board',
  'product.view', 'product.edit', 'product.price', 'product.import',
  'order.view', 'order.approve', 'order.ship',
  'statement.view', 'statement.create', 'statement.confirm',
  'expense.view', 'expense.approve',
  'loan.view', 'loan.approve',
  'leave.view', 'leave.create', 'leave.approve',
  'approval.view',
  'data.overview', 'data.funnel', 'data.customers', 'data.performance',
  'data.payments', 'data.scope.dept', 'data.scope.all',
  'target.view', 'target.manage'
]

export const ROLE_PRESETS = [
  {
    id: 'R01',
    name: '超级管理员',
    code: 'admin',
    members: 1,
    builtin: true,
    desc: '系统所有者，拥有全部功能权限，可配置组织架构、角色与数据',
    perms: ['*'],
    createdAt: '2021-03-01'
  },
  {
    id: 'R02',
    name: '销售总监',
    code: 'sales_director',
    members: 2,
    builtin: false,
    desc: '统管全公司销售：线索分配、合同与费用终审、业绩目标制定',
    perms: DIRECTOR,
    createdAt: '2021-03-02'
  },
  {
    id: 'R03',
    name: '销售主管',
    code: 'sales_manager',
    members: 3,
    builtin: false,
    desc: '带团队做单：分配线索、审批组内合同、拆解部门业绩目标',
    perms: MANAGER,
    createdAt: '2021-06-18'
  },
  {
    id: 'R04',
    name: '客户经理',
    code: 'account_manager',
    members: 18,
    builtin: false,
    desc: '一线销售：跟进名下线索与客户，发起合同、回款与开票申请',
    perms: ACCOUNT_MANAGER,
    createdAt: '2021-06-18'
  },
  {
    id: 'R05',
    name: '财务专员',
    code: 'finance',
    members: 4,
    builtin: false,
    desc: '核销回款、开具发票、审核费用，不接触线索与客户经营',
    perms: FINANCE,
    createdAt: '2021-08-09'
  },
  {
    id: 'R06',
    name: '市场专员',
    code: 'marketing',
    members: 5,
    builtin: false,
    desc: '负责线索获取与初步培育，领取后转交销售跟进',
    perms: MARKETING,
    createdAt: '2022-04-11'
  },
  {
    id: 'R07',
    name: '销售运营专员',
    code: 'sales_operations',
    members: 4,
    builtin: false,
    desc: '盯线索流转：新线索按区域与负载分给销售，超时未跟进的回收进池，成交后确认转客户',
    perms: SALES_OPS,
    createdAt: '2023-09-06'
  }
]
