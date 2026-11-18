/**
 * 导航配置。perm 决定菜单是否可见，需与 router 里 meta.perm 保持一致
 */
export const navItems = [
  { label: '工作台', icon: 'grid', path: '/dashboard', perm: 'dashboard.view' },
  /* 待办横跨审批、合同、发货、对账、退货、跟进、线索，放进任何业务分组都会被埋没；
     它是销售每天开工第一个要看的东西，所以紧跟工作台，且带实时条数徽标 */
  { label: '待办', icon: 'check-circle', path: '/todos', perm: 'dashboard.view', badge: 'todo' },
  {
    label: '线索',
    icon: 'target',
    children: [
      { label: '销售线索', path: '/leads', perm: 'lead.view' },
      { label: '线索池', path: '/leads/pool', perm: 'lead.pool' }
    ]
  },
  {
    label: '客户',
    icon: 'users',
    children: [
      { label: '客户列表', path: '/customers', perm: 'customer.view' },
      { label: '客户池', path: '/customers/public', perm: 'customer.public' },
      { label: '团队跟进', path: '/customers/follow-board', perm: 'followup.board' }
    ]
  },
  {
    label: '产品',
    icon: 'box',
    children: [
      { label: '产品列表', path: '/products', perm: 'product.view' },
      /* 库存回答「现在能不能发货」，产品列表回答「卖什么、多少钱」，两件事分开 */
      { label: '库存', path: '/products/inventory', perm: 'product.view' },
      { label: '品类管理', path: '/products/categories', perm: 'product.edit' },
      { label: '价格与折扣', path: '/products/pricing', perm: 'product.view' },
      { label: '套装组合', path: '/products/bundles', perm: 'product.view' }
    ]
  },
  {
    label: '订单',
    icon: 'briefcase',
    children: [
      { label: '订单列表', path: '/orders', perm: 'order.view' },
      { label: '合同', path: '/orders/contracts', perm: 'contract.view' },
      /* 退货是订单的反向单据，和发货、回款同级，不单设「售后中心」一级菜单 */
      { label: '退货与售后', path: '/orders/returns', perm: 'order.view' },
      { label: '对账单', path: '/orders/statements', perm: 'statement.view' },
      { label: '发票', path: '/orders/invoices', perm: 'invoice.view' },
      { label: '回款', path: '/orders/payments', perm: 'payment.view' }
    ]
  },
  {
    /* 报销、借款、请假三件事的共同点是「员工发起 → 主管审批 → 财务留痕」，
       所以放一个板块里；审批中心是这三类单据的统一待办入口。
       与订单回款没有上下游关系，不放进订单菜单，避免业务单据和内部事务混在一起 */
    label: '行政财务',
    icon: 'wallet',
    children: [
      { label: '费用报销', path: '/finance/expenses', perm: 'expense.view' },
      { label: '借款预支', path: '/finance/loans', perm: 'loan.view' },
      { label: '请假申请', path: '/finance/leaves', perm: 'leave.view' },
      { label: '审批中心', path: '/finance/approvals', perm: 'approval.view' }
    ]
  },
  {
    label: '数据',
    icon: 'chart',
    children: [
      { label: '销售概况', path: '/analytics/overview', perm: 'data.overview' },
      { label: '销售漏斗', path: '/analytics/funnel', perm: 'data.funnel' },
      { label: '客户分析', path: '/analytics/customers', perm: 'data.customers' },
      { label: '业绩分析', path: '/analytics/performance', perm: 'data.performance' },
      { label: '回款分析', path: '/analytics/payments', perm: 'data.payments' },
      { label: '产品分析', path: '/analytics/products', perm: 'data.products' },
      { label: '来源 ROI', path: '/analytics/sources', perm: 'data.sources' }
    ]
  },
  {
    label: '设置',
    icon: 'settings',
    children: [
      { label: '员工管理', path: '/settings/employees', perm: 'employee.view' },
      { label: '部门管理', path: '/settings/departments', perm: 'dept.view' },
      { label: '角色管理', path: '/settings/roles', perm: 'role.view' },
      { label: '业绩目标', path: '/settings/targets', perm: 'target.view' },
      /* 不带 perm：任何角色都要能看到自己的个人中心 */
      { label: '个人中心', path: '/settings/profile' }
    ]
  }
]

export const quickCreate = [
  { label: '新建线索', desc: '录入一条销售线索', icon: 'target', path: '/leads', perm: 'lead.create' },
  { label: '新建客户', desc: '创建客户档案', icon: 'users', path: '/customers', perm: 'customer.create' },
  { label: '新建合同', desc: '发起合同审批', icon: 'file', path: '/orders/contracts', perm: 'contract.create' },
  { label: '登记回款', desc: '录入银行到账并核销', icon: 'wallet', path: '/orders/payments', perm: 'payment.create' },
  { label: '填写报销单', desc: '差旅、招待、运费逐条录', icon: 'receipt', path: '/finance/expenses', perm: 'expense.create' },
  { label: '发起请假', desc: '年假、病假、事假与调休', icon: 'calendar', path: '/finance/leaves', perm: 'leave.create' }
]
