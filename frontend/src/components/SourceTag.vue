<template>
  <span class="src-tag" :class="mode" :title="title">
    <AppIcon :name="mode === 'live' ? 'check' : 'clock'" :size="12" />
    {{ mode === 'live' ? '实时数据' : '演示数据' }}
  </span>
</template>

<script setup>
import { computed } from 'vue'
import AppIcon from '@/components/AppIcon.vue'

const props = defineProps({
  mode: { type: String, default: 'demo' },
  /* 悬停说明：为什么是演示数据，后端差哪个接口 */
  hint: { type: String, default: '' }
})

const title = computed(() =>
  props.mode === 'live'
    ? '数据来自后端接口'
    : props.hint || '该页接口尚未就绪，数据为前端演示数据，不影响操作预览'
)
</script>

<style scoped>
/* 数据来源标记：联调期让「我看到的到底是不是真数据」一眼可见 */
.src-tag {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  height: 30px;
  padding: 0 10px;
  border-radius: 999px;
  font-size: 12px;
  white-space: nowrap;
  border: 1px solid transparent;
}
/* 演示数据用警示色：这是「数字不是真的」的提醒，不是中性信息，灰色太容易忽略 */
.src-tag.demo {
  color: var(--warning);
  background: var(--warning-bg);
  border-color: rgba(181, 71, 8, 0.2);
}
.src-tag.live {
  color: var(--success);
  background: rgba(18, 128, 92, 0.08);
  border-color: rgba(18, 128, 92, 0.22);
}
</style>
