import { request } from './http'

/**
 * 产品管理接口（契约先行，后端尚未实现）
 * ------------------------------------------------------------
 * 页面当前用本地数据演示，后端就绪后把视图里的本地数组换成这些方法即可，
 * 参数与返回结构不用再改。完整字段与校验见 docs/products-api.md。
 *
 * 通用约定：
 *  - 金额用「元」的 decimal(12,2)，与前端展示一致，不传分，避免换算错位。
 *  - 价格一律以最小单位（条 / 把 / 瓶 / 片 / 卷）为基准，saleUnit 只是报价单位；
 *    列表里的「箱价」由 单价 × 每箱数量 算出来，不单独存。
 *  - 列表接口统一返回 { rows, total, page, pageSize }。
 */

export const productApi = {
  /* ---------------- 产品 ---------------- */
  /** GET /api/products?keyword=&categoryId=&brand=&status=&mode=&page=1&pageSize=20 */
  list: (params = {}) => request('/products', { query: params }),
  /** GET /api/products/{id} */
  detail: (id) => request(`/products/${id}`),
  /** POST /api/products  201 */
  create: (body) => request('/products', { method: 'POST', body }),
  /** PUT /api/products/{id}  204 */
  update: (id, body) => request(`/products/${id}`, { method: 'PUT', body }),
  /** PATCH /api/products/{id}/status  { status: 'on' | 'off' } */
  toggleStatus: (id, status) => request(`/products/${id}/status`, { method: 'PATCH', body: { status } }),
  /** PATCH /api/products/{id}/stock   { stock: 'enough' | 'low' | 'made_to_order' } */
  updateStock: (id, stock) => request(`/products/${id}/stock`, { method: 'PATCH', body: { stock } }),
  /** DELETE /api/products/{id}  204；已被合同引用时 409 */
  remove: (id) => request(`/products/${id}`, { method: 'DELETE' }),
  /** POST /api/products/import  multipart  -> { created, updated, failed, errors[] } */
  importFile: (file) => {
    const body = new FormData()
    body.append('file', file)
    return request('/products/import', { method: 'POST', body })
  },
  /** GET /api/products/export?keyword=...  -> 文件流 */
  exportFile: (params = {}) => request('/products/export', { query: params, raw: true }),

  /* ---------------- 品类 ---------------- */
  /** GET /api/product-categories -> Category[]（含 attrs 模板与 productCount） */
  categories: () => request('/product-categories'),
  /** POST /api/product-categories  201 */
  createCategory: (body) => request('/product-categories', { method: 'POST', body }),
  /** PUT /api/product-categories/{id}  204；attars 整包覆盖 */
  updateCategory: (id, body) => request(`/product-categories/${id}`, { method: 'PUT', body }),
  /** DELETE /api/product-categories/{id}  204；有产品或历史单据引用时 409 */
  removeCategory: (id) => request(`/product-categories/${id}`, { method: 'DELETE' }),

  /* ---------------- 价格 ---------------- */
  /** GET /api/products/prices?categoryId= -> 含成本价与毛利率，需 product.cost */
  priceList: (params = {}) => request('/products/prices', { query: params }),
  /** PUT /api/products/{id}/prices  { standard, dealer, cost, tiers[] } */
  updatePrices: (id, body) => request(`/products/${id}/prices`, { method: 'PUT', body }),
  /** POST /api/products/prices/batch  { ids[], kind, mode: 'amount'|'percent', value } */
  batchAdjust: (body) => request('/products/prices/batch', { method: 'POST', body }),
  /** GET /api/customer-prices -> 协议价列表 */
  customerPrices: () => request('/customer-prices'),
  /** PUT /api/customer-prices/{customerId}  { discount, productIds[] } */
  saveCustomerPrice: (customerId, body) => request(`/customer-prices/${customerId}`, { method: 'PUT', body }),

  /* ---------------- 套装 ---------------- */
  /** GET /api/product-bundles */
  bundles: () => request('/product-bundles'),
  /** POST /api/product-bundles  201 */
  createBundle: (body) => request('/product-bundles', { method: 'POST', body }),
  /** PUT /api/product-bundles/{id}  204 */
  updateBundle: (id, body) => request(`/product-bundles/${id}`, { method: 'PUT', body }),
  /** PATCH /api/product-bundles/{id}/status  { status: 'on' | 'off' } */
  toggleBundle: (id, status) => request(`/product-bundles/${id}/status`, { method: 'PATCH', body: { status } })
}

export default productApi

