<template>
  <div class="page">
    <PageHead title="套装组合" desc="把常一起买的耗材打成一套按套报价：库存仍按子件扣，套装价低于单买价才允许上架">
      <button v-can="'product.edit'" class="btn btn-primary" type="button" @click="openCreate">
        <AppIcon name="plus" :size="14" />新建套装
      </button>
    </PageHead>

    <div class="kit-grid">
      <article v-for="b in rows" :key="b.id" class="card kit" :class="{ off: b.status === '停售' }">
        <div class="kit-head">
          <div class="kit-title">
            <strong>{{ b.name }}</strong>
            <span class="kit-code">{{ b.code }}</span>
          </div>
          <span class="tag" :class="b.status === '在售' ? 'tag-success' : 'tag-gray'">{{ b.status }}</span>
        </div>

        <ul class="kit-items">
          <li v-for="(it, i) in b.items" :key="i">
            <span class="ki-name">{{ productName(it.productId) }}</span>
            <span class="ki-qty">× {{ it.qty }} {{ it.unit }}</span>
            <span class="ki-price">¥{{ money(unitPrice(product(it.productId), it.unit) * it.qty) }}</span>
          </li>
        </ul>

        <div class="kit-sum">
          <span class="ks-label">单买合计</span>
          <span class="ks-origin">¥{{ money(originalOf(b)) }}</span>
        </div>

        <div class="kit-foot">
          <div class="kit-price">
            <b>¥{{ money(b.bundlePrice) }}</b>
            <span class="save" v-if="originalOf(b) > b.bundlePrice">
              省 ¥{{ money(originalOf(b) - b.bundlePrice) }}
              · {{ (((originalOf(b) - b.bundlePrice) / originalOf(b)) * 100).toFixed(0) }}%
            </span>
          </div>
          <div class="kit-ops">
            <button v-can="'product.edit'" class="btn-text" type="button" @click="openEdit(b)">编辑</button>
            <button v-can="'product.edit'" class="btn-text" type="button" @click="toggle(b)">
              {{ b.status === '在售' ? '下架' : '上架' }}
            </button>
          </div>
        </div>

        <p v-if="b.remark" class="kit-note">{{ b.remark }}</p>
      </article>

      <button v-can="'product.edit'" class="kit-add" type="button" @click="openCreate">
        <span class="add-ico"><AppIcon name="plus" :size="18" /></span>
        <strong>新建套装</strong>
        <span>选几个常一起买的 SKU</span>
      </button>
    </div>

    <ModalDialog
      v-model="editorOpen"
      :title="editing ? `编辑「${form.name}」` : '新建套装'"
      desc="子件按产品自身的销售单位计价，库存按子件扣减"
      width="wide"
      :ok-text="editing ? '保存' : '创建套装'"
      @confirm="save"
    >
      <div class="form-grid">
        <div class="field">
          <label class="label">套装名称<span class="req">*</span></label>
          <input v-model.trim="form.name" class="input" placeholder="如：新店开业洗车套餐" />
        </div>
        <div class="field">
          <label class="label">套装编码<span class="req">*</span></label>
          <input v-model.trim="form.code" class="input" placeholder="如：BC-KIT-OPEN" />
        </div>
        <div class="field">
          <label class="label">状态</label>
          <select v-model="form.status" class="select">
            <option>在售</option>
            <option>停售</option>
          </select>
        </div>
        <div class="field">
          <label class="label">套装价（元）<span class="req">*</span></label>
          <input v-model.number="form.bundlePrice" class="input" type="number" min="0" step="0.01" />
        </div>
        <div class="field span-2">
          <label class="label">说明</label>
          <input v-model.trim="form.remark" class="input" placeholder="这套装适合什么门店、卖点是什么" />
        </div>
      </div>

      <div class="items-head">
        <span class="label">包含产品</span>
        <button class="btn-text" type="button" @click="addItem">+ 添加子件</button>
      </div>

      <div v-if="!form.items.length" class="items-empty">还没有子件，至少添加一个产品</div>

      <div v-for="(it, i) in form.items" :key="i" class="item-row">
        <select v-model="it.productId" class="select" @change="onPickProduct(it)">
          <option value="">选择产品</option>
          <option v-for="p in products" :key="p.id" :value="p.id">{{ p.name }}</option>
        </select>
        <input v-model.number="it.qty" class="input qty" type="number" min="1" />
        <select v-model="it.unit" class="select unit" :disabled="!it.productId">
          <option value="">单位</option>
          <option v-for="u in unitsOf(it.productId)" :key="u" :value="u">{{ u }}</option>
        </select>
        <span class="line-price">¥{{ money(linePrice(it)) }}</span>
        <button class="btn-text danger" type="button" @click="form.items.splice(i, 1)">删除</button>
      </div>

      <div class="sum-box">
        <div class="sum-row">
          <span>单买合计</span>
          <b>¥{{ money(originalPrice) }}</b>
        </div>
        <div class="sum-row">
          <span>套装价</span>
          <b class="hl">¥{{ money(form.bundlePrice) }}</b>
        </div>
        <div class="sum-row save-row" v-if="originalPrice > form.bundlePrice">
          <span>客户省</span>
          <b>¥{{ money(originalPrice - form.bundlePrice) }}</b>
        </div>
        <p v-else-if="form.bundlePrice > 0" class="sum-warn">套装价不低于单买价，无法体现套装优惠</p>
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
import ModalDialog from '@/components/ModalDialog.vue'
import { toast } from '@/composables/useToast'
import { money, unitPrice } from '@/data/productCatalog'
import { todayStr } from '@/utils/date'

const catalog = ref([])
onMounted(async () => {
  try { catalog.value = (await productApi.list({ pageSize: 500 })).rows }
  catch (e) { toast(e.message, 'error') }
})
const rows = ref([])
async function reload() {
  rows.value = await productApi.bundles()
}
onMounted(() => reload().catch((e) => toast(e.message, 'error')))

const products = catalog

const product = (id) => catalog.value.find((p) => p.id === id)
const productName = (id) => product(id)?.name || '已删除的产品'
const unitsOf = (id) => product(id)?.units?.map((u) => u.name) || []

function linePrice(it) {
  const p = product(it.productId)
  if (!p || !it.qty) return 0
  return unitPrice(p, it.unit || p.saleUnit) * it.qty
}
function originalOf(b) {
  return b.items.reduce((sum, it) => sum + linePrice(it), 0)
}

/* ---------------- 编辑 ---------------- */
const editorOpen = ref(false)
const editing = ref(false)
const form = reactive({ id: '', code: '', name: '', status: '在售', remark: '', bundlePrice: 0, items: [] })

const originalPrice = computed(() => form.items.reduce((sum, it) => sum + linePrice(it), 0))

function reset() {
  Object.assign(form, { id: '', code: '', name: '', status: '在售', remark: '', bundlePrice: 0, items: [] })
}
function openCreate() {
  editing.value = false
  reset()
  form.items.push({ productId: '', qty: 1, unit: '' })
  editorOpen.value = true
}
function openEdit(b) {
  editing.value = true
  Object.assign(form, {
    id: b.id,
    code: b.code,
    name: b.name,
    status: b.status,
    remark: b.remark,
    bundlePrice: b.bundlePrice,
    items: b.items.map((i) => ({ ...i }))
  })
  editorOpen.value = true
}
function addItem() {
  form.items.push({ productId: '', qty: 1, unit: '' })
}
/* 选完产品把单位落到它的报价单位，避免出现「选了产品但单位空」的零价行 */
function onPickProduct(it) {
  it.unit = product(it.productId)?.saleUnit || ''
}
async function toggle(b) {
  try { await productApi.toggleBundle(b.id, b.status === '在售' ? 'off' : 'on'); await reload() } catch (e) { toast(e.message, 'error') }
  toast(`「${b.name}」已${b.status === '在售' ? '上架' : '下架'}`)
}

async function save() {
  if (!form.name) return toast('请填写套装名称', 'error')
  if (!form.code) return toast('请填写套装编码', 'error')
  if (rows.value.some((r) => r.code === form.code && r.id !== form.id)) return toast('套装编码已存在', 'error')

  const items = form.items.filter((i) => i.productId && i.qty > 0)
  if (!items.length) return toast('至少添加一个子件', 'error')

  /* 子件单位没选时落到产品默认销售单位，避免存进去一个空单位 */
  items.forEach((i) => {
    if (!i.unit) i.unit = product(i.productId)?.saleUnit || '箱'
  })

  if (!(Number(form.bundlePrice) > 0)) return toast('套装价必须大于 0', 'error')

  const payload = {
    code: form.code,
    name: form.name,
    status: form.status,
    remark: form.remark,
    bundlePrice: Number(form.bundlePrice),
    items,
    updatedAt: todayStr()
  }

  try {
    if (editing.value) await productApi.updateBundle(form.id, payload)
    else await productApi.createBundle(payload)
    editorOpen.value = false
    await reload()
    toast('已保存')
  } catch (e) { toast(e.message, 'error') }
}
</script>

<style scoped>
.kit-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 16px;
}
.kit {
  padding: 16px 18px 14px;
  display: flex;
  flex-direction: column;
  transition: box-shadow 0.2s, border-color 0.2s;
}
.kit:hover {
  border-color: #d3dce8;
  box-shadow: var(--shadow-sm);
}
.kit.off {
  opacity: 0.78;
}
.kit-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 10px;
}
.kit-title {
  display: flex;
  flex-direction: column;
  line-height: 1.45;
  min-width: 0;
}
.kit-title strong {
  font-size: 14px;
  font-weight: 600;
  color: var(--ink);
}
.kit-code {
  font-size: 11px;
  color: var(--faint);
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}

.kit-items {
  margin: 12px 0 10px;
  padding: 0;
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 5px;
}
.kit-items li {
  display: flex;
  align-items: baseline;
  gap: 8px;
  font-size: 12.2px;
  color: var(--muted);
}
.ki-name {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ki-qty {
  color: var(--text);
  white-space: nowrap;
}
.ki-price {
  font-variant-numeric: tabular-nums;
  color: var(--faint);
  white-space: nowrap;
}

.kit-sum {
  display: flex;
  justify-content: space-between;
  padding-top: 10px;
  border-top: 1px dashed var(--line);
  font-size: 12px;
  color: var(--faint);
}
.ks-origin {
  text-decoration: line-through;
  font-variant-numeric: tabular-nums;
}

.kit-foot {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  margin-top: 10px;
}
.kit-price b {
  font-size: 19px;
  font-weight: 650;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.3px;
}
.save {
  display: block;
  margin-top: 2px;
  font-size: 11.5px;
  color: var(--success);
}
.kit-ops {
  display: flex;
  gap: 10px;
}
.kit-note {
  margin: 10px 0 0;
  min-height: 34px;
  padding-top: 9px;
  border-top: 1px solid var(--line-soft);
  font-size: 11.5px;
  line-height: 1.6;
  color: var(--faint);
}

.kit-add {
  border: 1px dashed #d5dce6;
  border-radius: var(--radius);
  background: #fcfdfe;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 30px 18px;
  min-height: 200px;
  cursor: pointer;
  color: var(--faint);
  transition: all 0.18s;
}
.kit-add:hover {
  border-color: var(--brand);
  background: #f8fbff;
  color: var(--brand);
}
.add-ico {
  width: 38px;
  height: 38px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: #f1f5fa;
  color: inherit;
  margin-bottom: 2px;
}
.kit-add strong {
  font-size: 13px;
  font-weight: 550;
  color: var(--text);
}
.kit-add span:last-child {
  font-size: 11.5px;
}

.items-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin: 16px 0 8px;
}
.items-empty {
  padding: 14px;
  border: 1px dashed var(--line);
  border-radius: 8px;
  font-size: 12px;
  color: var(--faint);
  text-align: center;
}
.item-row {
  display: grid;
  grid-template-columns: 1fr 68px 76px 82px 40px;
  gap: 8px;
  align-items: center;
  margin-bottom: 8px;
}
.item-row .qty,
.item-row .unit {
  min-width: 0;
}
.line-price {
  padding-right: 4px;
  font-size: 12.5px;
  color: var(--muted);
  text-align: right;
  font-variant-numeric: tabular-nums;
}

.sum-box {
  margin-top: 14px;
  padding: 12px 14px;
  border-radius: 9px;
  background: #f7fafd;
  border: 1px solid #e4edf7;
}
.sum-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 12.5px;
  color: var(--muted);
  padding: 3px 0;
}
.sum-row b {
  font-size: 14px;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
}
.sum-row b.hl {
  color: var(--brand);
  font-size: 16px;
}
.save-row b {
  color: var(--success);
}
.sum-warn {
  margin: 6px 0 0;
  font-size: 11.5px;
  color: var(--warning);
}
</style>
