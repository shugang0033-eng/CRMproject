import { computed, ref } from 'vue'
import { request } from '@/api/http'


/**
 * 处理时限（天）。这不是数据库字段，是系统对「这类事该多快处理完」的约定，
 * 用来把待办分成 逾期 / 今天 / 本周，否则所有单据都没有到期日，只能按创建时间堆着。
 */
export const SLA = {
  审批: 2,
  合同: 2,
  发货: 1,
  对账: 3,
  退货: 1,
  线索: 1
}

/** 分组顺序即页面展示顺序 */
export const BUCKETS = [
  { key: 'overdue', label: '已逾期', hint: '超过约定处理时限，优先处理' },
  { key: 'today', label: '今天到期', hint: '今天必须处理完' },
  { key: 'week', label: '本周内', hint: '7 天内到期' },
  { key: 'later', label: '更晚', hint: '还有时间，可稍后处理' }
]

/** 类别顺序 */
export const KINDS = ['审批', '合同', '发货', '对账', '退货', '跟进', '线索']

const KIND_META = {
  审批: { icon: 'check-circle', path: '/finance/approvals', perm: 'approval.view' },
  合同: { icon: 'file', path: '/orders/contracts', perm: 'contract.view' },
  发货: { icon: 'box', path: '/orders', perm: 'order.view' },
  对账: { icon: 'receipt', path: '/orders/statements', perm: 'statement.view' },
  退货: { icon: 'refresh', path: '/orders/returns', perm: 'order.view' },
  跟进: { icon: 'users', path: '/customers/follow-board', perm: 'followup.board' },
  线索: { icon: 'target', path: '/leads', perm: 'lead.view' }
}

export { KIND_META }

const items = ref([])
const loading = ref(false)
const error = ref('')
const loadedAt = ref('')
let inflight = null

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { rows } = await request('/todos')
    items.value = rows
    loadedAt.value = new Date().toISOString()
  } catch (e) {
    items.value = []
    error.value = e.message
  } finally {
    loading.value = false
  }
  return items.value
}
export function useTodos() {
  const refresh = () => {
    if (!inflight) {
      inflight = load().finally(() => {
        inflight = null
      })
    }
    return inflight
  }

  const grouped = computed(() => {
    const map = {}
    BUCKETS.forEach((b) => {
      map[b.key] = items.value.filter((i) => i.bucket === b.key)
    })
    return map
  })

  const byKind = computed(() => {
    const map = {}
    items.value.forEach((i) => {
      map[i.kind] = (map[i.kind] || 0) + 1
    })
    return map
  })

  const counts = computed(() => ({
    total: items.value.length,
    overdue: items.value.filter((i) => i.bucket === 'overdue').length,
    today: items.value.filter((i) => i.bucket === 'today').length,
    week: items.value.filter((i) => i.bucket === 'week').length,
    byKind: byKind.value
  }))

  return { items, grouped, byKind, counts, loading, error, loadedAt, refresh }
}

/** 从列表里移除一条（行内处理成功后调用，避免整页重新聚合） */
export function dropTodo(key) {
  items.value = items.value.filter((i) => i.key !== key)
}
