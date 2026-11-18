<template>
  <Teleport to="body">
    <div class="toast-host">
      <transition-group name="toast">
        <div v-for="t in toasts" :key="t.id" class="toast" :class="t.type">
          <AppIcon :name="iconOf(t.type)" :size="15" />
          <span>{{ t.message }}</span>
        </div>
      </transition-group>
    </div>
  </Teleport>
</template>

<script setup>
import AppIcon from './AppIcon.vue'
import { toasts } from '@/composables/useToast'

/* info 用于「已在前端演示生效、接口待接入」这类提示，不要用绿色对勾冒充成功 */
function iconOf(type) {
  if (type === 'error') return 'close'
  if (type === 'info') return 'dot'
  return 'check-circle'
}
</script>

<style scoped>
.toast-host {
  position: fixed;
  top: 18px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 200;
  display: flex;
  flex-direction: column;
  gap: 8px;
  pointer-events: none;
}
.toast {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 16px;
  border-radius: 9px;
  background: #fff;
  border: 1px solid var(--line);
  box-shadow: 0 10px 30px rgba(16, 24, 40, 0.14);
  font-size: 13px;
  color: var(--ink);
}
.toast.success svg {
  color: var(--success);
}
.toast.error svg {
  color: var(--danger);
}
.toast.info svg {
  color: var(--brand);
}
.toast-enter-active,
.toast-leave-active {
  transition: all 0.22s ease;
}
.toast-enter-from,
.toast-leave-to {
  opacity: 0;
  transform: translateY(-8px);
}
</style>
