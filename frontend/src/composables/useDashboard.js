/**
 * 工作台实时指标
 * ------------------------------------------------------------
 * 原来这四个数字来自 src/data/mock.js 的 overview.kpi，和数据库完全无关：
 * 页面写着「本月成交额 ¥1,482 万」，实际库里一单都没有过。
 * 现在全部按真实单据算，口径统一在下面注释里，和「待办」「订单」「回款」页对得上。
 */
import { ref } from 'vue'
import { orderApi } from '@/api/orders'
import { leadApi } from '@/api/leads'
import { can } from '@/store/permissions'
import { todayStr } from '@/utils/date'

/* 作废订单不进入任何金额口径 */
const VOID_ORDER = ['草稿', '已取消', '已退货']

const pad = (n) => String(n).padStart(2, '0')
const monthOf = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}`

function shiftMonth(n) {
  const d = new Date()
  d.setDate(1)
  d.setMonth(d.getMonth() + n)
  return d
}

function delta(cur, prev) {
  if (!prev) return null
  return ((cur - prev) / prev) * 100
}

const dateOf = (row) =>
  String(row.order_date || row.date || row.payDate || row.pay_date || '').slice(0, 10)

export function useDashboard() {
  const kpi = ref([])
  const trend = ref([])
  const funnel = ref([])
  const loading = ref(false)
  const error = ref('')

  async function load() {
    loading.value = true
    error.value = ''
    const thisMonth = monthOf(new Date())
    const lastMonth = monthOf(shiftMonth(-1))

    try {
      const [orderRes, receiptRes, leads] = await Promise.all([
        can('order.view') ? orderApi.list({ pageSize: 500 }).catch(() => null) : Promise.resolve(null),
        can('payment.view') ? orderApi.receipts({ pageSize: 500 }).catch(() => null) : Promise.resolve(null),
        can('lead.view') ? leadApi.list(false).catch(() => []) : Promise.resolve([])
      ])

      const orders = (orderRes?.rows || []).filter((o) => !VOID_ORDER.includes(o.status))
      const receipts = receiptRes?.rows || []
      const leadRows = Array.isArray(leads) ? leads : leads?.rows || []

      const sum = (rows, month) =>
        rows.filter((r) => dateOf(r).startsWith(month)).reduce((s, r) => s + Number(r.amount || 0), 0)
      const count = (rows, month) => rows.filter((r) => dateOf(r).startsWith(month)).length

      /* 1. 本月下单额 */
      const orderCur = sum(orders, thisMonth)
      const orderPrev = sum(orders, lastMonth)

      /* 2. 本月回款额 */
      const recvCur = sum(receipts, thisMonth)
      const recvPrev = sum(receipts, lastMonth)

      /* 3. 本月成交单数 */
      const dealCur = count(orders, thisMonth)
      const dealPrev = count(orders, lastMonth)

      /* 4. 待发货订单：不是金额，是当前压着的出库任务 */
      const pendingShip = orders.filter((o) => o.status === '待发货').length

      kpi.value = [
        {
          key: 'orders',
          label: '本月下单额',
          value: orderCur,
          money: true,
          delta: delta(orderCur, orderPrev),
          hint: '不含草稿与已取消'
        },
        {
          key: 'received',
          label: '本月回款额',
          value: recvCur,
          money: true,
          delta: delta(recvCur, recvPrev),
          hint: '按到账日期归集'
        },
        {
          key: 'deals',
          label: '本月成单数',
          value: dealCur,
          unit: ' 单',
          delta: delta(dealCur, dealPrev),
          hint: '有效订单张数'
        },
        {
          key: 'ship',
          label: '待发货订单',
          value: pendingShip,
          unit: ' 单',
          delta: null,
          hint: pendingShip ? '需要安排出库' : '已清空'
        }
      ]

      /* 近 7 日下单额（万元），含今天 */
      const days = []
      for (let i = 6; i >= 0; i--) {
        const d = new Date()
        d.setDate(d.getDate() - i)
        days.push({ day: `${d.getMonth() + 1}/${d.getDate()}`, date: `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` })
      }
      trend.value = days.map((d) => {
        const amt = orders
          .filter((o) => dateOf(o) === d.date)
          .reduce((s, o) => s + Number(o.amount || 0), 0)
        return { day: d.day, value: Math.round((amt / 10000) * 10) / 10 }
      })

      /* 询盘漏斗：按「已经到达该阶段」累计，保证严格递减 */
      const stage = (...keys) => leadRows.filter((l) => keys.includes(l.status)).length
      const total = leadRows.length
      const contacted = stage('contacted', 'quoted', 'negotiating', 'won')
      const quoted = stage('quoted', 'negotiating', 'won')
      const negotiating = stage('negotiating', 'won')
      const won = stage('won')
      const rate = (cur, prev) => (prev ? Math.round((cur / prev) * 1000) / 10 : 0)

      funnel.value = [
        { stage: '线索接入', count: total, rate: 100 },
        { stage: '已联系', count: contacted, rate: rate(contacted, total) },
        { stage: '已报价', count: quoted, rate: rate(quoted, contacted) },
        { stage: '谈判中', count: negotiating, rate: rate(negotiating, quoted) },
        { stage: '成交', count: won, rate: rate(won, negotiating) }
      ]
    } catch (e) {
      error.value = e.message
    } finally {
      loading.value = false
    }
  }

  return { kpi, trend, funnel, loading, error, load, todayStr }
}
