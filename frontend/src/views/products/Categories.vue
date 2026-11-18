<template>
  <div class="page">
    <PageHead title="品类管理" desc="品类决定产品要填哪些规格字段：毛巾看克重和尺寸，刷子看刷毛与柄型，清洁剂看容量与稀释比">
      <button v-can="'product.edit'" class="btn btn-primary" type="button" @click="openCreate">
        <AppIcon name="plus" :size="14" />新建品类
      </button>
    </PageHead>

    <div class="card notice">
      <span class="n-ico"><AppIcon name="filter" :size="14" /></span>
      <div class="n-txt">
        <strong>属性模板是产品录入的「表单」</strong>
        <p>
          在这里改字段，产品编辑页会立刻按新模板渲染；已有产品的同名字段保留，新增字段为空。
          品类停用后不再出现在新建产品的选项里，但历史产品与单据照常显示。
        </p>
      </div>
    </div>

    <div class="card">
      <AppTable :columns="columns" :rows="rows" :page-size="8" empty-text="还没有品类">
        <template #cell-name="{ row }">
          <div class="cat-cell">
            <span class="cat-ico"><AppIcon :name="row.icon || 'box'" :size="15" /></span>
            <div class="cat-meta">
              <span class="cat-name">{{ row.name }}</span>
              <span class="cat-desc">{{ row.desc }}</span>
            </div>
          </div>
        </template>

        <template #cell-attrs="{ row }">
          <div class="attr-chips">
            <span v-for="a in row.attrs" :key="a.key" class="attr-chip">
              {{ a.label }}<i v-if="a.unit"> {{ a.unit }}</i>
            </span>
          </div>
        </template>

        <template #cell-count="{ row }">
          <span class="count">{{ countOf(row.id) }} 个</span>
        </template>

        <template #cell-status="{ row }">
          <span class="tag" :class="row.status === '启用' ? 'tag-success' : 'tag-gray'">{{ row.status }}</span>
        </template>

        <template #cell-ops="{ row }">
          <div class="ops">
            <button v-can="'product.edit'" class="btn-text" type="button" @click="openEdit(row)">编辑</button>
            <button
              v-can="'product.edit'"
              class="btn-text"
              type="button"
              :disabled="row.status === '停用' && countOf(row.id) > 0"
              :title="row.status === '停用' && countOf(row.id) > 0 ? '品类下还有产品，不能直接启用或删除' : ''"
              @click="toggle(row)"
            >
              {{ row.status === '启用' ? '停用' : '启用' }}
            </button>
          </div>
        </template>
      </AppTable>
    </div>

    <ModalDialog
      v-model="editorOpen"
      :title="editing ? `编辑「${form.name}」` : '新建品类'"
      desc="属性字段决定产品录入时的规格项，顺序即展示顺序"
      width="wide"
      :ok-text="editing ? '保存' : '创建品类'"
      @confirm="save"
    >
      <div class="form-grid">
        <div class="field">
          <label class="label">品类名称<span class="req">*</span></label>
          <input v-model.trim="form.name" class="input" placeholder="如：洗车毛巾" />
        </div>
        <div class="field">
          <label class="label">状态</label>
          <select v-model="form.status" class="select">
            <option>启用</option>
            <option>停用</option>
          </select>
        </div>
        <div class="field span-2">
          <label class="label">品类说明</label>
          <input v-model.trim="form.desc" class="input" placeholder="这个品类涵盖什么产品" />
        </div>
      </div>

      <div class="attr-head">
        <span class="label">属性字段</span>
        <button class="btn-text" type="button" @click="addAttr">+ 添加字段</button>
      </div>

      <div v-if="!form.attrs.length" class="attr-empty">还没有字段，产品录入时只能填名称与价格</div>

      <div v-for="(a, i) in form.attrs" :key="i" class="attr-row">
        <input v-model.trim="a.label" class="input" placeholder="字段名，如 克重" />
        <select v-model="a.type" class="select type-sel">
          <option value="text">文本</option>
          <option value="number">数字</option>
          <option value="select">单选</option>
        </select>
        <input v-model.trim="a.unit" class="input unit-input" placeholder="单位" />
        <input
          v-if="a.type === 'select'"
          v-model.trim="a.optionsText"
          class="input"
          placeholder="选项，用逗号分隔"
        />
        <span v-else class="attr-spacer" />
        <button class="btn-text danger" type="button" @click="form.attrs.splice(i, 1)">删除</button>
      </div>

      <p class="attr-tip">
        演示提示：字段 key 会自动生成；后端接入后由 <code>PUT /api/product-categories/{id}</code> 整包覆盖。
      </p>
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
import { productCategories, productItems } from '@/data/productCatalog'
import { can } from '@/store/permissions'

const rows = ref([])
async function reload() {
  rows.value = await productApi.categories()
}
onMounted(() => reload().catch((e) => toast(e.message, 'error')))

const columns = [
  { key: 'name', label: '品类', width: '260px' },
  { key: 'attrs', label: '规格字段', width: '' },
  { key: 'count', label: '产品数', width: '92px' },
  { key: 'status', label: '状态', width: '84px' },
  { key: 'ops', label: '操作', width: '120px', align: 'right' }
]

function countOf(id) {
  return productItems.filter((p) => p.categoryId === id).length
}

const editorOpen = ref(false)
const editing = ref(false)
const form = reactive({ id: '', name: '', desc: '', status: '启用', attrs: [] })

function reset() {
  Object.assign(form, { id: '', name: '', desc: '', status: '启用', attrs: [] })
}
function openCreate() {
  editing.value = false
  reset()
  editorOpen.value = true
}
function openEdit(row) {
  editing.value = true
  Object.assign(form, {
    id: row.id,
    name: row.name,
    desc: row.desc,
    status: row.status,
    attrs: row.attrs.map((a) => ({ ...a, optionsText: (a.options || []).join('，') }))
  })
  editorOpen.value = true
}
function addAttr() {
  form.attrs.push({ key: '', label: '', type: 'text', unit: '', optionsText: '' })
}
async function toggle(row) {
  try {
    await productApi.updateCategory(row.id, { ...row, status: row.status === '启用' ? '停用' : '启用' })
    await reload()
  } catch (e) { toast(e.message, 'error') }
}

async function save() {
  if (!form.name) return toast('请填写品类名称', 'error')
  if (rows.value.some((r) => r.name === form.name && r.id !== form.id)) return toast('品类名称已存在', 'error')

  const attrs = form.attrs
    .filter((a) => a.label)
    .map((a, i) => ({
      key: a.key || `f${Date.now().toString(36)}${i}`,
      label: a.label,
      type: a.type,
      unit: a.unit || '',
      options:
        a.type === 'select'
          ? a.optionsText.split(/[,，]/).map((s) => s.trim()).filter(Boolean)
          : undefined
    }))

  const payload = { name: form.name, desc: form.desc, status: form.status, attrs, icon: 'box' }
  try {
    if (editing.value) await productApi.updateCategory(form.id, payload)
    else await productApi.createCategory(payload)
    editorOpen.value = false
    await reload()
    toast('已保存')
  } catch (e) { toast(e.message, 'error') }
}
</script>

<style scoped>
.notice {
  display: flex;
  gap: 10px;
  padding: 14px 16px;
  margin-bottom: 16px;
  background: #f7fafd;
  border-color: #d8e3f3;
}
.n-ico {
  width: 26px;
  height: 26px;
  border-radius: 7px;
  display: grid;
  place-items: center;
  background: #e8f0fa;
  color: var(--brand);
  flex-shrink: 0;
}
.n-txt strong {
  display: block;
  font-size: 12.8px;
  color: var(--ink);
  font-weight: 550;
}
.n-txt p {
  margin: 3px 0 0;
  font-size: 12px;
  line-height: 1.7;
  color: var(--muted);
}

.cat-cell {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
}
.cat-ico {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  background: linear-gradient(150deg, #eef4fb, #e3edf8);
  border: 1px solid #e1eaf5;
  color: var(--brand);
  flex-shrink: 0;
}
.cat-meta {
  display: flex;
  flex-direction: column;
  min-width: 0;
  line-height: 1.5;
}
.cat-name {
  font-size: 13px;
  font-weight: 550;
  color: var(--ink);
}
.cat-desc {
  font-size: 11.5px;
  color: var(--faint);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.attr-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.attr-chip {
  display: inline-flex;
  align-items: baseline;
  gap: 3px;
  padding: 3px 8px;
  border-radius: 6px;
  background: #f4f7fb;
  border: 1px solid #e6edf5;
  font-size: 11.5px;
  color: var(--text);
}
.attr-chip i {
  font-style: normal;
  margin-left: 2px;
  font-size: 10.5px;
  color: var(--faint);
}
.count {
  font-size: 12.5px;
  color: var(--muted);
  font-variant-numeric: tabular-nums;
}

.ops {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}

.attr-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin: 16px 0 8px;
}
.attr-empty {
  padding: 14px;
  border: 1px dashed var(--line);
  border-radius: 8px;
  font-size: 12px;
  color: var(--faint);
  text-align: center;
}
.attr-row {
  display: grid;
  grid-template-columns: 1.1fr 92px 76px 1.6fr auto;
  gap: 8px;
  align-items: center;
  margin-bottom: 8px;
}
.attr-row .type-sel,
.attr-row .unit-input {
  min-width: 0;
}
.attr-spacer {
  min-width: 0;
}
.attr-tip {
  margin: 10px 0 0;
  font-size: 11.5px;
  color: var(--faint);
}
.attr-tip code {
  padding: 1px 4px;
  border-radius: 4px;
  background: #f2f4f7;
}
</style>
