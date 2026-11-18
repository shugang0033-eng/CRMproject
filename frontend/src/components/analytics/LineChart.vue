<template>
  <div ref="el" class="lchart" :style="{ height: height + 'px' }">
    <svg :width="width" :height="height" role="img">
      <defs>
        <linearGradient v-for="(s, i) in series" :id="`${gid}-${i}`" :key="i" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" :stop-color="color(i)" stop-opacity="0.22" />
          <stop offset="100%" :stop-color="color(i)" stop-opacity="0.01" />
        </linearGradient>
      </defs>

      <!-- 网格与 Y 轴 -->
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

      <!-- 面积 -->
      <path
        v-for="(s, i) in series"
        v-show="s.area"
        :key="`a${i}`"
        :d="areaPath(s.data)"
        :fill="`url(#${gid}-${i})`"
      />

      <!-- 折线 -->
      <path
        v-for="(s, i) in series"
        :key="`l${i}`"
        :d="linePath(s.data)"
        fill="none"
        :stroke="color(i)"
        :stroke-width="s.width || 2"
        :stroke-dasharray="s.dashed ? '5 4' : ''"
        stroke-linejoin="round"
        stroke-linecap="round"
      />

      <!-- 悬停点 -->
      <g v-if="active !== null">
        <line :x1="x(active)" :x2="x(active)" :y1="pad.t" :y2="height - pad.b" class="cursor" />
        <circle
          v-for="(s, i) in series"
          :key="`c${i}`"
          :cx="x(active)"
          :cy="y(s.data[active])"
          r="3.6"
          :fill="color(i)"
          stroke="#fff"
          stroke-width="1.6"
        />
      </g>

      <!-- X 轴 -->
      <text
        v-for="(l, i) in labels"
        v-show="showLabel(i)"
        :key="`x${i}`"
        :x="x(i)"
        :y="height - 6"
        class="axis"
        text-anchor="middle"
      >
        {{ l }}
      </text>

      <rect
        :x="pad.l"
        :y="0"
        :width="Math.max(0, width - pad.l - pad.r)"
        :height="height - pad.b"
        fill="transparent"
        @mousemove="onMove"
        @mouseleave="active = null"
      />
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
  /* [{ name, color, data: number[], area?, dashed? }] */
  series: { type: Array, required: true },
  height: { type: Number, default: 200 },
  unit: { type: String, default: '万' },
  /* 数值本身是否已经是万元 */
  prescaled: { type: Boolean, default: true }
})

const { el, width } = useElementWidth(680)
const gid = `lc${Math.random().toString(36).slice(2, 8)}`
const active = ref(null)

const palette = ['#2b6cb0', '#0f766e', '#b45309', '#7c3aed']
const color = (i) => props.series[i]?.color || palette[i % palette.length]

const pad = { t: 12, r: 14, b: 24, l: 44 }

const max = computed(() => {
  const all = props.series.flatMap((s) => s.data).filter((v) => Number.isFinite(v))
  const m = Math.max(1, ...all)
  const step = Math.pow(10, Math.floor(Math.log10(m)))
  return Math.ceil((m * 1.06) / step) * step
})

const ticks = computed(() => {
  const n = 4
  return Array.from({ length: n + 1 }, (_, i) => (max.value / n) * i)
})

const innerW = computed(() => Math.max(10, width.value - pad.l - pad.r))
const innerH = computed(() => props.height - pad.t - pad.b)

const x = (i) => pad.l + (props.labels.length <= 1 ? innerW.value / 2 : (i * innerW.value) / (props.labels.length - 1))
const y = (v) => pad.t + (1 - v / max.value) * innerH.value

function linePath(data) {
  return data.map((v, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ')
}
function areaPath(data) {
  if (!data.length) return ''
  const base = y(0)
  return `${linePath(data)} L${x(data.length - 1).toFixed(1)},${base} L${x(0).toFixed(1)},${base} Z`
}

function fmt(v) {
  if (!Number.isFinite(v)) return '—'
  const n = props.prescaled ? v : v / 10000
  /* 万元轴上 1500 写成 1.5k 会让人误读成千，直接给千分位 */
  if (Math.abs(n) >= 10000) return `${(n / 10000).toFixed(1)}w`
  return n % 1 === 0 ? n.toLocaleString('zh-CN') : n.toFixed(1)
}

function showLabel(i) {
  if (props.labels.length <= 8) return true
  return i % 2 === 0 || i === props.labels.length - 1
}

function onMove(e) {
  const rect = e.currentTarget.getBoundingClientRect()
  const px = e.clientX - rect.left
  const n = props.labels.length
  const idx = n <= 1 ? 0 : Math.round((px / rect.width) * (n - 1))
  active.value = Math.min(n - 1, Math.max(0, idx))
}

const tipStyle = computed(() => {
  const cx = x(active.value)
  const flip = cx > width.value - 130
  return {
    left: `${cx + (flip ? -12 : 12)}px`,
    top: '4px',
    transform: flip ? 'translateX(-100%)' : 'none'
  }
})
</script>

<style scoped>
.lchart {
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
.cursor {
  stroke: #cfd9e5;
  stroke-width: 1;
  stroke-dasharray: 3 3;
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
