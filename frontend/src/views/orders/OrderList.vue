<template>
  <div class="page">
    <PageHead title="订单" desc="合同订单与备货订单统一的要货单据，下单即锁库存、按协议价取价，发货与退货实时回写应收">
      <SourceTag v-if="sourceState.orders !== 'empty'" :mode="sourceState.orders" />
      <button class="btn" type="button" @click="exportOrders">
        <AppIcon name="download" :size="14" />导出
      </button>
      <button v-can="'order.create'" class="btn btn-primary" type="button" @click="openCreate">
        <AppIcon name="plus" :size="14" />新建订单
      </button>
    </PageHead>

    <div class="summary">
      <div class="kpi card">
        <span>本月订单额</span>
        <b>¥{{ wan(sum.monthAmount) }}<i>万</i></b>
        <em>{{ sum.monthCount }} 单</em>
      </div>
      <div class="kpi card">
        <span>待发货</span>
        <b>{{ sum.toShipCount }}<i>单</i></b>
        <em>¥{{ wan(sum.toShipAmount) }} 万</em>
      </div>
      <div class="kpi card">
        <span>待审批</span>
        <b class="warn">{{ sum.pendingApproval }}<i>单</i></b>
        <em>含超信用额度</em>
      </div>
      <div class="kpi card">
        <span>未收金额</span>
        <b class="danger">{{ unreceived == null ? '—' : '¥' + yuan(unreceived) }}</b>
        <em>已开票未核销</em>
      </div>
    </div>

    <div class="card">
      <div class="tabs">
        <button
          v-for="t in tabs"
          :key="t.value"
          class="tab"
          :class="{ active: status === t.value }"
          type="button"
          @click="status = t.value"
        >
          {{ t.label }}<span class="tab-count">{{ t.count }}</span>
        </button>
      </div>

      <div class="toolbar">
        <div class="search">
          <AppIcon name="search" :size="15" />
          <input v-model="keyword" class="input" type="text" placeholder="搜索订单号 / 客户 / 合同号" />
        </div>
        <select v-model="type" class="select">
          <option value="">全部类型</option>
          <option>合同订单</option>
          <option>备货订单</option>
        </select>
        <select v-model="owner" class="select">
          <option value="">全部业务员</option>
          <option v-for="o in owners" :key="o">{{ o }}</option>
        </select>
      </div>

      <AppTable
        :columns="columns"
        :rows="filtered"
        :page-size="8"
        empty-text="还没有订单 —— 点右上「新建订单」录第一单，或先把历史订单导进来"
      >
        <template #cell-id="{ row }">
          <div class="cell-main link" @click="openDetail(row)">{{ row.code }}</div>
          <div class="cell-sub">
            {{ row.type }}<template v-if="contractLabel(row.contractId)"> · {{ contractLabel(row.contractId) }}</template>
          </div>
        </template>
        <template #cell-customer="{ row }">
          <div class="cell-main ellip">{{ row.customer }}</div>
          <div class="cell-sub">{{ row.remark }}</div>
        </template>
        <template #cell-amount="{ row }">
          <span class="num">¥{{ yuan(amountOf(row)) }}</span>
          <div class="cell-sub">{{ boxesOf(row) }} 箱</div>
        </template>
        <template #cell-progress="{ row }">
          <div class="paid">
            <div class="bar"><i :style="{ width: shipRate(row) + '%', background: shipColor(row) }" /></div>
            <span>{{ shipRate(row) }}%</span>
          </div>
        </template>
        <template #cell-status="{ row }">
          <span class="tag" :class="tone[row.status]">{{ row.status }}</span>
        </template>
        <template #cell-ops="{ row }">
          <div class="row-tight ops">
            <button class="btn-text" type="button" @click="openDetail(row)">详情</button>
            <button
              v-if="row.status === '待审批'"
              v-can="'order.approve'"
              class="btn-text"
              type="button"
              @click="approve(row)"
            >
              审批
            </button>
          </div>
        </template>
      </AppTable>
    </div>

    <!-- 新建订单 -->
    <ModalDialog
      v-model="createOpen"
      width="wide"
      title="新建订单"
      desc="选客户后自动带出协议价；低于成本价或超出信用额度会转为待审批"
      ok-text="提交订单"
      @confirm="submitOrder"
    >
      <div class="form-grid">
        <div class="field">
          <label class="label">客户<span class="req">*</span></label>
          <select v-model="form.customer" class="select" @change="onCustomerChange">
            <option value="">请选择客户</option>
            <option v-for="c in customerNames" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
        </div>
        <div class="field">
          <label class="label">订单类型</label>
          <select v-model="form.type" class="select" @change="onTypeChange">
            <option :disabled="!canContract" value="合同订单">
              合同订单{{ canContract ? '' : '（需合同查看权限）' }}
            </option>
            <option value="备货订单">备货订单</option>
          </select>
          <em v-if="!canContract" class="field-note">无合同查看权限，只能下备货订单</em>
        </div>
        <div v-if="form.type === '合同订单'" class="field">
          <label class="label">关联合同<span class="req">*</span></label>
          <select v-model="form.contractId" class="select" @change="form.items.forEach(recalc)">
            <option value="">请选择合同</option>
            <option v-for="c in myContracts" :key="c.id" :value="c.id">
              {{ c.code || c.id }} · {{ c.name }}
            </option>
          </select>
        </div>
        <div v-else class="field">
          <label class="label">说明</label>
          <input v-model="form.remark" class="input" type="text" placeholder="如：客户临时补货" />
        </div>
        <div class="field">
          <label class="label">期望到货</label>
          <input v-model="form.expect" class="input" type="date" />
        </div>
      </div>

      <div class="lines">
        <div class="lines-head">
          <span>商品明细</span>
          <button class="btn-text" type="button" @click="addLine"><AppIcon name="plus" :size="13" />添加商品</button>
        </div>
        <table class="line-table">
          <thead>
            <tr>
              <th>产品</th>
              <th class="w-unit">单位</th>
              <th class="w-qty">数量</th>
              <th class="w-price">单价</th>
              <th class="w-src">取价</th>
              <th class="w-amt">金额</th>
              <th class="w-del"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(ln, i) in form.items" :key="i">
              <td>
                <select v-model="ln.productId" class="select" @change="onProductChange(ln)">
                  <option value="">选择产品</option>
                  <option v-for="p in sellable" :key="p.id" :value="p.id">{{ p.name }}</option>
                </select>
                <div v-if="stockOf(ln.productId)" class="stock-hint" :class="stockOf(ln.productId).tone">
                  {{ stockOf(ln.productId).text }}
                </div>
              </td>
              <td>
                <select v-model="ln.unit" class="select" @change="recalc(ln)">
                  <option v-for="u in unitsOf(ln.productId)" :key="u" :value="u">{{ u }}</option>
                </select>
              </td>
              <td><input v-model.number="ln.qty" class="input" type="number" min="1" @input="recalc(ln)" /></td>
              <td><input v-model.number="ln.price" class="input" type="number" min="0" step="0.01" /></td>
              <td>
                <span class="tag" :class="/协议|合同/.test(ln.source || '') ? 'tag-brand' : 'tag-gray'">{{ ln.source || '—' }}</span>
              </td>
              <td class="num">¥{{ yuan(lineTotal(ln)) }}</td>
              <td>
                <button class="btn-text danger" type="button" @click="form.items.splice(i, 1)">删</button>
              </td>
            </tr>
            <tr v-if="!form.items.length">
              <td colspan="7" class="empty-line">还没有商品，点右上「添加商品」</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="totals">
        <div class="tt">
          <span>合计</span>
          <b>¥{{ yuan(formTotal) }}</b>
        </div>
        <div v-if="canCost" class="tt">
          <span>预估毛利率</span>
          <b>{{ formMargin }}%</b>
        </div>
        <div class="tt" :class="{ bad: creditLeft < 0 }">
          <span>{{ credit && credit.limit === 0 ? '客户信用额度' : '客户可用额度' }}</span>
          <b v-if="credit == null">—</b>
          <b v-else-if="credit.limit === 0">未授信</b>
          <b v-else>¥{{ creditLeft.toLocaleString() }}</b>
        </div>
      </div>

      <div v-if="warnings.length" class="warn-box">
        <div v-for="(w, i) in warnings" :key="i" class="warn-row">
          <AppIcon name="flag" :size="12" />{{ w }}
        </div>
      </div>
    </ModalDialog>
  </div>
</template>

<script setup>
import { requestId as newRequestId } from '@/utils/requestId'
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import { toast } from '@/composables/useToast'
import { can } from '@/store/permissions'
import { unitPrice } from '@/data/productCatalog'
import { orderApi } from '@/api/orders'
import { customerApi } from '@/api/customers'
import { productApi } from '@/api/products'
import { ORDER_STATUS_TONE, resolvePrice } from '@/data/orderCenter'
import SourceTag from '@/components/SourceTag.vue'
import { sourceState, markOrders } from '@/api/orderSource'

const router = useRouter()
const route = useRoute()

/* 已经在订单页时，从顶栏搜索再跳一次也要重新筛（组件不会重挂） */
watch(
  () => route.query.keyword,
  (v) => applyQueryKeyword(v)
)
const rows = ref([])
const customers = ref([])
const products = ref([])
const contracts = ref([])
async function loadOrders() {
  rows.value = (await orderApi.list({ pageSize: 500 })).rows
  markOrders(rows.value.length)
}
/* 未收 = 已开票金额 - 已核销；没有 invoice.view 权限就保持「—」，别拿 0 糊弄人 */
const unreceived = ref(null)
async function loadUnreceived() {
  if (!can('invoice.view')) return
  try {
    const list = (await orderApi.invoices({ pageSize: 500 })).rows
    const open = list.filter((r) => r.status === '已开票')
      .reduce((s, r) => s + Number(r.amount) - Number(r.settledAmount || 0), 0)
    unreceived.value = Math.round(open * 100) / 100
  } catch { unreceived.value = null }
}
onMounted(() => {
  loadOrders().catch((e) => toast(e.message, 'error'))
  loadUnreceived()
  /* 合同号映射：列表要显示合同单号而不是主键，没有 contract.view 就跳过 */
  if (can('contract.view')) {
    orderApi.contracts({ pageSize: 500 })
      .then(({ rows: list }) => { contracts.value = list || [] })
      .catch(() => { contracts.value = [] })
  }
})
const keyword = ref('')
const status = ref('')
const type = ref('')
const owner = ref('')

/* 从全局搜索 / 库存页跳过来时只留这一条，别的筛选清掉，免得命中的单被 tab 藏起来 */
function applyQueryKeyword(v) {
  keyword.value = v ? String(v) : ''
  if (!v) return
  status.value = ''
  type.value = ''
  owner.value = ''
}
applyQueryKeyword(route.query.keyword)

const owners = computed(() => [...new Set(rows.value.map((r) => r.owner))])
const customerNames = customers
const sellable = computed(() => products.value.filter((p) => p.status === '在售'))
const canCost = computed(() => can('product.cost'))
const tone = ORDER_STATUS_TONE

/* 副标题里的合同号：接口只给 contract_id（数字主键），直接显示就成了「合同订单 · 13」。
   合同列表已加载就换成单号，没加载到就只显示类型，不要把主键当单号露出来 */
function contractLabel(id) {
  if (!id) return ''
  const hit = contracts.value.find((c) => String(c.id) === String(id))
  return hit ? (hit.code || '') : ''
}

const sum = computed(() => {
  const month = new Date().toISOString().slice(0, 7)
  const recent = rows.value.filter((r) => r.date?.startsWith(month) && r.status !== '已取消')
  const waiting = rows.value.filter((r) => ['待发货', '部分发货'].includes(r.status))
  const total = (list) => list.reduce((sum, row) => sum + Number(row.amount), 0)
  return { monthAmount: total(recent), monthCount: recent.length, toShipCount: waiting.length,
    toShipAmount: total(waiting), pendingApproval: rows.value.filter((r) => r.status === '待审批').length }
})

const tabs = computed(() => {
  const c = (s) => rows.value.filter((r) => (s === '' ? true : r.status === s)).length
  return [
    { label: '全部', value: '', count: rows.value.length },
    { label: '待审批', value: '待审批', count: c('待审批') },
    { label: '待发货', value: '待发货', count: c('待发货') },
    { label: '部分发货', value: '部分发货', count: c('部分发货') },
    { label: '已签收', value: '已签收', count: c('已签收') },
    { label: '退货', value: '已退货', count: c('已退货') }
  ]
})

const columns = [
  { key: 'id', label: '订单号', width: '172px' },
  { key: 'customer', label: '客户' },
  { key: 'amount', label: '订单金额', width: '126px', align: 'right' },
  { key: 'progress', label: '发货进度', width: '136px' },
  { key: 'date', label: '下单日期', width: '104px' },
  { key: 'owner', label: '业务员', width: '96px' },
  { key: 'status', label: '状态', width: '94px' },
  { key: 'ops', label: '操作', align: 'right', width: '88px' }
]

const filtered = computed(() =>
  rows.value.filter((r) => {
    if (status.value && r.status !== status.value) return false
    if (type.value && r.type !== type.value) return false
    if (owner.value && r.owner !== owner.value) return false
    if (keyword.value) {
      const k = keyword.value.trim()
      if (![r.id, r.customer, r.contractId].join(' ').includes(k)) return false
    }
    return true
  })
)

const yuan = (v) => Number(v).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const amountOf = (r) => Number(r.amount)
const boxesOf = (r) => Number(r.quantity || 0)
const shipRate = (r) => {
  const total = boxesOf(r)
  if (!total) return 0
  return Math.min(100, Math.round((Number(r.shipped || 0) / total) * 100))
}
const shipColor = (r) => {
  const p = shipRate(r)
  if (p >= 100) return '#12805c'
  if (p > 0) return '#2b6cb0'
  return '#cfd6e0'
}
const wan = (n) => (n / 10000).toFixed(1)

function openDetail(row) {
  router.push(`/orders/${row.id}`)
}

async function approve(row) {
  try {
    await orderApi.approve(row.id, { result: 'pass' })
    await loadOrders()
  } catch (e) { toast(e.message, 'error') }
}

/* ---------------- 新建订单 ---------------- */

const createOpen = ref(false)
let requestId
const saving = ref(false)
const form = reactive({
  customer: '', type: '合同订单', contractId: '', expect: '', remark: '',
  items: []
})

const myContracts = computed(() =>
  contracts.value.filter((c) => String(c.customer_id) === String(form.customer) && c.status === '执行中')
)

/* 客户名下没有执行中合同时，停在「合同订单」是条死路：合同下拉为空，
   提交一定被「请选择关联合同」拦住。这种时候直接切备货订单，省一次无效操作 */
watch(myContracts, (list) => {
  if (form.type !== '合同订单' || !form.customer || list.length) return
  form.type = '备货订单'
  form.contractId = ''
  for (const ln of form.items) recalc(ln)
})

const formTotal = computed(() =>
  Math.round(form.items.reduce((s, ln) => s + lineTotal(ln), 0) * 100) / 100
)

/* 成本优先用后端取价返回的 floor（含换算倍数），没有才回退本地目录，
   否则后端产品结构对不上时毛利会算成 100% */
const formMargin = computed(() => {
  let sales = 0
  let cost = 0
  for (const ln of form.items) {
    const amount = lineTotal(ln)
    if (!ln.productId || !amount) continue
    sales += amount
    const unitCost = ln.floor != null
      ? ln.floor
      : (() => {
          const p = products.value.find((x) => String(x.id) === String(ln.productId))
          return p ? unitPrice(p, ln.unit, 'cost') : 0
        })()
    cost += unitCost * (ln.qty || 0)
  }
  if (!sales) return 0
  return (((sales - cost) / sales) * 100).toFixed(1)
})

const credit = ref(null)
const creditLeft = computed(() => credit.value == null ? 0 : credit.value.available - formTotal.value)
const warnings = computed(() => {
  if (!credit.value) return []
  if (credit.value.limit === 0) return ['该客户尚未核定信用额度，提交后需审批']
  if (creditLeft.value < 0) return ['超出可用信用额度，提交后需审批']
  return []
})
watch(() => form.customer, async (customerId, _, onCleanup) => {
  let current = true
  onCleanup(() => { current = false })
  credit.value = null
  if (!customerId) return
  try {
    const value = await orderApi.credit({ customerId })
    if (current) credit.value = value
  } catch (e) { if (current) toast(e.message, 'error') }
})

/* 能不能下合同订单，取决于有没有合同查看权：合同列表接口要 contract.view，
   而销售顾问只有 order.create。以前这里三个请求一起 await，合同那个 403 会把
   整个弹窗拦掉，表现成「有新建订单权限却打不开」。 */
const canContract = computed(() => can('contract.view'))

async function exportOrders() {
  try {
    const file = await orderApi.exportOrders()
    const link = document.createElement('a')
    link.href = URL.createObjectURL(file)
    link.download = '订单列表.xlsx'
    link.click()
    URL.revokeObjectURL(link.href)
  } catch (e) { toast(e.message, 'error') }
}

async function openCreate() {
  try {
    const [people, catalog] = await Promise.all([
      customerApi.list(), productApi.list({ pageSize: 500 })
    ])
    customers.value = people
    products.value = catalog.rows
  } catch (e) { return toast(e.message, 'error') }

  /* 合同列表单独拉：没权限就留空，不影响下单（备货订单本来就不需要合同） */
  contracts.value = []
  if (canContract.value) {
    try { contracts.value = (await orderApi.contracts({ pageSize: 500 })).rows }
    catch { contracts.value = [] }
  }

  requestId = newRequestId()

  form.customer = ''
  form.type = canContract.value ? '合同订单' : '备货订单'
  form.contractId = ''
  form.expect = ''
  form.remark = ''
  form.items = []
  addLine()
  createOpen.value = true
}

function addLine() {
  form.items.push({ productId: '', unit: '箱', qty: 1, price: 0, source: '' })
}

function unitsOf(pid) {
  const p = products.value.find((x) => x.id === pid)
  return p ? p.units.map((u) => u.name) : ['箱']
}

/**
 * 明细行下方的库存提示。
 * 后端下单不校验库存（只在发货时扣），所以这里必须让销售看见状态，
 * 否则签了单仓库才发现没货，客户等三天。
 */
const STOCK_HINT = {
  充足: { tone: 'ok', text: '库存充足' },
  少量: { tone: 'low', text: '库存少量，发货前找仓库确认可发量' },
  需排产: { tone: 'mto', text: '需排产，不能按现货承诺交期' }
}

function stockOf(pid) {
  if (!pid) return null
  const p = products.value.find((x) => x.id === pid)
  if (!p || !p.stock) return null
  const base = STOCK_HINT[p.stock] || { tone: 'ok', text: `库存${p.stock}` }
  const cycle = p.stock === '需排产' && p.productionDays ? `（生产 ${p.productionDays} 天）` : ''
  return { ...base, text: base.text + cycle }
}

function onProductChange(ln) {
  const p = products.value.find((x) => x.id === ln.productId)
  if (!p) return
  ln.unit = p.saleUnit
  recalc(ln)
}

function onCustomerChange() {
  form.contractId = ''
  for (const ln of form.items) recalc(ln)
}

function onTypeChange() {
  if (form.type === '备货订单') form.contractId = ''
}

/* 取价：优先问后端（标准/经销/阶梯/客户协议价取最低，合同订单锁协议价），
   后端不通或还没接上时才退回本地演示目录估算。
   以前这里直接调 resolvePrice 却忘了 import，选完产品单价恒为 0、金额 ¥0.00。 */
async function recalc(ln) {
  if (!ln.productId) return
  const qty = ln.qty || 1
  if (sourceState.orders !== 'demo' && form.customer) {
    try {
      const [q] = await orderApi.quote({
        customerId: Number(form.customer), contractId: form.contractId || null, type: form.type,
        items: [{ productId: ln.productId, unit: ln.unit, qty }]
      })
      if (q && q.price != null) {
        ln.price = Number(q.price)
        ln.source = q.priceSource || ''
        ln.floor = q.floor != null ? Number(q.floor) : null
        return
      }
    } catch { /* 取价失败退回本地估算，别把弹窗卡死 */ }
  }
  const r = resolvePrice(ln.productId, form.customer, ln.unit, qty)
  ln.price = r.price
  ln.source = r.source
  ln.floor = null
}

function lineTotal(ln) {
  return Math.round((ln.price || 0) * (ln.qty || 0) * 100) / 100
}

async function submitOrder() {
  if (saving.value) return
  if (!form.customer || !form.items.length || form.items.some((line) => !line.productId || line.qty < 1)) {
    return toast('请选择客户并填写商品明细', 'error')
  }
  if (form.type === '合同订单' && !form.contractId) return toast('请选择关联合同', 'error')
  saving.value = true
  try {
    const result = await orderApi.create({
      customerId: form.customer, contractId: form.contractId || null, type: form.type,
      expectDate: form.expect || null, remark: form.remark, requestId,
      items: form.items.map(({ productId, unit, qty, price }) => ({ productId, unit, qty, price }))
    })
    createOpen.value = false
    /* 后端把「低于底价 / 超信用额度」做成 201 + warnings，不阻断下单只提示要走审批 */
    if (Array.isArray(result.warnings) && result.warnings.length) {
      /* 已经建单成功，只是需要审批 —— 用 info，别用红叉让人以为失败了 */
      toast(`${result.code} 已提交，${result.status}：${result.warnings.map((w) => w.message || w).join("；")}`, 'info')
    } else {
      toast(result.code + ' · ' + result.status)
    }
    await loadOrders()
  } catch (e) { toast(e.message, 'error') }
  finally { saving.value = false }
}
</script>

<style scoped>
.field-note {
  font-size: 12px;
  line-height: 1.5;
  color: var(--muted);
  font-style: normal;
}
.summary {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 16px;
  margin-bottom: 16px;
}
.kpi {
  padding: 14px 18px;
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.kpi span {
  font-size: 12.5px;
  color: var(--muted);
}
.kpi b {
  font-size: 20px;
  font-weight: 650;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.2px;
}
.kpi b.warn {
  color: var(--warning);
}
.kpi b.danger {
  color: var(--danger);
}
.kpi i {
  font-style: normal;
  font-size: 12px;
  font-weight: 500;
  color: var(--faint);
  margin-left: 2px;
}
.kpi em {
  font-style: normal;
  font-size: 11.5px;
  color: var(--faint);
}

.tab-count {
  display: inline-block;
  margin-left: 5px;
  padding: 0 5px;
  height: 17px;
  line-height: 17px;
  border-radius: 4px;
  background: #f2f4f7;
  color: var(--muted);
  font-size: 11px;
  font-variant-numeric: tabular-nums;
}
.tab.active .tab-count {
  background: var(--brand-soft);
  color: var(--brand);
}

.link {
  color: var(--brand);
  cursor: pointer;
}
.link:hover {
  text-decoration: underline;
}
.ellip {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.paid {
  display: flex;
  align-items: center;
  gap: 8px;
}
.paid .bar {
  flex: 1;
  min-width: 56px;
  height: 5px;
}
.paid span {
  font-size: 11.5px;
  color: var(--muted);
  font-variant-numeric: tabular-nums;
  width: 32px;
}
.ops {
  justify-content: flex-end;
}

/* -------- 新建订单弹窗 -------- */
.lines {
  margin-top: 14px;
  border: 1px solid var(--line);
  border-radius: 10px;
  overflow: hidden;
}
.lines-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 9px 12px;
  background: #fafbfc;
  border-bottom: 1px solid var(--line);
  font-size: 12.5px;
  font-weight: 550;
  color: var(--ink-2);
}
.line-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 12.5px;
}
.line-table th {
  text-align: left;
  font-weight: 500;
  color: var(--muted);
  background: #fcfcfd;
  padding: 7px 8px;
  border-bottom: 1px solid var(--line);
  white-space: nowrap;
}
.line-table td {
  padding: 6px 8px;
  border-bottom: 1px solid #f2f4f7;
  vertical-align: middle;
}
.line-table tbody tr:last-child td {
  border-bottom: none;
}
.line-table .select,
.line-table .input {
  height: 30px;
  font-size: 12.5px;
}
.w-unit {
  width: 74px;
}
.w-qty,
.w-price {
  width: 92px;
}
.w-src {
  width: 92px;
}
.w-amt {
  width: 104px;
  text-align: right;
}
.w-del {
  width: 44px;
}
.line-table .num {
  text-align: right;
}
.empty-line {
  text-align: center;
  color: var(--faint);
  padding: 16px 0;
}

/* 明细行的库存提示：下单不校验库存，只能靠这行让人别乱承诺交期 */
.stock-hint {
  margin-top: 4px;
  font-size: 10.5px;
  line-height: 1.35;
  padding-left: 1px;
}
.stock-hint.ok {
  color: var(--success);
}
.stock-hint.low {
  color: var(--warning);
}
.stock-hint.mto {
  color: var(--danger);
}

.totals {
  display: flex;
  align-items: center;
  gap: 28px;
  margin-top: 14px;
  padding: 10px 14px;
  background: #fafbfc;
  border-radius: 10px;
}
.tt {
  display: flex;
  align-items: baseline;
  gap: 8px;
}
.tt span {
  font-size: 12px;
  color: var(--muted);
}
.tt b {
  font-size: 16px;
  font-weight: 650;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
}
.tt.bad b {
  color: var(--danger);
}

.warn-box {
  margin-top: 10px;
  padding: 9px 12px;
  border-radius: 8px;
  background: #fdf6e8;
  border: 1px solid #f3e0b5;
}
.warn-row {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  color: #8a5a00;
  line-height: 1.7;
}

@media (max-width: 1180px) {
  .summary {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
</style>


