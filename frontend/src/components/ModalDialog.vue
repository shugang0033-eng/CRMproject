<template>
  <Teleport to="body">
    <div v-if="modelValue" class="modal-mask" @mousedown.self="close">
      <div class="modal" :class="{ wide: width === 'wide' }" role="dialog">
        <div class="modal-head">
          <div>
            <div class="modal-title">{{ title }}</div>
            <div v-if="desc" class="modal-desc">{{ desc }}</div>
          </div>
          <button class="modal-close" type="button" @click="close">
            <AppIcon name="close" :size="16" />
          </button>
        </div>

        <div class="modal-body">
          <slot />
        </div>

        <div v-if="!hideFooter" class="modal-foot">
          <slot name="footer">
            <button class="btn" type="button" @click="close">{{ cancelText }}</button>
            <button class="btn btn-primary" type="button" :disabled="loading" @click="$emit('confirm')">
              {{ loading ? '处理中…' : okText }}
            </button>
          </slot>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { onBeforeUnmount, watch } from 'vue'
import AppIcon from './AppIcon.vue'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  title: { type: String, default: '' },
  desc: { type: String, default: '' },
  width: { type: String, default: 'normal' },
  okText: { type: String, default: '确定' },
  cancelText: { type: String, default: '取消' },
  loading: { type: Boolean, default: false },
  hideFooter: { type: Boolean, default: false },
  closeOnMask: { type: Boolean, default: true }
})

const emit = defineEmits(['update:modelValue', 'confirm'])

function close() {
  if (!props.closeOnMask) return
  emit('update:modelValue', false)
}

function onKey(e) {
  if (e.key === 'Escape' && props.modelValue) close()
}

watch(
  () => props.modelValue,
  (open) => {
    document.body.style.overflow = open ? 'hidden' : ''
    if (open) window.addEventListener('keydown', onKey)
    else window.removeEventListener('keydown', onKey)
  }
)

onBeforeUnmount(() => {
  window.removeEventListener('keydown', onKey)
  document.body.style.overflow = ''
})
</script>
