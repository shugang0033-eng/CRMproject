# 合同新建 / 审批 / 详情 · 后端实现清单

> 回答一个具体问题：**「新建合同和审批合同的表单还没做，是需要后端做么？」**
>
> 答：**表单本身是前端的事，已经做完了；但这两个动作要落库，必须有 3 个后端接口。**
> 现状是后端只有 `GET /contracts`（列表），合同页的新建和审批点在接口上会 404。
>
> 前端已把 UI、校验、取价、状态流转全部做完并接好了 `src/api/orders.js` 里的方法，
> 后端按本文补完接口，页面不用再改一行就能跑通。
>
> 页面：`src/views/orders/Contracts.vue`　接口层：`src/api/orders.js`（第 83–95 行）

---

## 一、先看清单

| # | 接口 | 方法 | 权限码 | 优先级 | 不改的后果 |
|---|---|---|---|---|---|
| 1 | `/contracts` | POST | `contract.create` | **P0** | 新建合同无法保存 |
| 2 | `/contracts/{id}/approve` | POST | `contract.approve` | **P0** | 审批无法落库，合同永远停在待审批 |
| 3 | `/contracts/{id}` | GET | `contract.view` | **P1** | 详情页看不到协议价、覆盖商品、关联订单 |
| 4 | `/orders?contractId=` | GET（加参数） | `order.view` | **P1** | 无法按合同查订单，合同执行进度只能靠列表里的汇总数 |
| 5 | `/contracts/export` | GET | `contract.view` | P2 | 导出按钮点了只弹提示 |

P0 两个做完，合同这条线就闭环了。P1 是让详情页不再「空一半」。

---

## 二、数据现状（已确认，不用再建表）

```
crm_contracts        id, code, name, customer_id, type, amount, discount, term_days,
                     payment_term, sign_date, start_date, end_date, owner_id, status,
                     remark, created_by, created_at, updated_at, deleted_at
crm_contract_items   id, contract_id, product_id, unit, qty, price   ← 唯一键 (contract_id, product_id, unit)
crm_approval_logs    kind enum 已含「合同」，doc_id 存 contract.id     ← 审批痕迹直接复用，不要新表
```

- `type` 枚举是 **年框 / 季度 / 单次**（注意是「季度」不是「季框」，演示数据里写错的那个已经改了）
- `status` 枚举是 **草稿 / 待审批 / 执行中 / 已完成 / 已作废**
- 权限码 `contract.view` / `contract.create` / `contract.approve` **都已经在 `crm_permissions` 里**，角色也已经配好，不用补数据
- 单号用现成的 `DocCode.next(db, "HT", "crm_contracts")`

**唯一建议加的列（可选）**：`crm_contracts.request_id varchar(64)`，和 `crm_orders` 一样做提交幂等。不加也能跑，只是网络重试会出两份合同。

---

## 三、接口 1：POST /contracts（P0，最关键）

### 请求

```json
{
  "name": "驰远连锁 · 2027 年度耗材集采框架",
  "customerId": 13,
  "type": "年框",
  "discount": 0.88,
  "termDays": 45,
  "paymentTerm": "月结 45 天",
  "signDate": "2026-11-14",
  "startDate": "2026-11-14",
  "endDate": "2027-11-13",
  "remark": "按季度考核发货额",
  "items": [
    { "productId": 5, "unit": "箱", "qty": 900, "price": 563.20 }
  ]
}
```

`amount` **前端不传、后端也不收** —— 由明细汇总，见下面第 4 条。

### 响应

```json
201 { "id": 17, "code": "HT-2026-0109", "status": "待审批", "warnings": [] }
```

### 八条硬规则

1. **权限与归属**：`contract.create` 必须校验。`owner_id` 取当前登录人，**不接受前端指定**，
   否则有建单权的人可以替别人建单、把业绩挂在别人头上。
   客户归属复用 `OrderWriteService.checkOwner()`（本人 / `data.scope.all` / `data.scope.dept` 子树）。

2. **状态固定为「待审批」，不接受前端传值**。
   新合同必须审批才生效 —— 否则销售自己建一份「执行中」的合同，
   就能在 `OrderWriteService.resolve()` 里锁死协议价，绕过审批流程。
   同时写一条 `crm_approval_logs(kind='合同', doc_id, action='提交', operator_id=当前人)`。

3. **单号**：`DocCode.next(db, "HT", "crm_contracts")`，`code` 有唯一索引，靠它兜并发。

4. **金额由明细汇总**：
   ```
   amount = Σ(round(qty × price, 2))        -- 逐行先舍入再累加，和前端 totals 对齐
   ```
   写入 `crm_contracts.amount`。明细同时写 `crm_contract_items`，同一事务。

5. **协议单价的单位口径（最容易写错的一条）**：
   `crm_contract_items.price` 存的是**所选 unit 的单价**，不是销售单位（箱）价。
   前端已经按 `标准价 ÷ 销售单位换算系数 × 该单位系数` 算好才提交，
   后端**直接落库，不要再乘一次系数**。
   反例：一箱 60 把，标准价箱价 60 元，选「把」提交 `price=1.00`；
   后端若再乘 60，协议价就变成 60 元一把，订单取价时客户多付 60 倍。

6. **校验**（不满足返回 400）：
   | 项 | 规则 |
   |---|---|
   | `name` | 非空，≤120 字，同一客户下未作废合同不许重名 |
   | `customerId` | 存在、未合并（`merged_into_id IS NULL`）、有负责人 |
   | `type` | 必须 ∈ {年框, 季度, 单次} |
   | `discount` | 0.500–1.000，三位小数 |
   | `termDays` | 0–180 整数（0 = 款到发货） |
   | `signDate` | 空则 `CURDATE()` |
   | `endDate` | ≥ `startDate` |
   | `items` | 至少 1 行；同一 `(productId, unit)` 不许重复（DB 已有唯一键，提前拦成 400 而不是 500） |
   | `items[].qty` | ≥ 1 |
   | `items[].price` | > 0，两位小数 |
   | `items[].unit` | 必须存在于该产品的 `crm_product_units`，否则订单取价时 JOIN 会查不到直接炸 |

7. **不建议替前端校验「综合折扣 = discount」**。
   合同允许逐行让价（有的 SKU 冲量、有的不让），前端已经会提示实际折扣偏离；
   后端若强校验，业务上会出现「谈好的整单折扣对不上任何一行」的死结。

8. **可选 warnings**：某行 `price < 成本价 × 系数` 时返回
   `{"code":"BELOW_COST","message":"第 2 行低于成本价"}`，201 照常创建。
   和 `POST /orders` 的 warnings 结构保持一致，前端已经能渲染。

---

## 四、接口 2：POST /contracts/{id}/approve（P0）

### 请求 / 响应

```json
{ "result": "pass", "note": "同意，按季度考核发货额" }
```
```json
204
```

### 规则

1. 权限码 `contract.approve`（`data.scope` 与建单相同，走 `checkOwner`）。

2. **禁止自审**：`owner_id == 当前登录人` 直接 403。
   和 `OfficeService.decide()` 的口径必须一致 —— 全站一个规则，
   否则会出现「请假不能自审、合同能自审」这种没法解释的差异。
   前端已经按这条规则把本人单据的审批按钮换成了「本人提交」，不会让人白点。

3. **只有「待审批」能审**，其它状态返回 409（不是 400）。
   两个人同时点通过，第二个必须拿到 409 而不是静默成功。

4. **状态流转**：
   | result | 新状态 | 说明 |
   |---|---|---|
   | `pass` | 执行中 | 合同生效，可以挂订单按协议价取价 |
   | `reject` | 草稿 | 退回修改，负责人改完重新提交 |

5. **`note` 校验**：`reject` 时必填（≥2 字），`pass` 可空。
   驳回不写原因，负责人不知道该改什么。

6. **写审批痕迹**：`crm_approval_logs(kind='合同', doc_id=id, action='同意'|'驳回', operator_id, note)`。
   `GET /contracts/{id}` 的 `approvals` 就从这个表读，不要另建表。

---

## 五、接口 3：GET /contracts/{id}（P1）

前端已经按下面的结构写好了渲染（`Contracts.vue` 的 `contractLines` / `relatedOrders`），
字段名对不上会直接显示成空。

```json
{
  "contract": { "id":17, "code":"HT-2026-0109", "name":"...", "customer":"合肥皖通汽配贸易",
                "customer_id":13, "type":"年框", "amount":271920.00, "discount":0.88,
                "term_days":45, "payment_term":"月结 45 天",
                "sign_date":"2026-11-14", "start_date":"...", "end_date":"...",
                "owner":"李四", "status":"执行中", "remark":"..." },
  "items": [
    { "id":51, "productId":5, "name":"超细纤维洗车毛巾 40×40 300g",
      "unit":"箱", "qty":900, "price":563.20, "amount":506880.00 }
  ],
  "orders": [
    { "id":31, "code":"SO-2026-0112", "order_date":"2026-11-10", "amount":26000.00, "status":"待发货" }
  ],
  "approvals": [
    { "by":"李四", "action":"同意", "note":"...", "at":"2026-11-14 17:02" }
  ],
  "summary": { "orderedAmount":26000.00, "orderCount":1, "remainingAmount":245920.00 }
}
```

要点：

- `items[].amount` 由后端算（`qty × price`），前端不再自己乘
- `orders` 只取 `status <> '已取消' AND deleted_at IS NULL`，按 `order_date DESC`
- `approvals` 从 `crm_approval_logs` 取，`action` 原样返回「同意 / 驳回 / 提交」，前端映射成标签
- `summary.orderedAmount` 与列表接口的 `orderedAmount` 必须同口径，否则详情和列表数字打架

---

## 六、接口 4：GET /orders?contractId=（P1，小改）

`OrderQueryController.list()` 加一个 `Long contractId` 参数，透传给 `OrderQueryService.list()`，
在 `from` 里补 `AND (? IS NULL OR o.contract_id=?)`（对 `contracts` 资源忽略）。

改动量约 10 行。不做的话，「合同下的订单」只能靠详情接口一次带回来，
而合同列表页的「已下单 / 合同额」进度条也只能看汇总数，点不进去。

---

## 七、前端已经做完的部分（不用再提）

| 能力 | 位置 | 说明 |
|---|---|---|
| 新建合同表单 | `Contracts.vue` | 客户、类型、名称、账期、折扣、签订日期、有效期、备注、明细行 |
| 有效期联动 | `syncPeriod()` | 年框 +1 年、季度 +3 月、单次 +30 天，手改过就不再覆盖 |
| 协议价初算 | `suggestPrice()` | 标准价 × 折扣，按所选单位换算 |
| 折扣联动 | `watch(form.discount)` | 只重算没手改过的行，手改价不被冲掉 |
| 综合折扣提示 | `createIssues` | 明细手改后实际折扣偏离表单折扣时给出警告 |
| 提交前校验 | `submitCreate()` | 客户 / 名称 / 明细 / 数量 / 单价 / 日期区间逐项拦截 |
| 审批弹窗 | `submitApprove()` | 通过 / 驳回二选一，驳回必填意见 |
| 自审拦截 | `canAudit('contract.approve', row)` | 本人单据不摆审批按钮，显示「本人提交」 |
| 详情兜底 | `detailState` | 详情接口 404 时只显示列表摘要 + 明确提示，不假装「没有明细」 |
| 接口未就绪提示 | `attempt()` | 404 时明确告知「没有保存 / 状态未变」，不本地改状态骗人 |

两个修掉的既有 bug：

- `adaptContract()` 给的是 `term`，模板读的是 `paymentTerm`，真实数据下详情页账期空白
- 类型筛选项写「季框」，和后端 enum「季度」对不上，筛季度合同永远 0 条

---

## 八、验收（后端写完后直接跑）

```bash
# 1. 登录（超管）
curl -c /tmp/c.txt -X POST localhost:8080/api/auth/login \
  -H 'content-type: application/json' -d '{"username":"admin","password":"123456"}'

# 2. 新建合同 → 期望 201，code=HT-2026-01xx，status=待审批
curl -b /tmp/c.txt -X POST localhost:8080/api/contracts \
  -H 'content-type: application/json' -d '{
  "name":"走查合同","customerId":13,"type":"年框","discount":0.88,
  "termDays":45,"paymentTerm":"月结 45 天",
  "signDate":"2026-11-14","startDate":"2026-11-14","endDate":"2027-11-13",
  "items":[{"productId":5,"unit":"箱","qty":10,"price":563.20}]}'

# 3. 详情 → 期望 items[0].amount = 5632.00，summary.orderedAmount = 0
curl -b /tmp/c.txt localhost:8080/api/contracts/17

# 4. 审批通过 → 期望 204，再查详情 status=执行中，approvals 有 1 条
curl -b /tmp/c.txt -X POST localhost:8080/api/contracts/17/approve \
  -H 'content-type: application/json' -d '{"result":"pass","note":"同意"}'

# 5. 再点一次通过 → 期望 409（不能重复审）
# 6. 驳回不写意见 → 期望 400
# 7. 用自己的账号审自己的单 → 期望 403
# 8. 用销售顾问（X02）建合同 → 期望 201，owner_id=14
```

---

## 九、本期不做（留个记号，别当成 bug）

- **合同变更 / 续签**：审批通过的合同目前不能改金额和明细。真实业务需要「变更单」，
  而不是直接 UPDATE，否则已下的订单会失去价格依据。
- **合同作废入口**：`status` 里有「已作废」，但页面上没有按钮。
  需要先定规则：执行中的合同能不能作废？已成订单怎么处理？
- **额度预警**：合同执行额超过合同额时，列表进度条封顶在 100%，没有额外告警。
- **附件**：合同扫描件上传（`crm_contracts` 没有附件表）。
