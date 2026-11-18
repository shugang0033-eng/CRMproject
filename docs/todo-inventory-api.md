# 待办 / 退货 / 库存 这一轮的后端清单

> 本轮前端交付（全部读真实接口，无演示数据）：
>
> | 页面 | 路径 | 数据来源 |
> |---|---|---|
> | 待办 | `/todos` | `/approvals?box=pending`、`/contracts`、`/orders`、`/statements`、`/returns`、`/customers/follow-board`、`/leads` |
> | 退货与售后 | `/orders/returns` | `/returns`、`/orders` |
> | 库存 | `/products/inventory` | `/products`、`/product-categories`（+ `/inventory` 待接） |
> | 工作台 | `/dashboard` | `/orders`、`/receipts`、`/leads`、`/contracts`、待办聚合 |
> | 侧栏徽标 + 铃铛 | `AppLayout` | 待办聚合（只取逾期 / 今天） |
>
> 待办、退货、库存三页**没有一条写死的业务数据**；退货测试数据已用 `database/crm-return-demo.sql` 写进
> `crm_returns` / `crm_return_items`（3 条待审核，可重复执行，幂等）。
>
> 下面是后端需要补的东西，按「不做会挡住真实使用」→「不做只是体验差」排序。

---

## 零、优先级总表

| # | 事项 | 优先级 | 现状 | 影响 |
|---|---|---|---|---|
| 1 | `GET /api/inventory` 可用/占用/在途 | **P0** | 接口不存在（404） | 库存页只能看状态，看不到数量；下单无法校验 |
| 2 | 下单时库存预占与不足警告 | **P0** | 只校验信用额度 | 接单时不知道发不出去，等发货才失败 |
| 3 | 退货驳回理由入库 | **P1** | `result=reject` 只改状态，理由丢弃 | 客户问「为什么退不了」查不到记录 |
| 4 | 待办聚合 `GET /api/todos` | **P1** | 前端并发 7 个接口自己算 | 单据超 500 条会漏，且 7 次往返 |
| 5 | ~~业绩目标落库~~ | 已完成 | `crm_targets` + `GET/PUT /api/targets` 已实现 | 已完成额仍由前端算，缺口见 `docs/targets-api.md` |
| 6 | 合同新建 / 审批接口 | 已有 | `docs/contracts-api.md` | 本轮未改动 |
| 7 | 退货列表按单号、产品搜索 | P2 | 只支持 status / customerId / orderId | 数据多了以后找不到单 |

---

## 一、P0-1：`GET /api/inventory` 库存数量

### 为什么必须做

`crm_product_inventory` 表已经有了（12 行，合计 114200），`FulfillmentService` 发货时也在扣
（`available=available-?`），但**没有任何读接口**。所以前端只能读产品档案上的
`stock_status`（充足 / 少量 / 需排产）——那是人工维护的标签，不是数量。库存页目前显示
「—」并挂了一条说明，就是不想把「没接」当成 0。

### 接口

```
GET /api/inventory?keyword=&stock=&page=1&pageSize=200
```

返回（数组或 `{rows,total}` 都兼容，前端两种都认）：

```json
[
  { "productId": 3, "code": "P-1003", "name": "重载刹车片（前后套装）",
    "available": 1200.00, "occupied": 300.00, "inTransit": 0.00,
    "saleUnit": "套", "stock": "充足", "moq": 10, "productionDays": 3 }
]
```

字段规则：

- `productId` / `available` **必须叫这两个名字**（前端按 `x.productId ?? x.product_id` 读，
  两个都认，但别换别的名）。
- `occupied` = 已确认未发货的订单占用；`inTransit` = 在途采购/生产。没算就返回 `0`，
  **不要返回 `null`**（前端会把 `null` 当「没有数量」）。
- 数量单位必须是**销售单位**，不是库存单位。`crm_product_inventory.available` 存的是
  库存单位，换算靠 `crm_order_items.unit_factor`，返回前要除一次，否则会出现「1200 套」实际只有 120 套。
- `stock` 直接透传 `crm_products.stock_status` 的中文（`enough→充足`、`low→少量`、
  `made_to_order→需排产`），**字段名跟 `GET /products` 保持一致（`stock`，不是 `stockStatus`）**，
  前端 tab 就是按这三个字分组的。

### 参考 SQL

```sql
SELECT p.id AS productId, p.code, p.name, p.sale_unit AS saleUnit,
       p.stock_status AS stock, p.moq, p.production_days AS productionDays,
       i.available,
       0 AS occupied, 0 AS inTransit
FROM crm_products p
LEFT JOIN crm_product_inventory i ON i.product_id = p.id
WHERE p.status = 'on'
ORDER BY p.code;
```

### 验收

- 库存页「可发数量」列不再显示 `—`，顶部那条「接口还没实现」的说明条自动消失
  （前端判断的是「返回条数 > 0」，不用改前端）。
- 抽查一个 SKU，把发货扣减前后的 `available` 和页面数字对一遍，必须一致。

---

## 二、P0-2：下单时校验库存

### 为什么必须做

`OrderWriteService.create()` 现在只做两件事：**信用额度**（`credit_limit - credit_used - 未结订单`）
和**底价**（`floor_price`）。库存完全没碰。结果是：一个「需排产、周期 15 天」的产品，
销售可以按现货交期接单，仓库第二天才发现做不出来。

### 建议做法：不加锁、不阻断，只加警告

```java
// OrderWriteService.create() 里，循环 priced 明细时顺带查
if (product.stock == 需排产) {
    warnings.add(new Warning("MADE_TO_ORDER", "需排产，交期按 production_days 天算，不能承诺现货"));
} else if (available != null && available < 需要量) {
    warnings.add(new Warning("STOCK_SHORT", "库存不足，缺口按需排产处理"));
}
```

理由：**接单是业务判断，不该被系统拦死**。老客户急单可以先接再排产，硬拦会逼销售绕过系统。
警告 + 状态落 `待审批`，跟现在「超信用额度」的处理方式完全一致——复用同一条链路，前端不用改。

同时把可用量不足的订单落到 `crm_orders.credit_check` 之外的一个新字段（或直接进
`status='待审批'`），让审批人看到「这单要排产」再决定。

### 明细行返回库存提示（前端已做，等接口）

订单新建页的产品下拉下面已经接了提示条：

| stock | 提示 | 语气 |
|---|---|---|
| 充足 | 库存充足 | 绿 |
| 少量 | 库存少量，发货前找仓库确认可发量 | 橙 |
| 需排产 | 需排产，不能按现货承诺交期 | 红 |

它读的就是 `GET /products` 返回的 `stock`，**这个已经能用了**。等
`GET /inventory` 上线后，建议把提示升级成「可发 1200 套 / 本次要 1500 套」的具体数字。

### 验收

- 拿一个 `stock_status='made_to_order'` 的产品下单，返回的 `warnings` 里要有
  `MADE_TO_ORDER`，订单进 `待审批`。
- 正常产品下单，`warnings` 为空，状态仍是 `待发货`（不能因为加了校验就把所有单都变成待审批）。

---

## 三、P1-3：退货驳回理由

### 现状

```java
public record ReturnDecision(String result, boolean restock) {}
```

`result=reject` 时只执行 `UPDATE crm_returns SET status='已驳回'`，**理由没有入参也没有落库**。
前端驳回弹窗里让业务员填了说明（「不属质量问题」「已过三包期」），现在等于白填。

### 需要改的

1. 表加字段（`crm_returns`）：

```sql
ALTER TABLE crm_returns
  ADD COLUMN reject_reason VARCHAR(255) NULL COMMENT '驳回理由',
  ADD COLUMN confirmed_by BIGINT NULL COMMENT '处理人',
  ADD COLUMN confirmed_at DATETIME NULL COMMENT '处理时间';
```

> `confirmed_at` 代码里已经在写了，若列已存在则跳过。

2. 入参加 `reason`（可选，不传不报错，保持向后兼容）：

```java
public record ReturnDecision(String result, boolean restock, String reason) {}
```

3. `reject` 分支落库；`pass` 分支顺手记 `confirmed_by`：

```java
if ("reject".equals(result)) {
    db.update("UPDATE crm_returns SET status='已驳回', reject_reason=?, confirmed_by=?, confirmed_at=NOW() WHERE id=?",
        reason, employee, id);
    return;
}
```

4. 列表接口把 `reject_reason` 一起返回，前端表格的「备注」列直接显示。

### 验收

驳回一单 → `crm_returns.reject_reason` 有值、`confirmed_by` 是当前登录人；
再点一次驳回要报「状态已变更」而不是静默成功（现在 `state(...)` 已拦，确认一下即可）。

---

## 四、P1-4：待办聚合接口（可选，但建议做）

### 现状

前端 `src/composables/useTodos.js` 用 `Promise.allSettled` 并发拉 7 个接口，本地按
SLA 分桶（逾期 / 今天 / 本周 / 更晚）。好处是**后端零改动就能用**，坏处有两个：

1. 每个接口默认 `pageSize=20`，客户/订单超过 500 条时列表会漏。
2. 打开工作台就是 7 个请求，铃铛刷新又来一遍。

### 建议接口

```
GET /api/todos?box=mine
```

```json
{
  "total": 22, "overdue": 11, "today": 3, "week": 8,
  "byKind": { "审批": 4, "合同": 1, "发货": 3, "对账": 1, "退货": 3, "跟进": 6, "线索": 4 },
  "rows": [
    { "key": "approval:12", "kind": "审批", "title": "李四 提交的请假申请",
      "meta": "行政 · 3 天", "dueAt": "2026-11-13", "bucket": "overdue",
      "action": "decide", "targetId": 12, "amount": null }
  ]
}
```

- `key` 必须全局唯一且稳定（`kind:id`），前端 `dropTodo(key)` 就是靠它做「已处理」去重。
- `bucket` 由后端按 SLA 算（见下表），前端只渲染，避免两边口径不一致。
- `action` 用现有四类：`decide`（统一审批）/ `confirmReturn` / `confirmStatement` / `finishTask`。

### SLA 表（前端当前口径，后端照抄即可）

| 类型 | 天数 | 依据 |
|---|---|---|
| 审批 | 2 | 内部约定 48 小时 |
| 合同 | 2 | 同上 |
| 发货 | 1 | 客户等货，隔天就算迟 |
| 对账 | 3 | 月结，3 天内确认 |
| 退货 | 1 | 售后时效 |
| 线索 | 1 | 新线索 24 小时内必须联系 |

> 这是**系统约定**，不是数据库字段。要改成可配置就单独做一张
> `crm_sla_config(kind, days)`，别写死在代码里第三次。

### 不做也能用

前端已经是可用状态。做这个接口的收益是「口径统一 + 一次请求」，不紧急。

---

## 五、P1-5：业绩目标 —— 已完成（2026-11-16）

后端已实现 `crm_targets` 表 + `GET /api/targets?period=` + `PUT /api/targets`（批量 upsert），
前端 `src/store/targets.js` 已改为走真实接口，localStorage 那套已删除。

剩下的缺口都是「完成额算法服务端化」一类，单独整理在 **`docs/targets-api.md`**：

- P0 `GET /api/targets/progress` —— 现在前端拉 500 条合同自己算，合同超量会漏算且不报错
- P0 `crm_targets` 补 `updated_by` / `updated_at`（业绩目标改动要可追溯）
- P0 `crm_targets` 补 `metric`（现在硬校验只允许 `signed`，将来按回款考核要改表）
- P1 目标变更历史表、个人目标 `scope='employee'`

---

## 六、已就绪 / 不用动的

| 能力 | 状态 |
|---|---|
| 合同新建、合同审批 | `docs/contracts-api.md` 已有完整契约，后端已实现，本轮前端未改 |
| 退货申请 / 确认入库 | `POST /returns`、`POST /returns/{id}/confirm` 已实现，副作用（回补 `returned_qty`、`available`、整单退完转「已退货」）已实测通过 |
| 对账单生成 / 确认 | `POST /statements`、`POST /statements/{id}/confirm` 已实现 |
| 通用列表过滤 | `GET /{orders|contracts|invoices|receipts|statements|shipments|returns}` 已支持 `status/type/customerId/ownerId/period/orderId/contractId/page/pageSize` |
| 客户跟进看板 | `GET /customers/follow-board` 已实现 |

**P2 小项**：退货列表目前不能按单号 / 产品名搜索（`OrderQueryController` 没有 `keyword` 参数）。
退货单据上千条以后会难找，可以给 `crm_returns.code` 和产品名加一个 `keyword` 模糊匹配。

---

## 七、上线顺序

1. `GET /inventory` —— 单独上线，前端不用改，库存页自动从「只有状态」变成「有数量」。
2. 下单库存警告 —— 跟 `CREDIT_EXCEEDED` 走同一条 `warnings` 链路，风险最低。
3. 退货驳回理由 —— 加字段 + 加入参，向后兼容（不传 `reason` 也能跑）。
4. `GET /targets/progress` —— 前端 `useTargetProgress.js` 里 `loadTargetBase` 一处取数，
   换成接口后 `targetProgress` / `summaryOf` 直接映射，页面和侧栏都不用动。
5. `GET /todos` —— 最后做。前端现在能跑，等单据量上来（单类 > 500 条）再做不迟，
   做完前端把 `useTodos` 的 7 个请求换成一个即可，页面不用动。

---

## 八、每次改完的复核 SQL

```sql
-- 退货金额必须等于明细之和（不等就是事务漏了）
SELECT r.code, r.amount, SUM(i.amount) AS lineSum, r.amount - SUM(i.amount) AS diff
FROM crm_returns r JOIN crm_return_items i ON i.return_id = r.id
GROUP BY r.id HAVING diff <> 0;

-- 已发数量不能小于已退数量
SELECT id, order_id, shipped_qty, returned_qty FROM crm_order_items
WHERE returned_qty > shipped_qty;

-- 库存不能为负
SELECT product_id, available FROM crm_product_inventory WHERE available < 0;

-- 排在待办里但状态已经变了的（幽灵待办）
SELECT id, code, status FROM crm_returns WHERE status NOT IN ('待审核','已入库','已退款','已驳回');
```
