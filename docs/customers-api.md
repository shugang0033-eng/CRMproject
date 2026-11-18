# 客户 360 · 前端接口契约与后端清单

> 前端已完成，后端按本文档实现即可对接。所有接口前缀 `/api`，鉴权沿用现有 Cookie 会话。
> **前端在没有接口时会回落到本地演示数据**（`src/data/customerDetail.js`），所以页面现在就能看，接口一旦就绪自动切换。

## 一、这次改了什么

| 原来 | 现在 |
|---|---|
| 客户列表 / 公海客户 / 联系人 / 跟进记录（4 项） | 客户列表 / 客户池 / 团队跟进（3 项） |
| 「详情」按钮只弹提示 | 进入 `/customers/{id}` 客户 360 视图 |
| 联系人独立成表 | 客户详情 › 联系人 tab（列表页可按联系人姓名手机号搜客户） |
| 跟进记录独立成表 | 客户详情 › 跟进动态 tab；团队视角改由看板承载 |
| 客户状态、累计采购、最近跟进均为前端写死 | 由交易事实推导，后端补字段后直接读 |

## 二、表结构变更

### 2.1 crm_customers 补字段

```sql
ALTER TABLE crm_customers
  ADD COLUMN phone          VARCHAR(32)   NULL COMMENT '主电话号码',
  ADD COLUMN address        VARCHAR(255)  NULL COMMENT '注册/收货地址',
  ADD COLUMN region         VARCHAR(64)   NULL COMMENT '省 · 市，列表筛选用',
  ADD COLUMN status         VARCHAR(20)   NOT NULL DEFAULT '跟进中'
               COMMENT '合作中 / 跟进中 / 待回款 / 流失风险，由交易事实推导',
  ADD COLUMN status_at      DATETIME      NULL COMMENT '状态变更时间，用于「30 天无变化」预警',
  ADD COLUMN credit_limit   DECIMAL(14,2) NOT NULL DEFAULT 0 COMMENT '信用额度（元）',
  ADD COLUMN credit_used    DECIMAL(14,2) NOT NULL DEFAULT 0
               COMMENT '已用额度，只统计未结清合同，不许手工填',
  ADD COLUMN payment_term   SMALLINT      NOT NULL DEFAULT 0 COMMENT '账期天数，0 = 现款',
  ADD COLUMN source         VARCHAR(64)   NULL COMMENT '线索来源快照',
  ADD COLUMN note           VARCHAR(500)  NULL COMMENT '客户画像备注',
  ADD COLUMN last_follow_at DATETIME      NULL COMMENT '写跟进时同步更新，客户池回池判定依据',
  ADD COLUMN last_order_at  DATETIME      NULL COMMENT '最近下单时间',
  ADD COLUMN merged_into_id BIGINT UNSIGNED NULL COMMENT '合并后指向主档，非空即作废',
  ADD INDEX idx_cust_status (status),
  ADD INDEX idx_cust_last_follow (last_follow_at),
  ADD INDEX idx_cust_merged (merged_into_id);
```

> `credit_limit / payment_term` 与 `crm_customer_prices.discount` 是谈单时最常被问的三个数，前端已经摊在详情页头部。

### 2.2 crm_customer_contacts 补字段

```sql
ALTER TABLE crm_customer_contacts
  ADD COLUMN title           VARCHAR(64)  NULL COMMENT '职位',
  ADD COLUMN email           VARCHAR(128) NULL,
  ADD COLUMN role            VARCHAR(16)  NOT NULL DEFAULT 'user'
               COMMENT 'decision 决策人 / user 使用人 / payer 付款人',
  ADD COLUMN is_primary      TINYINT(1)   NOT NULL DEFAULT 0,
  ADD COLUMN last_contact_at DATETIME     NULL,
  ADD INDEX idx_contact_primary (customer_id, is_primary);
```

**同一客户只允许一个主联系人**，建议用生成列 + 唯一索引兜底：

```sql
ALTER TABLE crm_customer_contacts
  ADD COLUMN primary_key BIGINT UNSIGNED
      GENERATED ALWAYS AS (IF(is_primary = 1, customer_id, NULL)) STORED,
  ADD UNIQUE KEY uk_contact_primary (primary_key);
```

### 2.3 新增 crm_customer_follow_tasks（团队跟进看板的数据源）

```sql
CREATE TABLE IF NOT EXISTS crm_customer_follow_tasks (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  customer_id BIGINT UNSIGNED NOT NULL,
  owner_id    BIGINT UNSIGNED NOT NULL COMMENT '看板上按这个人分组',
  state       VARCHAR(16)     NOT NULL DEFAULT 'plan'
              COMMENT 'plan 计划 / due 今日到期 / overdue 超期 / done 已完成',
  due_date    DATE            NOT NULL COMMENT '约定跟进日',
  content     VARCHAR(500)    NULL COMMENT '这次要谈什么',
  source      VARCHAR(16)     NOT NULL DEFAULT 'manual'
              COMMENT 'manual 手工建 / followup 跟进时留的 next / contract 合同节点',
  done_at     DATETIME        NULL,
  done_by     BIGINT UNSIGNED NULL,
  created_by  BIGINT UNSIGNED NOT NULL,
  created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_task_owner_state (owner_id, state, due_date),
  KEY idx_task_customer (customer_id),
  CONSTRAINT fk_task_customer FOREIGN KEY (customer_id) REFERENCES crm_customers (id),
  CONSTRAINT fk_task_owner FOREIGN KEY (owner_id) REFERENCES crm_employees (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

`state` 是冗余字段，每天由定时任务重算（`due_date < CURDATE()` → overdue，`= CURDATE()` → due，`> CURDATE()` → plan）。**不要在查询时实时算**，看板要按状态排序和计数。

### 2.4 新增 crm_customer_attachments

```sql
CREATE TABLE IF NOT EXISTS crm_customer_attachments (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  customer_id BIGINT UNSIGNED NOT NULL,
  name        VARCHAR(200)    NOT NULL,
  type        VARCHAR(16)     NOT NULL COMMENT '资质 / 合同 / 财务',
  size_bytes  INT UNSIGNED    NOT NULL DEFAULT 0,
  url         VARCHAR(500)    NOT NULL COMMENT '对象存储地址，不要存二进制',
  uploaded_by BIGINT UNSIGNED NOT NULL,
  created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_att_customer (customer_id),
  CONSTRAINT fk_att_customer FOREIGN KEY (customer_id) REFERENCES crm_customers (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 2.5 新增 crm_customer_merges（合并审计）

```sql
CREATE TABLE IF NOT EXISTS crm_customer_merges (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  from_id         BIGINT UNSIGNED NOT NULL COMMENT '被作废的档案',
  to_id           BIGINT UNSIGNED NOT NULL COMMENT '主档',
  operator_id     BIGINT UNSIGNED NOT NULL,
  moved_contacts  INT NOT NULL DEFAULT 0,
  moved_followups INT NOT NULL DEFAULT 0,
  moved_contracts INT NOT NULL DEFAULT 0,
  note            VARCHAR(255) NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_merge_from (from_id),
  CONSTRAINT fk_merge_from FOREIGN KEY (from_id) REFERENCES crm_customers (id),
  CONSTRAINT fk_merge_to FOREIGN KEY (to_id) REFERENCES crm_customers (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**合并不能物理删除。** from 档案保留 + `merged_into_id` 指向 to，历史合同的外键才不会断。

## 三、接口清单

所有接口都走现有 `SALES_SCOPE` 数据范围（`none / dept / all`，权限码 `data.scope.dept` / `data.scope.all` 决定）。越权必须 **403**，不要静默返回空数组——前端会当成「没有数据」而不是「没权限」。

### 3.1 GET /customers/{id} —— 详情聚合（最重要）

一次返回详情页 4 个 tab 需要的全部数据，避免首屏打 5 个请求。

```json
{
  "profile": {
    "id": 4, "name": "杭州驰远汽车服务连锁", "industry": "汽修连锁",
    "level": "战略客户", "owner": "林致远", "ownerId": 5,
    "createdAt": "2023-04-18", "phone": "0571-8823 6610",
    "address": "浙江省杭州市拱墅区祥园路 208 号 3 幢", "region": "浙江 · 杭州",
    "source": "2023 上海汽配展 · 官网询盘",
    "tags": ["年度集采", "价格敏感度低"],
    "note": "集团采购中心统一比价…",
    "discount": 0.88, "discountScope": "洗车毛巾 / 清洁工具全系",
    "term": 30,
    "credit": { "limit": 1200000, "used": 745600 },
    "status": "合作中"
  },
  "metrics": {
    "total": 1864000, "net90": 428000, "orders": 14, "avgOrder": 133143,
    "cycle": 26, "lastOrder": "2026-11-06",
    "receivable": 745600, "overdue": 0, "creditRemain": 454400,
    "tier": { "label": "重要价值", "tone": "tag-brand" }
  },
  "contacts": [
    { "name": "沈立", "title": "供应链总监", "phone": "138****6621",
      "email": "shenli@chiyuan-auto.com", "role": "decision",
      "roleLabel": "决策人", "roleTone": "tag-brand",
      "primary": true, "lastContact": "2026-11-10" }
  ],
  "timeline": [
    { "at": "2026-11-10 11:00", "kind": "follow", "title": "线上会议跟进 · 林致远",
      "desc": "确认 2027 年度紧固件集采框架…", "meta": "下次跟进 2026-11-12", "tone": "success" }
  ],
  "contracts": [ ... ], "payments": [ ... ],
  "monthly": [ { "month": "06", "amount": 128000 } ],
  "attach": [ { "name": "营业执照.pdf", "size": "1.2 MB", "type": "资质",
                "at": "2023-04-18", "ok": true } ]
}
```

要点：

- `metrics` 由后端算，**不要前端拼**。`total` 是签约额，`receivable` 是未回款余额（含逾期），`overdue` 单独给。
- `timeline` 是合成流：跟进 + 合同签署 + 回款到账/逾期 + 负责人变更，按时间倒序，默认返回最近 50 条。
- `tier` 后端算（`total / net90 / cycle` 三个值推），前端只负责配色。
- `monthly` 固定返回最近 6 个月，没有的月份补 0，不要漏月。

### 3.2 GET /customers/{id}/timeline?before={datetime}&limit=50

时间线分页。`before` 用上一页最后一条的 `at`，游标分页（不要 offset，合成流会重复）。

### 3.3 GET /customers/{id}/orders

返回 `{ contracts: [], payments: [] }`。合同带 `paid` 百分比（已回款/签约额）。

### 3.4 POST /customers/{id}/followups

```json
{ "type": "电话", "result": "推进", "content": "…", "next": "2026-11-20" }
```

事务内必须做三件事：

1. 写 `crm_lead_followups`（跟进表已有，`customer_id` 复用）
2. 更新 `crm_customers.last_follow_at = NOW()`、`status` 重算
3. `next` 非空时，把对应 `crm_customer_follow_tasks` 标记 done 并新建一条 `source='followup'` 的任务

### 3.5 GET /customers/follow-board?range=week&deptId=&ownerId=

```json
{
  "serverDate": "2026-11-14",
  "members": [
    { "name": "林致远", "dept": "汽配渠道部", "role": "销售顾问",
      "done": 1, "total": 3, "rate": 33,
      "tasks": [
        { "id": 3001, "customer": "杭州驰远汽车服务连锁", "customerId": 4,
          "state": "due", "due": "2026-11-14", "last": "2026-11-10 11:00",
          "result": "推进", "content": "确认年度集采框架回签" }
      ] }
  ]
}
```

- `serverDate` 必须返回，前端不再用本地时间算超期（现在的 `ANCHOR` 常量会被它替换）。
- `tasks` 按「超期天数倒序 → 今日到期 → 计划」排，后端排好，前端不再排序。
- 没有待办的人也要返回（`tasks: []`），主管要看谁没排计划。

### 3.6 PATCH /customers/follow-tasks/{taskId}

```json
{ "done": true }
```

只允许改自己名下的任务（`dept` 范围除外）。

### 3.7 POST /customers/merge

```json
{ "fromId": 12, "toId": 4, "note": "同一门店两个采购分别询盘" }
```

事务内：迁移 contacts / followups / follow-tasks / attachments / contracts → 写 `merged_into_id` → 写 `crm_customer_merges`。

**校验**（缺一不可）：

| 情况 | 返回 |
|---|---|
| `fromId === toId` | 400 |
| `toId` 已被合并（`merged_into_id` 非空） | 400 |
| `fromId` 有未结清合同（`paid < 100` 且未终止） | 409 |
| 目标客户不在当前用户数据范围内 | 403 |
| 合并后主联系人超过 1 个 | 自动保留 toId 的原主联系人，其余置 0 |

### 3.8 POST /customers/duplicates/check

新建客户前查重，按名称相似 + 电话相同判定：

```json
{ "name": "杭州驰远汽车服务", "phone": "0571-88236610" }
→ { "duplicates": [ { "id": 4, "name": "杭州驰远汽车服务连锁", "owner": "林致远", "score": 0.92 } ] }
```

名称用 `LIKE` 前缀 + 编辑距离，别上全文索引，10 万级客户量级够用。

### 3.9 POST /customers/transfer —— **需要扩一个语义**

现有实现只支持「换负责人」。客户池退回要支持 `ownerId: null`：

```json
{ "ids": [4], "ownerId": null, "reason": "长期未跟进" }
```

`ownerId = null` 时：`owner_id` 置空（或置为池子的系统账号）、写 `pool_entered_at`、`pool_reason`、写 owner_history。**不能复用 transfer 的「必须是在职员工」校验**，要分支处理。

### 3.10 ⚠️ 路由冲突：GET /customers/contacts 必须改路径

现在 `GET /api/customers/contacts` 是「全部联系人」列表。加了 `GET /customers/{id}` 之后，Spring 会把 `contacts` 当成 `{id}` 解析，报 `NumberFormatException` → 500。

两个方案，选一个：

- **推荐**：把联系人列表挪到 `GET /api/contacts?customerId=`（独立资源，语义也更对）
- 或者：`{id}` 用 `@PathVariable Long id` 并在 contacts 之上下顺序声明，靠精确路径优先匹配——但 `setUseSuffixPatternMatch` 在新版本不可靠，不建议

前端 `customerApi.contacts()` 目前调的就是 `/customers/contacts`，改路径后同步改这一行即可。

## 四、口径与校验（写死在代码里，别留配置）

1. **累计下单额** = 该客户所有有效订单（排除 `草稿 / 已取消 / 已退货`）的 `amount` 之和。
   合同是框架额度，**不能**和订单额混在一个字段里；合同金额单独用 `contractAmount`。
   > 2026-11 调整：原口径写的是「合同 amount 之和」，但合同是年框额度（一份 123.5 万的框架，
   > 客户实际只下了 15.3 万），拿框架额当「累计签约」会让列表虚高 8 倍，故改为订单口径。
2. **应收余额** = 未回款合同金额 − 已确认回款，含逾期。**不能为负**，退款另走红冲。
3. **信用额度使用**：`credit_used` 由合同与回款计算，禁止提供写接口改。
4. **平均复购周期** = 相邻两笔订单 `sign_date` 间隔的均值（天），订单数 < 2 返回 `null` 而不是 0——前端会显示「—」。
5. **除数为 0 一律返回 `null`**，不要返回 `Infinity` 或 0（`avgOrder`、`cycle`、`rate` 都是）。
6. **客户状态推导优先级**：未成交 → 跟进中；有逾期 → 待回款；成交且超 90 天没下单 → 流失风险；其余 → 合作中。
   这个顺序不能调，否则「有逾期但也在正常进货」的客户会被判成合作中。
   「成交」的判定见 7.2，**不是**看有没有合同签署记录。
7. **金额单位**：接口一律「元」，`DECIMAL(14,2)`，前端负责转万。与产品模块价格口径不同（那里存最小单位价），别混。
8. **脱敏**：`phone` 返回时中间四位打码（列表和详情一致），编辑时才返回明文，且需要 `customer.edit`。

## 五、后端任务清单（建议按这个顺序做）

| # | 任务 | 依赖 | 估时 |
|---|---|---|---|
| 1 | `crm_customers` / `crm_customer_contacts` 加字段（2.1 / 2.2） | 无 | 0.5d |
| 2 | 建 3 张新表（2.3 / 2.4 / 2.5） | 1 | 0.5d |
| 3 | 把 `GET /customers/contacts` 挪到 `/api/contacts`，前端同步改一行 | 无 | 0.5h |
| 4 | `GET /customers/{id}` 聚合接口 + `metrics` 计算 | 1 | 2d |
| 5 | 写跟进接口，联动 `last_follow_at` 与 follow-task | 2,4 | 1d |
| 6 | 团队跟进看板接口 + `serverDate` + 每日状态重算定时任务 | 2 | 1.5d |
| 7 | 合并客户 + 查重 | 2 | 1.5d |
| 8 | `transfer` 支持 `ownerId = null`（退回客户池） | 无 | 0.5d |
| 9 | 附件上传（接对象存储，**不要存 BLOB**） | 2 | 1d |
| 10 | 客户池自动回池定时任务（`last_follow_at` 超 30 天） | 4 | 0.5d |

**合计约 9 人日。** 其中 #1 #3 #4 做完，360 详情页就能全部跑真实数据，可以先上线这一批，#6 #7 是第二批。

## 六、兼容与迁移

- `crm_demo_seed.sql` 里 10 个客户的名称是前端演示数据的匹配键（`buildCustomerDetail` 按名称取 profile）。**改名不会坏**，只会回落到默认值，接口就绪后此逻辑不再触发。
- 新增的两个权限点已由 `database/crm-customer-perms.sql` 灌库（已执行、幂等），销售默认没有合并与看板权限。
- 同一份脚本还补了运营总监（`demo_ops`）的 `customer.public` / `customer.public.claim`——他原来连客户池都进不去，但要盯滞留客户、退回问题客户。销售运营（`sales_operations`）一并补齐 `customer.edit` / `contact.edit`，否则转客户后改不了档案。
- 旧链接 `/customers/contacts` → `/customers`，`/customers/followups` → `/customers/follow-board`，已做前端重定向，书签不会 404。
- `src/views/customers/Contacts.vue`、`FollowUps.vue` 已不在路由里，保留作参考，可随时删除。
- 详情页访问越权客户时，前端不做「取第一条」兜底，直接显示「客户不存在、已被合并，或不在你的数据范围内」。后端上线后这里应该由 403 接管。

---

## 七、客户生命周期与档案编辑（2026-11 本轮）

### 7.1 三个维度必须分开，不要合成一个「状态」

| 维度 | 回答的问题 | 取值 | 谁能改 |
|---|---|---|---|
| 阶段 | 成交没成交 | 跟进中 / 已成交（有成交事实） | 系统，由订单与合同事件推导 |
| 健康度 | 钱收得回来吗 | 正常 / 待回款 / 逾期 / 沉睡 | 系统，由订单与回款推导 |
| 归属 | 有没有人负责 | 有主 / 客户池（`owner_id IS NULL`） | 主管，走 `POST /customers/transfer` |

**两条产品结论（已按此实现，不要回退）：**

1. **成交后不进客户池。** 池的语义是「无主、谁都能领」，把刚成交的客户放进去等于把销售谈下来的资产送给同事；
   而且客户池的回池规则是「30 天无跟进自动退回」，成交客户本来就不需要密集跟进，会被系统自动踢进池。
   **后端回池定时任务必须加条件 `status <> '合作中'`（或 `status NOT IN ('合作中','待回款')`）。**
2. **不新建「成交客户」菜单。** 同一个客户会同时出现在两个列表、金额口径要算两遍、合同到期又要挪。
   客户列表的「已成交」tab 就是这个视图（`hasDeal = true`）。

### 7.2 成交判定与状态推导

前端实现：`src/utils/customer.js`（列表与详情共用，唯一口径）。

```
作废订单     = 草稿 / 已取消 / 已退货            → 不计入任何金额
成交订单     = 待发货 / 部分发货 / 已签收        → 表示订单已成立
生效合同     = 执行中 / 已完成                  → 框架协议已生效
hasDeal      = 存在成交订单 或 存在生效合同
```

状态优先级（不可调序）：

| 顺序 | 条件 | 状态 |
|---|---|---|
| 1 | `!hasDeal` | 跟进中 |
| 2 | 逾期金额 > 0 | 待回款 |
| 3 | 成交且距今 > 90 天没有新订单 | 流失风险 |
| 4 | 其余 | 合作中 |

**后端要求（P0）：**

1. 订单进入 `待发货 / 已签收` 时回写 `crm_customers.last_order_at`；目前 `last_order_at` 一直是 `NULL`。
2. `status` 由系统重算并写 `status_at`，**`PATCH /customers/{id}` 不接受 `status` 入参**。
3. 回写建议放在事件里（下单 / 发货 / 签收 / 回款核销），不要散落在各个 Service 里各写一遍。
   需要全量纠偏时跑一次批处理：

```sql
UPDATE crm_customers c SET c.status = CASE
  WHEN NOT EXISTS (SELECT 1 FROM crm_orders o WHERE o.customer_id=c.id AND o.deleted_at IS NULL
                     AND o.status IN ('待发货','部分发货','已签收'))
   AND NOT EXISTS (SELECT 1 FROM crm_contracts ct WHERE ct.customer_id=c.id AND ct.deleted_at IS NULL
                     AND ct.status IN ('执行中','已完成')) THEN '跟进中'
  WHEN EXISTS (/* 已签收订单按日期先进先出冲销回款后，仍有超过 payment_term 的未收部分 */ 1) THEN '待回款'
  WHEN c.last_order_at IS NOT NULL AND DATEDIFF(CURDATE(), c.last_order_at) > 90 THEN '流失风险'
  ELSE '合作中' END,
  c.status_at = NOW()
WHERE c.merged_into_id IS NULL;
```

> 逾期那一段 SQL 只是占位：回款不落到单，必须按「先进先出冲销」（前端 `overdueOf()` 就是这么做的）。
> 建议在 Service 层用同款算法算，别硬塞进一条 SQL，否则以后加核销逻辑还要重写。

### 7.3 `GET /customers` 必须补聚合字段（P0）

现状：`CustomerRow` 只有 `id / name / industry / level / ownerId / owner / contacts`。
前端为了把列表金额算对，只能额外拉三张明细表再自己 group by：

```
GET /orders?pageSize=500
GET /contracts?pageSize=500
GET /receipts?pageSize=500
```

问题很明确：客户超过 500 家就统计不全；三次全表查询；`/receipts` 没权限时整列降级。

请给列表行补上（字段名随意，前端会同时兼容驼峰与下划线）：

| 字段 | 说明 |
|---|---|
| `orderCount` | 有效订单数（排除草稿/已取消/已退货） |
| `orderAmount` | 有效订单金额合计 |
| `net90Amount` | 近 90 天下单额 |
| `receivable` | 应收余额 = 已签收金额 − 已回款（不为负） |
| `overdue` | 逾期金额（FIFO 冲销后超过账期的部分） |
| `lastOrderAt` | 最近下单日期 |
| `paymentTerm` | 账期天数（**列表现在没有这个字段，只能从合同里猜**） |
| `creditLimit` / `creditUsed` | 授信 / 已用 |
| `contractAmount` | 生效合同金额合计（框架额度） |
| `status` | 后端回写后的状态 |

### 7.4 `GET /customers/{id}` 的 metrics 是写死的 0（P1）

实测（客户 4 杭州驰远，数据库 4 张订单合计 ¥152,613）：

```json
"metrics": {"total":0,"net90":0,"orders":0,"receivable":0,"overdue":0,"avgOrder":null,"cycle":null}
```

`contracts` / `payments` / `monthly` 也直接返回空数组。页面看起来「有数据」是因为前端拿演示档案按客户名兜底，
换成真实客户就全 0。

前端已改为按 `customerId` 拉订单 / 合同 / 回款三份明细自行汇总，接口补齐后删掉这段即可
（`CustomerDetail.vue` 的 `load()` 里会多出三次请求）。

### 7.5 `PATCH /customers/{id}` —— 档案编辑（P1）

前端已实现表单与提交（`CustomerDetail.vue` 编辑弹窗），接口未实现时返回 404，界面会明确提示「没有保存」，
**不会本地改值**。

请求体（只接受这些字段，其余忽略或 400）：

```json
{
  "name": "杭州驰远汽车服务连锁",
  "industry": "汽修连锁",
  "level": "战略客户",
  "region": "浙江 · 杭州",
  "phone": "13800000000",
  "address": "浙江省杭州市拱墅区…",
  "source": "官网询盘",
  "note": "决策链长，季度集采",
  "paymentTerm": 45,
  "creditLimit": 800000
}
```

规则（照抄，别放配置）：

1. **不接受** `status` / `status_at` / `creditUsed` / `lastOrderAt` / `ownerId` / `orderAmount`
   —— 这些是交易事实或另一个动作（转负责人），传了要 400，不能静默忽略。
2. `paymentTerm` / `creditLimit` 需要 `customer.credit` 权限（本轮新增），否则 **403**。
   理由：账期和额度直接决定能不能赊销下单，销售能改 = 自己提额度再下超限单，绕过审批。
3. `name` 必填、≤ 200 字；改名要查重（复用 `POST /customers/duplicates/check`），
   命中同名 409，让前端提示「是否合并」。
4. `phone` 可能是脱敏值：详情接口返回 `138****1188`，前端**不会**把它写回。
   后端收到含 `*` 的 phone 要 400，别把星号存进库。
5. `paymentTerm` 0–180；`creditLimit` ≥ 0，且 **不得小于 `creditUsed`**（否则可用额度变负），违反 400。
6. 逐字段留痕（见 7.6），返回 `{ changed: ["paymentTerm","note"] }` 让前端提示改了几项。
7. 档案字段整体替换语义（传了才改，不传视为不改），不要「未传就清空」。

### 7.6 变更留痕（P2）

额度、账期改动以后一定会有人问「谁改的」。建议新增：

```sql
CREATE TABLE IF NOT EXISTS crm_customer_changes (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  customer_id BIGINT UNSIGNED NOT NULL,
  field       VARCHAR(32)     NOT NULL,
  before_value VARCHAR(255)   NULL,
  after_value  VARCHAR(255)   NULL,
  operator_id BIGINT UNSIGNED NOT NULL,
  created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_change_customer (customer_id, created_at),
  CONSTRAINT fk_change_customer FOREIGN KEY (customer_id) REFERENCES crm_customers (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 7.7 权限（已在 `database/crm-customer-perms.sql` 执行，幂等）

| 权限码 | 给了谁 | 为什么 |
|---|---|---|
| `customer.credit`（新增） | 超管 / 销售主管 / 运营总监 | 拆出账期与额度，销售改不了 |
| `payment.view`（补发） | 销售顾问 | 原来只有财务和管理层有，销售打开自己客户详情页应收全是空，`/receipts` 403 |

### 7.8 后端任务清单（本轮新增，按优先级）

| # | 优先级 | 任务 | 不改的后果 |
|---|---|---|---|
| 1 | **P0** | 订单状态流转时回写 `last_order_at` / `status` / `status_at` | 客户永远「跟进中」，成交客户视图和回池规则全都失效 |
| 2 | **P0** | 客户池回池定时任务加 `status NOT IN ('合作中','待回款')` | 成交客户被系统自动踢进池，销售不敢签单 |
| 3 | **P0** | `GET /customers` 补 7.3 的聚合字段 | 客户超过 500 家统计就错，且每次列表页多 3 个全表请求 |
| 4 | P1 | `GET /customers/{id}` 的 `metrics` / `contracts` / `payments` / `monthly` 真实计算 | 详情页指标靠前端临时汇总 |
| 5 | P1 | `PATCH /customers/{id}`（7.5） | 编辑表单存不进库 |
| 6 | P2 | `crm_customer_changes` 留痕（7.6） | 额度被谁改的查不出来 |
| 7 | P2 | 回款按合同核销（`crm_receipt_allocations` 已有表，缺写入口） | 多合同时「回款进度」只能显示「按客户汇总」 |

### 7.9 已知取舍（接口补齐后要一起收掉）

- 列表 / 详情现在是「前端拉明细自己汇总」，`pageSize=500` 是硬上限，客户数超了会少算。
- 回款不按合同核销 → 只有一份合同时才显示回款进度百分比，多份显示「按客户汇总」。
- 销售顾问没 `payment.view` 时，应收与逾期返回 `null`，界面显示「—」而不是 0。

---

## 八、`POST /customers` —— 新建客户（2026-11 本轮，前端已完成）

前端入口：客户列表右上角「新建客户」（`customer.create`）。表单已做完，接口未实现时返回 **405**，
界面提示「新建客户接口还没实现（POST /customers），客户没有保存」，**不关弹窗、不往列表插假行**。

### 8.1 请求体

```json
{
  "name": "杭州驰远汽车服务连锁",
  "level": "C 类",
  "industry": "汽修连锁",
  "region": "浙江 · 杭州",
  "phone": "0571-88112233",
  "source": "官网询盘",
  "address": "浙江省杭州市拱墅区…",
  "paymentTerm": 0,
  "creditLimit": 0,
  "ownerId": 14,
  "contacts": [
    { "name": "沈立", "title": "采购经理", "phone": "13800000000", "isPrimary": true }
  ]
}
```

字段都是**可选除了 name**。前端只在有能力时才传 `ownerId` / `paymentTerm` / `creditLimit`。

### 8.2 硬规则（照抄，别做「更灵活」的版本）

| # | 规则 | 为什么 |
|---|---|---|
| 1 | `status` 固定写 **跟进中**，不接受入参 | 客户不可能一建档就成交；能传就能伪造成交 |
| 2 | `id` / 编号由后端生成，不接受入参 | 前端传编号 = 可覆盖他人档案 |
| 3 | `owner_id`：无 `lead.transfer` 的人传了也要 **忽略并落当前登录人**（建议直接 403 更明确） | 销售把客户建到同事名下，同事的业绩与跟进提醒都会错乱 |
| 4 | `paymentTerm` / `creditLimit` 需要 `customer.credit`，无权限传了要 **403**（不要静默改 0） | 静默改 0 会让销售以为设了额度，下单才发现不能赊销 |
| 5 | `paymentTerm` 0–180，`creditLimit` ≥ 0 且同一事务内 `credit_used` 从 0 起算 | 新客户不该带已用额度 |
| 6 | `name` 必填 ≤ 200，去首尾空格后查重：同名 **或** 同手机号命中 → `409` + `{ duplicates: [...] }` | 前端拿这个结果提示「已有相似客户」，让它自己决定要不要继续 |
| 7 | `level` 归一化为 `战略客户 / A 类 / B 类 / C 类` 四值 | 库里现在同时存在 `A` 和 `A 类`，两种写法会让筛选漏数据 |
| 8 | `contacts` 最多 1 条主联系人（本轮前端只提交 1 条），`is_primary` 为真时把同客户其他联系人置 0 | 多主联系人会让「联系谁」无法判断 |
| 9 | 事务内同时写 `crm_customers` + `crm_customer_contacts`，任意一步失败整体回滚 | 只建档案不建联系人，后续按手机号搜不到 |

### 8.3 响应

```json
{ "id": 27, "code": "C-2026-0027", "name": "杭州驰远汽车服务连锁", "ownerId": 14, "status": "跟进中" }
```

前端拿到 `id` 会**直接跳到新客户详情页**（`/customers/27`），接着补联系人、写跟进。
所以 `id` 一定要返回，返回 `code` 更好（列表里优先显示 `code`，没有才退回 `ID 26`）。

### 8.4 编号方案

`crm_customers` 现在没有编号列，列表只能用 `ID 26` 这种裸主键。建议加：

```sql
ALTER TABLE crm_customers
  ADD COLUMN code VARCHAR(32) NULL AFTER id,
  ADD UNIQUE KEY uk_customer_code (code);
```

生成规则与订单一致（`SO-2026-0101`）：`C-<年>-<4 位流水>`，按年重置，事务内取号。
存量 12 家客户需要一次性回填，回填脚本按 `created_at` 排序编号，否则老客户会全部显示 `ID xx`。

### 8.5 与编辑接口的关系

新建和编辑**共用同一份字段白名单**，区别只有三点：

| | `POST /customers` | `PATCH /customers/{id}` |
|---|---|---|
| 谁能调 | `customer.create` | `customer.edit` |
| 状态 | 固定写「跟进中」 | 不接受 |
| 负责人 | 可指定（需 `lead.transfer`） | 不接受，走 `/customers/transfer` |

### 8.6 本轮顺带修掉的显示问题

- 列表副标题原来写死 `{{ row.id }} · 建档 {{ row.createdAt }}`，而 `GET /customers` 不返回 `createdAt`，
  每一行都显示成「26 · 建档 」——现在改成 `ID 26`，有 `createdAt` 才追加建档时间，有 `code` 则优先显示 `code`。
- `.edit-sec / .readonly-grid / .warn-line / .field-note` 从客户详情页的 scoped 样式提升到 `global.css`，
  新建与编辑两个弹窗共用一套版式（原来是各写一份，容易越改越不像）。

---

## 九、后端实现进度（2026-11-14 22:54 同步）

写第七节时后端还只有 `list / contacts / transfer`；当天 22:54 后端补齐了客户模块，现状如下。
**第七节里标「待实现」的条目，以本节为准。**

### 9.1 已经能用的

| 接口 | 说明 |
|---|---|
| `GET /customers` | 每行带 `amount / orders / hasDeal / received / receivable / overdue / status / lastFollowAt`，金额按有效订单算 |
| `GET /customers/{id}` | `profile / metrics / contracts / payments / monthly / contacts / timeline` 全部真实计算 |
| `PATCH /customers/{id}` | 字段白名单、跳过无变化字段、返回 `{changed:[...]}`、逐字段写 `crm_customer_changes`、`phone` 含 `*` 直接 400、改名重名 409 |
| `GET /contacts`、`POST/PATCH .../contacts` | 联系人增改 |
| `POST /customers/{id}/followups` | 写跟进 |
| `POST /customers/merge`、`POST /customers/duplicates/check` | 合并与查重 |
| `GET /customers/pool`、`POST /customers/{id}/claim` | 客户池 |
| `GET /customers/follow-board`、`PATCH /customers/follow-tasks/{id}` | 跟进看板 |

实测 `GET /customers/4`（杭州驰远）：`total 152613.12 / orders 4 / receivable 31072 / received 101688.32 / cycle 30`，
与前端本地汇总、与 SQL 三方一致。

### 9.2 还没实现的

| 接口 | 现状 | 影响 |
|---|---|---|
| **`POST /customers`** | 405 | 本轮做的「新建客户」表单存不进库，这是唯一挡路的接口（契约见第八节） |

### 9.3 状态口径的实现方式变了（重要）

第七节建议「订单流转时回写 `status`」，后端实际选择**不落库、用视图 `crm_customer_trade` 实时算**：
`GET /customers` 的 `status` 由 `hasDeal / overdue / lastOrderAt` 现算，`crm_customers.status` 列仍是旧的「跟进中」。

这更省事，但带来两个约束：

1. **任何按 `status` 过滤的 SQL 都是错的**（列里全是「跟进中」）。要筛成交客户，必须 join `crm_customer_trade`。
   目前 `GET /customers/pool` 没有踩到，因为它按 `owner_id IS NULL AND pool_entered_at IS NOT NULL` 取——池只由**显式退回**产生。
2. **将来若加「30 天无跟进自动回池」的定时任务，条件里必须排除成交客户**（`hasDeal=1`），
   否则会自动把刚签下的客户扔进池子。这是产品红线，不是配置。

### 9.4 发现一个后端 bug：列表的联系人数量字段名是坏的

`CustomerMapper.list` 里这段子查询**没有别名**：

```sql
(SELECT COUNT(*) FROM crm_customer_contacts c WHERE c.customer_id = l.id)
```

MySQL 把整段 SQL 当列名，Spring 转 `Map` 再序列化后，JSON 里出现的是一个畸形键：

```json
"(SELECT COUNT(*) FROM crm_customer_contacts c WHERE c": { "customer_id = l": { "id)": 1 } }
```

后果：前端读不到 `contacts`，只能退回 `GET /contacts` 按客户名匹配来算（当前就是这么兜的，能显示对）。
修法一行：`... END) AS contacts`。

### 9.5 前端随接口就绪做的调整

- **编辑表单改成只提交改动字段**。原来整表回填，接口一上线就会把库里的 `NULL` 冲成空串，
  还在 `crm_customer_changes` 里记一堆「NULL → 空串」的假变更。实测只改备注时，库里只有 `note` 变动、留痕只有 1 条。
- 成功提示改用后端返回的 `changed.length`，不再用前端自己数的字段数。
