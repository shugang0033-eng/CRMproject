# 订单中心 · 第二批 / 第三批 接口清单

> 写给后端。第一批（订单 CRUD + 7 个列表）已上线并实测通过，这份只讲**还差什么**。
> 前端接口已经全部封好在 `src/api/orders.js`，方法名和参数就是契约；
> 本轮新增了 `src/api/orderSource.js` 做字段适配与降级，后端补一个接口，页面自动从「演示数据」变成「实时数据」，前端不用再改。

核对时间：2026-11-14 · 实测环境：Spring Boot 8080 + MySQL `crm` · 登录 `admin`

---

## 一、已经有的（不用再动）

| 接口 | 实现情况 | 实测返回 |
|---|---|---|
| `GET /api/orders/{id}` | ✅ | `{order, items, shipments, returns, invoices:[], receipts:[]}` |
| `POST /api/orders` | ✅ | `{id, code, status}`，支持 `requestId` 幂等 |
| `POST /api/orders/{id}/approve` | ✅ | 204 |
| `GET /api/{orders｜contracts｜invoices｜receipts｜statements｜shipments｜returns}` | ✅ 一个方法处理 7 个资源 | `{rows, total}`，行是 `crm_xxx.*` + `customer` + `owner` + `date` |

`OrderQueryService` 里已经做了权限映射（`order.view` / `contract.view` / `invoice.view` / `payment.view` / `statement.view`）和 `data.scope.*` 数据范围递归，这块是对的，后面新增接口照抄这套 `require + checkOwner` 即可。

---

## 二、第一批需要补的 6 个字段 / 3 个行为

这些不是「新功能」，是第一批已经能跑但数据不全，导致页面算不出来。**优先级最高，改动量最小。**

### 2.1 `GET /orders/{id}` 的 `invoices` 和 `receipts` 恒为空数组

```java
"invoices", List.of(), "receipts", List.of()   // OrderWriteService.detail 里写死的
```

影响：订单详情页「回款」链路节点永远是灰的；「未收金额」指标恒为 0；销售看不到这单到底收了多少钱。

要的：

```json
{
  "invoices": [{ "id": 12, "code": "FP-2026-0322", "no": "04412026 3388", "amount": 745600.00, "status": "已开票" }],
  "receipts": [{ "id": 3, "code": "SK-2026-0231", "amount": 300000.00, "payDate": "2026-11-12", "allocated": 300000.00 }]
}
```

取数口径：`invoices` 走 `statement_id IN (该客户该期间的已确认对账单)`，`receipts` 走 `crm_receipt_allocations` 里 `target_type='invoice'` 且发票属于本单的收款单。**不要按客户直接取全部发票**，会把别的单的钱算进来。

### 2.2 列表行缺聚合字段

| 资源 | 补字段 | 用途 | 口径 |
|---|---|---|---|
| `contracts` | `orderedAmount` | 合同页「已下单」进度条 | `SUM(crm_orders.amount) WHERE contract_id=? AND status<>'已取消' AND deleted_at IS NULL` |
| `contracts` | `term_days`（已有列，确保返回） | 账期展示 | 直出 |
| `invoices` | `statementCode` | 发票列表搜「对账单号」、跳转 | `LEFT JOIN crm_statements` |
| `invoices` | `contractCode` | 合同维度统计 | `LEFT JOIN crm_contracts` |
| `invoices` | `settledAmount` | 「已核销 / 未核销」列 | `SUM(receipt_allocations.amount) WHERE target_type='invoice' AND target_id=发票id AND revoked_at IS NULL` |
| `receipts` | `allocatedAmount` | 「已核销 / 未核销」列，现在只有派生的 `status` | 同上，按 `receipt_id` 汇总 |
| `orders` 明细 | `priceSource`、`floorPrice` | 详情页单价来源标签、毛利率列 | 建单时已算过，`crm_order_items` 里有这两列，`SELECT` 时带上即可 |

> 前端适配层就认这几个字段名（`orderedAmount` / `settledAmount` / `allocatedAmount`）。返回了就直接用，没返回就退回演示算法 —— 所以**字段名请保持一致，不要换驼峰**。

### 2.3 `POST /orders` 的错误码与契约不符

契约（`src/api/orders.js`）约定：

- `409` 客户信用额度不足，已转为待审批
- `422` 成交价低于成本价，需上级审批

实际实现是「照样 201，`status` 直接给 `待审批`，`credit_check` 给 `超限`」。前端拿到 201 会以为是成功，toast 提示「已提交」，用户不知道要走审批。

**两个方案，选一个：**

- A（推荐，改动小）：保持 201，但响应体补 `"warnings": ["超出客户可用额度 ¥58,400", "「燃油滤清器」成交价低于成本价"]`，前端按 warnings 展示醒目提示。
- B：改成 409 / 422，前端已有对应文案映射。

我按 A 在前端预留了处理位置（`OrderList.submit` 里 `res.warnings`），你没有返回也不会报错。

---

## 三、第二批接口（对账单 / 发票红冲 / 信用与底价校验）

### 3.1 `GET /api/statements/{id}` 对账单明细

前端：`orderApi.statementDetail(id)` → 对账单「明细」弹窗。现在弹窗是前端用订单临时凑的，需要后端给权威口径。

```json
{
  "statement": { "id": 7, "code": "DZ-2026-10-001", "period": "2026-10", "open": 486000, "shipped": 1039600, "received": 778000, "close": 747600, "status": "已开票" },
  "orders":    [{ "id": 41, "code": "SO-2026-0412", "date": "2026-11-12", "amount": 182000, "status": "已签收" }],
  "invoices":  [{ "id": 12, "code": "FP-2026-0322", "amount": 745600, "status": "已开票", "settled": 300000 }],
  "receipts":  [{ "id": 3, "code": "SK-2026-0231", "amount": 300000, "payDate": "2026-11-12" }]
}
```

`orders` 必须只包含「已签收 + 已发货未签收」的单，`已取消` 和 `草稿` 不能进对账。

### 3.2 `POST /api/statements` 生成对账单

```json
{ "customerId": 12, "period": "2026-11" }
→ 201 { "id": 8, "code": "DZ-2026-11-012", "open": 747600, "shipped": 0, "received": 0, "close": 747600, "status": "待确认", "orders": 0 }
```

服务端口径（**这是对账的全部意义，不能省**）：

```
open      = 上一期 close（没有上一期则 0，或客户首单前的期初欠款）
shipped   = SUM(订单明细金额) WHERE 客户=? AND 发货日 in period AND 已签收，减去当期退货金额
received  = SUM(crm_receipts.amount) WHERE 客户=? AND pay_date in period
close     = open + shipped − received
```

必拦：

- `409` 同客户同账期已存在（`uk_customer_period` 唯一键兜底）
- `400` 账期还没结束且不是当前账期
- 生成即冻结：生成后不能改金额，只能作废重开

> **对账恒等式是硬约束**：`close = open + shipped − received`，差值不为 0 直接 500 回滚。演示数据里 6 张全部可验算，可以当单测期望值。

### 3.3 `POST /api/statements/{id}/confirm`

无 body，`204`。校验：只有 `待确认` 能确认；确认后 `confirmed_at` 落库，状态转 `已确认`。

**前端缺口**：现在确认后前端是从 `r.data.confirmedAt` 拿时间，为空则用本地时间。要精确就返回 `{ "confirmedAt": "2026-11-14 10:22:31" }`。

### 3.4 `GET /api/statements/{id}/export`

返回 xlsx 流（`Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`）。前端 `exportStatement` 已经按 blob 接。

对账单一共四段：期初、本期发货明细、本期回款明细、期末应收。财务拿去盖章的就是这张，格式定死比好看重要。

### 3.5 `POST /api/invoices` 申请开票

```json
{ "statementId": 7, "customerId": 12, "amount": 745600, "taxRate": 0.13, "type": "增值税专用" }
→ 201 { "id": 13, "code": "FP-2026-0323", "amount": 745600, "taxAmount": 85771.68, "status": "待开票" }
```

必拦：

- `409` 对账单未 `已确认`（待确认不能开票）
- `400` 开票金额 > 该对账单可开票余额（`close − 已开票金额 + 已红冲金额`）
- `400` 对账单已全额开票
- 税额倒算：`tax_amount = ROUND(amount * rate / (1 + rate), 2)`。**价税合计是含税数，不是不含税**，这点 invoice 表和 statement 表口径一致，别重复加税。

### 3.6 `POST /api/invoices/{id}/issue` 实际开票

```json
{ "no": "04412026 3388" }
→ 200 { "no": "04412026 3388", "issueDate": "2026-11-07", "status": "已开票" }
```

必拦：`409` 发票号重复（税控号唯一）；`409` 当前状态不是 `待开票`。

### 3.7 `POST /api/invoices/{id}/red-flush` 红冲

```json
{ "reason": "客户要求重开" }
→ 201 { "id": 14, "code": "FP-2026-0324", "redFlushOf": 13, "amount": -745600, "status": "已红冲" }
```

**红冲不是把原票 status 改成「已红冲」就完事**，正确做法是：

1. 原票置 `已红冲`，`red_flush_of` 不动；
2. 新开一张负数发票，`red_flush_of` 指向原票，金额取负；
3. 两张票一起参与应收计算，净额为 0。

必拦：

- `409` 该发票已有核销（`receipt_allocations` 有未撤销记录）→ 必须先反核销再红冲
- `409` 已红冲的票不能再红冲
- `400` 跨年红冲需要财务总监权限（`invoice.redflush` 之外再加一道）

### 3.8 `GET /api/orders/credit` 下单前信用预检

```
?customerId=12&amount=182000
→ { "limit": 500000, "used": 320000, "reserved": 100000, "available": 80000, "enough": false }
```

`reserved` = 该客户「待审批 + 待发货 + 部分发货」订单的占用额。前端下单弹窗实时显示可用额度，超了立刻提示要转审批，别等提交才报错。

### 3.9 `POST /api/orders/quote` 取价预检

```json
{ "customerId": 12, "contractId": 3, "items": [{ "productId": 101, "unit": "箱", "qty": 300 }] }
→ [{ "productId": 101, "unit": "箱", "price": 3360, "priceSource": "合同协议价", "floor": 2800, "margin": 0.1667 }]
```

取价顺序**必须收敛成一个函数**，三处共用（下单、报价、改价复核）：

```
1. 合同订单 → 合同协议价（crm_contract_items.price），且校验协议量剩余
2. 备货订单 → 经销价 / 阶梯价 / 客户协议价 三者取最低
3. 底价 = crm_products.cost_price × 单位换算系数（factorOf），低于底价 → 需审批
```

单位换算必须走 `crm_product_units.factor`，不能拿箱价当瓶价用。**成本价对没有 `product.cost` 权限的角色不要返回**（前端毛利率列就是靠这个字段在不在来决定显不显示的）。

---

## 四、第三批接口（退货换货 / 发货物流）

### 4.1 `POST /api/orders/{id}/shipments` 分批发货

```json
{ "items": [{ "productId": 101, "unit": "箱", "qty": 120 }], "logistics": "德邦物流", "trackingNo": "DB7741 2288 6610", "at": "2026-11-13" }
→ 201 { "id": 9, "code": "FH-2026-0892", "amount": 403200, "status": "运输中" }
```

必拦：

- `400` 发货数量 > 订单该商品未发数量（`qty − shipped_qty`）
- `409` 订单状态不是 `待发货 / 部分发货`
- 事务内三件事必须一起成功：写 `crm_shipments` + `crm_shipment_items`、回写 `crm_order_items.shipped_qty`、扣减库存
- 部分发货后订单状态自动转 `部分发货`，发完转 `已签收`（或签收单确认后转）

### 4.2 `POST /api/returns` 申请退货

```json
{ "orderId": 41, "reason": "质量问题", "note": "毛巾边角脱线", "items": [{ "productId": 101, "unit": "箱", "qty": 40 }] }
→ 201 { "id": 7, "code": "RT-2026-0007", "amount": 134400, "status": "待确认" }
```

必拦：`400` 退货数量 > 已签收数量（不是已发货数量，**未签收不能退**）；`409` 该订单已全额退货。

### 4.3 `POST /api/returns/{id}/confirm` 退货确认

```json
{ "result": "pass", "restock": true }
```

通过时要连锁做四件事，缺一件账就乱：

1. `crm_order_items.returned_qty += qty`
2. 生成红字应收（负数金额挂在原订单上，进下一期对账的 `shipped` 减项）
3. `restock=true` 时回写库存，`false` 时走报废不入库
4. 订单状态：全额退货 → `已退货`，部分 → 保持 `已签收`

### 4.4 `GET /api/shipments/{id}/tracking` 物流轨迹

```
→ { "company": "德邦物流", "trackingNo": "DB7741 2288 6610", "status": "运输中",
    "traces": [{ "at": "2026-11-13 09:12", "text": "杭州转运中心已发出" }] }
```

这块建议**先接快递鸟/快递 100 的聚合接口**，别一家家对接。轨迹只读、失败不影响主流程（超时直接返回空 traces，不要抛错）。

---

## 五、前端接线点（我这轮已经做完，后端上线即生效）

新增 `src/api/orderSource.js`：每个资源独立判定数据来源。

- 接口返回有数据 → 页面标「实时数据」
- 接口 404/405 或表为空 → 保留演示数据，标「演示数据」（橙色标记，页头可见）
- 接口 400/403/409/422 → 照常抛出，toast 出来

接线对照：

| 页面 | 读接口 | 写接口 | 现状 |
|---|---|---|---|
| 订单列表 | `GET /orders` | `POST /orders`、`POST /orders/{id}/approve` | ✅ 已接，表空 → 空态引导 |
| 订单详情 | `GET /orders/{id}` | 发货 / 退货按钮**已画出但禁用** | 等 4.1 / 4.2 |
| 合同 | `GET /contracts` | `POST /contracts/{id}/approve` | 读已接；写等后端 |
| 对账单 | `GET /statements` | `POST /statements`、`/{id}/confirm` | 读已接；写等 3.2 / 3.3 |
| 发票 | `GET /invoices`、`GET /statements` | `POST /invoices`、`{id}/issue`、`{id}/red-flush` | 读已接；写等 3.5–3.7 |
| 回款 | `GET /receipts`、`GET /invoices` | `POST /receipts`、`{id}/allocate` | 读已接；写等第二批 |

**第三批货一发，前端要改的只有一行**：`src/views/orders/OrderDetail.vue` 里 `const canShip = ref(false)` 改成 `true`，发货/退货按钮就通电了。业务逻辑在，只是接口没通时不敢让人点。

---

## 六、必须后端拦的 8 条（前端已经拦了一遍，但前端拦不算数）

1. 对账恒等式 `close = open + shipped − received`，差值 ≠ 0 回滚。
2. 同客户同账期唯一（已建唯一键 `uk_customer_period`）。
3. 开票金额 ≤ 对账单可开票余额。
4. 已有核销的发票不能红冲，必须先反核销。
5. 核销合计 ≤ 收款单到账额；单条核销 ≤ 单据待收额。
6. 退货数量 ≤ 已签收数量；退款金额 = 退货明细金额合计，不允许手填。
7. 发货数量 ≤ 未发数量；库存在事务内扣。
8. 信用额度 = `limit − used − reserved`，`reserved` 必须含「待审批」的占用。

---

## 七、种子数据（需要一个）

7 张表现在全是 0 行，页面只能看演示数据。要验证真实链路，至少需要有：

- 3 个客户 × 各 1 份执行中合同
- 6 张订单，覆盖 待审批 / 待发货 / 部分发货 / 已签收 / 已退货
- 4 条发货、1 条退货、2 张对账单、2 笔收款（1 笔部分核销）、3 张发票（含 1 张红冲）

前端 `src/data/orderCenter.js` 里那套演示数据是**恒等式自洽**的（对账、税额、核销全部可验算），可以直接当 seed 的期望值。需要我生成 `database/crm-orders-seed.sql` 就说一声 —— 按之前的约定，**写库这一步我等你点头**。

---

## 八、建议顺序与人日

```
第 1 步  补 2.1–2.3 的字段与响应           1.5 人日   ← 先做，改完第一批页面立刻完整
第 2 步  credit / quote（取价收敛）         2.0 人日
第 3 步  statements 四个接口 + 恒等式       4.0 人日
第 4 步  invoices 申请/开票/红冲            3.5 人日
第 5 步  receipts 核销 + 反核销             2.5 人日
第 6 步  shipments 分批发货                 2.5 人日
第 7 步  returns 退货 + 四连锁              3.0 人日
第 8 步  物流轨迹对接（可选）                1.5 人日
第 9 步  seed 数据 + 联调                   2.0 人日
                                        合计 22.5 人日
```

为什么这个顺序：核销依赖发票，发票依赖对账单，对账依赖发货事实。**倒过来做会返工**。

砍到最小可用（只做对账 + 开票，不做红冲/退货/物流）约 12 人日，但我不建议砍退货 —— 汽配行业退换货是常态，没有退货单，销售会用「取消订单」绕过，账就烂了。

---

## 附录：回款核销 —— 口径已定 + 后端待办（2026-11-16）

### 一、业务口径（已拍板）

> **核销只认发票。合同不参与核销，合同回款进度在合同详情单独登记。**

理由：同一笔钱「先核合同、开票后再核发票」会在 `crm_receipt_allocations` 里落两条记录，
合同侧没有任何字段标记「这笔已转成发票核销」，两边各算一次，账永远对不平。
与其做自动冲抵（要引入「合同核销 → 发票核销」的转移关系，复杂度高且容易出错），
不如只留一条正道：**钱到了先挂在到账上，发票开出来再核到发票。**

由此推出三条界面规则（前端已实现）：

1. 核销弹窗只列「已开票且待收 > 0」的发票；
2. 客户没发票时弹窗是空表，明确提示「钱先挂在这笔到账上，等开票再核」——
   不再拿合同凑数，也不假装有可核对象；
3. 合同回款在合同详情登记，核销弹窗里写明「合同不参与核销」。

### 二、现在真的能跑的接口

`GET /api/receipts/{id}`：

| 字段 | 内容 | 前端用途 |
|---|---|---|
| `allocations` | 已核销记录（`id` / `targetType` / `target` 单号 / `amount` / `at`） | 「已核销记录」列表 + 反核销要用的 `id` |
| `availableInvoices` | 本客户**已开票且待收 > 0** 的发票 | 核销候选行 |
| `availableContracts` | 本客户执行中/已完成且待收 > 0 的合同 | **前端已不用**（见待办 2） |

`POST /api/receipts/{id}/allocate`：

```json
{ "allocations": [ { "targetType": "invoice", "targetId": 12, "amount": 5000 } ] }
```

后端已拦：目标属于同一客户、状态合法、单条 ≤ 待收、合计 ≤ 到账额；一批里任一条不合格整批回滚。

`POST /api/receipts/{id}/revoke-allocation`：

```json
{ "allocationId": 12, "reason": "核错单据" }
```

软删除（`revoked_at` + `revoke_reason`），权限 `payment.confirm`。

### 三、前端 2026-11-16 做完的

1. **弹窗只列发票**（原先把 `availableContracts` 一起列出，与上面的口径冲突，已移除）。
2. **反核销上线**：「已核销记录」每行一个「反核销」，就地填理由（必填，≥2 字），
   调 `revoke-allocation` 后把该条从列表移除、`allocatedAmount` 回退，这笔钱回到「待核销」。
   失败不改本地任何状态。
3. **`alreadyAllocated` 判断写错**：`computed` 返回布尔值，模板却写 `alreadyAllocated.length`
   （永远 undefined），「已核销记录」区块从来没渲染过——顺手修掉，反核销才有地方点。
4. **发票金额按单号回查取不到**：`adaptInvoice` 把发票号存在 `id` 上、没有 `code` 字段，
   原先按 `x.code` 匹配永远失败，金额列退化成「待收」、已核销恒显示 ¥0。
   改成 `x.code === i.code || x.id === i.code`，现在 `¥40,000 / 已核销 ¥33,000 / 待收 ¥7,000` 都对。
5. 核销成功后会重拉一次 `receiptDetail`，拿到新记录的 `id`（`allocate` 只回 204 不带 id），
   否则刚核完那条没有反核销按钮。
6. 输入超限当场标红（上限 = min(单据待收, 本笔未核销)）；成功提示的「剩余」提交前定格，不再出负数；
   汇总卡统一口径并改名为「累计到账」。

### 四、后端待办（按优先级）

**P0 — 不改会出错**

1. **`availableInvoices` 补 `i.amount`**

   ```sql
   SELECT i.id, i.code, i.amount,
          i.amount - COALESCE((SELECT SUM(a.amount) FROM crm_receipt_allocations a
            WHERE a.target_type='invoice' AND a.target_id=i.id AND a.revoked_at IS NULL),0) AS available
   FROM crm_invoices i WHERE i.customer_id=? AND i.status='已开票' HAVING available>0
   ```

   现在没带 `i.amount`，前端只能去 `/invoices` 列表按单号回查。发票超过一页（或客户发票多）就查不到，
   金额列会显示成「待收」，财务会误判。这是一行 SQL 的事。

2. **`allocate` 显式拒绝 `targetType='contract'`**

   口径定了不用合同核销，但接口还接受。别的客户端、脚本、以后的人照着旧文档调，账又会分裂。
   建议直接 `throw error(HttpStatus.BAD_REQUEST)` 并返回明确文案
   （「合同不参与核销，请核到发票」），把这半条路关死。

3. **`availableContracts` 下线**

   既然前端不用了，留着只会误导。要么删字段，要么改名 `pendingContracts` 并只用于
   「合同详情 · 预收登记」页面展示，注释写清「不可作为核销目标」。

**P1 — 审计与防重**

4. **反核销没记谁操作的**：`revoke` 只写 `revoked_at` / `revoke_reason`，
   没有 `revoked_by`。财务场景「谁把核销退了」必须可查。加一列并写入 `employeeId`：

   ```sql
   ALTER TABLE crm_receipt_allocations ADD COLUMN revoked_by BIGINT NULL AFTER revoke_reason;
   ```

   同时 `allocations` 返回里带上 `revokedBy`（反核销记录前端目前不展示历史，接口先备着）。

5. **反核销建议独立权限**：现在跟核销共用 `payment.confirm`，
   意味着能核销的人就能一键退回自己的核销。建议拆 `payment.revoke`，
   默认只给财务主管，前端按 `can('payment.revoke')` 决定显不显示按钮。

6. **`allocate` 没有幂等键**：快速双击会提交两次（前端只在点击时置忙，网络重试挡不住）。
   要么接 `requestId`（`crm_receipts` 已有这个字段的先例），要么在 `crm_receipt_allocations`
   上对 `(receipt_id, target_type, target_id, amount, created_at 秒)` 加唯一约束兜底。

**P2 — 顺带清理**

7. **`targetType='order'` 半条路**：后端支持但 `receiptDetail` 不给候选，前端选不到。
   按口径一起关掉，或补齐 `availableOrders` 并想清楚它和发票核销的关系。

8. **红冲发票**：`availableInvoices` 里 `status='已开票'` 会把金额为负的红冲票（如 FP-2026-0310 `-13,632`）
   一并捞出来，目前靠 `HAVING available>0` 挡掉。建议显式 `AND i.amount > 0`，别依赖副作用。

### 五、复核 SQL

```sql
-- 核销是否超过到账额（应为 0 行）
SELECT r.code, r.amount, SUM(a.amount) alloc
FROM crm_receipts r JOIN crm_receipt_allocations a ON a.receipt_id=r.id AND a.revoked_at IS NULL
GROUP BY r.id HAVING alloc > r.amount;

-- 核销是否超过单据金额（应为 0 行）
SELECT 'invoice' t, i.code, i.amount, SUM(a.amount) alloc
FROM crm_invoices i JOIN crm_receipt_allocations a
  ON a.target_type='invoice' AND a.target_id=i.id AND a.revoked_at IS NULL
GROUP BY i.id HAVING alloc > i.amount;

-- 口径执行得对不对：还有没有合同核销（口径定了之后应为 0 行）
SELECT a.id, r.code, c.code AS contract, a.amount
FROM crm_receipt_allocations a
JOIN crm_receipts r ON r.id=a.receipt_id
JOIN crm_contracts c ON c.id=a.target_id
WHERE a.target_type='contract' AND a.revoked_at IS NULL;

-- 挂账超过 7 天还没核的到账（财务要跟的）
SELECT r.code, c.name, r.amount, r.pay_date
FROM crm_receipts r LEFT JOIN crm_customers c ON c.id=r.customer_id
WHERE r.amount > (SELECT COALESCE(SUM(a.amount),0) FROM crm_receipt_allocations a
                  WHERE a.receipt_id=r.id AND a.revoked_at IS NULL)
  AND r.pay_date < DATE_SUB(CURDATE(), INTERVAL 7 DAY);
```

### 复核 SQL

```sql
-- 核销是否超过到账额（应为 0 行）
SELECT r.code, r.amount, SUM(a.amount) alloc
FROM crm_receipts r JOIN crm_receipt_allocations a ON a.receipt_id=r.id AND a.revoked_at IS NULL
GROUP BY r.id HAVING alloc > r.amount;

-- 核销是否超过单据金额（应为 0 行）
SELECT 'invoice' t, i.code, i.amount, SUM(a.amount) alloc
FROM crm_invoices i JOIN crm_receipt_allocations a
  ON a.target_type='invoice' AND a.target_id=i.id AND a.revoked_at IS NULL
GROUP BY i.id HAVING alloc > i.amount;

-- 挂账超过 7 天还没核的到账（财务要跟的）
SELECT r.code, c.name, r.amount, r.pay_date
FROM crm_receipts r LEFT JOIN crm_customers c ON c.id=r.customer_id
WHERE r.amount > (SELECT COALESCE(SUM(a.amount),0) FROM crm_receipt_allocations a
                  WHERE a.receipt_id=r.id AND a.revoked_at IS NULL)
  AND r.pay_date < DATE_SUB(CURDATE(), INTERVAL 7 DAY);
```
