# 数据模块接口契约（后端实现清单）

> 前端已完成：`/analytics/*` 七个页面 + `src/api/analytics.js` 契约。
> 页面当前读 `src/data/analytics.js` 的本地数据，后端就绪后换成这些方法即可，
> 参数与返回结构不用改。本文是后端需要照着做的东西。

---

## 一、先统一口径（不统一，页面数字会互相打架）

| 指标 | 口径 | 备注 |
|---|---|---|
| 业绩 / 发货额 | 订单 **实际发货金额**（含税），已签收或运输中计入 | 已取消订单不计，退货冲减；**不再用签约额**，年框金额会虚高 |
| 回款额 | 财务核销到账金额 | 只做质量指标，**不参与完成度** |
| 完成度 | 发货额 ÷ 目标 | 目标取 `crm_targets`，年度 = 季度目标 × 4 |
| 应收余额 | 累计应收 − 已回款 | 与账龄五项合计必须相等 |
| 线索阶段 | 六态：`pending → contacted → quoted → negotiating → won / invalid` | 见第四节 |
| 转化率 | 成交数 ÷ 线索接入数 | 无效单独统计，不参与阶段转化 |
| 复购率 | 近 12 个月下单 ≥ 2 次的客户 ÷ 有成交客户 | 按合同去重，一个合同算一单 |
| 平均复购周期 | 同一客户相邻两单的间隔天数均值 | 无第二单的客户不参与 |
| 账龄 | 以回款计划 `due_date` 分桶：未到期 / 1–30 / 31–60 / 61–90 / 90+ | 按应收余额而非合同额 |
| 获客成本 CAC | 渠道市场投入 ÷ 该渠道成交单数 | 投入见 `crm_channel_costs` |
| 渠道 ROI | 该渠道发货额 ÷ 市场投入 | 前端展示为 `60.1x` |

金额统一 **元（decimal(12,2)）**，比率统一 **百分数保留 1 位**（`74.0` 而不是 `0.74`）。
时间按自然月归集，**发货日**落在哪个月算哪个月。

> ⚠️ 口径变更提醒：早期版本用「合同签约额」作为业绩口径，现已改为「发货额」。
> 后端实现时请以 `crm_orders` + `crm_shipments` 为事实表，不要再用 `crm_contracts.amount` 聚合，
> 否则年框一签就是几百万、实际只发了一部分，业绩会被显著高估。

---

## 二、权限

新增 9 个权限点，脚本见 `database/crm-analytics.sql`：

```
data.overview   data.funnel   data.customers   data.performance
data.payments   data.products data.sources
data.scope.dept   data.scope.all
```

数据范围（`scope`）由后端判定，**前端不做过滤**：

| 角色持有点 | scope | 过滤条件 |
|---|---|---|
| 无 `data.scope.*` | `self` | `owner_id = 当前用户` |
| `data.scope.dept` | `dept` | 本部门及所有下级部门 |
| `data.scope.all` | `all` | 全公司（隐含 dept） |

**越权必须返回 403**：`self` 的账号传了别人的 `ownerId`、或传了其他 `deptId`，
不要静默返回空数组 —— 前端要靠 403 提示"数据范围不足"。

**字段级裁剪**：无 `product.cost` 权限时，`/analytics/products` 的
`gross` / `margin` / `cost` **整个字段不要返回**（不是返回 null）。
前端按字段是否存在决定是否渲染毛利列。

---

## 三、接口一览

统一筛选参数（除 export 外都带）：

```
period   month | quarter | year | last12   默认 year
deptId   部门 ID，可空
ownerId  负责人 ID，可空
```

| 方法 | 路径 | 页面 |
|---|---|---|
| GET | `/api/analytics/summary` | 销售概况 |
| GET | `/api/analytics/funnel` | 销售漏斗 |
| GET | `/api/analytics/customers` | 客户分析 |
| GET | `/api/analytics/performance?dimension=dept\|staff` | 业绩分析 |
| GET | `/api/analytics/payments` | 回款分析 |
| GET | `/api/analytics/products` | 产品分析 |
| GET | `/api/analytics/sources` | 来源 ROI |
| GET | `/api/analytics/export?type=summary\|funnel\|...` | 导出 xlsx |

### 3.1 summary

```json
{
  "kpis": {
    "ytdSigned": 41313000, "signedDelta": 2.1,
    "annualTarget": 45600000, "completion": 90.6, "timeProgress": 91.7,
    "ytdReceived": 38938000, "receivedDelta": 1.5,
    "ytdCustomers": 147, "customersDelta": 1.4,
    "ytdLeads": 1240, "ytdDeals": 156,
    "avgDeal": 264827, "winRate": 12.6,
    "monthSigned": 4766000, "monthSignedDelta": -5.0, "monthDeals": 18
  },
  "monthly": [
    { "month": "2026-10", "label": "10月", "signed": 4520000, "received": 3980000, "deals": 17, "leads": 129, "customers": 6 }
  ],
  "alerts": [
    { "key": "overdue", "level": "danger", "title": "回款已逾期", "count": 6, "amount": 2360000, "desc": "...", "path": "/analytics/payments", "perm": "data.payments" }
  ]
}
```

`monthly` 固定返回 12 条（近 12 个自然月，最后一条是当前月），折线图直接吃。

### 3.2 funnel

```json
{
  "stages": [
    { "key": "new", "label": "线索接入", "count": 1240, "fromPrev": 100, "avgDays": 0, "desc": "..." },
    { "key": "contacted", "label": "已联系", "count": 872, "fromPrev": 70.3, "avgDays": 1.8 }
  ],
  "invalid": 168,
  "overallRate": 12.6, "overallRateDelta": 1.4,
  "lossReasons": [{ "label": "价格高于心理预期", "count": 214, "ratio": 34.1 }],
  "bySource": [{ "source": "汽配展", "count": 386, "contacted": 302, "quoted": 186, "negotiating": 108, "won": 62, "rate": 16.1 }],
  "trend": [{ "label": "6月", "value": 10.4 }]
}
```

- `count` 用「**曾到达**该阶段」的线索数（不超过该阶段就流失的不算），
  否则漏斗会出现下一段比上一段多。
- `fromPrev` = 本段 count ÷ 上一段 count。
- `avgDays` = 该阶段的 `stage_entered_at` 到下一阶段进入时间的中位数；
  需要第四节加的字段，没有就先返回 0。
- `lossReasons` 来自线索标记的无效原因字典（见第六节待补字段）。

### 3.3 customers

```json
{
  "total": 386, "active": 214, "following": 168, "sleeping": 96, "churnRisk": 42, "churned": 34,
  "repeatRate": 62.4, "repeatRateDelta": 3.8, "avgCycle": 38, "avgCycleDelta": -2.4,
  "cycleBuckets": [{ "label": "20 天以内", "count": 84, "ratio": 21.8 }],
  "sleepingList": [{ "id": "CU-1017", "name": "...", "owner": "梁书", "level": "C 类", "lastOrder": "2026-08-26", "days": 80, "amount": 54000, "cycle": 45 }],
  "follow": {
    "total": 2860, "perPerson": 286, "overdue": 38, "overdueRate": 13.3, "avgPerDay": 9.5,
    "resultDist": [{ "label": "推进", "count": 1659, "ratio": 58, "tone": "success" }],
    "typeDist": [{ "label": "微信", "count": 1042, "ratio": 36.4 }]
  },
  "statusFlow": [{ "label": "跟进中", "from": 186, "to": 168, "moved": -18 }]
}
```

- `sleeping`：超过 60 天没有新合同的客户；`days` 用最大合同日期算。
- `follow.overdue`：「承诺下次跟进日已过、且没有新跟进记录」的客户数。
- `statusFlow`：取区间首尾两天的客户状态快照，或按状态变更日志统计。

### 3.4 performance

```json
{
  "depts": [{ "dept": "区域销售部", "headcount": 4, "target": 16800000, "signed": 15320000, "deals": 105, "completion": 91.2, "avgDeal": 145904, "perHead": 3830000 }],
  "staff": [{ "name": "许知远", "dept": "区域销售部", "deptTop": "区域销售部", "role": "销售主管", "target": 8400000, "signed": 8680000, "deals": 43, "completion": 103.3, "avgDeal": 201860, "gap": -280000 }],
  "top10": [{ "name": "许知远", "dept": "区域销售部", "signed": 8680000, "completion": 103.3 }],
  "buckets": [{ "label": "超 100%", "count": 1, "tone": "success" }],
  "quarters": [{ "label": "Q1", "target": 11400000, "signed": 9915000, "completion": 87.0 }]
}
```

- `dept` 是二级部门（华东组 / 华南组），`deptTop` 归到一级部门；部门汇总按 `deptTop`。
- `gap` = target − signed，正数表示还差，前端加负号显示。
- Q4 未结束也按整季目标算（前端页脚已注明）。

### 3.5 payments

```json
{
  "receivable": 6400000, "received": 18204000, "overdue": 2360000,
  "rate": 74, "rateDelta": 2.6, "avgDays": 41,
  "aging": [{ "label": "未到期", "amount": 4040000, "ratio": 63.1, "tone": "success" }],
  "overdueList": [{ "contract": "HT-2026-0186", "customer": "...", "owner": "苏晚", "amount": 338800, "dueDate": "2026-11-08", "days": 6, "method": "月结 60 天" }],
  "byOwner": [{ "owner": "许知远", "dept": "区域销售部", "receivable": 5860000, "received": 3210000, "rate": 54.8 }]
}
```

**硬校验**：`aging` 五项 amount 合计 === `receivable`，`aging` 中逾期四项合计 === `overdue`。
前端把三个数字放一屏，对不上就是 bug。

### 3.6 products

```json
{
  "categories": [{ "name": "洗车毛巾", "sales": 12860000, "qty": 186000, "gross": 4120000, "margin": 32, "ratio": 33.6, "delta": 8.4 }],
  "topSku": [{ "code": "BC-TW4060-380", "name": "...", "category": "洗车毛巾", "qty": 62000, "amount": 3180000, "margin": 30.2, "owner": "汽配展" }],
  "slowMoving": [{ "code": "BC-LP4060", "name": "...", "category": "洗车毛巾", "stock": 1860, "amount": 232500, "days": 96, "cost": 880 }],
  "trend": [{ "label": "12月", "洗车毛巾": 71.4, "清洁工具": 54.6, "清洁剂": 32.6, "抛光耗材": 25.2 }]
}
```

- 销量按**最小销售单位**汇总，不是箱数。
- `slowMoving`：60 天内零出库，`amount` = 库存 × 成本价。
- `trend` 的键是品类名（中文），值是万元；前端按 `Object.keys` 画线。

### 3.7 sources

```json
{
  "rows": [{ "source": "汽配展", "leads": 386, "won": 62, "amount": 17200000, "cost": 286000, "cycle": 46, "note": "...", "rate": 16.1, "cac": 4613, "roi": 60.1, "avgDeal": 277419 }],
  "trend": [{ "label": "12月", "汽配展": 30, "1688 询盘": 26 }]
}
```

---

## 四、线索状态改造（漏斗的前置条件）

当前 `crm_leads.status` 是 4 态 ENUM，画不出五段漏斗。需要：

```sql
-- 见 database/crm-analytics.sql B 段，三步走避免老值被清空
ALTER TABLE crm_leads MODIFY COLUMN status
  ENUM('pending','contacted','quoted','negotiating','won','converted','invalid') NOT NULL DEFAULT 'pending';
UPDATE crm_leads SET status = 'won' WHERE status = 'converted';
ALTER TABLE crm_leads MODIFY COLUMN status
  ENUM('pending','contacted','quoted','negotiating','won','invalid') NOT NULL DEFAULT 'pending';
```

同时加一个字段，否则「平均停留天数」只能硬编码：

```sql
ALTER TABLE crm_leads ADD COLUMN stage_entered_at DATETIME NULL COMMENT '进入当前阶段的时刻';
```

状态变更时写 `stage_entered_at = NOW()`。前端已经把 6 态跑通，
`LeadList.vue` 的 `statusLabels` 与这里一一对应，**改枚举要两边一起改**。

**兼容**：前端仍会把老的 `converted` 展示成「成交」，所以迁移可以分批做，
不会出现空白状态。

---

## 五、新增表

```sql
CREATE TABLE crm_channel_costs (
  id           BIGINT NOT NULL AUTO_INCREMENT,
  channel      VARCHAR(32) NOT NULL,
  period_month CHAR(7) NOT NULL COMMENT 'YYYY-MM',
  amount       DECIMAL(12,2) NOT NULL DEFAULT 0,
  remark       VARCHAR(255),
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_channel_month (channel, period_month)
);
```

渠道 ROI 没有这张表就只能把成本写死在代码里。渠道名要与线索的 `source` 对齐
（汽配展 / 1688 询盘 / 官网询盘 / 汽配城拜访 / 客户转介绍 / 电话外呼），
建议给 `crm_leads.source` 建字典表，避免"汽配展"和"汽配展会"算成两个渠道。

其余数据都从现有表算，不新建宽表：
`crm_leads` / `crm_customers` / `crm_followups` / `crm_contracts` / `crm_payments` / `crm_products` / `crm_targets` / `crm_employees` / `crm_departments`。

---

## 六、待补的两个字典（可选，但建议一起做）

1. `crm_lead_loss_reasons` —— 无效原因（价格 / 已有供应商 / 起订量 / 账期 / 需求延后 / 联系不上）。
   现在是前端写死的六条，后端有字典才能做真实归因。
2. `crm_lead_sources` —— 渠道字典（含渠道类型、是否计费），同时被线索和渠道成本表引用。

---

## 七、实现建议

- **别用实时聚合**：七个页面每次刷新都全表 scan 会拖垮线索表。
  建议每日凌晨跑一次物化（`crm_stat_daily`：日期 × 部门 × 员工 × 渠道 × 品类），
  接口只查汇总表。当月数据可以实时算，历史月份走物化表。
- **`period` 与 `last12` 的边界**：`last12` 固定返回 12 条，不受自然年影响；
  `year` 是 1 月 1 日到今天；`quarter` 是本季首日到今天；`month` 是本月 1 日到今天。
- **除零**：目标为 0、线索为 0 时 `completion` / `rate` 返回 `null`，前端显示「—」，
  不要返回 `Infinity` 或 `NaN`（JSON 序列化会直接崩）。
- **导出**：复用页面同一套计算，导出 xlsx 时**不要**按权限二次裁剪，
  已经查出来的数据就是用户能看的。
- **缓存**：同一组 `(period, deptId, ownerId, scope)` 的结果缓存 5 分钟即可，
  页面切筛选频繁，每次重算不划算。

---

## 八、前端已就绪的部分

| 文件 | 说明 |
|---|---|
| `src/api/analytics.js` | 8 个方法，参数与本文一致，后端通了直接换 |
| `src/data/analytics.js` | 演示数据，确定性生成，可作为返回结构的参照 |
| `src/views/analytics/*.vue` | 七个页面 |
| `src/components/analytics/*` | 图表与卡片，全部手写 SVG，无第三方依赖 |
| `database/crm-analytics.sql` | 权限点、线索枚举、渠道成本表 |

页面上的「导出」按钮目前只弹提示，接 `/api/analytics/export` 时把 `exportReport` 换成
`analyticsApi.exportFile(type, filters)` 再触发下载即可。
