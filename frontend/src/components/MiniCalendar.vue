<template>
  <div class="cal">
    <div class="cal-head">
      <div class="cal-month">{{ year }} 年 {{ month + 1 }} 月</div>
      <div class="cal-nav">
        <button type="button" @click="shift(-1)"><AppIcon name="chevron-left" :size="14" /></button>
        <button type="button" class="today-btn" @click="toToday">今天</button>
        <button type="button" @click="shift(1)"><AppIcon name="chevron-right" :size="14" /></button>
      </div>
    </div>

    <div class="cal-week">
      <span v-for="w in week" :key="w">{{ w }}</span>
    </div>

    <div class="cal-grid">
      <button
        v-for="cell in cells"
        :key="cell.key"
        type="button"
        class="cal-cell"
        :class="{
          muted: !cell.inMonth,
          today: cell.isToday,
          active: cell.isSelected,
          has: cell.mark
        }"
        @click="select(cell)"
      >
        <span class="d">{{ cell.day }}</span>
        <i v-if="cell.mark" class="mark" />
      </button>
    </div>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue'
import AppIcon from './AppIcon.vue'

const props = defineProps({
  marks: { type: Object, default: () => ({}) }
})
const emit = defineEmits(['select'])

const week = ['一', '二', '三', '四', '五', '六', '日']

const today = new Date()
const year = ref(today.getFullYear())
const month = ref(today.getMonth())
const selectedKey = ref(fmtKey(today))

function fmtKey(d) {
  return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`
}

const cells = computed(() => {
  const first = new Date(year.value, month.value, 1)
  // 周一为一周起点
  const offset = (first.getDay() + 6) % 7
  const start = new Date(year.value, month.value, 1 - offset)
  const list = []
  for (let i = 0; i < 42; i++) {
    const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
    const k = fmtKey(d)
    list.push({
      key: k,
      day: d.getDate(),
      inMonth: d.getMonth() === month.value,
      isToday: k === fmtKey(today),
      isSelected: k === selectedKey.value,
      /* 优先用完整日期做 key（跨月不会标错），兼容老的「按日号」写法 */
      mark: d.getMonth() === month.value && (props.marks[k] ?? props.marks[d.getDate()])
    })
  }
  return list
})

function shift(n) {
  const d = new Date(year.value, month.value + n, 1)
  year.value = d.getFullYear()
  month.value = d.getMonth()
}

function toToday() {
  year.value = today.getFullYear()
  month.value = today.getMonth()
  selectedKey.value = fmtKey(today)
  emit('select', selectedKey.value)
}

function select(cell) {
  selectedKey.value = cell.key
  if (!cell.inMonth) {
    const [y, m] = cell.key.split('-')
    year.value = Number(y)
    month.value = Number(m) - 1
  }
  emit('select', cell.key)
}
</script>

<style scoped>
.cal-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 14px;
}
.cal-month {
  font-size: 14px;
  font-weight: 600;
  color: var(--ink);
}
.cal-nav {
  display: flex;
  align-items: center;
  gap: 2px;
}
.cal-nav button {
  width: 26px;
  height: 26px;
  display: grid;
  place-items: center;
  border: 1px solid transparent;
  background: transparent;
  border-radius: 6px;
  color: var(--muted);
  cursor: pointer;
}
.cal-nav button:hover {
  background: #f2f4f7;
  color: var(--ink);
}
.cal-nav .today-btn {
  width: auto;
  padding: 0 8px;
  font-size: 12px;
  height: 26px;
}
.cal-week {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  margin-bottom: 6px;
}
.cal-week span {
  text-align: center;
  font-size: 11.5px;
  color: var(--faint);
  padding: 4px 0;
}
.cal-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 2px;
}
.cal-cell {
  position: relative;
  height: 38px;
  border: none;
  background: transparent;
  border-radius: 8px;
  color: var(--text);
  font-size: 12.5px;
  font-variant-numeric: tabular-nums;
  cursor: pointer;
  display: grid;
  place-items: center;
  transition: background 0.14s, color 0.14s;
}
.cal-cell:hover {
  background: #f2f5f9;
}
.cal-cell.muted {
  color: #c3c9d3;
}
.cal-cell.today {
  color: var(--brand);
  font-weight: 650;
}
.cal-cell.has .d::after {
  content: '';
  position: absolute;
  left: 50%;
  bottom: 6px;
  width: 4px;
  height: 4px;
  margin-left: -2px;
  border-radius: 50%;
  background: #c9d6e6;
}
.cal-cell.has.today .d::after {
  background: var(--brand);
}
.cal-cell.active {
  background: var(--brand);
  color: #fff;
  font-weight: 600;
  box-shadow: 0 2px 6px rgba(43, 108, 176, 0.32);
}
.cal-cell.active .d::after {
  background: rgba(255, 255, 255, 0.75) !important;
}
.d {
  position: static;
  line-height: 1;
}
</style>
