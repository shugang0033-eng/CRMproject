<template>
  <span class="avatar" :class="size" :style="style">
    <img v-if="src" :src="src" :alt="name" />
    <template v-else>{{ initials(name) }}</template>
  </span>
</template>

<script setup>
import { computed } from 'vue'
import { nameColor, initials } from '@/utils/avatar'

const props = defineProps({
  name: { type: String, default: '' },
  size: { type: String, default: '' },
  /** 有头像图片时优先显示图片，否则回退到姓名首字 */
  src: { type: String, default: '' }
})

const style = computed(() => ({
  background: props.src ? 'transparent' : nameColor(props.name)
}))
</script>
