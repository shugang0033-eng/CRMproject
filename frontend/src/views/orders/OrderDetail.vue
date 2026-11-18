<template>
  <div class="page">
    <div class="crumbs">
      <button class="btn-text back" type="button" @click="router.push('/orders')">
        <AppIcon name="chevron-left" :size="14" />订单
      </button>
      <span class="sep">/</span>
      <span class="cur">{{ orderNo }}</span>
      <span v-if="isLocal" class="local-hint"><AppIcon name="flag" :size="11" />演示数据</span>
    </div>

    <div v-if="!order.id" class="card empty-card">
      <AppIcon name="flag" :size="18" />
      <div>订单不存在，或不在你的数据范围内</div>
      <button class="btn" type="button" @click="router.push('/orders')">返回订单列表</button>
    </div>

    <template v-else>
      <!-- 头部 -->
      <div class="card head">
        <div class="head-main">
          <div class="name-row">
            <h2>{{ orderNo }}</h2>
            <span class="tag" :class="tone[order.status]">{{ order.status }}</span>
            <span class="tag tag-gray plain">{{ order.type }}</span>
            <span v-if="order.creditCheck === '超额度'" class="tag tag-danger">超信用额度</span>
          </div>
          <div class="sub">
            <span>{{ order.customer }}</span>
            <span class="dot">·</span>
            <span>业务员 {{ order.owner }}</span>
            <span class="dot">·</span>
            <span>下单 {{ order.date }}</span>
            <span class="dot">·</span>
            <span>期望到货 {{ order.expect }}</span>
          </div>
        </div>
        <div class="head-amount">
          <span>订单金额</span>
          <b>¥{{ amount.toLocaleString() }}</b>
          <em>{{ totalBoxes }} 箱 · 毛利率 {{ margin === '—' ? '—' : margin + '%' }}</em>
        </div>
      </div>

      <!-- 单据链路 -->
      <div class="card chain">
        <div v-for="n in chain" :key="n.key" class="node" :class="[n.state, { act: !!n.action }]">
          <div class="node-dot">
            <AppIcon v-if="n.state === 'done'" name="check" :size="11" />
          </div>
          <div class="node-body">
            <div class="node-label">{{ n.label }}</div>
            <div class="node-note">{{ n.note }}</div>
            <button v-if="n.action" class="node-act" type="button" @click.stop="router.push(n.action.to)">
              {{ n.action.text }}<AppIcon name="chevron-right" :size="10" />
            </button>
          </div>
        </div>
      </div>

      <div class="two-col">
        <div class="col-main">
          <!-- 商品明细 -->
          <div class="card">
            <div class="card-head">
              <div>
                <div class="card-title">商品明细</div>
                <div class="card-sub">单价按「协议价 → 阶梯价 → 经销价」取最低，低于成本价需审批</div>
              </div>
            </div>
            <AppTable :columns="lineColumns" :rows="lineRows" row-key="key" :show-pager="false" compact>
              <template #cell-name="{ row }">
                <div class="cell-main">{{ row.name }}</div>
                <div class="cell-sub">{{ row.spec }}</div>
              </template>
              <template #cell-price="{ row }">
                <span class="num">¥{{ row.price.toFixed(2) }}</span>
                <div class="cell-sub">{{ row.source }}</div>
              </template>
              <template #cell-amount="{ row }">
                <span class="num">¥{{ row.amount.toLocaleString() }}</span>
              </template>
              <template #cell-margin="{ row }">
                <span :class="row.margin == null ? 'faint' : row.margin < 0 ? 'text-danger' : 'num'">
                  {{ row.margin == null ? '—' : row.margin + '%' }}
                </span>
              </template>
            </AppTable>
            <div class="table-foot">
              <span>合计 {{ totalBoxes }} 箱</span>
              <b>¥{{ amount.toLocaleString() }}</b>
            </div>
          </div>

          <!-- 发货记录 -->
          <div class="card">
            <div class="card-head">
              <div>
                <div class="card-title">发货记录</div>
                <div class="card-sub">支持分批发货，每次发货同时回写库存与应收</div>
              </div>
              <button
                v-can="'order.ship'"
                class="btn btn-sm"
                type="button"
                :disabled="!canShip"
                @click="openShip"
              >
                <AppIcon name="box" :size="13" />登记发货
              </button>
            </div>
            <AppTable v-if="lines.length" :columns="shipColumns" :rows="lines" row-key="id" :show-pager="false" compact>
              <template #cell-status="{ row }">
                <span class="tag" :class="row.status === '已签收' ? 'tag-success' : 'tag-info'">{{ row.status }}</span>
                <button v-if="row.status === '运输中'" v-can="'order.ship'" class="btn-text" @click="signShipment(row)">确认签收</button>
              </template>
            </AppTable>
            <div v-else class="empty-slim">
              {{ canShip ? '还没有发货记录，点右上「登记发货」按批发货' : '还没有发货记录' }}
            </div>
          </div>

          <!-- 退货 -->
          <div class="card">
            <div class="card-head">
              <div>
                <div class="card-title">退货记录</div>
                <div class="card-sub">退货会冲减订单已发数量与应收，并回写库存</div>
              </div>
              <button
                v-can="'order.return'"
                class="btn btn-sm"
                type="button"
                :disabled="!canReturn"
                @click="openReturn"
              >
                <AppIcon name="refresh" :size="13" />申请退货
              </button>
            </div>
            <AppTable v-if="myReturns.length" :columns="returnColumns" :rows="myReturns" row-key="id" :show-pager="false" compact>
              <template #cell-status="{ row }">
                <span class="tag" :class="row.status === '待审核' ? 'tag-warning' : 'tag-success'">{{ row.status }}</span>
                <template v-if="row.status === '待审核'">
                  <button v-can="'order.approve'" class="btn-text" @click="reviewReturn(row, 'pass')">确认入库</button>
                  <button v-can="'order.approve'" class="btn-text" @click="reviewReturn(row, 'reject')">驳回</button>
                </template>
              </template>
              <template #cell-amount="{ row }">
                <span class="num text-danger">-¥{{ row.amount.toLocaleString() }}</span>
              </template>
            </AppTable>
            <div v-else class="empty-slim">没有退货记录</div>
          </div>
        </div>

        <div class="col-side">
          <!-- 金额 -->
          <div class="card">
            <div class="card-head"><div class="card-title">金额概览</div></div>
            <div class="money-list">
              <div class="ml"><span>订单金额</span><b>¥{{ amount.toLocaleString() }}</b></div>
              <div class="ml"><span>已发货</span><b>¥{{ shippedAmount.toLocaleString() }}</b></div>
              <div v-if="returnAmount > 0" class="ml">
                <span>退货冲减</span><b class="text-danger">-¥{{ returnAmount.toLocaleString() }}</b>
              </div>
              <div class="ml strong"><span>待发货</span><b>¥{{ (amount - shippedAmount).toLocaleString() }}</b></div>
            </div>
          </div>

          <!-- 客户与合同 -->
          <div class="card">
            <div class="card-head"><div class="card-title">客户与合同</div></div>
            <div class="info-list">
              <div class="il"><span>客户</span><b>{{ order.customer }}</b></div>
              <div class="il"><span>关联合同</span><b>{{ contractLabel }}</b></div>
              <div class="il"><span>账期</span><b>{{ creditInfo ? `月结 ${creditInfo.term} 天` : '—' }}</b></div>
              <div class="il">
                <span>可用额度</span>
                <b :class="{ 'text-danger': creditLeft != null && creditLeft < 0 }">
                  {{ creditLeft == null ? '—' : '¥' + creditLeft.toLocaleString() }}
                </b>
              </div>
              <div class="il"><span>备注</span><b class="remark">{{ order.remark }}</b></div>
            </div>
          </div>

          <!-- 需要处理 -->
          <div v-if="todos.length" class="card">
            <div class="card-head"><div class="card-title">需要处理</div></div>
            <div class="todo-list">
              <div v-for="(t, i) in todos" :key="i" class="todo" :class="t.tone">
                <AppIcon name="bell" :size="13" />
                <div>
                  <div class="td-title">{{ t.title }}</div>
                  <div class="td-desc">{{ t.desc }}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>

    <!-- 发货 -->
    <ModalDialog v-model="shipOpen" title="登记发货" :desc="`${orderNo} · ${order.customer}`" ok-text="确认发货" @confirm="confirmShip">
      <div class="form-grid">
        <div class="field span-2">
          <label class="label">本次发货箱数<span class="req">*</span></label>
          <select v-model="shipForm.lineId" class="select">
            <option v-for="line in order.items" :key="line.id" :value="line.id">{{ line.name }} · {{ line.unit }}</option>
          </select>
          <input v-model.number="shipForm.boxes" class="input" type="number" min="1" :max="remainBoxes" />
          <div class="hint">未发 {{ remainBoxes }} 箱，可分批发出</div>
        </div>
        <div class="field">
          <label class="label">物流公司</label>
          <select v-model="shipForm.logistics" class="select">
            <option>德邦物流</option>
            <option>安能物流</option>
            <option>顺丰重货</option>
            <option>自有车队</option>
          </select>
        </div>
        <div class="field">
          <label class="label">物流单号</label>
          <input v-model="shipForm.trackingNo" class="input" type="text" placeholder="自有车队可留空" />
        </div>
      </div>
    </ModalDialog>

    <!-- 退货 -->
    <ModalDialog v-model="returnOpen" title="申请退货" :desc="`${orderNo} · ${order.customer}`" ok-text="提交退货" @confirm="confirmReturn">
      <div class="form-grid">
        <div class="field span-2">
          <label class="label">退货原因<span class="req">*</span></label>
          <select v-model="returnForm.reason" class="select">
            <option>质量问题</option>
            <option>发错规格</option>
            <option>包装破损</option>
            <option>客户取消订单</option>
            <option>其他</option>
          </select>
        </div>
        <div class="field">
          <label class="label">退货箱数</label>
          <select v-model="returnForm.lineId" class="select">
            <option v-for="line in order.items" :key="line.id" :value="line.id">{{ line.name }} · {{ line.unit }}</option>
          </select>
          <input v-model.number="returnForm.qty" class="input" type="number" min="1"  />
          <div class="hint">已发 {{ sentBoxes }} 箱</div>
        </div>
        <div class="field">
          <label class="label">说明</label>
          <input v-model="returnForm.note" class="input" type="text" placeholder="如：边角脱线，整批退回" />
        </div>
      </div>
    </ModalDialog>
  </div>
</template>

<script setup>
import { computed, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import { toast } from '@/composables/useToast'
import { can } from '@/store/permissions'
import { orderApi } from '@/api/orders'
import { productItems, specSummary, unitPrice } from '@/data/productCatalog'
import {
  orderAmount, orderMargin, orderBoxes, linePrice, lineAmount,
  ORDER_STATUS_TONE
} from '@/data/orderCenter'

const route = useRoute()
const router = useRouter()

/* 没有 product.cost 权限时不展示毛利率列，也不返回成本相关字段 */
const canCost = computed(() => can('product.cost'))

/* 只认精确 id，不做兜底：否则越权访问会显示成别人的单 */
const detail = ref(null)
watch(() => route.params.id, async (id, _, onCleanup) => {
  let current = true
  onCleanup(() => { current = false })
  detail.value = null
  try {
    const data = await orderApi.detail(id)
    if (current) detail.value = data
  } catch (e) { if (current) toast(e.message, 'error') }
}, { immediate: true })
const order = computed(() => {
  if (!detail.value) return {}
  const o = detail.value.order
  return { ...o, date: o.order_date, expect: o.expect_date, contractId: o.contract_id,
    creditCheck: o.credit_check, items: detail.value.items }
})
/* 详情接口只回 contract_id，页面上要给人看单号：拉一次合同列表做映射。
   没有 contract.view 权限或接口不通就退回「合同 #id」，不编造单号 */
const contractCodes = ref({})
if (can('contract.view')) {
  orderApi.contracts({ pageSize: 500 })
    .then(({ rows }) => { contractCodes.value = Object.fromEntries((rows || []).map((c) => [c.id, c.code])) })
    .catch(() => { contractCodes.value = {} })
}
const contractLabel = computed(() => {
  const id = order.value.contractId
  if (!id) return '—（备货订单）'
  return contractCodes.value[id] || '—'
})

/* 单号：实时数据 id 是数字主键，展示要用 code；演示数据 id 本身就是单号 */
const orderNo = computed(() => order.value.code || order.value.id || '')

const isLocal = false
const tone = ORDER_STATUS_TONE

const amount = computed(() => (order.value.id ? Number(order.value.amount) : 0))
/* 订单毛利率：任一行成本取不到就不出数，宁可显示「—」也不报假毛利 */
const margin = computed(() => {
  const items = order.value.items || []
  if (!items.length) return '—'
  let sales = 0
  let cost = 0
  for (const it of items) {
    const p = productItems.find((x) => x.name === it.name)
    const c = p ? unitPrice(p, it.unit, 'cost') : 0
    const price = linePrice(order.value, it)
    if (!c || !price) return '—'
    sales += price * it.qty
    cost += c * it.qty
  }
  return sales ? (((sales - cost) / sales) * 100).toFixed(1) : '—'
})
const totalBoxes = computed(() => (order.value.id ? order.value.items.reduce((sum, line) => sum + Number(line.qty), 0) : 0))
const sentBoxes = computed(() => (order.value.id ? order.value.items.reduce((sum, line) => sum + Number(line.shippedQty) - Number(line.returnedQty), 0) : 0))
const remainBoxes = computed(() => Math.max(0, totalBoxes.value - sentBoxes.value))
/* 已发货金额按「毛发货」算：退货单独一行冲减，否则已退货的单会显示成「已发 0、待发全额」 */
const grossBoxes = computed(() => (order.value.items || []).reduce((s, it) => s + Number(it.shippedQty || 0), 0))
const shippedRatio = computed(() => (totalBoxes.value ? grossBoxes.value / totalBoxes.value : 0))
const shippedAmount = computed(() => Math.round(amount.value * shippedRatio.value))

/* 单号列要显示单号（RT-…）；id 留给接口寻址，别混用 */
const myReturns = computed(() => (detail.value?.returns || []).map((row) => ({ ...row, no: row.code || row.id, at: row.return_date })))
const returnAmount = computed(() => myReturns.value.reduce((s, r) => s + r.amount, 0))
const lines = computed(() => (detail.value?.shipments || []).map((row) => ({ ...row, no: row.code || row.id, at: row.ship_date, trackingNo: row.tracking_no })))

/* 客户信用额度：接口还没把额度/账期带进订单详情，没数据就显示「—」，
   不要拿 0 元额度糊弄人（看起来像客户被冻结了） */
const creditInfo = computed(() => order.value.customerCredit || null)
const creditLeft = computed(() => (creditInfo.value?.available ?? null))

/* 发货/退货接口属于第三批，后端未实现前按钮禁用；接口上线后改成 true 即可通电 */
const canShip = computed(() => remainBoxes.value > 0 && ['待发货', '部分发货'].includes(order.value.status))
const canReturn = computed(() => order.value.status === '已签收')
async function reload() {
  detail.value = await orderApi.detail(route.params.id)
}

/* 单据链路：状态由交易事实推导，不单独存字段 */
/* 签收了吗：以发货事实为准，别只看订单状态——已退货的单也发过货、也签收过 */
const signedUp = computed(() => {
  const o = order.value
  return o.status === '已签收' || o.status === '已退货' ||
    (lines.value.length > 0 && lines.value.every((l) => l.status === '已签收'))
})

/* 能对哪几个月的账：按签收月份归集。对账单是「客户 + 账期」维度，
   所以这里给的是候选账期列表，具体用哪个由对账单页判断（已对过的跳过） */
const signedMonths = computed(() => {
  const set = new Set()
  for (const l of lines.value) {
    if (l.status !== '已签收') continue
    const m = String(l.signed_at || l.at || '').slice(0, 7)
    if (/^\d{4}-\d{2}$/.test(m)) set.add(m)
  }
  return [...set].sort()
})

/* 该客户的对账单：判断「这期对没对过账」必须看真实数据。
   原来那处判断查的是演示常量 statements，真实客户永远查不到，等于没提示 */
const custStatements = ref([])
watch(() => order.value.customer_id, async (cid, _, onCleanup) => {
  if (!cid || !can('statement.view')) {
    custStatements.value = []
    return
  }
  let current = true
  onCleanup(() => { current = false })
  try {
    const { rows } = await orderApi.statements({ customerId: cid, pageSize: 100 })
    if (current) custStatements.value = rows || []
  } catch {
    if (current) custStatements.value = [] // 取不到就只提示「未对账」，不乱报已对账
  }
}, { immediate: true })

/* 已签收、但对应账期还没有对账单的部分：这才叫「该收没收进账」 */
const unbilled = computed(() => {
  const billed = new Set(custStatements.value.map((s) => s.period))
  const acc = new Map()
  for (const l of lines.value) {
    if (l.status !== '已签收') continue
    const m = String(l.signed_at || l.at || '').slice(0, 7)
    if (!/^\d{4}-\d{2}$/.test(m) || billed.has(m)) continue
    const prev = acc.get(m) || { period: m, amount: 0, count: 0 }
    prev.amount += Number(l.amount || 0)
    prev.count += 1
    acc.set(m, prev)
  }
  return [...acc.values()].sort((a, b) => (a.period < b.period ? -1 : 1))
})

/* 「回款」节点的去处：带着客户和账期跳到对账单页，把断掉的流程接上。
   没有 statement.view 就别给入口——路由守卫会直接把人送到 403 */
const payTo = computed(() => {
  const o = order.value
  if (!signedUp.value || !o.customer || !o.customer_id || !can('statement.view')) return null
  return {
    name: 'statements',
    query: { customer: o.customer, periods: signedMonths.value.join(','), from: o.code || '' }
  }
})

const chain = computed(() => {
  const o = order.value
  if (!o.id) return []
  const sent = lines.value.length > 0 || grossBoxes.value > 0
  const signed = signedUp.value
  return [
    {
      key: 'contract',
      label: '合同',
      note: contractLabel.value,
      state: o.contractId ? 'done' : 'skip'
    },
    { key: 'order', label: '下单', note: o.date, state: 'done' },
    { key: 'ship', label: '发货', note: sent ? `已发 ${grossBoxes.value} 箱` : '待发货', state: sent ? 'done' : 'now' },
    { key: 'sign', label: '签收', note: signed ? '客户已签收' : '未签收', state: signed ? 'done' : sent ? 'now' : 'wait' },
    {
      key: 'pay',
      label: '回款',
      note: signed ? '已进入对账周期' : '签收后生成应收',
      state: signed ? 'now' : 'wait',
      action: payTo.value ? { text: '去对账', to: payTo.value } : null
    }
  ]
})

const lineColumns = computed(() => [
  { key: 'name', label: '产品' },
  { key: 'unit', label: '单位', width: '68px' },
  { key: 'qty', label: '数量', width: '78px', align: 'right' },
  { key: 'price', label: '单价', width: '104px', align: 'right' },
  ...(canCost.value ? [{ key: 'margin', label: '毛利率', width: '84px', align: 'right' }] : []),
  { key: 'amount', label: '金额', width: '116px', align: 'right' }
])

const lineRows = computed(() =>
  (order.value.items || []).map((it, i) => {
    /* 后端明细只回 productId + 品名：按品名回查产品档案，才能拿到规格和成本价。
       查不到就退化成品名，别让规格列编造内容 */
    const p = productItems.find((x) => x.name === it.name) || { name: it.name }
    const price = linePrice(order.value, it)
    const cost = unitPrice(p, it.unit, 'cost')
    /* 成本取不到就别报 100% 毛利，显示「—」比报个假数体面 */
    const ratio = cost > 0 && price > 0 ? ((price - cost) / price) * 100 : null
    return {
      key: `${it.productId}-${i}`,
      name: p.name || it.productId,
      spec: p.id ? specSummary(p) : '—',
      unit: it.unit,
      qty: it.qty,
      price,
      /* 后端算了取价来源（标准价/经销价/阶梯价/合同协议价），以它为准 */
      source: it.priceSource || (it.price != null ? '成交价' : '协议价'),
      amount: lineAmount(order.value, it),
      margin: ratio == null ? null : ratio.toFixed(1)
    }
  })
)

const shipColumns = [
  { key: 'no', label: '发货单号', width: '140px' },
  { key: 'at', label: '发货日期', width: '104px' },
  { key: 'boxes', label: '箱数', width: '72px', align: 'right' },
  { key: 'logistics', label: '物流', width: '104px' },
  { key: 'trackingNo', label: '运单号' },
  { key: 'status', label: '状态', width: '86px' }
]

const returnColumns = [
  { key: 'no', label: '退货单号', width: '132px' },
  { key: 'at', label: '申请日期', width: '104px' },
  { key: 'reason', label: '原因', width: '94px' },
  { key: 'note', label: '说明' },
  { key: 'amount', label: '金额', width: '104px', align: 'right' },
  { key: 'status', label: '状态', width: '86px' }
]

const todos = computed(() => {
  const list = []
  const o = order.value
  if (!o.id) return list
  if (o.status === '待审批') {
    list.push({
      title: o.creditCheck === '超额度' ? '超出客户信用额度' : '成交价低于底价',
      desc: '需主管审批后才能发货，避免继续扩大应收',
      tone: 'danger'
    })
  }
  if (remainBoxes.value > 0 && canShip.value) {
    list.push({ title: `还有 ${remainBoxes.value} 箱未发`, desc: '客户期望到货日 ' + o.expect, tone: 'warning' })
  }
  const pendingReturn = myReturns.value.find((r) => r.status === '待确认')
  if (pendingReturn) {
    list.push({ title: `${pendingReturn.id} 待确认`, desc: pendingReturn.note, tone: 'warning' })
  }

  /* 对账 → 开票 → 回款：签收后这一段原来没有任何提示，用户走到这里就断了。
     判断一律用该客户的真实对账单（custStatements），不拿演示数据凑 */
  if (can('statement.view') && signedUp.value && o.status !== '已取消' && o.status !== '草稿') {
    if (unbilled.value.length) {
      const amount = unbilled.value.reduce((s, x) => s + x.amount, 0)
      const periods = unbilled.value.map((x) => x.period)
      const count = unbilled.value.reduce((s, x) => s + x.count, 0)
      list.push({
        title: `${periods.length === 1 ? '本期 ' : ''}¥${amount.toLocaleString()} 未对账`,
        desc: `${periods.join('、')} 已签收 ${count} 笔，还没生成对账单；点链路里的「去对账」生成，客户确认后才好开票`,
        tone: 'warning'
      })
    } else {
      /* 都对过账了：按最近一张未结清的对账单推下一步 */
      const closed = new Set(['已回款', '已作废'])
      const last = custStatements.value
        .filter((s) => !closed.has(s.status))
        .sort((a, b) => (a.period < b.period ? -1 : 1))[0]
      const next = last && {
        待确认: { title: `${last.period} 对账单待客户确认`, desc: `${last.code} 客户确认后才能开票`, tone: 'info' },
        已确认: { title: `${last.period} 对账单可开票`, desc: `${last.code} 已确认，去「发票 › 申请开票」`, tone: 'info' },
        已开票: { title: `${last.period} 对账单待回款`, desc: `${last.code} 已开票，收款后去「回款 › 登记收款」核销`, tone: 'warning' }
      }[last.status]
      if (next) list.push(next)
    }
  }
  return list
})

/* ---------------- 发货 ---------------- */
const shipOpen = ref(false)
const shipForm = reactive({ boxes: 1, logistics: '德邦物流', trackingNo: '' })

function openShip() {
  shipForm.lineId = order.value.items.find((line) => line.qty > line.shippedQty)?.id
  shipForm.boxes = 1
  shipForm.logistics = '德邦物流'
  shipForm.trackingNo = ''
  shipOpen.value = true
}

async function confirmShip() {
  const line = order.value.items.find((item) => item.id === shipForm.lineId)
  if (!line || shipForm.boxes <= 0) return toast('请选择商品并填写发货数量', 'error')
  try {
    await orderApi.ship(order.value.id, {
      items: [{ productId: line.productId, unit: line.unit, qty: shipForm.boxes }],
      logistics: shipForm.logistics, trackingNo: shipForm.trackingNo
    })
    shipOpen.value = false
    await reload()
  } catch (e) { toast(e.message, 'error') }
}

async function signShipment(shipment) {
  try {
    await orderApi.sign(shipment.id)
    await reload()
  } catch (e) { toast(e.message, 'error') }
}

async function reviewReturn(row, result) {
  try {
    await orderApi.confirmReturn(row.id, { result, restock: result === 'pass' })
    await reload()
  } catch (e) { toast(e.message, 'error') }
}

/* ---------------- 退货 ---------------- */
const returnOpen = ref(false)
const returnForm = reactive({ reason: '质量问题', qty: 1, note: '' })

function openReturn() {
  returnForm.lineId = order.value.items[0]?.id
  returnForm.reason = '质量问题'
  returnForm.qty = 1
  returnForm.note = ''
  returnOpen.value = true
}

async function confirmReturn() {
  const line = order.value.items.find((item) => item.id === returnForm.lineId)
  if (!line || returnForm.qty <= 0) return toast('请选择商品并填写退货数量', 'error')
  try {
    await orderApi.createReturn({
      orderId: order.value.id, reason: returnForm.reason, note: returnForm.note,
      items: [{ productId: line.productId, unit: line.unit, qty: returnForm.qty }]
    })
    returnOpen.value = false
    await reload()
  } catch (e) { toast(e.message, 'error') }
}
</script>

<style scoped>
.crumbs {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 14px;
  font-size: 13px;
  color: var(--muted);
}
.crumbs .back {
  display: inline-flex;
  align-items: center;
  gap: 3px;
}
.crumbs .cur {
  color: var(--ink);
  font-weight: 550;
  font-variant-numeric: tabular-nums;
}
.crumbs .sep {
  color: var(--faint);
}
.local-hint {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  margin-left: 6px;
  padding: 1px 7px;
  border-radius: 5px;
  background: #fdf6e8;
  color: #8a5a00;
  font-size: 11px;
}

.empty-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 56px 0;
  color: var(--muted);
}

/* 头部 */
.head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 24px;
  padding: 18px 22px;
  margin-bottom: 14px;
}
.name-row {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}
.name-row h2 {
  margin: 0;
  font-size: 19px;
  font-weight: 650;
  letter-spacing: -0.2px;
  font-variant-numeric: tabular-nums;
}
.sub {
  margin-top: 7px;
  font-size: 12.5px;
  color: var(--muted);
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.sub .dot {
  color: var(--faint);
}
.head-amount {
  text-align: right;
  flex-shrink: 0;
}
.head-amount span {
  display: block;
  font-size: 12px;
  color: var(--muted);
}
.head-amount b {
  display: block;
  margin-top: 2px;
  font-size: 24px;
  font-weight: 680;
  letter-spacing: -0.5px;
  font-variant-numeric: tabular-nums;
}
.head-amount em {
  font-style: normal;
  font-size: 11.5px;
  color: var(--faint);
}

/* 链路 */
.chain {
  display: flex;
  align-items: flex-start;
  padding: 16px 22px 14px;
  margin-bottom: 14px;
  overflow-x: auto;
}
.node {
  position: relative;
  display: flex;
  gap: 9px;
  flex: 1;
  min-width: 132px;
}
/* 连线画在节点层：从圆点右侧拉到下一个节点，节点均分宽度所以能接上 */
.node::after {
  content: '';
  position: absolute;
  top: 7px;
  left: 16px;
  right: 0;
  height: 1.5px;
  background: #e6eaf1;
}
.node:last-child::after {
  display: none;
}
.node.done::after {
  background: rgba(43, 108, 176, 0.4);
}
.node-dot {
  position: relative;
  z-index: 1;
  width: 16px;
  height: 16px;
  border-radius: 50%;
  border: 1.5px solid #d8dee8;
  background: #fff;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  flex-shrink: 0;
  margin-top: 0.5px;
}
.node.done .node-dot {
  background: var(--brand);
  border-color: var(--brand);
}
.node.now .node-dot {
  border-color: var(--brand);
  box-shadow: 0 0 0 3px rgba(43, 108, 176, 0.14);
}
.node.skip .node-dot {
  border-style: dashed;
}
.node-body {
  padding-right: 12px;
}
.node-label {
  font-size: 12.5px;
  font-weight: 550;
  color: var(--ink);
}
.node-note {
  font-size: 11.5px;
  color: var(--faint);
  margin-top: 2px;
  white-space: nowrap;
}
/* 「去对账」：把链路末端的死点接上，点一下带着客户和账期跳到对账单页 */
.node-act {
  display: inline-flex;
  align-items: center;
  gap: 1px;
  margin-top: 5px;
  padding: 0;
  border: 0;
  background: none;
  font: inherit;
  font-size: 11.5px;
  font-weight: 550;
  color: var(--brand);
  cursor: pointer;
}
.node-act:hover {
  text-decoration: underline;
}

.two-col {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 320px;
  gap: 14px;
  align-items: start;
}
.col-main,
.col-side {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.card-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 18px 12px;
}
.card-title {
  font-size: 13.5px;
  font-weight: 600;
  color: var(--ink);
}
.card-sub {
  margin-top: 2px;
  font-size: 11.5px;
  color: var(--faint);
}
.table-foot {
  display: flex;
  justify-content: flex-end;
  align-items: baseline;
  gap: 14px;
  padding: 10px 18px;
  border-top: 1px solid var(--line);
  font-size: 12.5px;
  color: var(--muted);
}
.table-foot b {
  font-size: 15px;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
}

.money-list,
.info-list {
  padding: 0 18px 14px;
}
.ml,
.il {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  padding: 6px 0;
  font-size: 12.5px;
}
.ml span,
.il span {
  color: var(--muted);
  flex-shrink: 0;
}
.ml b,
.il b {
  font-weight: 550;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
  text-align: right;
}
.ml.strong {
  border-top: 1px dashed var(--line);
  margin-top: 4px;
  padding-top: 9px;
}
.ml.strong b {
  font-size: 15px;
  font-weight: 650;
}
.remark {
  font-weight: 400 !important;
  font-size: 12px;
  color: var(--muted) !important;
  line-height: 1.5;
}
.text-danger {
  color: var(--danger) !important;
}

.todo-list {
  padding: 0 16px 14px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.todo {
  display: flex;
  gap: 8px;
  padding: 9px 11px;
  border-radius: 8px;
  background: #fafbfc;
  border-left: 2px solid var(--brand);
}
.todo.danger {
  background: #fdf0f0;
  border-left-color: var(--danger);
}
.todo.warning {
  background: #fdf7ea;
  border-left-color: var(--warning);
}
.td-title {
  font-size: 12.5px;
  font-weight: 550;
  color: var(--ink);
}
.td-desc {
  font-size: 11.5px;
  color: var(--muted);
  margin-top: 2px;
  line-height: 1.5;
}

.hint {
  margin-top: 4px;
  font-size: 11.5px;
  color: var(--faint);
}

/* 详情页里的空状态要短，不然两张空表会把页面撑出一大截空白 */
.empty-slim {
  padding: 22px 18px 26px;
  text-align: center;
  font-size: 12.5px;
  color: var(--faint);
}

@media (max-width: 1180px) {
  .two-col {
    grid-template-columns: 1fr;
  }
}
</style>


