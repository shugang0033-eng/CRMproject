import { createRouter, createWebHistory } from 'vue-router'
import { isLoggedIn, refreshSession } from '@/store/session'
import { can, firstAllowedPath } from '@/store/permissions'

const routes = [
  {
    path: '/login',
    name: 'login',
    component: () => import('@/views/Login.vue'),
    meta: { public: true, title: '登录' }
  },
  {
    path: '/',
    component: () => import('@/layout/AppLayout.vue'),
    redirect: '/dashboard',
    children: [
      {
        path: 'dashboard',
        name: 'dashboard',
        component: () => import('@/views/Dashboard.vue'),
        meta: { title: '工作台', group: '概览', perm: 'dashboard.view' }
      },
      {
        /* 待办横跨审批 / 合同 / 发货 / 对账 / 退货 / 跟进 / 线索，
           不属于任何一个业务分组，所以放在概览下作为独立入口 */
        path: 'todos',
        name: 'todos',
        component: () => import('@/views/Todos.vue'),
        meta: { title: '待办', group: '概览', perm: 'dashboard.view' }
      },

      /* ---------------- 线索 ---------------- */
      {
        path: 'leads',
        name: 'leads',
        component: () => import('@/views/leads/LeadList.vue'),
        meta: { title: '销售线索', group: '线索', perm: 'lead.view' }
      },
      {
        path: 'leads/pool',
        name: 'lead-pool',
        component: () => import('@/views/leads/LeadPool.vue'),
        meta: { title: '线索池', group: '线索', perm: 'lead.pool' }
      },

      /* ---------------- 客户 ---------------- */
      {
        path: 'customers',
        name: 'customers',
        component: () => import('@/views/customers/CustomerList.vue'),
        meta: { title: '客户列表', group: '客户', perm: 'customer.view' }
      },
      {
        path: 'customers/public',
        name: 'public-customers',
        component: () => import('@/views/customers/PublicPool.vue'),
        meta: { title: '客户池', group: '客户', perm: 'customer.public' }
      },
      {
        path: 'customers/follow-board',
        name: 'follow-board',
        component: () => import('@/views/customers/FollowBoard.vue'),
        meta: { title: '团队跟进', group: '客户', perm: 'followup.board' }
      },
      {
        /* 客户 360：联系人 / 跟进 / 合同回款 / 附件都在这一页里。
           navPath 让左侧菜单高亮回「客户列表」 */
        path: 'customers/:id',
        name: 'customer-detail',
        component: () => import('@/views/customers/CustomerDetail.vue'),
        meta: { title: '客户详情', group: '客户', perm: 'customer.view', navPath: '/customers' }
      },
      {
        /* 联系人已收进客户详情，旧链接保留不 404；列表页支持按联系人姓名手机号搜客户 */
        path: 'customers/contacts',
        redirect: '/customers'
      },
      {
        /* 跟进记录收进详情页，团队视角改由看板承载 */
        path: 'customers/followups',
        redirect: '/customers/follow-board'
      },

      /* ---------------- 产品 ---------------- */
      {
        path: 'products',
        name: 'product-list',
        component: () => import('@/views/products/ProductList.vue'),
        meta: { title: '产品列表', group: '产品', perm: 'product.view' }
      },
      {
        path: 'products/inventory',
        name: 'product-inventory',
        component: () => import('@/views/products/Inventory.vue'),
        meta: { title: '库存', group: '产品', perm: 'product.view' }
      },
      {
        path: 'products/categories',
        name: 'product-categories',
        component: () => import('@/views/products/Categories.vue'),
        meta: { title: '品类管理', group: '产品', perm: 'product.edit' }
      },
      {
        path: 'products/pricing',
        name: 'product-pricing',
        component: () => import('@/views/products/Pricing.vue'),
        meta: { title: '价格与折扣', group: '产品', perm: 'product.view' }
      },
      {
        path: 'products/bundles',
        name: 'product-bundles',
        component: () => import('@/views/products/Bundles.vue'),
        meta: { title: '套装组合', group: '产品', perm: 'product.view' }
      },

      /* ---------------- 订单 ---------------- */
      {
        /* 配件目录已升级为「产品管理 › 产品列表」，旧链接保持可用 */
        path: 'orders/products',
        redirect: '/products'
      },
      {
        path: 'orders',
        name: 'orders',
        component: () => import('@/views/orders/OrderList.vue'),
        meta: { title: '订单列表', group: '订单', perm: 'order.view' }
      },
      {
        path: 'orders/contracts',
        name: 'contracts',
        component: () => import('@/views/orders/Contracts.vue'),
        meta: { title: '合同', group: '订单', perm: 'contract.view' }
      },
      {
        path: 'orders/statements',
        name: 'statements',
        component: () => import('@/views/orders/Statements.vue'),
        meta: { title: '对账单', group: '订单', perm: 'statement.view' }
      },
      {
        path: 'orders/invoices',
        name: 'invoices',
        component: () => import('@/views/orders/Invoices.vue'),
        meta: { title: '发票', group: '订单', perm: 'invoice.view' }
      },
      {
        path: 'orders/returns',
        name: 'returns',
        component: () => import('@/views/orders/Returns.vue'),
        meta: { title: '退货与售后', group: '订单', perm: 'order.view' }
      },
      {
        path: 'orders/payments',
        name: 'payments',
        component: () => import('@/views/orders/Payments.vue'),
        meta: { title: '回款', group: '订单', perm: 'payment.view' }
      },
      {
        /* 放最后：静态路径优先匹配，写在 /orders 各子路由之后更直观。
           navPath 让左侧菜单高亮回「订单列表」 */
        path: 'orders/:id',
        name: 'order-detail',
        component: () => import('@/views/orders/OrderDetail.vue'),
        meta: { title: '订单详情', group: '订单', perm: 'order.view', navPath: '/orders' }
      },
      {
        /* 费用从订单板块迁出，旧链接重定向 */
        path: 'orders/expenses',
        redirect: '/finance/expenses'
      },

      /* ---------------- 行政财务 ---------------- */
      {
        path: 'finance',
        redirect: '/finance/expenses'
      },
      {
        path: 'finance/expenses',
        name: 'expenses',
        component: () => import('@/views/finance/Expenses.vue'),
        meta: { title: '费用报销', group: '行政财务', perm: 'expense.view' }
      },
      {
        path: 'finance/loans',
        name: 'loans',
        component: () => import('@/views/finance/Loans.vue'),
        meta: { title: '借款预支', group: '行政财务', perm: 'loan.view' }
      },
      {
        path: 'finance/leaves',
        name: 'leaves',
        component: () => import('@/views/finance/Leaves.vue'),
        meta: { title: '请假申请', group: '行政财务', perm: 'leave.view' }
      },
      {
        path: 'finance/approvals',
        name: 'approvals',
        component: () => import('@/views/finance/Approvals.vue'),
        meta: { title: '审批中心', group: '行政财务', perm: 'approval.view' }
      },

      /* ---------------- 数据 ---------------- */
      {
        path: 'analytics',
        redirect: '/analytics/overview'
      },
      {
        path: 'analytics/overview',
        name: 'analytics-overview',
        component: () => import('@/views/analytics/Overview.vue'),
        meta: { title: '销售概况', group: '数据', perm: 'data.overview' }
      },
      {
        path: 'analytics/funnel',
        name: 'analytics-funnel',
        component: () => import('@/views/analytics/Funnel.vue'),
        meta: { title: '销售漏斗', group: '数据', perm: 'data.funnel' }
      },
      {
        path: 'analytics/customers',
        name: 'analytics-customers',
        component: () => import('@/views/analytics/Customers.vue'),
        meta: { title: '客户分析', group: '数据', perm: 'data.customers' }
      },
      {
        path: 'analytics/performance',
        name: 'analytics-performance',
        component: () => import('@/views/analytics/Performance.vue'),
        meta: { title: '业绩分析', group: '数据', perm: 'data.performance' }
      },
      {
        path: 'analytics/payments',
        name: 'analytics-payments',
        component: () => import('@/views/analytics/Payments.vue'),
        meta: { title: '回款分析', group: '数据', perm: 'data.payments' }
      },
      {
        path: 'analytics/products',
        name: 'analytics-products',
        component: () => import('@/views/analytics/Products.vue'),
        meta: { title: '产品分析', group: '数据', perm: 'data.products' }
      },
      {
        path: 'analytics/sources',
        name: 'analytics-sources',
        component: () => import('@/views/analytics/Sources.vue'),
        meta: { title: '来源 ROI', group: '数据', perm: 'data.sources' }
      },

      /* ---------------- 设置 ---------------- */
      {
        path: 'settings/employees',
        name: 'employees',
        component: () => import('@/views/settings/Employees.vue'),
        meta: { title: '员工管理', group: '设置', perm: 'employee.view' }
      },
      {
        path: 'settings/departments',
        name: 'departments',
        component: () => import('@/views/settings/Departments.vue'),
        meta: { title: '部门管理', group: '设置', perm: 'dept.view' }
      },
      {
        path: 'settings/roles',
        name: 'roles',
        component: () => import('@/views/settings/Roles.vue'),
        meta: { title: '角色管理', group: '设置', perm: 'role.view' }
      },
      {
        path: 'settings/targets',
        name: 'targets',
        component: () => import('@/views/settings/Targets.vue'),
        meta: { title: '业绩目标', group: '设置', perm: 'target.view' }
      },
      {
        /* 所有登录角色都能进：账号自有能力，不挂在功能权限上 */
        path: 'settings/profile',
        name: 'profile',
        component: () => import('@/views/settings/Profile.vue'),
        meta: { title: '个人中心', group: '设置' }
      },

      /* ---------------- 无权限 ---------------- */
      {
        path: 'forbidden',
        name: 'forbidden',
        component: () => import('@/views/Forbidden.vue'),
        meta: { title: '无访问权限', group: '提示' }
      }
    ]
  },
  { path: '/:pathMatch(.*)*', redirect: '/dashboard' }
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior: () => ({ top: 0 })
})

router.beforeEach(async (to) => {
  await refreshSession()
  /* 1. 未登录 */
  if (!to.meta.public && !isLoggedIn()) {
    return { name: 'login', query: to.fullPath === '/dashboard' ? {} : { redirect: to.fullPath } }
  }

  /* 2. 已登录还去登录页 → 回自己的落地页 */
  if (to.name === 'login' && isLoggedIn()) {
    return firstAllowedPath()
  }

  /* 3. 根路径 / 工作台：没有工作台权限的账号直接落到第一个能看的页面 */
  if (to.path === '/' || (to.name === 'dashboard' && !can('dashboard.view'))) {
    return firstAllowedPath()
  }

  /* 4. 功能权限 */
  if (to.meta.perm && !can(to.meta.perm)) {
    return { name: 'forbidden', query: { from: to.fullPath } }
  }

  const title = to.meta.title
  document.title = title ? `${title} · 北辰装配科技 CRM` : '北辰装配科技 · 汽车配件耗材销售 CRM'
  return true
})

export default router

