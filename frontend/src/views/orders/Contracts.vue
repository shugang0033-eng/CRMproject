<template>
  <div class="page">
    <PageHead
      title="合同"
      desc="年度与季度供货框架，约定总额、账期与协议折扣；合同下的每次要货走订单，发货额按订单累计"
    >
      <SourceTag :mode="sourceState.contracts" hint="合同列表接口未返回数据，当前展示演示合同" />
      <button class="btn" type="button" @click="exportList">
        <AppIcon name="download" :size="14" />导出
      </button>
      <button v-can="'contract.create'" class="btn btn-primary" type="button" @click="openCreate">
        <AppIcon name="plus" :size="14" />新建合同
      </button>
    </PageHead>

    <div class="summary">
      <div class="kpi card">
        <span>合同总额</span>
        <b>¥{{ wan(totalAmount) }}<i>万</i></b>
        <em>{{ filtered.length }} 份</em>
      </div>
      <div class="kpi card">
        <span>已下单</span>
        <b>¥{{ wan(totalOrdered) }}<i>万</i></b>
        <em>占合同额 {{ orderedRate }}%</em>
      </div>
      <div class="kpi card">
        <span>待审批</span>
        <b class="warn">{{ countOf('待审批') }}<i>份</i></b>
        <em>审批通过才生效</em>
      </div>
      <div class="kpi card">
        <span>执行中</span>
        <b>{{ countOf('执行中') }}<i>份</i></b>
        <em>已完成 {{ countOf('已完成') }} 份</em>
      </div>
    </div>

    <div class="card">
      <div class="toolbar">
        <div class="search">
          <AppIcon name="search" :size="15" />
          <input v-model="keyword" class="input" type="text" placeholder="搜索合同名称 / 编号 / 客户" />
        </div>
        <select v-model="status" class="select">
          <option value="">全部状态</option>
          <option v-for="s in statuses" :key="s">{{ s }}</option>
        </select>
        <select v-model="type" class="select">
          <option value="">全部类型</option>
          <option v-for="t in contractTypes" :key="t">{{ t }}</option>
        </select>
        <select v-model="owner" class="select">
          <option value="">全部负责人</option>
          <option v-for="o in owners" :key="o">{{ o }}</option>
        </select>
      </div>

      <AppTable :columns="columns" :rows="filtered" :page-size="8" empty-text="还没有合同 —— 点右上「新建合同」录第一份框架协议">
        <template #cell-name="{ row }">
          <div class="cell-main">{{ row.name }}</div>
          <div class="cell-sub">{{ row.id }} · {{ row.type }} · {{ row.term || row.paymentTerm }}</div>
        </template>
        <template #cell-amount="{ row }">
          <span class="num">¥{{ row.amount.toLocaleString() }}</span>
          <div class="cell-sub">{{ discountText(row.discount) }}</div>
        </template>
        <template #cell-ordered="{ row }">
          <div class="paid">
            <div class="bar"><i :style="{ width: orderedRateOf(row) + '%', background: barColor(orderedRateOf(row)) }" /></div>
            <span>{{ orderedRateOf(row) }}%</span>
          </div>
          <div class="cell-sub">¥{{ orderedOf(row).toLocaleString() }}</div>
        </template>
        <template #cell-status="{ row }">
          <span class="tag" :class="tone[row.status]">{{ row.status }}</span>
        </template>
        <template #cell-owner="{ row }">
          <span class="row-tight">
            <UserAvatar :name="row.owner" size="sm" />
            <span>{{ row.owner }}</span>
          </span>
        </template>
        <template #cell-ops="{ row }">
          <div class="row-tight ops">
            <button class="btn-text" type="button" @click="openDetail(row)">详情</button>
            <template v-if="row.status === '待审批'">
              <button v-if="canAudit('contract.approve', row)" class="btn-text" type="button" @click="openApprove(row)">
                审批
              </button>
              <span v-else-if="isMine(row) && can('contract.approve')" class="own-note">本人提交</span>
            </template>
          </div>
        </template>
      </AppTable>
    </div>

    <!-- ---------------- 新建合同 ---------------- -->
    <ModalDialog
      v-model="createOpen"
      width="wide"
      title="新建合同"
      desc="先定框架再要货：合同额由明细汇总，协议单价按折扣自动折算，可逐行手改"
      ok-text="提交审批"
      :loading="saving"
      @confirm="submitCreate"
    >
      <div class="form-grid">
        <div class="field">
          <label class="label">客户<span class="req">*</span></label>
          <select v-model="form.customerId" class="select">
            <option value="">请选择客户</option>
            <option v-for="c in customers" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
        </div>
        <div class="field">
          <label class="label">合同类型</label>
          <select v-model="form.type" class="select" @change="syncPeriod">
            <option v-for="t in contractTypes" :key="t">{{ t }}</option>
          </select>
        </div>
        <div class="field span-2">
          <label class="label">合同名称<span class="req">*</span></label>
          <input
            v-model="form.name"
            class="input"
            type="text"
            maxlength="120"
            placeholder="如：驰远连锁 · 2027 年度耗材集采框架"
          />
        </div>
        <div class="field">
          <label class="label">账期</label>
          <select v-model="form.paymentTerm" class="select">
            <option v-for="t in termOptions" :key="t.label" :value="t.label">{{ t.label }}</option>
          </select>
          <em class="field-note">账期天数 {{ termDays }} 天，决定订单的应收到期日</em>
        </div>
        <div class="field">
          <label class="label">协议折扣</label>
          <div class="discount-row">
            <input
              v-model.number="form.discount"
              class="input"
              type="number"
              min="0.5"
              max="1"
              step="0.01"
            />
            <span class="discount-tag">{{ discountText(form.discount) }}</span>
          </div>
          <em class="field-note">0.88 = 88 折；1 = 无折扣，明细单价按标准价初算</em>
        </div>
        <div class="field">
          <label class="label">签订日期</label>
          <input v-model="form.signDate" class="input" type="date" @change="syncPeriod" />
        </div>
        <div class="field">
          <label class="label">有效期</label>
          <div class="period-row">
            <input v-model="form.startDate" class="input" type="date" />
            <span class="tilde">至</span>
            <input v-model="form.endDate" class="input" type="date" />
          </div>
          <em class="field-note">{{ periodHint }}</em>
        </div>
        <div class="field span-2">
          <label class="label">备注</label>
          <input v-model="form.remark" class="input" type="text" maxlength="500" placeholder="如：按季度考核发货额，未达量次年不再续签" />
        </div>
      </div>

      <div class="lines">
        <div class="lines-head">
          <span>协议覆盖商品</span>
          <button class="btn-text" type="button" @click="addLine">
            <AppIcon name="plus" :size="13" />添加商品
          </button>
        </div>
        <table class="line-table">
          <thead>
            <tr>
              <th>产品</th>
              <th class="w-unit">单位</th>
              <th class="w-qty">年度约定量</th>
              <th class="w-price">协议单价</th>
              <th class="w-amt">协议金额</th>
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
              </td>
              <td>
                <select v-model="ln.unit" class="select" @change="onUnitChange(ln)">
                  <option v-for="u in unitsOf(ln.productId)" :key="u" :value="u">{{ u }}</option>
                </select>
              </td>
              <td><input v-model.number="ln.qty" class="input" type="number" min="1" step="1" /></td>
              <td>
                <input
                  v-model.number="ln.price"
                  class="input"
                  type="number"
                  min="0"
                  step="0.01"
                  @input="ln.manual = true"
                />
                <div v-if="ln.productId" class="price-hint">
                  <span>标准价 ¥{{ listPrice(ln).toFixed(2) }}</span>
                  <button v-if="ln.manual" class="btn-text link-sm" type="button" @click="resetPrice(ln)">还原</button>
                </div>
              </td>
              <td class="num">¥{{ lineTotal(ln).toFixed(2) }}</td>
              <td>
                <button class="btn-text danger" type="button" @click="form.items.splice(i, 1)">删</button>
              </td>
            </tr>
            <tr v-if="!form.items.length">
              <td colspan="6" class="empty-line">还没有商品，点右上「添加商品」</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="totals">
        <div class="tt">
          <span>协议总额</span>
          <b>¥{{ formTotal.toLocaleString(undefined, { minimumFractionDigits: 2 }) }}</b>
        </div>
        <div class="tt">
          <span>标准价合计</span>
          <b class="muted">¥{{ formListTotal.toLocaleString(undefined, { minimumFractionDigits: 2 }) }}</b>
        </div>
        <div class="tt">
          <span>让利</span>
          <b class="warn">¥{{ (formListTotal - formTotal).toLocaleString(undefined, { minimumFractionDigits: 2 }) }}</b>
        </div>
        <div class="tt">
          <span>实际折扣</span>
          <b>{{ realDiscount ? (realDiscount * 10).toFixed(1) + ' 折' : '—' }}</b>
        </div>
      </div>

      <div v-if="submitAttempted && createIssues.length" class="warn-box">
        <div v-for="(w, i) in createIssues" :key="i" class="warn-row">
          <AppIcon name="flag" :size="12" />{{ w }}
        </div>
      </div>
    </ModalDialog>

    <!-- ---------------- 审批合同 ---------------- -->
    <ModalDialog
      v-model="approveOpen"
      title="审批合同"
      :desc="approveRow.name"
      :ok-text="decision === 'pass' ? '通过并生效' : '驳回退回草稿'"
      :loading="saving"
      @confirm="submitApprove"
    >
      <div v-if="approveRow.id" class="apx">
        <div class="apx-meta">
          <div class="dm"><span>客户</span><b>{{ approveRow.customer }}</b></div>
          <div class="dm"><span>合同类型</span><b>{{ approveRow.type }}</b></div>
          <div class="dm"><span>合同总额</span><b>¥{{ approveRow.amount?.toLocaleString() }}</b></div>
          <div class="dm"><span>协议折扣</span><b>{{ discountText(approveRow.discount) }}</b></div>
          <div class="dm"><span>账期</span><b>{{ approveRow.term || approveRow.paymentTerm }}</b></div>
          <div class="dm"><span>负责人</span><b>{{ approveRow.owner }}</b></div>
        </div>

        <div class="field">
          <label class="label">审批结果</label>
          <div class="decide">
            <button class="decide-btn" :class="{ on: decision === 'pass' }" type="button" @click="decision = 'pass'">
              通过
              <em>合同转为执行中，可挂订单取协议价</em>
            </button>
            <button class="decide-btn danger" :class="{ on: decision === 'reject' }" type="button" @click="decision = 'reject'">
              驳回
              <em>退回草稿，负责人改完再提交</em>
            </button>
          </div>
        </div>

        <div class="field">
          <label class="label">审批意见<span v-if="decision === 'reject'" class="req">*</span></label>
          <textarea
            v-model="note"
            class="textarea"
            :placeholder="decision === 'reject' ? '驳回必须写清原因，负责人要照着改' : '如：同意，按季度考核发货额'"
          />
        </div>

        <div class="api-note">
          <AppIcon name="flag" :size="12" />
          <span>后端审批接口（POST /contracts/{{ approveRow.dbId }}/approve）还没实现，现在提交不会改变合同状态。</span>
        </div>
      </div>
    </ModalDialog>

    <!-- ---------------- 合同详情 ---------------- -->
    <ModalDialog v-model="detailOpen" width="wide" :title="current.name || ''" :desc="current.id" hide-footer>
      <div v-if="current.id" class="detail">
        <div class="d-meta">
          <div class="dm"><span>客户</span><b>{{ current.customer }}</b></div>
          <div class="dm"><span>合同总额</span><b>¥{{ (current.amount || 0).toLocaleString() }}</b></div>
          <div class="dm"><span>账期</span><b>{{ current.term || current.paymentTerm || '—' }}</b></div>
          <div class="dm"><span>协议折扣</span><b>{{ discountText(current.discount) }}</b></div>
          <div class="dm"><span>负责人</span><b>{{ current.owner }}</b></div>
          <div class="dm"><span>签订日期</span><b>{{ current.signDate || '—' }}</b></div>
          <div v-if="current.start || current.end" class="dm">
            <span>有效期</span><b>{{ current.start || '—' }} 至 {{ current.end || '—' }}</b>
          </div>
          <div class="dm"><span>状态</span><b>{{ current.status }}</b></div>
        </div>

        <div v-if="detailState === 'missing'" class="api-note">
          <AppIcon name="flag" :size="12" />
          <span>
            合同详情接口（GET /contracts/{{ current.dbId }}）还没实现，商品的协议价、关联订单和审批痕迹暂时看不到。
            上面的摘要来自列表接口。
          </span>
        </div>

        <div v-if="detailReady" class="d-sec">
          <div class="d-title">协议覆盖的商品 <span class="cnt">{{ contractLines.length }} 项</span></div>
          <table class="mini">
            <thead>
              <tr>
                <th>产品</th>
                <th class="r">年度约定量</th>
                <th class="r">协议单价</th>
                <th class="r">协议金额</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(it, i) in contractLines" :key="i">
                <td>{{ it.name }}<div class="cell-sub">{{ it.spec }}</div></td>
                <td class="r">{{ it.qty.toLocaleString() }} {{ it.unit }}</td>
                <td class="r">¥{{ it.price.toFixed(2) }}</td>
                <td class="r">¥{{ it.amount.toLocaleString() }}</td>
              </tr>
              <tr v-if="!contractLines.length">
                <td colspan="4" class="empty-line">这份合同还没有商品明细</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div v-if="detailReady" class="d-sec">
          <div class="d-title">合同下的订单 <span class="cnt">{{ relatedOrders.length }} 单</span></div>
          <AppTable
            :columns="orderColumns"
            :rows="relatedOrders"
            :show-pager="false"
            compact
            empty-text="还没有以此合同下单"
          >
            <template #cell-amount="{ row }">
              <span class="num">¥{{ Number(row.amount).toLocaleString() }}</span>
            </template>
            <template #cell-status="{ row }">
              <span class="tag" :class="orderTone[row.status]">{{ row.status }}</span>
            </template>
          </AppTable>
        </div>

        <div class="d-sec" v-if="detailReady">
          <div class="d-title">审批痕迹</div>
          <div v-if="current.approvals && current.approvals.length" class="timeline">
            <div v-for="(a, i) in current.approvals" :key="i" class="tl">
              <span class="tl-dot done" />
              <div class="tl-body">
                <div class="tl-head">
                  <b>{{ a.by }}</b>
                  <span class="tag tag-gray plain">{{ a.action }}</span>
                  <span class="tl-time">{{ a.at }}</span>
                </div>
                <div class="tl-note">{{ a.note }}</div>
              </div>
            </div>
          </div>
          <div v-else class="empty-note">还没有审批记录</div>
        </div>
      </div>
    </ModalDialog>
  </div>
</template>

<script setup>
import { computed, reactive, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import UserAvatar from '@/components/UserAvatar.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import SourceTag from '@/components/SourceTag.vue'
import { toast } from '@/composables/useToast'
import { can, canAudit, isMine } from '@/store/permissions'
import { orderApi } from '@/api/orders'
import { customerApi } from '@/api/customers'
import { productApi } from '@/api/products'
import { loadContracts, attempt, sourceState } from '@/api/orderSource'
import { productItems, specSummary, unitPrice } from '@/data/productCatalog'
import { localDate } from '@/utils/date'
import {
  contracts as seed, orders, resolvePrice, orderAmount,
  CONTRACT_STATUS_TONE, ORDER_STATUS_TONE
} from '@/data/orderCenter'

/* ---------------- 列表 ---------------- */

const rows = ref(seed.map((r) => ({ ...r, approvals: [...(r.approvals || [])] })))

/* 后端 /contracts 有数据就切真数据；表还是空的就先看演示，页头有标记 */
loadContracts()
  .then((live) => {
    if (live && live.length) rows.value = live.map((r) => ({ ...r, approvals: [...(r.approvals || [])] }))
  })
  .catch((e) => toast(e.message, 'error'))

const keyword = ref('')
const status = ref('')
const type = ref('')
const owner = ref('')

/* 负责人要跟着数据走：以前在 loadContracts 回调之后同步算一次，
   那时 rows 还是演示数据，真实合同的负责人永远进不了筛选下拉 */
const owners = computed(() => [...new Set(rows.value.map((r) => r.owner).filter(Boolean))])

const statuses = ['草稿', '待审批', '执行中', '已完成', '已作废']
/* 和 crm_contracts.type 的 enum 对齐：年框 / 季度 / 单次（演示数据里写的「季框」是错的） */
const contractTypes = ['年框', '季度', '单次']
const tone = CONTRACT_STATUS_TONE
const orderTone = ORDER_STATUS_TONE

/* 0.88 → 8.8 折；1.0 是没有折扣，写成「10.0 折」容易让人以为打了狠折 */
function discountText(discount) {
  const n = Number(discount)
  if (!n || n >= 1) return '无折扣'
  return `${(n * 10).toFixed(1).replace(/\.0$/, '')} 折`
}

const columns = [
  { key: 'name', label: '合同名称' },
  { key: 'customer', label: '客户', width: '184px' },
  { key: 'amount', label: '合同金额', width: '128px', align: 'right' },
  { key: 'ordered', label: '已下单', width: '150px' },
  { key: 'owner', label: '负责人', width: '108px' },
  { key: 'status', label: '状态', width: '92px' },
  { key: 'ops', label: '操作', align: 'right', width: '108px' }
]

const route = useRoute()

/* 从全局搜索跳过来时只留这一条：其它筛选一并清掉，
   否则命中的那条会被某个 tab 藏起来，看着像「搜到了又没搜到」 */
function applyQueryKeyword(v) {
  keyword.value = v ? String(v) : ''
  if (!v) return
  status.value = ''
  type.value = ''
  owner.value = ''
}
applyQueryKeyword(route.query.keyword)
watch(() => route.query.keyword, applyQueryKeyword)

const filtered = computed(() =>
  rows.value.filter((r) => {
    if (status.value && r.status !== status.value) return false
    if (type.value && r.type !== type.value) return false
    if (owner.value && r.owner !== owner.value) return false
    if (keyword.value) {
      const k = keyword.value.trim()
      if (![r.name, r.code, r.id, r.customer].join(' ').includes(k)) return false
    }
    return true
  })
)

function orderedOf(c) {
  /* 后端合同列表直接带已下单额；演示数据才需要把订单加总 */
  if (c.orderedAmount != null) return c.orderedAmount
  return Math.round(
    orders.filter((o) => o.contractId === c.id && o.status !== '已取消').reduce((s, o) => s + orderAmount(o), 0)
  )
}
function orderedRateOf(c) {
  if (!c.amount) return 0
  return Math.min(100, Math.round((orderedOf(c) / c.amount) * 100))
}

const totalAmount = computed(() => filtered.value.reduce((s, r) => s + r.amount, 0))
const totalOrdered = computed(() => filtered.value.reduce((s, r) => s + orderedOf(r), 0))
const orderedRate = computed(() =>
  totalAmount.value ? Math.round((totalOrdered.value / totalAmount.value) * 100) : 0
)
const countOf = (s) => rows.value.filter((r) => r.status === s).length
const wan = (n) => (n / 10000).toFixed(1)

function barColor(p) {
  if (p >= 100) return '#12805c'
  if (p >= 50) return '#2b6cb0'
  if (p > 0) return '#c98a2e'
  return '#cfd6e0'
}

function exportList() {
  toast('合同导出接口还没做（GET /contracts/export），先把筛选条件定下来也能用', 'info')
}

/* ---------------- 新建合同 ---------------- */

const customers = ref([])
const products = ref([])
const sellable = computed(() => products.value.filter((p) => p.status === '在售'))

const termOptions = [
  { label: '款到发货', days: 0 },
  { label: '月结 30 天', days: 30 },
  { label: '月结 45 天', days: 45 },
  { label: '月结 60 天', days: 60 },
  { label: '月结 90 天', days: 90 }
]

const createOpen = ref(false)
const saving = ref(false)
/* 刚打开表单就列三条「还没选客户」是在骂人；等真点了提交再说 */
const submitAttempted = ref(false)
const form = reactive({
  customerId: '',
  type: '年框',
  name: '',
  paymentTerm: '月结 30 天',
  discount: 1,
  signDate: '',
  startDate: '',
  endDate: '',
  remark: '',
  items: []
})

const termDays = computed(() => termOptions.find((t) => t.label === form.paymentTerm)?.days ?? 30)

/* 有效期按类型算：年框一年、季度三个月、单次 30 天。
   用户手改过 endDate 就不再覆盖，别把人的输入冲掉 */
let endTouched = false
watch(() => form.endDate, (v, old) => {
  if (v && v !== old && old !== '' && !form.__auto) endTouched = true
})

const periodHint = computed(() => {
  if (form.type === '年框') return '年框默认签订日起 1 年'
  if (form.type === '季度') return '季度默认签订日起 3 个月'
  return '单次默认签订日起 30 天'
})

function addMonths(dateStr, n) {
  const d = new Date(`${dateStr}T00:00:00`)
  const day = d.getDate()
  d.setMonth(d.getMonth() + n)
  /* 1/31 加一个月会溢出到 3/3，退回到上月最后一天 */
  if (d.getDate() < day) d.setDate(0)
  return localDate(d)
}
function addDays(dateStr, n) {
  const d = new Date(`${dateStr}T00:00:00`)
  d.setDate(d.getDate() + n)
  return localDate(d)
}

function syncPeriod() {
  if (!form.signDate) return
  if (!form.startDate) form.startDate = form.signDate
  if (endTouched) return
  const end = form.type === '年框'
    ? addDays(addMonths(form.signDate, 12), -1)
    : form.type === '季度'
      ? addDays(addMonths(form.signDate, 3), -1)
      : addDays(form.signDate, 30)
  form.__auto = true
  form.endDate = end
  form.__auto = false
}

async function openCreate() {
  try {
    const [people, catalog] = await Promise.all([
      customerApi.list(),
      productApi.list({ pageSize: 500 })
    ])
    customers.value = people
    products.value = catalog.rows
  } catch (e) {
    return toast(`客户或产品列表加载失败：${e.message}`, 'error')
  }

  form.customerId = ''
  form.type = '年框'
  form.name = ''
  form.paymentTerm = '月结 30 天'
  form.discount = 1
  form.signDate = localDate()
  form.startDate = localDate()
  endTouched = false
  syncPeriod()
  form.remark = ''
  form.items = []
  addLine()
  submitAttempted.value = false
  createOpen.value = true
}

function addLine() {
  form.items.push({ productId: '', unit: '箱', qty: 1, price: 0, manual: false })
}

function unitsOf(pid) {
  const p = products.value.find((x) => String(x.id) === String(pid))
  return p ? p.units.map((u) => u.name) : ['箱']
}

/* 产品的报价单位价：产品接口给的是 saleUnit（箱）价，换成当前单位 */
function listPrice(ln) {
  const p = products.value.find((x) => String(x.id) === String(ln.productId))
  if (!p) return 0
  return Math.round(unitPrice(p, ln.unit || p.saleUnit, 'standard') * 100) / 100
}

function suggestPrice(ln) {
  return Math.round(listPrice(ln) * Number(form.discount || 1) * 100) / 100
}

function onProductChange(ln) {
  const p = products.value.find((x) => String(x.id) === String(ln.productId))
  if (!p) return
  ln.unit = p.saleUnit
  ln.manual = false
  ln.price = suggestPrice(ln)
}

function onUnitChange(ln) {
  if (ln.manual) return
  ln.price = suggestPrice(ln)
}

function resetPrice(ln) {
  ln.manual = false
  ln.price = suggestPrice(ln)
}

/* 改折扣时只重算没手改过的行，手改价代表谈定的特殊价，不能被冲掉 */
watch(() => form.discount, () => {
  for (const ln of form.items) if (!ln.manual) ln.price = suggestPrice(ln)
})

function lineTotal(ln) {
  return Math.round((ln.price || 0) * (ln.qty || 0) * 100) / 100
}

const formTotal = computed(() => Math.round(form.items.reduce((s, ln) => s + lineTotal(ln), 0) * 100) / 100)
const formListTotal = computed(() =>
  Math.round(form.items.reduce((s, ln) => s + listPrice(ln) * (ln.qty || 0), 0) * 100) / 100
)
const realDiscount = computed(() => (formListTotal.value ? formTotal.value / formListTotal.value : 0))

const createIssues = computed(() => {
  const out = []
  if (!form.customerId) out.push('还没选客户')
  if (!form.name.trim()) out.push('合同名称不能为空')
  if (!form.items.length) out.push('至少要有一条商品明细')
  if (form.items.some((ln) => !ln.productId)) out.push('有明细行没选产品')
  if (form.items.some((ln) => ln.productId && !(ln.qty >= 1))) out.push('年度约定量要大于 0')
  if (form.items.some((ln) => ln.productId && !(ln.price > 0))) out.push('协议单价要大于 0')
  if (form.startDate && form.endDate && form.endDate < form.startDate) out.push('到期日不能早于生效日')
  if (realDiscount.value && Math.abs(realDiscount.value - Number(form.discount || 1)) > 0.005) {
    out.push(`明细单价手改过，实际折扣是 ${(realDiscount.value * 10).toFixed(1)} 折，和上面的 ${(Number(form.discount) * 10).toFixed(1)} 折不一致`)
  }
  return out
})

async function submitCreate() {
  if (saving.value) return
  submitAttempted.value = true
  if (!form.customerId || !form.name.trim() || !form.items.length) {
    return toast(createIssues.value[0] || '客户、合同名称和商品明细都要填', 'error')
  }
  if (form.items.some((ln) => !ln.productId || !(ln.qty >= 1) || !(ln.price > 0))) {
    return toast('明细里有产品、数量或单价没填对', 'error')
  }
  if (form.endDate && form.startDate && form.endDate < form.startDate) {
    return toast('到期日不能早于生效日', 'error')
  }

  saving.value = true
  try {
    const r = await attempt({
      label: 'POST /contracts',
      call: () => orderApi.createContract({
        name: form.name.trim(),
        customerId: Number(form.customerId),
        type: form.type,
        discount: Number(form.discount),
        termDays: termDays.value,
        paymentTerm: form.paymentTerm,
        signDate: form.signDate || null,
        startDate: form.startDate || null,
        endDate: form.endDate || null,
        remark: form.remark,
        items: form.items.map(({ productId, unit, qty, price }) => ({
          productId: Number(productId), unit, qty: Number(qty), price: Number(price)
        }))
      }),
      demoNote: '后端接口未就绪'
    })

    if (r.mode === 'live') {
      createOpen.value = false
      toast(`${r.data?.code || '合同'} 已提交，等待审批`)
      await reload()
    } else {
      /* 不往列表里塞假合同：接口没写就说没保存，别让人以为已经落库 */
      toast('POST /contracts 还没实现，这份合同没有保存。接口清单在 docs/contracts-api.md，后端补上后可直接提交', 'error')
    }
  } catch (e) {
    toast(e.message, 'error')
  } finally {
    saving.value = false
  }
}

async function reload() {
  try {
    const live = await loadContracts()
    if (live) rows.value = live.map((r) => ({ ...r, approvals: [...(r.approvals || [])] }))
  } catch (e) { toast(e.message, 'error') }
}

/* ---------------- 审批合同 ---------------- */

const approveOpen = ref(false)
const approveRow = ref({})
const decision = ref('pass')
const note = ref('')

function openApprove(row) {
  approveRow.value = row
  decision.value = 'pass'
  note.value = ''
  approveOpen.value = true
}

async function submitApprove() {
  if (saving.value) return
  if (decision.value === 'reject' && !note.value.trim()) {
    return toast('驳回要写清原因，负责人照着改', 'error')
  }
  saving.value = true
  try {
    const r = await attempt({
      label: 'POST /contracts/{id}/approve',
      call: () => orderApi.approveContract(approveRow.value.dbId, {
        result: decision.value,
        note: note.value.trim()
      }),
      demoNote: '后端接口未就绪'
    })
    if (r.mode === 'live') {
      approveOpen.value = false
      toast(decision.value === 'pass' ? '合同已通过，转为执行中' : '已驳回，合同退回草稿')
      await reload()
    } else {
      toast('POST /contracts/{id}/approve 还没实现，审批没有落库，合同状态保持不变', 'error')
    }
  } catch (e) {
    toast(e.message, 'error')
  } finally {
    saving.value = false
  }
}

/* ---------------- 详情 ---------------- */

const detailOpen = ref(false)
const current = ref({})
const detail = ref(null)
/* demo：演示数据自带明细；live：详情接口有返回；missing：接口没写，只能看列表摘要 */
const detailState = ref('demo')
const detailReady = computed(() => detailState.value !== 'missing')

const contractLines = computed(() => {
  const list = detail.value?.items || current.value.items || []
  return list.map((it) => {
    const pid = it.productId ?? it.product_id
    const p = products.value.find((x) => String(x.id) === String(pid))
      || productItems.find((x) => String(x.id) === String(pid))
    const qty = Number(it.qty || 0)
    /* 后端给的是已含折扣的协议单价；演示数据只有量，才需要现算 */
    const given = it.price == null ? 0 : Number(it.price)
    const price = given > 0
      ? given
      : resolvePrice(pid, current.value.customer, it.unit, qty).price
    return {
      name: p?.name || `产品 ${pid}`,
      spec: p?.id ? specSummary(p) : '—',
      unit: it.unit,
      qty,
      price,
      amount: Math.round(price * qty * 100) / 100
    }
  })
})

/* 后端详情会带 orders；没有就回落到演示订单里按合同号匹配 */
const relatedOrders = computed(() => {
  const live = detail.value?.orders
  if (Array.isArray(live)) {
    return live.map((o) => ({
      id: o.code || o.id,
      date: (o.order_date || o.orderDate || '').slice(0, 10),
      amount: Number(o.amount || 0),
      status: o.status
    }))
  }
  return orders.filter((o) => o.contractId === current.value.id)
})

const orderColumns = [
  { key: 'id', label: '订单号', width: '150px' },
  { key: 'date', label: '下单日', width: '104px' },
  { key: 'amount', label: '金额', width: '120px', align: 'right' },
  { key: 'status', label: '状态', width: '92px' }
]

async function openDetail(row) {
  current.value = row
  detail.value = null
  detailState.value = 'demo'
  detailOpen.value = true
  if (!row.dbId) return
  try {
    detail.value = await orderApi.contractDetail(row.dbId)
    detailState.value = 'live'
    const c = detail.value?.contract
    if (c) {
      current.value = {
        ...row,
        name: c.name || row.name,
        customer: c.customer || row.customer,
        amount: Number(c.amount ?? row.amount),
        discount: c.discount ?? row.discount,
        term: c.payment_term || row.term,
        signDate: c.sign_date || row.signDate,
        start: c.start_date || row.start,
        end: c.end_date || row.end,
        status: c.status || row.status,
        approvals: detail.value?.approvals || row.approvals || []
      }
    }
  } catch {
    /* 详情接口还没做（404）：列表行本身已经有摘要，明细和订单走演示兜底 */
    detailState.value = 'missing'
  }
}
</script>

<style scoped>
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
.kpi i {
  font-style: normal;
  font-size: 12px;
  font-weight: 500;
  color: var(--faint);
}
.kpi em {
  font-style: normal;
  font-size: 11.5px;
  color: var(--faint);
}

.row-tight > span {
  white-space: nowrap;
}

.own-note {
  font-size: 11.5px;
  color: var(--faint);
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

/* -------- 新建合同表单 -------- */
.field-note {
  font-size: 12px;
  line-height: 1.5;
  color: var(--muted);
  font-style: normal;
}
.discount-row {
  display: flex;
  align-items: center;
  gap: 8px;
}
.discount-row .input {
  max-width: 110px;
}
.discount-tag {
  font-size: 12.5px;
  font-weight: 550;
  color: var(--brand);
  background: var(--brand-soft);
  border-radius: 6px;
  padding: 3px 8px;
  white-space: nowrap;
}
.period-row {
  display: flex;
  align-items: center;
  gap: 6px;
}
.tilde {
  font-size: 12px;
  color: var(--faint);
}

.lines {
  margin-top: 16px;
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
  table-layout: fixed;
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
  vertical-align: top;
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
.w-qty {
  width: 108px;
}
.w-price {
  width: 128px;
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
  padding-top: 13px;
  font-variant-numeric: tabular-nums;
}
.price-hint {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 2px 6px;
  margin-top: 3px;
  font-size: 11px;
  color: var(--faint);
}
.link-sm {
  font-size: 11px;
  color: var(--brand);
}
.empty-line {
  text-align: center;
  color: var(--faint);
  padding: 16px 0;
  font-size: 12.5px;
}

.totals {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 26px;
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
  font-size: 15px;
  font-weight: 650;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
}
.tt b.muted {
  color: var(--muted);
  font-weight: 550;
}
.tt b.warn {
  color: var(--warning);
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

/* -------- 审批 -------- */
.apx {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.apx-meta {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px 18px;
  padding: 12px 14px;
  background: #fafbfc;
  border-radius: 10px;
}
.decide {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}
.decide-btn {
  display: flex;
  flex-direction: column;
  gap: 4px;
  align-items: flex-start;
  padding: 10px 12px;
  border: 1px solid var(--line);
  border-radius: 10px;
  background: var(--surface);
  font-size: 13px;
  font-weight: 550;
  color: var(--ink);
  cursor: pointer;
  text-align: left;
  transition: border-color 0.16s, box-shadow 0.16s, background 0.16s;
}
.decide-btn em {
  font-style: normal;
  font-size: 11.5px;
  font-weight: 400;
  color: var(--muted);
  line-height: 1.45;
}
.decide-btn:hover {
  border-color: #cfd6e0;
}
.decide-btn.on {
  border-color: var(--brand);
  background: var(--brand-soft);
  box-shadow: 0 0 0 3px rgba(43, 108, 176, 0.1);
}
.decide-btn.danger.on {
  border-color: var(--danger);
  background: #fdf2f2;
  box-shadow: 0 0 0 3px rgba(200, 60, 60, 0.1);
}
.api-note {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  padding: 9px 12px;
  border-radius: 8px;
  background: #f5f7fa;
  font-size: 11.5px;
  color: var(--muted);
  line-height: 1.6;
}

/* -------- 详情 -------- */
.detail {
  display: flex;
  flex-direction: column;
  gap: 18px;
}
.d-meta {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px 18px;
  padding: 12px 14px;
  background: #fafbfc;
  border-radius: 10px;
}
.dm {
  display: flex;
  flex-direction: column;
  gap: 3px;
  min-width: 0;
}
.dm span {
  font-size: 11.5px;
  color: var(--muted);
}
.dm b {
  font-size: 13px;
  font-weight: 550;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
}
.d-title {
  font-size: 12.5px;
  font-weight: 600;
  color: var(--ink);
  margin-bottom: 8px;
}
.d-title .cnt {
  font-weight: 400;
  color: var(--faint);
  margin-left: 4px;
}
.mini {
  width: 100%;
  border-collapse: collapse;
  font-size: 12.5px;
  border: 1px solid var(--line);
  border-radius: 8px;
  overflow: hidden;
}
.mini th {
  text-align: left;
  font-weight: 500;
  color: var(--muted);
  background: #fafbfc;
  padding: 8px 10px;
  border-bottom: 1px solid var(--line);
  white-space: nowrap;
}
.mini td {
  padding: 8px 10px;
  border-bottom: 1px solid #f2f4f7;
}
.mini tr:last-child td {
  border-bottom: none;
}
.mini .r {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

.timeline {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding-left: 4px;
}
.tl {
  display: flex;
  gap: 10px;
}
.tl-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #cfd6e0;
  margin-top: 6px;
  flex-shrink: 0;
}
.tl-dot.done {
  background: var(--brand);
}
.tl-head {
  display: flex;
  align-items: center;
  gap: 8px;
}
.tl-head b {
  font-size: 12.5px;
  font-weight: 550;
}
.tl-time {
  font-size: 11.5px;
  color: var(--faint);
  font-variant-numeric: tabular-nums;
}
.tl-note {
  font-size: 12px;
  color: var(--muted);
  margin-top: 3px;
  line-height: 1.5;
}
.empty-note {
  font-size: 12.5px;
  color: var(--faint);
  padding: 8px 0;
}

@media (max-width: 900px) {
  .summary {
    grid-template-columns: 1fr 1fr;
  }
  .d-meta,
  .apx-meta {
    grid-template-columns: 1fr 1fr;
  }
  .decide {
    grid-template-columns: 1fr;
  }
}
</style>
