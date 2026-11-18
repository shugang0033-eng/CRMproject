<template>
  <article class="tile card">
    <div class="tile-top">
      <span>{{ label }}</span>
      <span class="tile-ico" :class="tone"><AppIcon :name="icon" :size="15" /></span>
    </div>
    <div class="tile-val">
      <template v-if="value == null">—</template>
      <template v-else-if="money">
        <i class="cur">¥</i>{{ wanText(value) }}<i>{{ unit || '万' }}</i>
      </template>
      <template v-else>{{ value }}<i>{{ unit }}</i></template>
    </div>
    <div class="tile-foot">
      <span v-if="delta !== null" class="delta" :class="delta >= 0 ? 'pos' : 'neg'">
        <AppIcon :name="delta >= 0 ? 'arrow-up' : 'arrow-down'" :size="11" />
        {{ Math.abs(delta) }}%
      </span>
      <span class="faint">{{ hint }}</span>
    </div>
  </article>
</template>

<script setup>
import AppIcon from '@/components/AppIcon.vue'

defineProps({
  label: { type: String, required: true },
  value: { type: [Number, String], default: null },
  unit: { type: String, default: '' },
  /* 传了 money 就按「元 → 万」展示 */
  money: { type: Boolean, default: false },
  delta: { type: Number, default: null },
  hint: { type: String, default: '较去年同期' },
  icon: { type: String, default: 'chart' },
  tone: { type: String, default: '' }
})

/** 元 → 万元，带千分位：41313000 → 4,131.3 */
function wanText(v) {
  const [int, dec] = (Number(v) / 10000).toFixed(1).split('.')
  return `${int.replace(/\B(?=(\d{3})+(?!\d))/g, ',')}.${dec}`
}
</script>

<style scoped>
.tile {
  padding: 15px 17px 13px;
  transition: box-shadow 0.2s, transform 0.2s;
}
.tile:hover {
  box-shadow: var(--shadow-sm);
  transform: translateY(-1px);
}
.tile-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 12.5px;
  color: var(--muted);
  gap: 8px;
}
.tile-ico {
  width: 26px;
  height: 26px;
  border-radius: 7px;
  display: grid;
  place-items: center;
  background: var(--brand-soft);
  color: var(--brand);
  flex-shrink: 0;
}
.tile-ico.success {
  background: var(--success-bg);
  color: var(--success);
}
.tile-ico.warning {
  background: var(--warning-bg);
  color: var(--warning);
}
.tile-ico.danger {
  background: var(--danger-bg);
  color: var(--danger);
}
.tile-val {
  margin: 9px 0;
  font-size: 25px;
  font-weight: 650;
  color: var(--ink);
  letter-spacing: -0.2px;
  font-variant-numeric: tabular-nums;
  line-height: 1.1;
  white-space: nowrap;
}
.tile-val .cur {
  font-size: 15px;
  font-style: normal;
  font-weight: 600;
  margin-right: 1px;
}
.tile-val i {
  font-style: normal;
  font-size: 12.5px;
  font-weight: 500;
  color: var(--faint);
  margin-left: 3px;
  letter-spacing: 0;
}
.tile-foot {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 11.5px;
  min-height: 16px;
}
.delta {
  display: inline-flex;
  align-items: center;
  gap: 1px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}
</style>

