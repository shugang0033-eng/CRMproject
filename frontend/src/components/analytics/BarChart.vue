<template>
  <div ref="el" class="bchart" :style="{ height: height + 'px' }">
    <svg :width="width" :height="height" role="img">
      <!-- 网格 -->
      <g>
        <line
          v-for="(t, i) in ticks"
          :key="`g${i}`"
          :x1="pad.l"
          :x2="width - pad.r"
          :y1="y(t)"
          :y2="y(t)"
          class="grid"
        />
        <text v-for="(t, i) in ticks" :key="`t${i}`" :x="pad.l - 8" :y="y(t) + 3.5" class="axis" text-anchor="end">
          {{ fmt(t) }}
        </text>
      </g>

      <!-- 柱 -->
      <g v-for="(l, bi) in labels" :key="l">
        <template v-if="stacked">
          <rect
            v-for="(s, si) in series"
            :key="`s${si}`"
            :x="bandX(bi) + barW / 2"
            :y="stackY(bi, si)"
            :width="barW"
            :height="stackH(bi, si)"
            :fill="color(si)"
            rx="2"
          />
        </template>
        <template v-else>
          <rect
            v-for="(s, si) in series"
            :key="`s${si}`"
            :x="groupX(bi, si)"
            :y="y(s.data[bi])"
            :width="barW"
            :height="Math.max(0, y(0) - y(s.data[bi]))"
            :fill="color(si)"
            :opacity="active === null || active === bi ? 1 : 0.45"
            rx="2.5"
          />
        </template>
        <text v-if="showLabel(bi)" :x="bandX(bi) + band / 2" :y="height - 6" class="axis" text-anchor="middle">
          {{ l }}
        </text>
        <rect
          :x="bandX(bi)"
          y="0"
          :width="band"
          :height="height - pad.b"
          fill="transparent"
          @mouseenter="active = bi"
          @mouseleave="active = null"
        />
      </g>
    </svg>

    <div v-if="active !== null" class="tip" :style="tipStyle">
      <div class="tip-head">{{ labels[active] }}</div>
      <div v-for="(s, i) in series" :key="s.name" class="tip-row">
        <i :style="{ background: color(i) }" />
        <span>{{ s.name }}</span>
        <b>{{ fmt(s.data[active]) }}{{ unit }}</b>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'
import { useElementWidth } from '@/composables/useElementWidth'

const props = defineProps({
  labels: { type: Array, required: true },
  /* [{ name, color, data: number[] }] */
  series: { type: Array, required: true },
  height: { type: Number, default: 200 },
  stacked: { type: Boolean, default: false },
  unit: { type: String, default: '万' },
  prescaled: { type: Boolean, default: true }
})

const { el, width } = useElementWidth(680)
const active = ref(null)

const palette = ['#2b6cb0', '#7fa9d4', '#0f766e', '#b45309', '#7c3aed', '#94a3b8']
const color = (i) => props.series[i]?.color || palette[i % palette.length]

const pad = { t: 12, r: 14, b: 24, l: 44 }
const band = computed(() => Math.max(6, (width.value - pad.l - pad.r) / Math.max(1, props.labels.length)))
const barW = computed(() => {
  const n = props.series.length
  return Math.max(4, Math.min(30, (band.value * 0.58) / (props.stacked ? 1 : n)))
})

const max = computed(() => {
  let m = 1
  props.labels.forEach((_, i) => {
    if (props.stacked) {
      m = Math.max(m, props.series.reduce((s, ser) => s + (ser.data[i] || 0), 0))
    } else {
      props.series.forEach((ser) => (m = Math.max(m, ser.data[i] || 0)))
    }
  })
  const step = Math.pow(10, Math.floor(Math.log10(m)))
  return Math.ceil((m * 1.06) / step) * step
})

const ticks = computed(() => Array.from({ length: 5 }, (_, i) => (max.value / 4) * i))

const bandX = (i) => pad.l + i * band.value
const groupX = (bi, si) => {
  const total = barW.value * props.series.length + 2 * (props.series.length - 1)
  return bandX(bi) + (band.value - total) / 2 + si * (barW.value + 2)
}
const y = (v) => pad.t + (1 - v / max.value) * (props.height - pad.t - pad.b)

/* 堆叠：series[0] 贴底，依次向上，和表格里的阅读顺序一致 */
function stackBottom(bi, si) {
  let acc = 0
  for (let k = 0; k < si; k += 1) acc += props.series[k].data[bi] || 0
  return acc
}
function stackY(bi, si) {
  return y(stackBottom(bi, si) + (props.series[si].data[bi] || 0))
}
function stackH(bi, si) {
  return Math.max(0, y(stackBottom(bi, si)) - stackY(bi, si))
}

function fmt(v) {
  if (!Number.isFinite(v)) return '—'
  const n = props.prescaled ? v : v / 10000
  if (Math.abs(n) >= 10000) return `${(n / 10000).toFixed(1)}w`
  return n % 1 === 0 ? n.toLocaleString('zh-CN') : n.toFixed(1)
}

function showLabel(i) {
  if (props.labels.length <= 8) return true
  return i % 2 === 0 || i === props.labels.length - 1
}

const tipStyle = computed(() => {
  const cx = bandX(active.value) + band.value / 2
  const flip = cx > width.value - 130
  return { left: `${cx + (flip ? -10 : 10)}px`, top: '4px', transform: flip ? 'translateX(-100%)' : 'none' }
})
</script>

<style scoped>
.bchart {
  position: relative;
  width: 100%;
}
svg {
  display: block;
}
.grid {
  stroke: #f1f3f7;
  stroke-width: 1;
}
.axis {
  font-size: 10.5px;
  fill: var(--faint);
  font-variant-numeric: tabular-nums;
}
.tip {
  position: absolute;
  z-index: 3;
  pointer-events: none;
  background: rgba(255, 255, 255, 0.98);
  border: 1px solid var(--line);
  border-radius: 8px;
  box-shadow: var(--shadow-sm);
  padding: 8px 10px;
  min-width: 116px;
}
.tip-head {
  font-size: 11px;
  color: var(--faint);
  margin-bottom: 5px;
}
.tip-row {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 11.5px;
  line-height: 1.7;
  color: var(--muted);
}
.tip-row i {
  width: 7px;
  height: 7px;
  border-radius: 2px;
  flex-shrink: 0;
}
.tip-row b {
  margin-left: auto;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
}
</style>
