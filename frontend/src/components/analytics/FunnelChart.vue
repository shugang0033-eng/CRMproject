<template>
  <div class="funnel">
    <div v-for="(s, i) in stages" :key="s.label" class="f-row">
      <div class="f-meta">
        <span class="f-stage">
          {{ s.label }}
          <em v-if="s.desc">{{ s.desc }}</em>
        </span>
        <span class="f-right">
          <b>{{ s.count.toLocaleString('zh-CN') }}</b>
          <i>条</i>
        </span>
      </div>
      <div class="f-track">
        <div class="f-fill" :style="fillStyle(s, i)">
          <span class="f-inner">{{ pctOf(s) }}</span>
        </div>
        <span v-if="i > 0" class="f-conv">转化 {{ s.fromPrev }}%</span>
      </div>
      <div v-if="s.avgDays" class="f-days">平均停留 {{ s.avgDays }} 天</div>
    </div>

    <div v-if="invalid" class="f-invalid">
      <span class="fi-dot" />
      无效线索 <b>{{ invalid.toLocaleString('zh-CN') }}</b> 条，不参与阶段转化计算
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  /* [{ label, count, fromPrev, avgDays, desc }] */
  stages: { type: Array, required: true },
  invalid: { type: Number, default: 0 }
})

const first = () => props.stages[0]?.count || 1

function pctOf(s) {
  return `${((s.count / first()) * 100).toFixed(1)}%`
}

/* 用一个居中的梯形块模拟漏斗收窄：宽度按首段占比，左右各留一半空白 */
function fillStyle(s, i) {
  const w = Math.max(14, (s.count / first()) * 100)
  const hue = 0.42 + i * 0.13
  return {
    width: `${w}%`,
    opacity: Math.min(1, hue),
    margin: '0 auto'
  }
}
</script>

<style scoped>
.funnel {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.f-row + .f-row {
  margin-top: 6px;
}
.f-meta {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 6px;
}
.f-stage {
  font-size: 12.5px;
  color: var(--ink);
  font-weight: 550;
  display: flex;
  align-items: baseline;
  gap: 8px;
  min-width: 0;
}
.f-stage em {
  font-style: normal;
  font-size: 11px;
  color: var(--faint);
  font-weight: 400;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.f-right {
  display: inline-flex;
  align-items: baseline;
  gap: 3px;
  flex-shrink: 0;
}
.f-right b {
  font-size: 13.5px;
  font-weight: 650;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
}
.f-right i {
  font-style: normal;
  font-size: 10.5px;
  color: var(--faint);
}
.f-track {
  position: relative;
  height: 34px;
  border-radius: 5px;
  background: #f6f8fb;
  display: flex;
  align-items: center;
  overflow: hidden;
}
.f-fill {
  height: 26px;
  border-radius: 4px;
  background: linear-gradient(90deg, #3b7cbd, #2b6cb0);
  display: flex;
  align-items: center;
  justify-content: center;
  transition: width 0.55s cubic-bezier(0.22, 1, 0.36, 1);
  min-width: 54px;
}
.f-inner {
  font-size: 10.5px;
  font-weight: 600;
  color: #fff;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}
.f-conv {
  position: absolute;
  right: 10px;
  font-size: 10.5px;
  color: var(--faint);
  font-variant-numeric: tabular-nums;
}
.f-days {
  margin-top: 4px;
  font-size: 10.5px;
  color: var(--faint);
  text-align: right;
}
.f-invalid {
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px dashed var(--line);
  font-size: 11.5px;
  color: var(--faint);
  display: flex;
  align-items: center;
  gap: 6px;
}
.f-invalid b {
  color: var(--muted);
  font-variant-numeric: tabular-nums;
}
.fi-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: var(--faint);
  flex-shrink: 0;
}
</style>
