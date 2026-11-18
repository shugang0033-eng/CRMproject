<template>
  <section class="card chart-card">
    <div class="card-head">
      <div class="ch-left">
        <div class="card-title"><span class="dot" />{{ title }}</div>
        <span v-if="sub" class="card-sub">{{ sub }}</span>
      </div>
      <div class="ch-right">
        <div v-if="legend?.length" class="legend">
          <span v-for="l in legend" :key="l.label">
            <i
              :class="{ line: l.line }"
              :style="l.line ? { borderTopColor: l.color } : { background: l.color }"
            />
            {{ l.label }}
          </span>
        </div>
        <slot name="action" />
      </div>
    </div>
    <div class="card-body" :class="{ flush }">
      <slot />
    </div>
    <div v-if="$slots.foot" class="ch-foot">
      <slot name="foot" />
    </div>
  </section>
</template>

<script setup>
defineProps({
  title: { type: String, required: true },
  sub: { type: String, default: '' },
  /* [{ label, color, line?, dashed? }] */
  legend: { type: Array, default: () => [] },
  /* flush：图表自己贴边，去掉卡片内边距 */
  flush: { type: Boolean, default: false }
})
</script>

<style scoped>
.chart-card {
  display: flex;
  flex-direction: column;
  min-width: 0;
}
.ch-left {
  display: flex;
  align-items: baseline;
  gap: 10px;
  min-width: 0;
}
.ch-right {
  display: flex;
  align-items: center;
  gap: 12px;
}
.legend {
  display: flex;
  align-items: center;
  gap: 14px;
  font-size: 11.5px;
  color: var(--faint);
  flex-wrap: wrap;
}
.legend span {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  white-space: nowrap;
}
.legend i {
  width: 8px;
  height: 8px;
  border-radius: 2px;
  display: inline-block;
}
.legend i.line {
  width: 14px;
  height: 0;
  border-radius: 0;
  border-top-width: 2px;
  background: transparent !important;
  border-color: currentColor;
}
.card-body.flush {
  padding: 0;
}
.ch-foot {
  padding: 10px 18px;
  border-top: 1px solid var(--line-soft);
  background: #fbfcfd;
  border-radius: 0 0 var(--radius) var(--radius);
  font-size: 11.5px;
  color: var(--faint);
  display: flex;
  align-items: center;
  gap: 6px;
}
</style>
