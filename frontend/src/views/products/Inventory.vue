<template>
  <div class="page">
    <PageHead
      title="库存"
      desc="按 SKU 看可发状态与交期。下单前先确认这里：需排产的产品不能承诺现货交期，少量要问仓库实际可发量"
    >
      <button class="btn" type="button" :disabled="loading" @click="load">
        <AppIcon name="refresh" :size="14" :class="{ spin: loading }" />
        刷新
      </button>
      <button class="btn" type="button" @click="goProducts">
        <AppIcon name="box" :size="14" />产品档案
      </button>
    </PageHead>

    <div v-if="!availableReady && !loading" class="api-note">
      <AppIcon name="flag" :size="13" />
      <span>
        可用数量接口（GET /inventory）还没实现，现在只能看库存状态（充足 / 少量 / 需排产）。
        状态来自产品档案，是真实数据；<b>具体可发多少件要问仓库</b>。
      </span>
    </div>

    <div class="summary">
      <div class="kpi card">
        <span>在售 SKU</span>
        <b>{{ rows.length }}<i>个</i></b>
        <em>停售产品不计入</em>
      </div>
      <div class="kpi card">
        <span>充足</span>
        <b class="ok">{{ countOf('充足') }}<i>个</i></b>
        <em>可直接承诺现货</em>
      </div>
      <div class="kpi card">
        <span>少量</span>
        <b class="warn">{{ countOf('少量') }}<i>个</i></b>
        <em>发货前确认实际可发量</em>
      </div>
      <div class="kpi card">
        <span>需排产</span>
        <b class="danger">{{ countOf('需排产') }}<i>个</i></b>
        <em>按生产周期约定交期</em>
      </div>
    </div>

    <div class="card">
      <div class="toolbar">
        <div class="search">
          <AppIcon name="search" :size="15" />
          <input v-model="keyword" class="input" type="text" placeholder="搜索产品名称 / 编码" />
        </div>
        <select v-model="stockFilter" class="select">
          <option value="">全部库存状态</option>
          <option v-for="s in STOCKS" :key="s">{{ s }}</option>
        </select>
        <select v-model="modeFilter" class="select">
          <option value="">全部生产方式</option>
          <option value="自产">自产</option>
          <option value="外采">外采</option>
        </select>
        <div class="spacer" />
        <span v-if="!canEdit" class="faint hint">没有产品编辑权限，只能查看</span>
        <span v-else class="faint hint">改库存状态会立即写入产品档案</span>
      </div>

      <div v-if="loadError" class="warn-line">
        <AppIcon name="flag" :size="13" />
        <span>{{ loadError }}</span>
      </div>

      <AppTable :columns="columns" :rows="filtered" :page-size="12" empty-text="没有符合条件的产品">
        <template #cell-name="{ row }">
          <div class="cell-main">{{ row.name }}</div>
          <div class="cell-sub">{{ row.code }}{{ row.brand ? ` · ${row.brand}` : '' }}</div>
        </template>
        <template #cell-category="{ row }">
          <span class="faint">{{ categoryName(row.categoryId) }}</span>
        </template>
        <template #cell-available="{ row }">
          <span v-if="row.available != null" class="num">{{ Number(row.available).toLocaleString() }}</span>
          <span v-else class="faint">—</span>
        </template>
        <template #cell-stock="{ row }">
          <select
            v-if="canEdit"
            class="select stock-select"
            :class="`st-${stockKey(row.stock)}`"
            :value="row.stock"
            @change="changeStock(row, $event.target.value)"
          >
            <option v-for="s in STOCKS" :key="s">{{ s }}</option>
          </select>
          <span v-else class="tag" :class="STOCK_TONE[row.stock] || 'tag-gray'">{{ row.stock }}</span>
        </template>
        <template #cell-cycle="{ row }">
          <div class="cell-main">{{ row.productionDays }} 天</div>
          <div class="cell-sub">{{ row.mode === '自产' ? '自产' : '外采' }}</div>
        </template>
        <template #cell-moq="{ row }">
          <span class="num">{{ Number(row.moq || 0).toLocaleString() }} {{ row.saleUnit }}</span>
        </template>
        <template #cell-ops="{ row }">
          <div class="row-tight ops">
            <button class="btn-text" type="button" @click="goOrders(row)">看订单</button>
          </div>
        </template>
      </AppTable>
    </div>

    <div class="card tip-card">
      <div class="tip-head">
        <AppIcon name="flag" :size="14" />
        <strong>下单前的三条硬规则</strong>
      </div>
      <ul class="tip-list">
        <li>
          <b>需排产</b>：交期 = 生产周期（本页「周期」列）+ 物流时间，不能按现货承诺。
          当前 {{ countOf('需排产') }} 个 SKU 处于这个状态，下单时要在备注里写明交期。
        </li>
        <li>
          <b>少量</b>：库存状态只是档位，不代表具体数量。超过 {{ lowMoq }} 箱的订单请先找仓库确认。
        </li>
        <li>
          <b>下单目前不校验库存</b>：后端只在发货时扣减，库存不足会在发货环节才失败。
          这是已知缺口，已列入后端清单（下单时按可用量预占）。
        </li>
      </ul>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import { toast } from '@/composables/useToast'
import { productApi } from '@/api/products'
import { request } from '@/api/http'
import { can } from '@/store/permissions'

const router = useRouter()
const productApiRef = productApi

const STOCKS = ['充足', '少量', '需排产']
const STOCK_TONE = { 充足: 'tag-success', 少量: 'tag-warning', 需排产: 'tag-danger' }

const rows = ref([])
const categories = ref([])
const loading = ref(false)
const loadError = ref('')
/* /inventory 未实现时为 false，页面明确说明而不是把「—」当 0 */
const availableReady = ref(false)

const canEdit = computed(() => can('product.edit'))
const keyword = ref('')
const stockFilter = ref('')
const modeFilter = ref('')

const columns = computed(() => [
  { key: 'name', label: '产品' },
  { key: 'category', label: '品类', width: '120px' },
  { key: 'available', label: '可用数量', width: '100px', align: 'right' },
  { key: 'stock', label: '库存状态', width: '124px' },
  { key: 'moq', label: '最小起订', width: '116px', align: 'right' },
  { key: 'cycle', label: '生产周期', width: '96px' },
  { key: 'ops', label: '操作', width: '88px', align: 'right' }
])

const countOf = (s) => rows.value.filter((r) => r.stock === s).length
const lowMoq = computed(() => Math.min(...rows.value.map((r) => Number(r.moq || 0)), 10) || 10)

const categoryName = (id) => categories.value.find((c) => c.id === id)?.name || '—'

const stockKey = (s) => (s === '充足' ? 'ok' : s === '少量' ? 'low' : 'mto')

const filtered = computed(() =>
  rows.value.filter((r) => {
    if (stockFilter.value && r.stock !== stockFilter.value) return false
    if (modeFilter.value && r.mode !== modeFilter.value) return false
    if (keyword.value) {
      const k = keyword.value.trim().toLowerCase()
      if (!`${r.name}${r.code}`.toLowerCase().includes(k)) return false
    }
    return true
  })
)

async function load() {
  loading.value = true
  loadError.value = ''
  try {
    const data = await productApiRef.list({ pageSize: 500, status: '在售' })
    const list = (data?.rows || []).map((p) => ({ ...p, available: null }))

    /* 库存数量接口未就绪时 404，按「未接入」处理，不当作 0 */
    try {
      const inv = await request('/inventory')
      const invRows = Array.isArray(inv) ? inv : inv?.rows || []
      const map = new Map(invRows.map((x) => [x.productId ?? x.product_id, x.available]))
      list.forEach((p) => {
        if (map.has(p.id)) p.available = map.get(p.id)
      })
      availableReady.value = invRows.length > 0
    } catch {
      availableReady.value = false
    }

    rows.value = list
  } catch (e) {
    loadError.value = `产品库存加载失败：${e.message}`
    rows.value = []
  } finally {
    loading.value = false
    productApiRef
      .categories()
      .then((list) => {
        categories.value = Array.isArray(list) ? list : list?.rows || []
      })
      .catch(() => {})
  }
}

async function changeStock(row, value) {
  if (value === row.stock) return
  const before = row.stock
  try {
    await productApiRef.updateStock(row.id, value)
    row.stock = value
    toast(`${row.name} 库存状态：${before} → ${value}`)
  } catch (e) {
    /* 失败回滚下拉框，不能让界面显示已改但库里没变 */
    toast(e.message, 'error')
    await load()
  }
}

function goProducts() {
  router.push('/products')
}

function goOrders(row) {
  router.push({ path: '/orders', query: { keyword: row.name } })
}

onMounted(load)
</script>

<style scoped>
.spin {
  animation: spin 0.9s linear infinite;
}
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
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
}
.kpi b.ok {
  color: var(--success);
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
}
.kpi em {
  font-style: normal;
  font-size: 11.5px;
  color: var(--faint);
}

.stock-select {
  height: 28px;
  padding: 0 24px 0 8px;
  font-size: 12px;
  width: 100px;
}
.stock-select.st-ok {
  color: var(--success);
  border-color: #b7e4c7;
  background: #f2fdf6;
}
.stock-select.st-low {
  color: var(--warning);
  border-color: #f5d9a8;
  background: #fffbf1;
}
.stock-select.st-mto {
  color: var(--danger);
  border-color: #f3c1bd;
  background: #fef5f4;
}

.ops {
  justify-content: flex-end;
}
.hint {
  font-size: 12px;
}
.num {
  font-variant-numeric: tabular-nums;
}

.tip-card {
  margin-top: 16px;
  padding: 14px 18px 16px;
}
.tip-head {
  display: flex;
  align-items: center;
  gap: 7px;
  color: var(--brand);
  font-size: 12.5px;
  margin-bottom: 8px;
}
.tip-list {
  margin: 0;
  padding-left: 18px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.tip-list li {
  font-size: 12px;
  line-height: 1.65;
  color: var(--muted);
}
.tip-list b {
  color: var(--text);
  font-weight: 600;
}

@media (max-width: 900px) {
  .summary {
    grid-template-columns: 1fr 1fr;
  }
}
</style>
