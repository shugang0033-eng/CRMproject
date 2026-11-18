import { reactive } from 'vue'

export const toasts = reactive([])
let seq = 0

export function toast(message, type = 'success') {
  const item = { id: ++seq, message, type }
  toasts.push(item)
  setTimeout(() => {
    const i = toasts.findIndex((t) => t.id === item.id)
    if (i > -1) toasts.splice(i, 1)
  }, 2600)
  return item
}
