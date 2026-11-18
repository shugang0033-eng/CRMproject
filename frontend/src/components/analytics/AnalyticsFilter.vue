<template>
  <div class="fbar">
    <div class="seg">
      <button
        v-for="p in periods"
        :key="p.value"
        type="button"
        class="seg-btn"
        :class="{ on: period === p.value }"
        @click="$emit('update:period', p.value)"
      >
        {{ p.label }}
      </button>
    </div>

    <select
      v-if="depts.length"
      class="select"
      :value="dept"
      @change="$emit('update:dept', $event.target.value)"
    >
      <option value="">全部部门</option>
      <option v-for="d in depts" :key="d.id" :value="d.id">{{ d.name }}</option>
    </select>

    <select
      v-if="owners.length"
      class="select"
      :value="owner"
      @change="$emit('update:owner', $event.target.value)"
    >
      <option value="">全部负责人</option>
      <option v-for="o in owners" :key="o.id" :value="o.id">{{ o.name }}</option>
    </select>

    <div class="spacer" />

    <span v-if="scopeLabel" class="scope-chip">
      <AppIcon name="shield" :size="12" />
      {{ scopeLabel }}
    </span>
    <slot name="action" />
  </div>
</template>

<script setup>
import AppIcon from '@/components/AppIcon.vue'

defineProps({
  period: { type: String, default: 'year' },
  dept: { type: String, default: '' },
  owner: { type: String, default: '' },
  periods: { type: Array, default: () => [] },
  depts: { type: Array, default: () => [] },
  owners: { type: Array, default: () => [] },
  /* 当前账号能看到的数据范围，由后端 /api/auth/me 返回 */
  scopeLabel: { type: String, default: '' }
})

defineEmits(['update:period', 'update:dept', 'update:owner'])
</script>

<style scoped>
.fbar {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  margin-bottom: 16px;
}
.spacer {
  flex: 1;
}
.select {
  width: auto;
  min-width: 118px;
  height: 34px;
}

/* 与「销售线索」页顶部分段控件同一套视觉，保持全站一致 */
.seg {
  display: inline-flex;
  gap: 2px;
  padding: 3px;
  border: 1px solid var(--line-soft);
  border-radius: 8px;
  background: #f6f8fa;
}
.seg-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 5px 12px;
  border: 0;
  border-radius: 6px;
  background: none;
  color: var(--muted);
  font-size: 12.5px;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease;
  white-space: nowrap;
}
.seg-btn:hover {
  color: var(--text);
}
.seg-btn.on {
  background: #fff;
  color: var(--ink);
  font-weight: 600;
  box-shadow: var(--shadow-xs);
}

.scope-chip {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  height: 28px;
  padding: 0 10px;
  border-radius: 999px;
  background: var(--brand-soft);
  color: var(--brand);
  font-size: 11.5px;
  font-weight: 500;
  white-space: nowrap;
}
</style>

