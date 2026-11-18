# 订单中心接口契约（后端实现清单）

> 前端已交付：`/orders`（订单列表）、`/orders/:id`（订单详情）、`/orders/contracts`（合同）、
> `/orders/statements`（对账单）、`/orders/invoices`（发票）、`/orders/payments`（回款）、
> `/finance/expenses`（费用报销），共 7 个页面 + `src/api/orders.js` 契约。
>
> 页面当前读 `src/data/orderCenter.js` 的本地演示数据，**没有写数据库**。
> 后端就绪后把 `orderApi.*` 的返回换成真实数据即可，方法名与参数不用改。
> 本文是后端需要照着做的东西 —— 建表、接口、校验、批处理、上线顺序。

---

## 一、先看懂单据链路（不按这个顺序建模，后面全是补丁）

```
合同（年框承诺）───┐
                  ├──> 订单（这次要多少货）──> 发货（可分批）──> 签收
备货订单（无合同）─┘                          │
                                             └──> 退货（冲减已发数量 + 冲减应收）

月末：对账单（客户确认）──> 开票 ──> 收款单 ──> 核销
                                                  ↑
                          一笔到账可冲多张票，一张票也可被多笔到账冲
```

四个环节各自解决一个问题，**不要合并**：

| 环节 | 解决的问题 | 合并后会出的问题 |
|---|---|---|
| 合同 | 价格与账期的承诺 | 没有协议价依据，业务员随便打折 |
| 订单 | 本次要货数量 | 无法分批发货，也无法统计待发 |
| 发货 + 签收 | 货权转移与收入确认时点 | 业绩按签约额算，年框一签几百万全算进去 |
| 对账 + 开票 + 核销 | 客户认不认这笔钱、钱对不对得上 | 只有「已回款」标记，说不清哪笔钱冲的哪张票 |

---

## 二、建模三条铁律

**1. 金额以明细行为唯一事实，汇总字段只是写时缓存。**
`crm_orders.amount`、`crm_returns.amount` 这类字段允许存在（列表页要排序分页，每次 `SUM` 子查询会慢），但必须在同一事务里由明细算出来写入，并且提供一个日检 SQL 定期比对，不一致就报警。对账单例外 —— 对账单是**快照**，生成那一刻冻结，之后订单再变也不回改。

**2. 订单分两类，取价规则不同。**

| 类型 | 有合同 | 取价来源 | 信用占用 |
|---|---|---|---|
| 合同订单 | 必填 `contract_id` | 协议折扣（合同中谈定） | 占用，冲减合同剩余量 |
| 备货订单 | 空 | 阶梯价 / 经销价 | 占用，不冲减合同 |

**3. 收款与应收是多对多，必须有核销明细表。**
不能只给发票加一个 `paid` 标记。一笔 30 万到账可能冲 20 万 + 10 万两张票，一张票也可能先收 17 万后收 10 万。没有 `crm_receipt_allocations`，后面客户来对账你答不上来。

---

## 三、表结构

共 12 张表。前缀沿用现有 `crm_` 约定，字符集 `utf8mb4`，引擎 InnoDB。

### 3.1 `crm_contracts` 合同

```sql
CREATE TABLE crm_contracts (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code          VARCHAR(32)  NOT NULL COMMENT '合同编号 HT-2026-0187',
  name          VARCHAR(120) NOT NULL,
  customer_id   BIGINT UNSIGNED NOT NULL,
  type          ENUM('年框','季度','单次') NOT NULL DEFAULT '单次',
  amount        DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '含税总额，由明细汇总',
  discount      DECIMAL(4,3)  NOT NULL DEFAULT 1.000 COMMENT '协议折扣 0.880 = 88折',
  term_days     INT          NOT NULL DEFAULT 30 COMMENT '账期天数',
  payment_term  VARCHAR(40)  NOT NULL DEFAULT '' COMMENT '展示文案：月结 30 天',
  sign_date     DATE         NULL,
  start_date    DATE         NULL,
  end_date      DATE         NULL,
  owner_id      BIGINT UNSIGNED NOT NULL COMMENT '负责人',
  status        ENUM('草稿','待审批','执行中','已完成','已作废') NOT NULL DEFAULT '草稿',
  remark        VARCHAR(500) NOT NULL DEFAULT '',
  created_by    BIGINT UNSIGNED NOT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at    DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  KEY idx_customer (customer_id, status),
  KEY idx_owner (owner_id, status)
) COMMENT='合同/年框';
```

### 3.2 `crm_contract_items` 合同协议商品

```sql
CREATE TABLE crm_contract_items (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  contract_id BIGINT UNSIGNED NOT NULL,
  product_id  BIGINT UNSIGNED NOT NULL,
  unit        VARCHAR(16) NOT NULL COMMENT '销售单位，如 箱',
  qty         DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '协议总量',
  price       DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '协议单价（已含折扣）',
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_contract_product (contract_id, product_id, unit),
  KEY idx_product (product_id)
) COMMENT='合同覆盖的商品与协议价';
```

> 已下单量**不存字段**，按 `crm_orders` 聚合（见 6.1）。存了就会不一致。

### 3.3 `crm_contract_approvals` 合同审批痕迹

```sql
CREATE TABLE crm_contract_approvals (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  contract_id BIGINT UNSIGNED NOT NULL,
  action      ENUM('提交','审核','批准','驳回','作废') NOT NULL,
  operator_id BIGINT UNSIGNED NOT NULL,
  note        VARCHAR(500) NOT NULL DEFAULT '',
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_contract (contract_id, created_at)
) COMMENT='合同审批时间线';
```

### 3.4 `crm_orders` 订单

```sql
CREATE TABLE crm_orders (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code         VARCHAR(32) NOT NULL COMMENT 'SO-2026-0412',
  customer_id  BIGINT UNSIGNED NOT NULL,
  contract_id  BIGINT UNSIGNED NULL COMMENT '备货订单为空',
  type         ENUM('合同订单','备货订单') NOT NULL DEFAULT '合同订单',
  order_date   DATE NOT NULL,
  expect_date  DATE NULL COMMENT '期望到货',
  owner_id     BIGINT UNSIGNED NOT NULL,
  status       ENUM('草稿','待审批','待发货','部分发货','已签收','已取消','已退货')
               NOT NULL DEFAULT '草稿',
  credit_check ENUM('通过','待审批','超限') NOT NULL DEFAULT '通过',
  amount       DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '含税金额，明细汇总缓存',
  remark       VARCHAR(500) NOT NULL DEFAULT '',
  request_id   VARCHAR(64) NULL COMMENT '幂等键，防重复提交',
  created_by   BIGINT UNSIGNED NOT NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at   DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  UNIQUE KEY uk_request (request_id),
  KEY idx_customer_date (customer_id, order_date),
  KEY idx_status_date (status, order_date),
  KEY idx_contract (contract_id)
) COMMENT='销售订单（要货单）';
```

### 3.5 `crm_order_items` 订单明细

```sql
CREATE TABLE crm_order_items (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id     BIGINT UNSIGNED NOT NULL,
  product_id   BIGINT UNSIGNED NOT NULL,
  unit         VARCHAR(16) NOT NULL,
  qty          DECIMAL(12,2) NOT NULL,
  price        DECIMAL(12,2) NOT NULL COMMENT '成交单价（含税）',
  price_source VARCHAR(24) NOT NULL DEFAULT '' COMMENT '协议价/阶梯价/经销价/标准价',
  floor_price  DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '下单时成本价快照，审计用',
  amount       DECIMAL(12,2) NOT NULL COMMENT 'qty * price',
  shipped_qty  DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '已发数量缓存',
  returned_qty DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '已退数量缓存',
  sort_no      INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_order (order_id),
  KEY idx_product (product_id)
) COMMENT='订单商品明细';
```

> `floor_price` 必须存快照。产品成本会变，三个月后有人质疑「当时为什么批了低价」，只有快照能自证。
> `shipped_qty` / `returned_qty` 是缓存，可发货量 = `qty - shipped_qty + returned_qty - 退货在途`。

### 3.6 `crm_shipments` + `crm_shipment_items` 发货

```sql
CREATE TABLE crm_shipments (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code        VARCHAR(32) NOT NULL COMMENT 'FH-2026-0891',
  order_id    BIGINT UNSIGNED NOT NULL,
  ship_date   DATE NOT NULL,
  logistics   VARCHAR(60) NOT NULL DEFAULT '',
  tracking_no VARCHAR(60) NOT NULL DEFAULT '',
  status      ENUM('已发货','运输中','已签收','已拒收') NOT NULL DEFAULT '已发货',
  signed_at   DATETIME NULL COMMENT '签收时间 —— 收入确认与账龄起算都用它',
  amount      DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '本批含税金额',
  boxes       INT NOT NULL DEFAULT 0 COMMENT '箱数，展示用',
  created_by  BIGINT UNSIGNED NOT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  KEY idx_order (order_id, ship_date)
) COMMENT='发货单';

CREATE TABLE crm_shipment_items (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  shipment_id   BIGINT UNSIGNED NOT NULL,
  order_item_id BIGINT UNSIGNED NOT NULL,
  product_id    BIGINT UNSIGNED NOT NULL,
  unit          VARCHAR(16) NOT NULL,
  qty           DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_shipment (shipment_id),
  KEY idx_order_item (order_item_id)
) COMMENT='发货明细';
```

### 3.7 `crm_returns` + `crm_return_items` 退货

```sql
CREATE TABLE crm_returns (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code        VARCHAR(32) NOT NULL COMMENT 'RT-2026-0006',
  order_id    BIGINT UNSIGNED NOT NULL,
  customer_id BIGINT UNSIGNED NOT NULL,
  return_date DATE NOT NULL,
  reason      ENUM('质量问题','发错规格','客户取消','运输破损','其他') NOT NULL,
  status      ENUM('待审核','已入库','已退款','已驳回') NOT NULL DEFAULT '待审核',
  amount      DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '冲减金额，明细汇总',
  note        VARCHAR(500) NOT NULL DEFAULT '',
  created_by  BIGINT UNSIGNED NOT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  KEY idx_order (order_id),
  KEY idx_customer_date (customer_id, return_date)
) COMMENT='退货单';

CREATE TABLE crm_return_items (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  return_id    BIGINT UNSIGNED NOT NULL,
  order_item_id BIGINT UNSIGNED NOT NULL,
  product_id   BIGINT UNSIGNED NOT NULL,
  unit         VARCHAR(16) NOT NULL,
  qty          DECIMAL(12,2) NOT NULL,
  price        DECIMAL(12,2) NOT NULL COMMENT '按原订单单价冲减，不能重新取价',
  amount       DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_return (return_id)
) COMMENT='退货明细';
```

### 3.8 `crm_statements` 对账单（快照）

```sql
CREATE TABLE crm_statements (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code           VARCHAR(32) NOT NULL COMMENT 'DZ-2026-10-001',
  customer_id    BIGINT UNSIGNED NOT NULL,
  period         CHAR(7) NOT NULL COMMENT '2026-10',
  start_date     DATE NOT NULL,
  end_date       DATE NOT NULL,
  open_amount    DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '期初应收',
  shipped_amount DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '本期发货（减退货）',
  received_amount DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '本期回款',
  close_amount   DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '期末应收 = 期初+发货-回款',
  order_count    INT NOT NULL DEFAULT 0,
  status         ENUM('待确认','已确认','已开票','已回款','已作废') NOT NULL DEFAULT '待确认',
  confirmed_at   DATETIME NULL,
  created_by     BIGINT UNSIGNED NOT NULL,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  UNIQUE KEY uk_customer_period (customer_id, period),
  KEY idx_period (period)
) COMMENT='月度对账单，生成即冻结';
```

### 3.9 `crm_receipts` + `crm_receipt_allocations` 收款与核销

```sql
CREATE TABLE crm_receipts (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code       VARCHAR(32) NOT NULL COMMENT 'SK-2026-0231',
  customer_id BIGINT UNSIGNED NOT NULL,
  amount     DECIMAL(12,2) NOT NULL COMMENT '到账金额',
  pay_date   DATE NOT NULL,
  method     ENUM('银行转账','银行承兑','对公转账','现金') NOT NULL DEFAULT '银行转账',
  bank       VARCHAR(80) NOT NULL DEFAULT '',
  remark     VARCHAR(500) NOT NULL DEFAULT '',
  request_id VARCHAR(64) NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  UNIQUE KEY uk_request (request_id),
  KEY idx_customer_date (customer_id, pay_date)
) COMMENT='收款单（银行到账）';

CREATE TABLE crm_receipt_allocations (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  receipt_id    BIGINT UNSIGNED NOT NULL,
  target_type   ENUM('invoice','statement') NOT NULL DEFAULT 'invoice',
  target_id     BIGINT UNSIGNED NOT NULL,
  amount        DECIMAL(12,2) NOT NULL,
  revoked_at    DATETIME NULL COMMENT '反核销时间，软删，不物理删',
  revoke_reason VARCHAR(200) NOT NULL DEFAULT '',
  created_by    BIGINT UNSIGNED NOT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_receipt (receipt_id),
  KEY idx_target (target_type, target_id)
) COMMENT='核销明细 —— 这张表是回款模块的核心，不能省';
```

### 3.10 `crm_invoices` 发票

```sql
CREATE TABLE crm_invoices (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code          VARCHAR(32) NOT NULL COMMENT 'FP-2026-0322',
  no            VARCHAR(40) NOT NULL DEFAULT '' COMMENT '税控发票号',
  customer_id   BIGINT UNSIGNED NOT NULL,
  contract_id   BIGINT UNSIGNED NULL,
  statement_id  BIGINT UNSIGNED NULL,
  amount        DECIMAL(12,2) NOT NULL COMMENT '价税合计',
  tax_rate      DECIMAL(5,4) NOT NULL DEFAULT 0.1300,
  tax_amount    DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT 'amount*rate/(1+rate)',
  type          ENUM('增值税专用','增值税普通') NOT NULL DEFAULT '增值税专用',
  apply_date    DATE NOT NULL,
  issue_date    DATE NULL,
  status        ENUM('待开票','已开票','已驳回','已红冲') NOT NULL DEFAULT '待开票',
  red_flush_of  BIGINT UNSIGNED NULL COMMENT '红冲指向的原票 id',
  red_flush_reason VARCHAR(200) NOT NULL DEFAULT '',
  created_by    BIGINT UNSIGNED NOT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  KEY idx_customer (customer_id, status),
  KEY idx_statement (statement_id)
) COMMENT='发票';
```

### 3.11 客户表补两列（信用额度）

```sql
ALTER TABLE crm_customers
  ADD COLUMN credit_limit DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '信用额度',
  ADD COLUMN term_days    INT NOT NULL DEFAULT 30 COMMENT '默认账期';
```

`credit_used` **不要存字段**，用 6.2 的 SQL 现算。存了必然和订单状态打架。

---

## 四、权限

已执行脚本：`database/crm-order-perms.sql`（幂等，可重复跑）。新增 9 个权限码：

| 权限码 | 中文 | 谁该有 |
|---|---|---|
| `order.view` | 查看订单 | 全员销售、财务、运营 |
| `order.create` | 新建订单 | 销售、销售主管 |
| `order.approve` | 审批订单 | 销售主管、运营（超限/低价的审批） |
| `order.ship` | 登记发货 | 销售、仓配 |
| `order.return` | 申请退货 | 销售、售后 |
| `statement.view` | 查看对账单 | 销售、财务 |
| `statement.create` | 生成对账单 | 财务 |
| `statement.confirm` | 确认对账单 | 财务 |
| `invoice.redflush` | 发票红冲 | 财务 |

沿用已有的 `contract.view / contract.create / contract.approve`、`invoice.view / invoice.create`、
`payment.view / payment.create / payment.confirm`、`expense.*`。

当前授权矩阵（脚本已落库）：

| 角色 | 订单 | 合同 | 对账 | 发票 | 回款 |
|---|---|---|---|---|---|
| `sales_manager` | view/create/approve/ship/return | 全部 | view | view/create | view/create/confirm |
| `demo_sales` | view/create/ship | view/create | view | view | view |
| `demo_finance` | view | view | view/confirm | view/create/redflush | view/confirm |
| `demo_ops` | view/approve/ship | view | view/confirm | view | view |

**数据范围由后端判定，前端不做过滤**：无 `data.scope.*` → 只看自己 `owner_id`；
`data.scope.dept` → 本部门及下级；`data.scope.all` → 全公司。

---

## 五、接口清单

统一约定：金额单位「元」`DECIMAL(12,2)`，不接受字符串；日期 `YYYY-MM-DD`；
列表返回 `{ rows, total }`；写接口带 `requestId` 做幂等。

### 5.1 订单

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/orders` | 列表。`type/status/customerId/ownerId/period/keyword/page/pageSize` |
| GET | `/orders/{id}` | 详情。返回 `{ order, items, shipments, returns, invoices, receipts, credit }` |
| POST | `/orders` | 新建。body `{ type, customerId, contractId?, expectDate?, remark?, requestId, items[] }` |
| POST | `/orders/{id}/approve` | 审批 `{ result: pass\|reject, note }` |
| POST | `/orders/{id}/cancel` | 取消（仅待发货前可取消） |
| POST | `/orders/quote` | 取价试算，返回 `[{productId, unit, price, priceSource, floor, margin}]` |
| GET | `/orders/credit` | 信用预检 `?customerId=&amount=` 返回 `{ limit, used, available, exceeded }` |
| GET | `/orders/export` | 导出 xlsx 流 |

### 5.2 发货 / 签收 / 退货

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/orders/{id}/shipments` | 登记发货 `{ items[], logistics, trackingNo, shipDate }` |
| POST | `/shipments/{id}/sign` | 签收 `{ signedAt, signedBy }`，触发收入确认 |
| GET | `/shipments` | 列表 `?orderId=&status=&period=` |
| GET | `/returns` | 退货列表 |
| POST | `/returns` | 申请退货 `{ orderId, reason, note, items[] }` |
| POST | `/returns/{id}/confirm` | 审核 `{ result, restock: boolean }` |

### 5.3 合同

> 合同这条线的完整实现清单（请求体、校验、状态流转、禁自审、验收 curl）已单独整理在
> **[`contracts-api.md`](./contracts-api.md)**，本节只保留索引，细节以那份为准。

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/contracts` | 列表，**必须返回 `orderedAmount`**（该合同下订单发货累计） |
| GET | `/contracts/{id}` | `{ contract, items, orders, approvals, summary }` |
| POST | `/contracts` | 新建 `{ name, customerId, type, discount, termDays, paymentTerm, signDate, startDate, endDate, remark, items[] }`，status 固定「待审批」 |
| POST | `/contracts/{id}/approve` | 审批 `{ result, note }`，禁自审，非待审批 409 |
| GET | `/contracts/{id}/available` | 合同剩余可下单量（按商品） |

### 5.4 对账单

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/statements` | 列表 `?customerId=&period=&status=` |
| GET | `/statements/{id}` | `{ statement, orders, shipments, returns, receipts }` |
| POST | `/statements/generate` | 生成 `{ customerId, period }`，幂等 |
| POST | `/statements/{id}/confirm` | 客户确认 |
| POST | `/statements/{id}/void` | 作废重开（仅未开票） |
| GET | `/statements/{id}/export` | 导出 Excel / PDF |

### 5.5 发票

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/invoices` | 列表 `?status=&type=&customerId=&period=` |
| POST | `/invoices` | 申请 `{ statementId, customerId, amount, taxRate, type }` |
| POST | `/invoices/{id}/issue` | 实际开具 `{ no, issueDate }` 回填发票号 |
| POST | `/invoices/{id}/reject` | 驳回 `{ reason }` |
| POST | `/invoices/{id}/red-flush` | 红冲 `{ reason }`，生成负数票，原票置 `已红冲` |

### 5.6 回款与核销

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/receipts` | 列表，每行返回 `allocatedAmount / openAmount` |
| GET | `/receipts/{id}` | `{ receipt, allocations, availableInvoices }` |
| POST | `/receipts` | 登记到账 |
| POST | `/receipts/{id}/allocate` | 核销 `{ allocations: [{ targetType, targetId, amount }] }` |
| POST | `/receipts/{id}/revoke-allocation` | 反核销 `{ allocationId, reason }` |
| GET | `/receivables` | 应收明细（发票维度），供核销弹窗选单 |

### 5.7 费用

沿用现有 `expense.*`，路径 `/finance/expenses`，与订单**无外键关系**，独立核算。

---

## 六、后端必须拦的 15 条规则

这些是前端已经在提示、但**只有后端拦才算数**的。前端提示只是体验，绕过前端直接调接口必须被挡。

| # | 规则 | 触发时机 | 返回 |
|---|---|---|---|
| 1 | 单号唯一（每类单据各自序列，按年重置） | 创建 | 409 `单号已存在` |
| 2 | `requestId` 重复直接返回上次结果 | 创建 | 200 原结果 |
| 3 | 成交价 < 成本价 → 转「待审批」，不阻断 | 建单 | 202 `{ status: '待审批', reason: '低于成本价' }` |
| 4 | 信用占用 + 本次金额 > `credit_limit` → 转「待审批」 | 建单 | 202 `{ status: '待审批', reason: '超出信用额度', available }` |
| 5 | 合同订单必须校验合同状态 = 执行中，且商品在协议范围内 | 建单 | 422 `合同未生效或商品不在协议范围` |
| 6 | 合同订单累计下单量不得超过协议量 | 建单 | 422 `超出合同协议量，剩余 X 箱` |
| 7 | 已取消/已签收订单不能再发货 | 发货 | 409 `订单状态不允许发货` |
| 8 | 单次发货量 ≤ 未发量（`qty - shipped_qty`） | 发货 | 400 `发货数量超过未发数量` |
| 9 | 退货量 ≤ 已签收量 − 已退量 | 退货 | 400 `退货数量超过已签收数量` |
| 10 | 退货单价必须取原订单明细单价，不允许重新取价 | 退货 | 内部断言，不对外 |
| 11 | 对账单 `close = open + shipped − received` 必须成立 | 生成/确认 | 500 内部一致性错误，写日志 |
| 12 | 同一客户同一 `period` 只能有一张有效对账单 | 生成 | 409 `该客户本期对账单已存在（DZ-xxx）` |
| 13 | 开票金额 ≤ 对账单已确认金额 − 已开票金额；对账单未确认不能开票 | 开票 | 409 `对账单尚未确认` / 400 `超过可开票金额` |
| 14 | 单条核销额 ≤ 单据未收金额；合计 ≤ 收款单未核销余额 | 核销 | 400 / 422 |
| 15 | 发票已有核销不能红冲，必须先反核销 | 红冲 | 409 `该发票已有核销 ¥X，需先反核销` |

补充两条一致性作业（非接口，但必须做）：

- **库存**：发货成功扣减可用库存，退货入库回补。若库存模块未上线，先只记录发货数量，不扣库存但要留 `stock_applied` 标记，避免后续补账困难。
- **金额缓存校验**（每日 02:00）：
  ```sql
  SELECT o.id, o.amount, SUM(i.amount) AS calc
  FROM crm_orders o JOIN crm_order_items i ON i.order_id = o.id
  WHERE o.deleted_at IS NULL
  GROUP BY o.id, o.amount
  HAVING ABS(o.amount - calc) > 0.01;
  ```
  有结果就告警，不要自动修 —— 自动修会把 bug 藏起来。

---

## 七、取价服务（一个函数，多处复用）

下单、改价、退货校验、报价单全走同一套逻辑，**不要在四个地方各写一遍**。

```
输入：productId, customerId, unit, qty
1. 标准价 list   = crm_product_units 中该单位的标准价
2. 成本价 floor  = 同表的成本价（底价，不外露给无 product.cost 权限的角色）
3. 协议价 = list × 合同折扣（取执行中合同；无合同则 list）
4. 阶梯价 = 按销售单位折算销量后命中的最高一档（crm_product_tiers）
5. 经销价 = crm_product_units 中该单位的经销价
6. 候选集 = [协议价, 阶梯价, 经销价]，取最小值；标准价兜底
7. 同时返回 priceSource 用于前端展示来源
```

三条注意：

- **单位换算必须走 `factorOf`**。产品模块存 `base_price`（最小单位价）+ `sale_unit`，箱/包的倍率在 `crm_product_units` 里，别硬编码。
- **阶梯价按销售单位折算销量再比档位**，否则「买 10 箱」会被当成「买 10 个」错配到最低档。
- **成本价权限隔离**：`order.view` 但不带 `product.cost` 的角色，接口返回里不能出现 `floor` 字段，前端毛利率列也要隐藏。

---

## 八、批处理与定时任务

| 任务 | 频率 | 说明 |
|---|---|---|
| 月度对账单预生成 | 每月 1 日 06:00 | 给有往来的客户生成 `待确认` 草稿，财务复核后发客户 |
| 超期未核销提醒 | 每日 09:00 | 到账 > 7 天仍未核销完的收款单，通知财务 |
| 账龄刷新 | 每日 01:00 | 按签收日 + 账期算逾期，写入 `crm_ar_aging` 或直接现算 |
| 金额缓存校验 | 每日 02:00 | 见第六节末尾 |
| 合同到期提醒 | 每日 09:00 | 30 天内到期的执行中合同，推给负责人 |

---

## 九、上线顺序（按这个顺序，不要并行）

1. **建表 + 权限**：跑 DDL，`crm-order-perms.sql` 已就绪。
2. **合同**：先有合同才有协议价，订单才能建。接口 5.3。
3. **订单 + 取价**：5.1 + 第七节。此时 `/orders`、详情页可以切真实数据。
4. **发货 + 签收**：5.2 前半。业绩口径从这里开始有数。
5. **退货**：5.2 后半。
6. **对账单**：5.4。依赖 3、4、5 的明细准确。
7. **发票**：5.5。
8. **收款 + 核销**：5.6。**必须最后做** —— 它依赖发票，发票依赖对账。
9. **切换前端**：把 `src/data/orderCenter.js` 的引用逐页换成 `orderApi.*`，一页一页切，每切一页跑一次对账恒等式校验。

数据迁移注意：现有 `crm_contracts` 如果已有签约金额数据（老版本），迁移时把 `amount` 保留，`discount` 默认 1.000、`status` 置 `执行中`，不要重算，历史数据重算会变。

---

## 十、工作量估算（1 名后端，含自测）

| 阶段 | 内容 | 人日 |
|---|---|---|
| 1 | 12 张表 DDL + 索引 + 权限脚本执行 | 1.5 |
| 2 | 合同（含协议商品、审批流） | 2.5 |
| 3 | 取价服务 + 订单 CRUD + 双重拦截 | 4 |
| 4 | 发货 / 签收 / 退货（含数量回写） | 4 |
| 5 | 对账单生成 + 恒等式校验 + 导出 | 3 |
| 6 | 发票（含红冲、税额倒算） | 2.5 |
| 7 | 收款 + 核销 + 反核销 | 4 |
| 8 | 批处理 5 个定时任务 | 2 |
| 9 | 前端逐页切换 + 联调 | 3 |
| | **合计** | **26.5 人日** |

如果只做最小可用（合同 + 订单 + 发货 + 回款核销，砍掉对账与发票），约 13 人日，但**对账单必须先做**，否则客户月度对账还是靠 Excel，财务不认这个系统。

---

## 十一、前端已有的假数据（后端可对照字段）

`src/data/orderCenter.js` 里每个集合就是接口返回的字段样例：

| 集合 | 条数 | 对应表 |
|---|---|---|
| `contracts` | 8 | `crm_contracts` + `crm_contract_items` + `crm_contract_approvals` |
| `orders` | 15 | `crm_orders` + `crm_order_items` |
| `shipments` | 13 | `crm_shipments` |
| `returns` | 3 | `crm_returns` + `crm_return_items` |
| `statements` | 6 | `crm_statements` |
| `receipts` | 7 | `crm_receipts` + `crm_receipt_allocations` |
| `invoices` | 10 | `crm_invoices` |

演示数据里的恒等式都是真的，可以当后端单测的期望值用：

- 所有对账单满足 `open + shipped − received = close`
- 所有收款单满足 `Σ allocations ≤ amount`
- 所有发票满足 `tax_amount = amount × 0.13 ÷ 1.13`

---

## 十二、权限相关的两处坑（2026-11-14 联调补充）

### 1. 新建订单弹窗把「无权限的资源」一起预加载，403 拖垮整个弹窗

`OrderList.openCreate()` 原来是：

```js
const [people, catalog, agreements] = await Promise.all([
  customerApi.list(), productApi.list({ pageSize: 500 }), orderApi.contracts({ pageSize: 500 })
])
```

销售顾问（`demo_sales`）有 `order.create`，却没有 `contract.view`。三个请求并发，
`GET /contracts` 返回 403 → `Promise.all` 整体 reject → 弹窗根本没打开，
只弹一句「没有权限执行该操作」。用户看到的是「有新建订单权限却用不了」。

**现在的处理**：

| 情况 | 行为 |
|---|---|
| 有 `contract.view` | 正常加载合同，订单类型默认「合同订单」 |
| 没有 `contract.view` | 跳过合同请求，订单类型默认「备货订单」，「合同订单」置灰并提示「无合同查看权限，只能下备货订单」 |
| 客户名下没有执行中合同 | 自动从「合同订单」切到「备货订单」，避免提交时被「请选择关联合同」拦住 |

**后端要记住的契约**：`order.create` 与 `contract.view` 是两个独立权限点，
`POST /orders` 只校验 `order.create`，`GET /contracts` 只校验 `contract.view`。
前端不能假设「能下单就能看合同」。

### 2. 数据侧：销售顾问有 `contract.create` 却漏了 `contract.view`

`crm_role_permissions` 里 `demo_sales` 原本有「新建合同」却没有「查看合同」，
结果是建完的合同自己也打不开、下单也选不了合同。已在 `database/crm-order-perms.sql`
第 4.1 节补上 `contract.view`（合同列表按 `owner_id` 过滤，不会看到别人的合同）。

顺带发现：`sales_manager`、`super_admin` 都是 `order.create + contract.view + contract.create` 齐全，
只有销售顾问这个角色是断的。新增角色时建议按下面这个组合检查：

```
能下合同订单  = order.create && contract.view
能下备货订单  = order.create
能看合同单号  = contract.view
```

### 3. 订单列表「合同订单 · 13」把主键当单号显示

列表接口返回的是 `contractId`（合同表主键），模板直接拼进副标题就是「合同订单 · 13」。
现在页面会额外拉一次合同列表做 id→单号映射，没权限或没加载到就只显示「合同订单」。

### 4. 建议后端补的两点

- `POST /orders` 在「低于底价 / 超信用额度」时返回 201 + `warnings`，前端已按「成功但有提示」处理
  （之前用红色报错图标，像是下单失败）。建议 `warnings` 里带上机器可读的 `code`，
  例如 `{code:'CREDIT_EXCEEDED', message:'超过可用信用额度'}`，前端好做不同的引导。
- `GET /orders/{id}` 目前不返回客户信用信息，详情页的「账期 / 可用额度」还是前端演示常量，
  真实数据下会显示成假值。建议在 `order` 里补 `customerCredit: {limit, used, available, term}`，
  或让详情页单独调 `GET /customers/{id}/credit`。
