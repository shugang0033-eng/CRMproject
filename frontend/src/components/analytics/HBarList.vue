<template>
  <div class="hbl">
    <div v-for="(r, i) in rows" :key="r.label" class="hb-row">
      <span class="hb-rank" :class="{ top: i < 3 }">{{ i + 1 }}</span>
      <div class="hb-main">
        <div class="hb-top">
          <span class="hb-label" :title="r.label">{{ r.label }}</span>
          <span class="hb-val">{{ r.display || value(r) }}</span>
        </div>
        <div class="hb-track">
          <div class="hb-fill" :class="r.tone" :style="{ width: widthOf(r) }" />
        </div>
        <div v-if="r.note || r.sub" class="hb-sub">
          <span>{{ r.note }}</span>
          <span v-if="r.sub" class="hb-pct">{{ r.sub }}</span>
        </div>
      </div>
    </div>
    <div v-if="!rows.length" class="hb-empty">暂无数据</div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  /* [{ label, value, ratio?, note?, sub?, tone?, display? }] */
  rows: { type: Array, default: () => [] },
  /* 分母：不传则用最大值 */
  max: { type: Number, default: 0 },
  /* 值是金额时传 true，自动折万 */
  money: { type: Boolean, default: false }
})

const top = computed(() => {
  if (props.max) return props.max
  return Math.max(1, ...props.rows.map((r) => (r.ratio !== undefined ? r.ratio : r.value)))
})

function widthOf(r) {
  const n = r.ratio !== undefined ? r.ratio : r.value
  return `${Math.max(2, Math.min(100, (n / top.value) * 100))}%`
}

function value(r) {
  if (props.money) return `¥${(r.value / 10000).toFixed(0)} 万`
  return r.value
}
</script>

<style scoped>
.hbl {
  display: flex;
  flex-direction: column;
  gap: 13px;
}
.hb-row {
  display: flex;
  gap: 10px;
  align-items: flex-start;
}
.hb-rank {
  width: 18px;
  height: 18px;
  border-radius: 5px;
  display: grid;
  place-items: center;
  font-size: 10.5px;
  font-weight: 650;
  background: #f2f4f7;
  color: var(--faint);
  flex-shrink: 0;
  margin-top: 1px;
  font-variant-numeric: tabular-nums;
}
.hb-rank.top {
  background: var(--brand-soft);
  color: var(--brand);
}
.hb-main {
  flex: 1;
  min-width: 0;
}
.hb-top {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 5px;
}
.hb-label {
  font-size: 12.5px;
  color: var(--text);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.hb-val {
  font-size: 12.5px;
  font-weight: 600;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}
.hb-track {
  height: 6px;
  border-radius: 3px;
  background: #f2f4f7;
  overflow: hidden;
}
.hb-fill {
  height: 100%;
  border-radius: 3px;
  background: var(--brand);
  transition: width 0.5s cubic-bezier(0.22, 1, 0.36, 1);
}
.hb-fill.success {
  background: var(--success);
}
.hb-fill.warning {
  background: var(--warning);
}
.hb-fill.danger {
  background: var(--danger);
}
.hb-fill.info {
  background: var(--info);
}
.hb-fill.gray {
  background: var(--faint);
}
.hb-sub {
  display: flex;
  justify-content: space-between;
  gap: 8px;
  margin-top: 4px;
  font-size: 11px;
  color: var(--faint);
}
.hb-pct {
  font-variant-numeric: tabular-nums;
}
.hb-empty {
  padding: 18px 0;
  text-align: center;
  font-size: 12px;
  color: var(--faint);
}
</style>
