import { onBeforeUnmount, onMounted, ref } from 'vue'

/**
 * 监听元素宽度，供 SVG 图表按容器实际尺寸重算坐标。
 * 图表不用 viewBox 拉伸，避免文字被等比放大或压扁。
 */
export function useElementWidth(initial = 640) {
  const el = ref(null)
  const width = ref(initial)
  let ro = null

  onMounted(() => {
    if (!el.value || typeof ResizeObserver === 'undefined') return
    ro = new ResizeObserver(([entry]) => {
      const w = Math.round(entry.contentRect.width)
      if (w > 0) width.value = Math.max(240, w)
    })
    ro.observe(el.value)
  })

  onBeforeUnmount(() => ro?.disconnect())

  return { el, width }
}
