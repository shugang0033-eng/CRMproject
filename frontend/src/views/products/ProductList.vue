<template>
  <div class="page">
    <PageHead title="产品列表" desc="汽车美容耗材的主数据：一个 SKU 一条记录，规格、装箱与价格统一维护，报价与合同都从这里引用">
      <button v-can="'product.import'" class="btn" type="button" @click="importOpen = true">
        <AppIcon name="inbox" :size="13" />导入
      </button>
      <button class="btn" type="button" @click="exportCsv">
        <AppIcon name="download" :size="13" />导出
      </button>
      <button v-can="'product.edit'" class="btn btn-primary" type="button" @click="openCreate">
        <AppIcon name="plus" :size="14" />新建产品
      </button>
    </PageHead>

    <div class="prod-layout">
      <!-- 左：品类树 -->
      <aside class="card cat-tree">
        <div class="ct-head">
          <span>品类</span>
          <span class="ct-count">{{ rows.length }}</span>
        </div>
        <button class="ct-item" :class="{ on: !categoryId }" type="button" @click="pickCategory('')">
          <AppIcon name="box" :size="14" />
          <span class="ct-name">全部产品</span>
          <span class="ct-num">{{ rows.length }}</span>
        </button>
        <button
          v-for="c in categories"
          :key="c.id"
          class="ct-item"
          :class="{ on: categoryId === c.id, off: c.status === '停用' }"
          type="button"
          @click="pickCategory(c.id)"
        >
          <AppIcon :name="c.icon || 'box'" :size="14" />
          <span class="ct-name">{{ c.name }}</span>
          <span class="ct-num">{{ countOf(c.id) }}</span>
        </button>
        <div class="ct-foot">
          <button v-can="'product.edit'" class="btn-text" type="button" @click="router.push('/products/categories')">
            管理品类与属性
            <AppIcon name="chevron-right" :size="12" />
          </button>
        </div>
      </aside>

      <!-- 右：列表 -->
      <section class="card list-card">
        <div class="toolbar">
          <div class="search">
            <AppIcon name="search" :size="15" />
            <input v-model.trim="keyword" class="input" type="text" placeholder="搜索产品名称 / 物料编码" />
          </div>
          <select v-model="brand" class="select">
            <option value="">全部品牌</option>
            <option v-for="b in brands" :key="b">{{ b }}</option>
          </select>
          <select v-model="mode" class="select">
            <option value="">全部生产方式</option>
            <option>自产</option>
            <option>外采</option>
          </select>
          <div class="spacer" />
          <div class="seg">
            <button
              v-for="s in ['全部', '在售', '停售']"
              :key="s"
              type="button"
              :class="{ on: status === s }"
              @click="status = s"
            >
              {{ s }}
            </button>
          </div>
          <button v-if="hasFilter" class="btn-text" type="button" @click="resetFilter">重置</button>
        </div>

        <div v-if="selected.length" class="bulk-bar">
          <span>已选 <b>{{ selected.length }}</b> 项</span>
          <div class="spacer" />
          <button v-can="'product.edit'" class="btn btn-sm" type="button" @click="batchStatus('在售')">批量上架</button>
          <button v-can="'product.edit'" class="btn btn-sm" type="button" @click="batchStatus('停售')">批量下架</button>
          <button class="btn-text" type="button" @click="selected = []">取消选择</button>
        </div>

        <AppTable
          v-model:selected="selected"
          :selectable="canEdit"
          compact
          :columns="columns"
          :rows="filtered"
          :page-size="10"
          empty-text="没有符合条件的产品"
        >
          <template #cell-name="{ row }">
            <div class="prod-cell">
              <span class="prod-ico"><AppIcon :name="iconOf(row.categoryId)" :size="15" /></span>
              <div class="prod-meta">
                <span class="prod-name" :title="row.name">{{ row.name }}</span>
                <span class="prod-code">{{ row.code }}</span>
              </div>
            </div>
          </template>

          <template #cell-spec="{ row }">
            <span class="spec" :title="specSummary(row)">{{ shortSpec(row) }}</span>
          </template>

          <template #cell-unit="{ row }">
            <div class="unit-cell">
              <span class="nowrap">{{ packingOf(row).main }}</span>
              <span v-if="packingOf(row).sub" class="sub">{{ packingOf(row).sub }}</span>
            </div>
          </template>

          <template #cell-price="{ row }">
            <div class="price-cell">
              <b>¥{{ money(row.prices.standard) }}</b>
              <span class="sub">¥{{ unitPrice(row, row.units[0].name).toFixed(2) }}/{{ row.units[0].name }}</span>
            </div>
          </template>

          <template #cell-stock="{ row }">
            <span class="tag" :class="stockTone[row.stock]">{{ row.stock }}</span>
          </template>

          <template #cell-status="{ row }">
            <span class="tag" :class="row.status === '在售' ? 'tag-success' : 'tag-gray'">{{ row.status }}</span>
          </template>

          <template #cell-ops="{ row }">
            <div class="ops">
              <button v-can="'product.edit'" class="btn-text" type="button" @click="openEdit(row)">编辑</button>
              <button v-can="'product.price'" class="btn-text" type="button" @click="openPrice(row)">调价</button>
              <button v-can="'product.edit'" class="btn-text" type="button" @click="toggleStatus(row)">
                {{ row.status === '在售' ? '下架' : '上架' }}
              </button>
            </div>
          </template>
        </AppTable>
      </section>
    </div>

    <!-- ==================== 新建 / 编辑 ==================== -->
    <ModalDialog
      v-model="editorOpen"
      :title="editing ? `编辑「${form.name}」` : '新建产品'"
      desc="规格字段跟着品类走；价格以销售单位（箱）标价，系统自动折算单价"
      width="wide"
      :ok-text="editing ? '保存' : '创建产品'"
      @confirm="saveProduct"
    >
      <div class="sec">
        <div class="sec-title">基本信息</div>
        <div class="form-grid">
          <div class="field">
            <label class="label">产品名称<span class="req">*</span></label>
            <input v-model.trim="form.name" class="input" placeholder="如：超细纤维洗车毛巾 40×40 300g" />
          </div>
          <div class="field">
            <label class="label">物料编码<span class="req">*</span></label>
            <input v-model.trim="form.code" class="input" placeholder="如：BC-TW4040-300" />
          </div>
          <div class="field">
            <label class="label">品类<span class="req">*</span></label>
            <select v-model="form.categoryId" class="select" @change="onCategoryChange">
              <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
            </select>
          </div>
          <div class="field">
            <label class="label">品牌</label>
            <input v-model.trim="form.brand" class="input" placeholder="如：北辰" />
          </div>
        </div>
      </div>

      <div class="sec">
        <div class="sec-title">
          规格参数
          <span class="sec-hint">{{ currentCategory?.name }} 的字段模板</span>
        </div>
        <div class="form-grid cols-3">
          <div v-for="a in currentAttrs" :key="a.key" class="field">
            <label class="label">{{ a.label }}<span v-if="a.unit" class="unit-tag">（{{ a.unit }}）</span></label>
            <select v-if="a.type === 'select'" v-model="form.specs[a.key]" class="select">
              <option value="">请选择</option>
              <option v-for="o in a.options" :key="o">{{ o }}</option>
            </select>
            <input v-else v-model="form.specs[a.key]" class="input" :placeholder="a.placeholder || `填写${a.label}`" />
          </div>
        </div>
      </div>

      <div class="sec">
        <div class="sec-title">单位与装箱</div>
        <div class="form-grid">
          <div class="field">
            <label class="label">最小单位<span class="req">*</span></label>
            <input v-model.trim="form.baseUnit" class="input" placeholder="条 / 把 / 瓶" />
          </div>
          <div class="field">
            <label class="label">报价单位</label>
            <select v-model="form.saleUnit" class="select">
              <option v-for="u in unitOptions" :key="u" :value="u">{{ u }}</option>
            </select>
          </div>
          <div class="field">
            <label class="label">中包装<span class="lock-tag">0 表示没有</span></label>
            <div class="inline-2">
              <input v-model.number="form.midFactor" class="input" type="number" min="0" placeholder="10" />
              <span class="inline-suffix">{{ form.baseUnit || '个' }} / 包</span>
            </div>
          </div>
          <div class="field">
            <label class="label">整箱数量<span class="req">*</span></label>
            <div class="inline-2">
              <input v-model.number="form.caseFactor" class="input" type="number" min="1" placeholder="200" />
              <span class="inline-suffix">{{ form.baseUnit || '个' }} / 箱</span>
            </div>
          </div>
        </div>
      </div>

      <div class="sec">
        <div class="sec-title">
          价格
          <span class="sec-hint">单位：元 / {{ form.saleUnit }}</span>
        </div>
        <div class="form-grid" :class="{ 'cols-3': canSeeCost }">
          <div class="field">
            <label class="label">标准价<span class="req">*</span></label>
            <input v-model.number="form.prices.standard" class="input" type="number" min="0" step="0.01" />
          </div>
          <div class="field">
            <label class="label">经销价</label>
            <input v-model.number="form.prices.dealer" class="input" type="number" min="0" step="0.01" />
          </div>
          <div v-if="canSeeCost" class="field">
            <label class="label">成本价<span class="lock-tag">仅管理员 / 财务</span></label>
            <input v-model.number="form.prices.cost" class="input" type="number" min="0" step="0.01" />
          </div>
        </div>
        <p class="price-tip">
          按 {{ form.saleUnit }} 标价，折合
          <b>¥{{ baseUnitPrice.toFixed(2) }}</b> / {{ form.baseUnit || '最小单位' }}
          <template v-if="canSeeCost && margin !== null">，毛利率 <b>{{ margin.toFixed(1) }}%</b></template>
        </p>

        <div class="tier-head">
          <span class="label">阶梯价</span>
          <button class="btn-text" type="button" @click="addTier">+ 加一档</button>
        </div>
        <div v-if="!form.tiers.length" class="tier-empty">未设置阶梯价，按标准价成交</div>
        <div v-for="(t, i) in form.tiers" :key="i" class="tier-row">
          <span class="tier-at">满</span>
          <input v-model.number="t.min" class="input" type="number" min="1" />
          <span class="tier-at">{{ form.saleUnit }}</span>
          <span class="tier-at">单价</span>
          <input v-model.number="t.price" class="input" type="number" min="0" step="0.01" />
          <button class="btn-text danger" type="button" @click="form.tiers.splice(i, 1)">删除</button>
        </div>
      </div>

      <div class="sec">
        <div class="sec-title">供应信息</div>
        <div class="form-grid">
          <div class="field">
            <label class="label">生产方式</label>
            <select v-model="form.mode" class="select">
              <option>自产</option>
              <option>外采</option>
            </select>
          </div>
          <div class="field">
            <label class="label">可发量</label>
            <select v-model="form.stock" class="select">
              <option>充足</option>
              <option>少量</option>
              <option>需排产</option>
            </select>
          </div>
          <div class="field">
            <label class="label">起订量（{{ form.saleUnit }}）</label>
            <input v-model.number="form.moq" class="input" type="number" min="1" />
          </div>
          <div class="field">
            <label class="label">生产周期（天）</label>
            <input v-model.number="form.productionDays" class="input" type="number" min="0" />
          </div>
        </div>
        <label class="check-line">
          <input v-model="form.customizable" type="checkbox" />
          <span>支持贴牌 / 印 LOGO（自产线可做，销售谈单时可承诺）</span>
        </label>
        <div class="field">
          <label class="label">备注</label>
          <textarea v-model.trim="form.remark" class="textarea" rows="2" placeholder="卖点、适用场景、注意事项" />
        </div>
      </div>
    </ModalDialog>

    <!-- ==================== 调价 ==================== -->
    <ModalDialog
      v-model="priceOpen"
      :title="`调整价格 · ${priceRow?.name || ''}`"
      desc="改价只影响之后的报价与合同，已签署单据按当时的价格快照执行"
      ok-text="保存价格"
      @confirm="savePrice"
    >
      <div v-if="priceRow" class="form-grid">
        <div class="field">
          <label class="label">标准价</label>
          <input v-model.number="priceForm.standard" class="input" type="number" min="0" step="0.01" />
        </div>
        <div class="field">
          <label class="label">经销价</label>
          <input v-model.number="priceForm.dealer" class="input" type="number" min="0" step="0.01" />
        </div>
        <div v-if="canSeeCost" class="field">
          <label class="label">成本价</label>
          <input v-model.number="priceForm.cost" class="input" type="number" min="0" step="0.01" />
        </div>
      </div>
      <p v-if="priceRow" class="price-tip">
        单位：元 / {{ priceRow.saleUnit }} · 折合 ¥{{ (priceForm.standard / caseFactorOf(priceRow)).toFixed(2) }} /
        {{ priceRow.units[0].name }}
      </p>
    </ModalDialog>

    <!-- ==================== 导入 ==================== -->
    <ModalDialog
      v-model="importOpen"
      title="批量导入产品"
      desc="按模板填写后上传，编码相同视为更新，编码不存在则新建"
      ok-text="开始导入"
      @confirm="doImport"
    >
      <div class="imp-box">
        <div class="imp-row">
          <span class="imp-label">下载模板</span>
          <button class="btn-text" type="button" @click="downloadTemplate">产品导入模板.csv</button>
        </div>
        <div class="imp-row">
          <span class="imp-label">选择文件</span>
          <input ref="fileInput" type="file" accept=".csv,.xlsx" @change="onFile" />
        </div>
        <p class="imp-note">
          前端已支持校验与预览，上传接口 <code>POST /api/products/import</code> 待后端实现；
          接口就绪前不会写入任何数据。
        </p>
      </div>
    </ModalDialog>
  </div>
</template>

<script setup>
import { onMounted } from 'vue'
import { productApi } from '@/api/products'
import { computed, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import { toast } from '@/composables/useToast'
import { can } from '@/store/permissions'
import {
  productCategories,
  productItems,
    money,
  specSummary,
  unitPrice,
  unitSummary,
  stockTone,
  factorOf
} from '@/data/productCatalog'
import { todayStr } from '@/utils/date'

const router = useRouter()

/* 本地数据：后端就绪后替换为 productApi.list()，字段结构一致 */
const rows = ref([])
async function reload() {
  rows.value = (await productApi.list({ pageSize: 500 })).rows
}
onMounted(() => reload().catch((e) => toast(e.message, 'error')))

const categories = ref([])
onMounted(async () => {
  try { categories.value = await productApi.categories() }
  catch (e) { toast(e.message, 'error') }
})

const categoryName = (id) => categories.value.find((c) => c.id === id)?.name || '未分类'
const keyword = ref('')
const categoryId = ref('')
const brand = ref('')
const mode = ref('')
const status = ref('全部')
const selected = ref([])

const brands = computed(() => [...new Set(rows.value.map((r) => r.brand))])
const hasFilter = computed(
  () => !!(keyword.value || categoryId.value || brand.value || mode.value || status.value !== '全部')
)

const filtered = computed(() =>
  rows.value.filter((r) => {
    if (categoryId.value && r.categoryId !== categoryId.value) return false
    if (brand.value && r.brand !== brand.value) return false
    if (mode.value && r.mode !== mode.value) return false
    if (status.value !== '全部' && r.status !== status.value) return false
    if (keyword.value) {
      const q = keyword.value.toLowerCase()
      if (!`${r.name}${r.code}${r.brand}`.toLowerCase().includes(q)) return false
    }
    return true
  })
)

function countOf(id) {
  return rows.value.filter((r) => r.categoryId === id).length
}
function pickCategory(id) {
  categoryId.value = id
  selected.value = []
}
function resetFilter() {
  keyword.value = ''
  categoryId.value = ''
  brand.value = ''
  mode.value = ''
  status.value = '全部'
}

const canEdit = computed(() => can('product.edit'))
const canPrice = computed(() => can('product.price'))

/* 只读角色（销售、财务）不显示操作列，否则会留一列空白 */
const columns = computed(() => {
  const base = [
    { key: 'name', label: '产品', width: '198px' },
    { key: 'spec', label: '规格', width: '154px' },
    { key: 'unit', label: '装箱', width: '96px' },
    { key: 'price', label: '标准价', width: '116px', align: 'right' },
    { key: 'stock', label: '可发量', width: '76px' },
    { key: 'status', label: '状态', width: '64px' }
  ]
  if (canEdit.value || canPrice.value) {
    base.push({ key: 'ops', label: '操作', width: '124px', align: 'right' })
  }
  return base
})

/** 列表里的规格只放前三项，全量放 title，避免一行挤成两行 */
function shortSpec(row) {
  const cat = categories.value.find((c) => c.id === row.categoryId)
  const vals = (cat?.attrs || []).map((a) => row.specs?.[a.key]).filter((v) => v && v !== '—')
  return vals.slice(0, 3).join(' / ') + (vals.length > 3 ? ` +${vals.length - 3}` : '')
}

/** 「200 条/箱」+ 副行「10 条/包」，比 unitSummary 的斜杠串更好读 */
function packingOf(row) {
  const base = row.units.find((u) => u.factor === 1)?.name || ''
  const box = row.units.find((u) => u.name === '箱')
  const mid = row.units.find((u) => u.factor > 1 && u.name !== '箱')
  return {
    main: box ? `${box.factor} ${base}/箱` : `1 ${base}`,
    sub: mid ? `${mid.factor} ${base}/包` : ''
  }
}

const CATEGORY_ICON = { C01: 'layers', C02: 'grid', C03: 'sparkle', C04: 'shield', C05: 'box' }
function iconOf(id) {
  return CATEGORY_ICON[id] || 'box'
}

/* ---------------- 新建 / 编辑 ---------------- */
const editorOpen = ref(false)
const editing = ref(false)
const canSeeCost = computed(() => can('product.cost'))

const blankForm = () => ({
  id: '',
  code: '',
  name: '',
  categoryId: categories.value[0]?.id || '',
  brand: '北辰',
  specs: {},
  baseUnit: '件',
  midFactor: 0,
  caseFactor: 100,
  saleUnit: '箱',
  prices: { standard: 0, dealer: 0, cost: 0 },
  tiers: [],
  moq: 1,
  productionDays: 7,
  mode: '自产',
  customizable: false,
  stock: '充足',
  status: '在售',
  remark: ''
})
const form = reactive(blankForm())

const currentCategory = computed(() => categories.value.find((c) => c.id === form.categoryId))
const currentAttrs = computed(() => currentCategory.value?.attrs || [])
const unitOptions = computed(() => {
  const list = [form.baseUnit || '件']
  if (form.midFactor > 0) list.push('包')
  list.push('箱')
  return [...new Set(list)]
})
const caseFactorOf = (p) => factorOf(p, p.saleUnit) || 1
const baseUnitPrice = computed(() => {
  const f = form.saleUnit === '箱' ? form.caseFactor : form.saleUnit === '包' ? form.midFactor : 1
  return (Number(form.prices.standard) || 0) / (f || 1)
})
const margin = computed(() => {
  const s = Number(form.prices.standard) || 0
  const c = Number(form.prices.cost) || 0
  if (!s) return null
  return ((s - c) / s) * 100
})

function fillForm(row) {
  const units = row.units || []
  const base = units.find((u) => u.factor === 1)?.name || '件'
  const mid = units.find((u) => u.factor > 1 && u.name !== '箱')
  const box = units.find((u) => u.name === '箱') || units[units.length - 1]
  Object.assign(form, {
    id: row.id,
    code: row.code,
    name: row.name,
    categoryId: row.categoryId,
    brand: row.brand,
    specs: { ...row.specs },
    baseUnit: base,
    midFactor: mid ? mid.factor : 0,
    caseFactor: box ? box.factor : 1,
    saleUnit: row.saleUnit,
    prices: { ...row.prices },
    tiers: (row.tiers || []).map((t) => ({ ...t })),
    moq: row.moq,
    productionDays: row.productionDays,
    mode: row.mode,
    customizable: !!row.customizable,
    stock: row.stock,
    status: row.status,
    remark: row.remark || ''
  })
}

function openCreate() {
  editing.value = false
  Object.assign(form, blankForm())
  editorOpen.value = true
}
function openEdit(row) {
  editing.value = true
  fillForm(row)
  editorOpen.value = true
}
function onCategoryChange() {
  /* 换品类时清空旧字段，避免把毛巾的「克重」带到刷子上 */
  form.specs = {}
}

function buildUnits() {
  const units = [{ name: form.baseUnit || '件', factor: 1 }]
  if (form.midFactor > 0) units.push({ name: '包', factor: Number(form.midFactor) })
  units.push({ name: '箱', factor: Number(form.caseFactor) || 1 })
  /* 报价单位若不在换算链里（比如把最小单位改名了），退回整箱 */
  if (!units.some((u) => u.name === form.saleUnit)) form.saleUnit = '箱'
  return units
}

async function saveProduct() {
  if (!form.name) return toast('请填写产品名称', 'error')
  if (!form.code) return toast('请填写物料编码', 'error')
  if (rows.value.some((r) => r.code === form.code && r.id !== form.id)) return toast('物料编码已存在', 'error')
  if (!(Number(form.prices.standard) > 0)) return toast('标准价必须大于 0', 'error')
  if (!(Number(form.caseFactor) > 0)) return toast('整箱数量必须大于 0', 'error')

  const units = buildUnits()
  const payload = {
    code: form.code,
    name: form.name,
    categoryId: form.categoryId,
    brand: form.brand,
    specs: { ...form.specs },
    units,
    saleUnit: form.saleUnit,
    prices: { ...form.prices },
    tiers: form.tiers.filter((t) => t.min > 0).sort((a, b) => a.min - b.min),
    moq: form.moq,
    productionDays: form.productionDays,
    mode: form.mode,
    customizable: form.customizable,
    stock: form.stock,
    status: form.status,
    remark: form.remark,
    updatedAt: todayStr()
  }

  try {
    if (editing.value) await productApi.update(form.id, payload)
    else await productApi.create(payload)
    editorOpen.value = false
    await reload()
    toast('已保存')
  } catch (e) { toast(e.message, 'error') }
}

async function toggleStatus(row) {
  try {
    await productApi.toggleStatus(row.id, row.status === '在售' ? 'off' : 'on')
    await reload()
  } catch (e) { toast(e.message, 'error') }
}
async function batchStatus(next) {
  try {
    for (const id of selected.value) await productApi.toggleStatus(id, next)
    selected.value = []
  } catch (e) { toast(e.message, 'error') }
  await reload().catch((e) => toast(e.message, 'error'))
}

/* ---------------- 调价 ---------------- */
const priceOpen = ref(false)
const priceRow = ref(null)
const priceForm = reactive({ standard: 0, dealer: 0, cost: 0 })
function openPrice(row) {
  priceRow.value = row
  Object.assign(priceForm, row.prices)
  priceOpen.value = true
}
async function savePrice() {
  try {
    await productApi.updatePrices(priceRow.value.id, priceForm)
    priceOpen.value = false
    await reload()
  } catch (e) { toast(e.message, 'error') }
}

/* ---------------- 导入 / 导出 ---------------- */
const importOpen = ref(false)
const fileInput = ref(null)
const pickedFile = ref('')
function onFile(e) {
  pickedFile.value = e.target.files?.[0]?.name || ''
}
function downloadTemplate() {
  const head = ['物料编码', '产品名称', '品类', '品牌', '规格', '最小单位', '每箱数量', '标准价(元/箱)', '经销价(元/箱)', '起订量', '生产周期(天)', '生产方式', '状态']
  const sample = ['BC-TW4040-300', '超细纤维洗车毛巾 40×40 300g', '洗车毛巾', '北辰', '40×40/300g/超细纤维', '条', '200', '640', '560', '5', '7', '自产', '在售']
  downloadCsv('产品导入模板.csv', [head, sample])
}
function exportCsv() {
  const head = ['物料编码', '产品名称', '品类', '品牌', '规格', '单位换算', '报价单位', '标准价', '经销价', '可发量', '状态']
  const body = filtered.value.map((r) => [
    r.code,
    r.name,
    categoryName(r.categoryId),
    r.brand,
    specSummary(r),
    unitSummary(r),
    r.saleUnit,
    r.prices.standard,
    r.prices.dealer,
    r.stock,
    r.status
  ])
  downloadCsv(`产品列表-${todayStr()}.csv`, [head, ...body])
  toast(`已导出 ${filtered.value.length} 条产品`)
}
function downloadCsv(name, table) {
  const csv = table
    .map((row) => row.map((c) => `"${String(c ?? '').replace(/"/g, '""')}"`).join(','))
    .join('\r\n')
  /* BOM：Excel 打开中文 CSV 不乱码 */
  const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8' })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = name
  a.click()
  URL.revokeObjectURL(a.href)
}
async function doImport() {
  const file = fileInput.value?.files?.[0]
  if (!file) return toast('请先选择导入文件', 'error')
  try {
    const result = await productApi.importFile(file)
    if (result.failed) return toast('导入失败，请检查第 ' + result.errors[0].row + ' 行', 'error')
    importOpen.value = false
    await reload()
    toast('已新增 ' + result.created + ' 条，更新 ' + result.updated + ' 条')
  } catch (e) { toast(e.message, 'error') }
}
</script>

<style scoped>
.prod-layout {
  display: grid;
  grid-template-columns: 204px minmax(0, 1fr);
  gap: 16px;
  align-items: start;
}

/* 左侧品类树 */
.cat-tree {
  padding: 8px;
  position: sticky;
  top: 12px;
}
.ct-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 6px 10px 10px;
  font-size: 12px;
  color: var(--muted);
  font-weight: 550;
}
.ct-count {
  font-variant-numeric: tabular-nums;
  color: var(--faint);
}
.ct-item {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  border: none;
  border-radius: 7px;
  background: transparent;
  font-size: 12.8px;
  color: var(--text);
  cursor: pointer;
  text-align: left;
  transition: background 0.15s;
}
.ct-item:hover {
  background: #f5f8fc;
}
.ct-item.on {
  background: var(--brand-soft);
  color: var(--brand);
  font-weight: 550;
}
.ct-item.off {
  color: var(--faint);
}
.ct-name {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ct-num {
  font-size: 11px;
  color: var(--faint);
  font-variant-numeric: tabular-nums;
}
.ct-foot {
  margin-top: 6px;
  padding: 8px 10px 2px;
  border-top: 1px solid var(--line-soft);
}
.ct-foot .btn-text {
  font-size: 12px;
  display: inline-flex;
  align-items: center;
  gap: 2px;
}

/* 右侧列表 */
.list-card {
  padding: 0;
  overflow: hidden;
}
.toolbar {
  border-bottom: 1px solid var(--line-soft);
}
.bulk-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  background: #f2f7fd;
  border-bottom: 1px solid #e2ecf7;
  font-size: 12.5px;
  color: var(--text);
}
.bulk-bar b {
  color: var(--brand);
}
.spacer {
  flex: 1;
}
.seg {
  display: flex;
  padding: 2px;
  background: #f2f4f7;
  border-radius: 7px;
}
.seg button {
  height: 28px;
  padding: 0 12px;
  border: none;
  background: transparent;
  border-radius: 5px;
  font-size: 12.5px;
  color: var(--muted);
  cursor: pointer;
}
.seg button.on {
  background: #fff;
  color: var(--ink);
  font-weight: 550;
  box-shadow: var(--shadow-xs);
}

/* 8 列挤在 830px 里，内边距必须比默认表格紧一点 */
:deep(.table thead th),
:deep(.table tbody td) {
  padding-left: 12px;
  padding-right: 12px;
}

/* 单元格 */
.prod-cell {
  display: flex;
  align-items: center;
  gap: 9px;
  min-width: 0;
}
.prod-ico {
  width: 30px;
  height: 30px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  background: linear-gradient(150deg, #eef4fb, #e3edf8);
  border: 1px solid #e1eaf5;
  color: var(--brand);
  flex-shrink: 0;
}
.prod-meta {
  display: flex;
  flex-direction: column;
  min-width: 0;
  line-height: 1.45;
}
.prod-name {
  font-size: 13px;
  font-weight: 550;
  color: var(--ink);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.prod-code {
  font-size: 11px;
  color: var(--faint);
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}
.spec {
  display: block;
  font-size: 12px;
  color: var(--muted);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.unit-cell,
.price-cell {
  display: flex;
  flex-direction: column;
  line-height: 1.5;
}
.unit-cell .sub,
.price-cell .sub {
  font-size: 11px;
  color: var(--faint);
  white-space: nowrap;
}
.price-cell {
  align-items: flex-end;
}
.price-cell b {
  font-size: 13px;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
}
.ops {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  flex-wrap: nowrap;
}
.ops .btn-text {
  white-space: nowrap;
}
.nowrap {
  white-space: nowrap;
}

/* 弹窗内区块 */
.sec {
  padding-bottom: 16px;
  margin-bottom: 16px;
  border-bottom: 1px dashed var(--line);
}
.sec:last-child {
  border-bottom: none;
  margin-bottom: 0;
  padding-bottom: 0;
}
.sec-title {
  display: flex;
  align-items: baseline;
  gap: 8px;
  margin-bottom: 10px;
  font-size: 13px;
  font-weight: 600;
  color: var(--ink);
}
.sec-hint {
  font-size: 11.5px;
  font-weight: 400;
  color: var(--faint);
}
.unit-tag,
.lock-tag {
  font-size: 10.5px;
  font-weight: 400;
  color: var(--faint);
}
.lock-tag {
  margin-left: 6px;
  padding: 1px 5px;
  border-radius: 4px;
  background: #f2f4f7;
}
.form-grid.cols-3 {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}
.inline-2 {
  display: flex;
  align-items: center;
  gap: 8px;
}
.inline-2 .input {
  flex: 1;
}
.inline-suffix {
  font-size: 11.5px;
  color: var(--muted);
  white-space: nowrap;
}
.select.short {
  max-width: 160px;
}
.price-tip {
  margin: 10px 0 0;
  font-size: 12px;
  color: var(--muted);
  padding: 8px 10px;
  border-radius: 7px;
  background: #f7fafd;
}
.price-tip b {
  color: var(--ink);
}
.tier-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 14px;
}
.tier-empty {
  margin-top: 6px;
  font-size: 12px;
  color: var(--faint);
}
.tier-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 8px;
}
.tier-row .input {
  width: 108px;
}
.tier-at {
  font-size: 12px;
  color: var(--muted);
  white-space: nowrap;
}
.check-line {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 12px 0;
  font-size: 12.5px;
  color: var(--text);
  cursor: pointer;
}
.check-line input {
  accent-color: var(--brand);
}
.textarea {
  width: 100%;
  padding: 8px 10px;
  border: 1px solid var(--line);
  border-radius: 8px;
  font-size: 12.8px;
  font-family: inherit;
  color: var(--text);
  resize: vertical;
}
.textarea:focus {
  outline: none;
  border-color: var(--brand);
}

/* 导入 */
.imp-box {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.imp-row {
  display: flex;
  align-items: center;
  gap: 14px;
  font-size: 12.8px;
}
.imp-label {
  width: 68px;
  color: var(--muted);
  flex-shrink: 0;
}
.imp-note {
  margin: 0;
  padding: 10px 12px;
  border-radius: 8px;
  background: #fffbf2;
  border: 1px solid #f0dfc0;
  font-size: 12px;
  line-height: 1.7;
  color: #8a6a24;
}
.imp-note code {
  padding: 1px 4px;
  border-radius: 4px;
  background: #f6edda;
  font-size: 11.5px;
}
</style>
