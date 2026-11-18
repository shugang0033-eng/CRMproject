import { computed, ref } from 'vue'
import { customerApi } from '@/api/customers'
import { CUSTOMER_CREDIT } from '@/data/orderCenter'

/**
 * 单据页的「客户」下拉选项。
 *
 * 背景：对账单 / 发票 / 回款三个页面原来都直接拿演示常量 CUSTOMER_CREDIT 的 key
 * 当选项，于是下拉里永远是那 10 个假客户，真实客户（比如「开封远洋汽修店」）
 * 根本选不到，也就走不到对账、开票、登记收款。
 *
 * 这里统一从客户接口取，取不到（没连后端 / 演示模式）才退回演示名单，
 * 页面不至于变成空下拉。三个页面共用同一份请求，不会各拉一次。
 */

const people = ref([])
const settled = ref(false) // 是否已经问过接口（成功失败都算）
let task = null

function ensure() {
  if (task) return task
  task = customerApi
    .list()
    .then((list) => {
      people.value = Array.isArray(list) ? list.filter((p) => p && p.name) : []
    })
    .catch(() => {
      people.value = []
    })
    .finally(() => {
      settled.value = true
    })
  return task
}

export function useCustomerOptions() {
  ensure()

  /* 真实客户优先；一个都没有时退回演示名单 */
  const names = computed(() =>
    people.value.length ? people.value.map((p) => p.name) : Object.keys(CUSTOMER_CREDIT)
  )

  /** 名字 → 客户 id；演示客户没有 id，返回 null（调用方据此走演示分支） */
  const idOf = (name) => people.value.find((p) => p.name === name)?.id ?? null

  /** 这个客户是真实客户还是演示名单里的 */
  const isLive = (name) => people.value.some((p) => p.name === name)

  /** 等客户列表落地（成功或失败都会 resolve），给「从别处带客户跳过来」的场景用 */
  const ready = () => ensure()

  return { names, idOf, isLive, ready, waiting: computed(() => !settled.value) }
}
