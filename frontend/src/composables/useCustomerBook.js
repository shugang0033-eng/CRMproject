import { shallowRef } from 'vue'
import { customerApi } from '@/api/customers'

/**
 * 客户档案索引（撞单核对 / 接收人负载共用）
 * ------------------------------------------------------------
 * 这两处都要回答「这家公司现在有没有主」「这个人手里压了多少家客户」。
 * 以前读的是 `@/data/mock` 的演示客户，数字看着有，其实全是编的。
 * 现在统一从 `GET /customers` 拉一次、全模块共享：
 *   - 拉到了 → customerBookReady = true，按姓名 / 公司名比对
 *   - 拉不到（没 customer.view 权限或接口异常）→ 保持空数组并标记未就绪，
 *     调用方提示「客户档案未加载」，不拿 0 冒充真实值。
 */

export const customerBook = shallowRef([])
export const customerBookReady = shallowRef(false)

let pending = null

export function loadCustomerBook(force = false) {
  if (pending && !force) return pending
  pending = customerApi
    .list()
    .then((data) => {
      const rows = Array.isArray(data) ? data : data?.rows || []
      customerBook.value = rows
      /* 成功就算「已知」，客户表本来是空的也应该显示 0 家，而不是「没加载到」 */
      customerBookReady.value = true
      return rows
    })
    .catch(() => {
      customerBook.value = []
      customerBookReady.value = false
      return []
    })
  return pending
}

/* 模块加载即预热：调用方多是同步 computed，等第一次渲染时数据已经在路上 */
loadCustomerBook()
