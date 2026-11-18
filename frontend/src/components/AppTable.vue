<template>
  <div class="tbl">
    <div class="table-wrap">
      <table class="table" :class="{ 'table-compact': compact }">
        <thead>
          <tr>
            <th v-if="selectable" class="col-sel">
              <input
                type="checkbox"
                :checked="allChecked"
                :title="allChecked ? '取消本页全选' : '全选本页'"
                @change="toggleAll"
              />
            </th>
            <th
              v-for="col in columns"
              :key="col.key"
              :style="{ width: col.width, textAlign: col.align || 'left' }"
            >
              {{ col.label }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="(row, i) in pageRows"
            :key="row[rowKey] || i"
            :class="{ 'row-picked': selectable && selected.includes(row[rowKey]) }"
          >
            <td v-if="selectable" class="col-sel">
              <input
                type="checkbox"
                :checked="selected.includes(row[rowKey])"
                @change="toggleRow(row[rowKey], $event.target.checked)"
              />
            </td>
            <td
              v-for="col in columns"
              :key="col.key"
              :style="{ textAlign: col.align || 'left' }"
              :class="col.class"
            >
              <slot :name="`cell-${col.key}`" :row="row" :value="row[col.key]" :index="i">
                {{ row[col.key] ?? '—' }}
              </slot>
            </td>
          </tr>
          <tr v-if="!pageRows.length">
            <td :colspan="columns.length + (selectable ? 1 : 0)">
              <div class="empty">
                <div class="empty-icon">
                  <AppIcon name="inbox" :size="20" />
                </div>
                <slot name="empty">
                  <span>{{ emptyText }}</span>
                </slot>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-if="showPager && rows.length" class="pager">
      <span>共 {{ rows.length }} 条记录 · 第 {{ page }} / {{ totalPages }} 页</span>
      <div class="pager-btns">
        <button :disabled="page === 1" @click="page--">
          <AppIcon name="chevron-left" :size="13" />
        </button>
        <button
          v-for="(p, i) in pageList"
          :key="`${p.value}-${i}`"
          :class="{ active: p.value === page }"
          :disabled="p.gap"
          @click="!p.gap && (page = p.value)"
        >
          {{ p.label }}
        </button>
        <button :disabled="page === totalPages" @click="page++">
          <AppIcon name="chevron-right" :size="13" />
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue'
import AppIcon from './AppIcon.vue'

const props = defineProps({
  columns: { type: Array, required: true },
  rows: { type: Array, default: () => [] },
  rowKey: { type: String, default: 'id' },
  pageSize: { type: Number, default: 8 },
  showPager: { type: Boolean, default: true },
  compact: { type: Boolean, default: false },
  emptyText: { type: String, default: '暂无数据' },
  /* 多选：开启后表格最左多一列复选框，配合 v-model:selected 使用 */
  selectable: { type: Boolean, default: false },
  selected: { type: Array, default: () => [] }
})

const emit = defineEmits(['update:selected'])

const page = ref(1)

const totalPages = computed(() => Math.max(1, Math.ceil(props.rows.length / props.pageSize)))
const pageRows = computed(() => {
  const start = (page.value - 1) * props.pageSize
  return props.rows.slice(start, start + props.pageSize)
})

/* 全选只作用于当前页可见行，避免在分页表格里误选看不见的数据 */
const pageKeys = computed(() => pageRows.value.map((r) => r[props.rowKey]))
const allChecked = computed(
  () => pageKeys.value.length > 0 && pageKeys.value.every((k) => props.selected.includes(k))
)

function toggleAll(e) {
  const next = new Set(props.selected)
  if (e.target.checked) pageKeys.value.forEach((k) => next.add(k))
  else pageKeys.value.forEach((k) => next.delete(k))
  emit('update:selected', [...next])
}

function toggleRow(key, checked) {
  const next = new Set(props.selected)
  if (checked) next.add(key)
  else next.delete(key)
  emit('update:selected', [...next])
}

const pageList = computed(() => {
  const total = totalPages.value
  if (total <= 7) return Array.from({ length: total }, (_, i) => ({ label: i + 1, value: i + 1 }))
  const cur = page.value
  const nums = [...new Set([1, total, cur - 1, cur, cur + 1])]
    .filter((p) => p >= 1 && p <= total)
    .sort((a, b) => a - b)
  const out = []
  nums.forEach((p, i) => {
    if (i && p - nums[i - 1] > 1) out.push({ label: '···', value: p, gap: true })
    out.push({ label: p, value: p })
  })
  return out
})

watch(
  () => props.rows.length,
  () => {
    if (page.value > totalPages.value) page.value = 1
  }
)

function goPage(p) {
  if (typeof p === 'number') page.value = p
}
</script>

<script>
export default { name: 'AppTable' }
</script>

<style scoped>
.tbl {
  width: 100%;
}
.pager-btns button {
  display: inline-grid;
  place-items: center;
}

/* ---- 多选列 ---- */
.col-sel {
  width: 44px;
  padding-right: 0 !important;
  padding-left: 16px !important;
}
.col-sel input {
  width: 14px;
  height: 14px;
  margin: 0;
  accent-color: var(--brand);
  cursor: pointer;
  vertical-align: middle;
}
.table tbody tr.row-picked td,
.table tbody tr.row-picked:hover td {
  background: #eef4fb;
}
</style>
