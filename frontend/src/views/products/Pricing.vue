<template>
  <div class="page">
    <PageHead title="价格与折扣" desc="耗材靠量，价格分档：客户协议价优先于阶梯价，阶梯价优先于经销价，最后才落到标准价">
      <button v-can="'product.price'" class="btn" type="button" :disabled="!selected.length" @click="openBatch">
        <AppIcon name="trend-up" :size="13" />批量调价{{ selected.length ? `（${selected.length}）` : '' }}
      </button>
    </PageHead>

    <div class="card rule">
      <div class="rule-title">
        <AppIcon name="filter" :size="14" />
        取价顺序
      </div>
      <div class="rule-flow">
        <span class="rule-step">客户协议价</span>
        <AppIcon name="chevron-right" :size="13" />
        <span class="rule-step">阶梯价</span>
        <AppIcon name="chevron-right" :size="13" />
        <span class="rule-step">经销价</span>
        <AppIcon name="chevron-right" :size="13" />
        <span class="rule-step last">标准价</span>
      </div>
      <p class="rule-note">
        开单时按客户、数量依次匹配；改价只影响之后的报价与合同，已签单据按签署时的价格快照执行。
      </p>
    </div>

    <div class="card">
      <div class="toolbar">
        <div class="search">
          <AppIcon name="search" :size="15" />
          <input v-model.trim="keyword" class="input" type="text" placeholder="搜索产品名称 / 编码" />
        </div>
        <select v-model="categoryId" class="select">
          <option value="">全部品类</option>
          <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
        <div class="spacer" />
        <span v-if="!canSeeCost" class="cost-hint">
          <AppIcon name="lock" :size="12" />成本价与毛利率需「查看成本价」权限
        </span>
      </div>

      <AppTable
        v-model:selected="selected"
        :columns="columns"
        :rows="filtered"
        :page-size="8"
        :selectable="canPrice"
        empty-text="没有符合条件的产品"
      >
        <template #cell-name="{ row }">
          <div class="p-cell">
            <span class="p-name" :title="row.name">{{ row.name }}</span>
            <span class="p-code">{{ row.code }} · {{ row.saleUnit }}装</span>
          </div>
        </template>
        <template #cell-category="{ row }">
          <span class="nowrap">{{ categoryName(row.categoryId) }}</span>
        </template>
        <template #cell-standard="{ row }">
          <b class="num">¥{{ money(row.prices.standard) }}</b>
        </template>
        <template #cell-dealer="{ row }">
          <span class="num muted">¥{{ money(row.prices.dealer) }}</span>
        </template>
        <template #cell-cost="{ row }">
          <span v-if="canSeeCost" class="num muted">¥{{ money(row.prices.cost) }}</span>
          <span v-else class="locked">—</span>
        </template>
        <template #cell-margin="{ row }">
          <span v-if="canSeeCost" class="margin" :class="marginTone(row)">{{ marginText(row) }}</span>
          <span v-else class="locked">—</span>
        </template>
        <template #cell-updated="{ row }">
          <span class="date">{{ row.updatedAt }}</span>
        </template>
      </AppTable>
    </div>

    <div class="block-head">
      <div>
        <h3>客户协议价</h3>
        <p>按客户单独谈的折扣，覆盖该客户常买的品类；开单时自动带出，不覆盖阶梯价上限</p>
      </div>
    </div>

    <div class="card">
      <AppTable :columns="custColumns" :rows="customerPrices" :page-size="5" :show-pager="false">
        <template #cell-customer="{ row }">
          <span class="cust">{{ row.customer }}</span>
        </template>
        <template #cell-level="{ row }">
          <span class="tag tag-brand plain">{{ row.level }}</span>
        </template>
        <template #cell-discount="{ row }">
          <b class="num">{{ (row.discount * 10).toFixed(1) }} 折</b>
        </template>
        <template #cell-products="{ row }">
          <span class="num muted">{{ row.products }} 个 SKU</span>
        </template>
        <template #cell-owner="{ row }">
          <span>{{ row.owner }}</span>
        </template>
        <template #cell-updated="{ row }">
          <span class="date">{{ row.updatedAt }}</span>
        </template>
      </AppTable>
    </div>

    <!-- 批量调价 -->
    <ModalDialog
      v-model="batchOpen"
      title="批量调价"
      :desc="`将对 ${selected.length} 个产品按同一规则调整标准价，调价记录会留痕`"
      ok-text="确认调价"
      @confirm="applyBatch"
    >
      <div class="form-grid">
        <div class="field">
          <label class="label">调整方式</label>
          <select v-model="batchForm.mode" class="select">
            <option value="percent">按百分比</option>
            <option value="amount">按固定金额</option>
          </select>
        </div>
        <div class="field">
          <label class="label">方向</label>
          <select v-model="batchForm.direction" class="select">
            <option value="up">上调</option>
            <option value="down">下调</option>
          </select>
        </div>
        <div class="field">
          <label class="label">{{ batchForm.mode === 'percent' ? '幅度（%）' : '金额（元）' }}</label>
          <input v-model.number="batchForm.value" class="input" type="number" min="0" step="0.01" />
        </div>
      </div>
      <div class="batch-preview">
        <span>调整后预览</span>
        <ul>
          <li v-for="r in previewRows" :key="r.id">
            <span class="pv-name">{{ r.name }}</span>
            <span class="pv-price">¥{{ money(r.prices.standard) }} → ¥{{ money(batchPrice(r)) }}</span>
          </li>
        </ul>
      </div>
    </ModalDialog>
  </div>
</template>

<script setup>
import { onMounted } from 'vue'
import { productApi } from '@/api/products'
import { computed, reactive, ref } from 'vue'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import { toast } from '@/composables/useToast'
import { can } from '@/store/permissions'
import { money, marginOf } from '@/data/productCatalog'
import { todayStr } from '@/utils/date'

const rows = ref([])
const categories = ref([])
const customerPrices = ref([])
const categoryName = (id) => categories.value.find((category) => category.id === id)?.name || '未分类'
async function loadPrices() {
  rows.value = (await productApi.priceList({ pageSize: 500 })).rows
}
onMounted(async () => {
  try {
    await loadPrices()
    categories.value = await productApi.categories()
    customerPrices.value = await productApi.customerPrices()
  } catch (e) { toast(e.message, 'error') }
})
const keyword = ref('')
const categoryId = ref('')
const selected = ref([])

const canSeeCost = computed(() => can('product.cost'))
const canPrice = computed(() => can('product.price'))

const columns = computed(() => {
  const base = [
    { key: 'name', label: '产品', width: '230px' },
    { key: 'category', label: '品类', width: '96px' },
    { key: 'standard', label: '标准价', width: '104px', align: 'right' },
    { key: 'dealer', label: '经销价', width: '104px', align: 'right' }
  ]
  if (canSeeCost.value) {
    base.push({ key: 'cost', label: '成本价', width: '100px', align: 'right' })
    base.push({ key: 'margin', label: '毛利率', width: '92px', align: 'right' })
  }
  base.push({ key: 'updated', label: '最近调价', width: '100px' })
  return base
})

const custColumns = [
  { key: 'customer', label: '客户' },
  { key: 'level', label: '等级', width: '108px' },
  { key: 'discount', label: '折扣', width: '92px', align: 'right' },
  { key: 'products', label: '覆盖产品', width: '112px' },
  { key: 'owner', label: '负责人', width: '92px' },
  { key: 'updated', label: '更新时间', width: '108px' }
]

const filtered = computed(() =>
  rows.value.filter((r) => {
    if (categoryId.value && r.categoryId !== categoryId.value) return false
    if (keyword.value) {
      const q = keyword.value.toLowerCase()
      if (!`${r.name}${r.code}`.toLowerCase().includes(q)) return false
    }
    return true
  })
)

function marginText(row) {
  const m = marginOf(row)
  return m == null ? '—' : `${m.toFixed(1)}%`
}
function marginTone(row) {
  const m = marginOf(row)
  if (m == null) return ''
  if (m >= 35) return 'good'
  if (m >= 22) return 'mid'
  return 'low'
}

/* ---------------- 批量调价 ---------------- */
const batchOpen = ref(false)
const batchForm = reactive({ mode: 'percent', direction: 'up', value: 3 })

const selectedRows = computed(() => rows.value.filter((r) => selected.value.includes(r.id)))
const previewRows = computed(() => selectedRows.value.slice(0, 4))

function batchPrice(row) {
  const base = Number(row.prices.standard) || 0
  const v = Number(batchForm.value) || 0
  const delta = batchForm.mode === 'percent' ? (base * v) / 100 : v
  const next = batchForm.direction === 'up' ? base + delta : base - delta
  return Math.max(0, Math.round(next * 100) / 100)
}
function openBatch() {
  if (!selected.value.length) return toast('请先勾选要调价的产品', 'error')
  batchOpen.value = true
}
async function applyBatch() {
  if (!(batchForm.value > 0)) return toast('请填写调整幅度', 'error')
  try {
    await productApi.batchAdjust({ ids: selected.value, kind: 'standard', mode: batchForm.mode,
      value: batchForm.direction === 'up' ? batchForm.value : -batchForm.value })
    selected.value = []
    batchOpen.value = false
    await loadPrices()
    toast('已保存调价')
  } catch (e) { toast(e.message, 'error') }
}
</script>

<style scoped>
.rule {
  padding: 14px 18px;
  margin-bottom: 16px;
  background: #fbfcfe;
}
.rule-title {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12.5px;
  font-weight: 550;
  color: var(--ink);
}
.rule-flow {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 10px 0 8px;
  color: var(--faint);
  flex-wrap: wrap;
}
.rule-step {
  padding: 4px 10px;
  border-radius: 6px;
  background: #eef4fb;
  border: 1px solid #dfeaf6;
  font-size: 12px;
  color: #2f5d8a;
}
.rule-step.last {
  background: #f4f6f8;
  border-color: #e6eaef;
  color: var(--muted);
}
.rule-note {
  margin: 0;
  font-size: 11.8px;
  color: var(--faint);
  line-height: 1.7;
}

.toolbar {
  border-bottom: 1px solid var(--line-soft);
}
.spacer {
  flex: 1;
}
.cost-hint {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 11.5px;
  color: var(--faint);
}

.p-cell {
  display: flex;
  flex-direction: column;
  line-height: 1.5;
  min-width: 0;
}
.p-name {
  font-size: 13px;
  font-weight: 550;
  color: var(--ink);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.p-code {
  font-size: 11px;
  color: var(--faint);
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}
.num {
  font-variant-numeric: tabular-nums;
  font-size: 13px;
  color: var(--ink);
}
.num.muted {
  color: var(--muted);
  font-weight: 400;
}
.margin {
  font-size: 12.5px;
  font-variant-numeric: tabular-nums;
  padding: 2px 7px;
  border-radius: 6px;
}
.margin.good {
  background: var(--success-bg);
  color: var(--success);
}
.margin.mid {
  background: #f4f7fb;
  color: var(--muted);
}
.margin.low {
  background: var(--danger-bg);
  color: var(--danger);
}
.locked {
  color: var(--faint);
}
.date {
  font-size: 12px;
  color: var(--muted);
  font-variant-numeric: tabular-nums;
}
.cust {
  font-size: 12.8px;
  color: var(--ink);
}
.nowrap {
  white-space: nowrap;
}

.block-head {
  margin: 22px 0 10px;
}
.block-head h3 {
  margin: 0;
  font-size: 14px;
  font-weight: 600;
  color: var(--ink);
}
.block-head p {
  margin: 4px 0 0;
  font-size: 12px;
  color: var(--faint);
}

.batch-preview {
  margin-top: 14px;
  padding: 10px 12px;
  border-radius: 8px;
  background: #f7fafd;
  font-size: 12px;
  color: var(--muted);
}
.batch-preview ul {
  margin: 6px 0 0;
  padding: 0;
  list-style: none;
}
.batch-preview li {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  padding: 3px 0;
}
.pv-name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pv-price {
  color: var(--ink);
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}
</style>
