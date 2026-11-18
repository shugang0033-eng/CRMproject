<template>
  <div v-if="conflicts.length" class="cf">
    <div class="cf-head">
      <span class="cf-ico"><AppIcon name="flag" :size="13" /></span>
      <strong>可能撞单</strong>
      <span class="cf-sub">{{ conflicts.length }} 条重复记录</span>
    </div>

    <ul class="cf-list">
      <li v-for="c in conflicts" :key="`${c.type}-${c.code}-${c.leadId}`">
        <span class="cf-tag" :class="`is-${c.type}`">{{ conflictTypeLabel(c.type) }}</span>
        <div class="cf-main">
          <strong>{{ c.name }}</strong>
          <span>
            {{ c.code }} · {{ ownerText(c) }}<template v-if="c.detail"> · {{ c.detail }}</template>
          </span>
        </div>
      </li>
    </ul>

    <label class="cf-ack">
      <input
        type="checkbox"
        :checked="modelValue"
        @change="$emit('update:modelValue', $event.target.checked)"
      />
      <span>
        我已核对，不是同一家店或已与对方负责人沟通，仍要{{ actionLabel
        }}<template v-if="targetName">给 {{ targetName }}</template>
      </span>
    </label>
  </div>
</template>

<script setup>
import AppIcon from './AppIcon.vue'
import { conflictTypeLabel } from '@/composables/useLeadConflicts'

defineProps({
  /* 已按目标接收人过滤过的冲突项 */
  conflicts: { type: Array, default: () => [] },
  /* 勾选「已知悉」状态 */
  modelValue: { type: Boolean, default: false },
  targetName: { type: String, default: '' },
  actionLabel: { type: String, default: '分配' },
  /* api / local，仅用于悬浮说明核对来源 */
  source: { type: String, default: 'local' }
})

defineEmits(['update:modelValue'])

function ownerText(c) {
  if (c.owner) return `负责人 ${c.owner}`
  return c.type === 'pool' || !c.ownerId ? '暂无负责人' : '负责人未知'
}
</script>

<style scoped>
.cf {
  margin-top: 14px;
  padding: 11px 13px 12px;
  border: 1px solid #f0dcb4;
  border-radius: var(--radius-sm);
  background: #fffcf4;
}
.cf-head {
  display: flex;
  align-items: center;
  gap: 8px;
}
.cf-ico {
  width: 20px;
  height: 20px;
  border-radius: 5px;
  display: grid;
  place-items: center;
  background: #fdf0d5;
  color: #a8730f;
  flex-shrink: 0;
}
.cf-head strong {
  font-size: 12.8px;
  font-weight: 600;
  color: #8a5a06;
}
.cf-sub {
  font-size: 11.8px;
  color: #b08a48;
}

.cf-list {
  margin: 9px 0 0;
  padding: 0;
  list-style: none;
  display: grid;
  gap: 6px;
}
.cf-list li {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  padding: 7px 9px;
  border-radius: 6px;
  background: #fff;
  border: 1px solid #f3e6cc;
}
.cf-tag {
  flex-shrink: 0;
  height: 18px;
  line-height: 18px;
  padding: 0 6px;
  border-radius: 4px;
  font-size: 11px;
  white-space: nowrap;
}
.cf-tag.is-customer {
  background: #fdeeda;
  color: #a1600a;
}
.cf-tag.is-lead {
  background: #e8f0fa;
  color: var(--brand-700);
}
.cf-tag.is-pool,
.cf-tag.is-duplicate {
  background: #f1f3f6;
  color: var(--muted);
}
.cf-main {
  min-width: 0;
  line-height: 1.5;
}
.cf-main strong {
  display: block;
  font-size: 12.5px;
  font-weight: 550;
  color: var(--ink);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cf-main span {
  display: block;
  margin-top: 1px;
  font-size: 11.5px;
  color: var(--faint);
}

.cf-ack {
  display: flex;
  align-items: flex-start;
  gap: 7px;
  margin-top: 10px;
  font-size: 12px;
  line-height: 1.55;
  color: #8a6516;
  cursor: pointer;
  user-select: none;
}
.cf-ack input {
  margin: 2px 0 0;
  accent-color: #d69a26;
}
</style>
