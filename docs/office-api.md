# 行政财务接口契约（后端实现清单）

> 前端已交付：`/finance/expenses`（费用报销）、`/finance/loans`（借款预支）、
> `/finance/leaves`（请假申请）、`/finance/approvals`（审批中心），共 4 个页面 + `src/api/office.js` 契约。
>
> 页面当前读 `src/data/office.js` 的本地演示数据，**没有写数据库**。
> 后端就绪后把 `officeApi.*` 的返回换成真实数据即可，方法名与参数不用改。
>
> 原「财务」菜单已改名「行政财务」——报销和借款是财务，请假是行政，两类合流。

---

## 一、为什么这四件事放一个板块

它们的骨架完全一样：**员工发起 → 主管审批 → 财务留痕**。

拆成三个互不相干的页面会有两个后果：审批人每天在三个列表里找待办；员工说不清「我上周那笔钱走到哪了」。
所以四个页面共用一套审批链路，审批中心是统一入口，工作台的「待处理审批」也指到这里。

```
费用报销 ──┐
借款预支 ──┼──> 审批中心（待我审批 / 我发起的 / 已办结）──> 回写源单据状态
请假申请 ──┘

报销单 ──(审批通过)──> 借款抵扣生效 ──> 借款余额减少 / 清零
```

---

## 二、四条业务铁律

**1. 报销金额由明细汇总，不接受手填总额。**
一张报销单可能是「高铁 1240 + 住宿 3000 + 市内交通 1000」，只存总额财务审不了，员工也说不清钱花在哪。`crm_expenses.total_amount` 允许存在，但必须事务内由明细算出，且每日校验。

**2. 借款抵扣「审批通过才生效」，不是提交即生效。**
提交就冲会让被驳回的单子白占额度，员工要重新申请。所以报销单上只记 `deduct_loan_id + deduct_amount`（意向），真正的 `crm_loan_writeoffs` 记录在审批通过那一刻生成。

**3. 借款余额不存字段。**
`未还 = 借款金额 − Σ 已生效抵扣`，现算。存了之后只要有一处漏更新，财务就会拿着两套数字来问你。
另外：**只有审批通过（钱已打出去）的借款才有余额**，待审批和已驳回的一分钱没出，算进「在借」会让财务白紧张。

**4. 请假天数后端重算，不信前端传的值。**
前端算天数只是即时反馈，后端必须按同一规则重算：跳过周六周日（法定节假日和调休上班不在本期范围）。同时校验额度、校验同一人时间不重叠。

---

## 三、表结构

7 张表。沿用 `crm_` 前缀，`utf8mb4` / InnoDB。

### 3.1 `crm_expenses` 报销单

```sql
CREATE TABLE crm_expenses (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code           VARCHAR(32) NOT NULL COMMENT 'FY-2026-0612',
  applicant_id   BIGINT UNSIGNED NOT NULL,
  dept_id        BIGINT UNSIGNED NOT NULL COMMENT '承担部门，进部门成本',
  project_name   VARCHAR(120) NOT NULL DEFAULT '' COMMENT '关联客户/项目，自由文本',
  apply_date     DATE NOT NULL,
  total_amount   DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '明细汇总缓存，事务内同步',
  bill_count     INT NOT NULL DEFAULT 0 COMMENT '票据张数，缺票要退单',
  trip_from      VARCHAR(60) NOT NULL DEFAULT '',
  trip_to        VARCHAR(60) NOT NULL DEFAULT '',
  trip_start     DATE NULL,
  trip_end       DATE NULL,
  trip_days      INT NOT NULL DEFAULT 0 COMMENT '自然日，不跳周末',
  deduct_loan_id BIGINT UNSIGNED NULL COMMENT '意向抵扣的借款，审批通过才落 writeoff',
  deduct_amount  DECIMAL(12,2) NOT NULL DEFAULT 0,
  remark         VARCHAR(500) NOT NULL DEFAULT '',
  status         ENUM('审批中','已通过','已驳回','已撤回') NOT NULL DEFAULT '审批中',
  approver_id    BIGINT UNSIGNED NULL,
  approved_at    DATETIME NULL,
  reject_reason  VARCHAR(200) NOT NULL DEFAULT '',
  request_id     VARCHAR(64) NULL COMMENT '幂等键',
  created_by     BIGINT UNSIGNED NOT NULL,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  UNIQUE KEY uk_request (request_id),
  KEY idx_applicant (applicant_id, apply_date),
  KEY idx_status (status, apply_date),
  KEY idx_dept (dept_id, apply_date)
) COMMENT='费用报销单';
```

### 3.2 `crm_expense_items` 报销明细

```sql
CREATE TABLE crm_expense_items (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  expense_id   BIGINT UNSIGNED NOT NULL,
  occur_date   DATE NOT NULL COMMENT '发生日期，不是申请日期',
  type         ENUM('差旅','客户招待','市场活动','物流运费','样品费','办公用品','其他') NOT NULL,
  amount       DECIMAL(12,2) NOT NULL,
  note         VARCHAR(300) NOT NULL COMMENT '必填，审批人要据此判断该不该批',
  bills        INT NOT NULL DEFAULT 0 COMMENT '票据张数',
  sort_no      INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_expense (expense_id)
) COMMENT='报销明细，金额唯一事实来源';
```

### 3.3 `crm_expense_attachments` 票据附件

```sql
CREATE TABLE crm_expense_attachments (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  expense_id  BIGINT UNSIGNED NOT NULL,
  file_id     VARCHAR(64) NOT NULL COMMENT '对象存储 fileId，不要存路径',
  file_name   VARCHAR(160) NOT NULL,
  file_size   INT UNSIGNED NOT NULL DEFAULT 0,
  mime_type   VARCHAR(60) NOT NULL DEFAULT '',
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_expense (expense_id)
) COMMENT='报销票据，一张单可多张';
```

### 3.4 `crm_loans` 借款单

```sql
CREATE TABLE crm_loans (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code         VARCHAR(32) NOT NULL COMMENT 'JK-2026-0034',
  applicant_id BIGINT UNSIGNED NOT NULL,
  dept_id      BIGINT UNSIGNED NOT NULL,
  type         ENUM('差旅预支','备用金','采购垫付') NOT NULL DEFAULT '差旅预支',
  amount       DECIMAL(12,2) NOT NULL,
  purpose      VARCHAR(300) NOT NULL COMMENT '必填，财务据此判断该不该借',
  apply_date   DATE NOT NULL,
  pay_date     DATE NULL COMMENT '实际打款日，未打款为 NULL',
  due_date     DATE NULL COMMENT '应清账日',
  status       ENUM('待审批','已通过','已驳回') NOT NULL DEFAULT '待审批',
  approver_id  BIGINT UNSIGNED NULL,
  approved_at  DATETIME NULL,
  reject_reason VARCHAR(200) NOT NULL DEFAULT '',
  request_id   VARCHAR(64) NULL,
  created_by   BIGINT UNSIGNED NOT NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  UNIQUE KEY uk_request (request_id),
  KEY idx_applicant (applicant_id, status),
  KEY idx_due (status, due_date)
) COMMENT='借款/预支单。金额是本金，余额靠 writeoffs 现算，不存字段';
```

### 3.5 `crm_loan_writeoffs` 借款核销记录

```sql
CREATE TABLE crm_loan_writeoffs (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  loan_id    BIGINT UNSIGNED NOT NULL,
  source     ENUM('expense','cash') NOT NULL COMMENT 'expense=报销抵扣，cash=现金退回',
  expense_id BIGINT UNSIGNED NULL COMMENT 'source=expense 时必填，且唯一',
  amount     DECIMAL(12,2) NOT NULL,
  note       VARCHAR(200) NOT NULL DEFAULT '',
  created_by BIGINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  /* 同一张报销单对同一笔借款只能核销一次，防重复提交把余额冲成负数 */
  UNIQUE KEY uk_expense_loan (expense_id, loan_id),
  KEY idx_loan (loan_id)
) COMMENT='借款核销明细 —— 没有这张表，借款余额永远算不清';
```

### 3.6 `crm_leaves` 请假单

```sql
CREATE TABLE crm_leaves (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code         VARCHAR(32) NOT NULL COMMENT 'QJ-2026-0092',
  applicant_id BIGINT UNSIGNED NOT NULL,
  dept_id      BIGINT UNSIGNED NOT NULL,
  type         ENUM('年假','病假','事假','调休') NOT NULL,
  start_date   DATE NOT NULL,
  end_date     DATE NOT NULL,
  days         DECIMAL(5,1) NOT NULL COMMENT '后端按工作日重算，半天用 .5',
  reason       VARCHAR(300) NOT NULL,
  handover_id  BIGINT UNSIGNED NULL COMMENT '工作交接人',
  apply_date   DATE NOT NULL,
  status       ENUM('待审批','已通过','已驳回','已撤销') NOT NULL DEFAULT '待审批',
  approver_id  BIGINT UNSIGNED NULL,
  approved_at  DATETIME NULL,
  reject_reason VARCHAR(200) NOT NULL DEFAULT '',
  request_id   VARCHAR(64) NULL,
  created_by   BIGINT UNSIGNED NOT NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  UNIQUE KEY uk_request (request_id),
  KEY idx_applicant (applicant_id, start_date),
  /* 同一个人同一时间段只能有一条有效请假，重叠提交直接拒 */
  KEY idx_range (applicant_id, start_date, end_date, status)
) COMMENT='请假单';
```

### 3.7 `crm_leave_quotas` 请假额度

```sql
CREATE TABLE crm_leave_quotas (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  employee_id  BIGINT UNSIGNED NOT NULL,
  year         SMALLINT UNSIGNED NOT NULL,
  type         ENUM('年假','病假','调休') NOT NULL COMMENT '事假不设额度，不落这张表',
  quota_days   DECIMAL(5,1) NOT NULL DEFAULT 0,
  used_days    DECIMAL(5,1) NOT NULL DEFAULT 0 COMMENT '已通过的天数缓存，每日校一次',
  PRIMARY KEY (id),
  UNIQUE KEY uk_emp_year_type (employee_id, year, type)
) COMMENT='年度额度。额度按入职年限给，所以必须落到人，不能全局配置';
```

### 3.8 `crm_approval_logs` 审批流水（通用）

```sql
CREATE TABLE crm_approval_logs (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  kind        ENUM('费用报销','借款预支','请假申请','合同','订单') NOT NULL,
  doc_id      BIGINT UNSIGNED NOT NULL,
  action      ENUM('提交','同意','驳回','撤回','转交') NOT NULL,
  operator_id BIGINT UNSIGNED NOT NULL,
  note        VARCHAR(300) NOT NULL DEFAULT '',
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_doc (kind, doc_id, created_at)
) COMMENT='审批流水。只追加不修改，用来回答「谁在什么时候批的」';
```

---

## 四、权限

新增 7 个权限码（`expense.*` 三个已有）：

| 权限码 | 中文 | 谁该有 |
|---|---|---|
| `expense.view` | 查看费用报销 | 全员 |
| `expense.create` | 提交报销单 | 全员 |
| `expense.approve` | 审批费用 | 销售主管、运营、财务 |
| `loan.view` | 查看借款预支 | 全员 |
| `loan.create` | 申请借款 | 全员 |
| `loan.approve` | 审批借款 | 销售主管、运营、财务 |
| `leave.view` | 查看请假 | 全员 |
| `leave.create` | 发起请假 | 全员 |
| `leave.approve` | 审批请假 | 主管、运营 |
| `approval.view` | 查看审批中心 | 全员（只看自己的也保留入口） |

脚本已备好但**未执行**：`database/crm-office-perms.sql`（幂等，可重复跑）。

角色建议：

| 角色 | 报销 | 借款 | 请假 | 审批中心 |
|---|---|---|---|---|
| 销售总监 | 全部 | 全部 | 全部 | ✓ |
| 销售主管 | 全部 | 全部 | 全部 | ✓ |
| 客户经理 | view/create | view/create | view/create | ✓ |
| 财务专员 | view/create/approve | view/approve | view | ✓ |
| 销售运营 | view/approve | view/approve | 全部 | ✓ |

**数据范围**：`approval.view` 只给入口，看到哪些单由后端判定 —— 普通员工只看自己发起的；
有 `expense.approve` / `loan.approve` / `leave.approve` 的看本部门及下级；`data.scope.all` 看全公司。

---

## 五、接口清单

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/expenses` | 列表，行内带 `totalAmount` / `billCount` |
| GET | `/expenses/{id}` | `{ expense, items, trip, attachments, deduct, logs }` |
| POST | `/expenses` | 新建，body 见 `src/api/office.js` 注释 |
| POST | `/expenses/{id}/approve` | `{ result, note }`，通过时生成借款核销 |
| POST | `/expenses/{id}/withdraw` | 撤回（仅审批中） |
| GET | `/loans` | 列表，行内带 `clearedAmount` / `openAmount` / `derivedStatus` |
| GET | `/loans/{id}` | `{ loan, writeOffs }` |
| POST | `/loans` | 申请借款 |
| POST | `/loans/{id}/approve` | `{ result, note }`，通过时回填 `pay_date` |
| GET | `/loans/open` | 报销抵扣下拉用，只返回该员工未清的 |
| POST | `/loans/{id}/write-off` | 手工核销（现金退回），报销抵扣不走这个 |
| GET | `/leaves` | 列表 |
| GET | `/leaves/{id}` | 详情 |
| GET | `/leaves/quota` | `{ 年假: {quota, used, left}, ... }` |
| POST | `/leaves` | 发起请假 |
| POST | `/leaves/{id}/approve` | `{ result, note }` |
| POST | `/leaves/{id}/revoke` | 撤销（已通过未开始） |
| GET | `/approvals` | `?box=pending\|mine\|done`，三类单据 UNION |
| POST | `/approvals/decide` | `{ kind, docId, result, note }` 统一审批入口 |
| GET | `/approvals/{kind}/{docId}/history` | 审批流水 |
| GET | `/expenses/export` `/loans/export` | xlsx 流 |

---

## 六、后端必须拦的 12 条规则

前端已经在提示，但**只有后端拦才算数**。

| # | 规则 | 返回 |
|---|---|---|
| 1 | `requestId` 重复直接返回上次结果，不新建 | 200 原结果 |
| 2 | 报销明细至少一条，每条 `amount > 0` 且 `note` 非空 | 400 `费用明细不完整` |
| 3 | `total_amount` 必须等于明细之和 | 事务内计算，不接受传值 |
| 4 | 明细含「差旅」时，行程四项（出发地/到达地/起止日）必填 | 400 `差旅报销要填行程` |
| 5 | `trip_days` 由起止日算，结束早于开始直接拒 | 400 |
| 6 | 抵扣金额 ≤ 报销合计，且 ≤ 该借款未还余额，且借款属于该员工 | 422 `超过借款未还余额` |
| 7 | **借款核销只在报销审批通过时生成**，且 `(expense_id, loan_id)` 唯一 | 409 `报销单已核销过该借款` |
| 8 | 借款 `approve` 通过时回填 `pay_date`；未通过的借款 `open_amount` 恒为 0 | 内部计算 |
| 9 | 请假天数后端按工作日重算，忽略前端传值 | 内部计算 |
| 10 | 请假天数 ≤ 该员工该类型当年额度余额（事假不限） | 422 `年假余额不足` |
| 11 | 同一员工请假时间段不得与已有「待审批/已通过」记录重叠 | 409 `与已有请假时间重叠` |
| 12 | **不能审批自己提交的单据**（哪怕同时持有 approve 权限） | 403 `不能审批自己的单据` |

第 12 条容易被漏掉，但真出过事：主管给自己批报销。校验放在统一的 `decide` 入口，三类单据都覆盖。

每日一致性校验（定时任务跑，异常告警不要自动修）：

```sql
-- 报销总额必须等于明细之和
SELECT e.id, e.total_amount, SUM(i.amount) calc
FROM crm_expenses e JOIN crm_expense_items i ON i.expense_id = e.id
WHERE e.status <> '已撤回'
GROUP BY e.id, e.total_amount
HAVING ABS(e.total_amount - calc) > 0.01;

-- 借款核销不得超本金
SELECT loan_id, SUM(amount) FROM crm_loan_writeoffs
GROUP BY loan_id
HAVING SUM(amount) > (SELECT amount FROM crm_loans l WHERE l.id = loan_id);
```

---

## 七、定时任务

| 任务 | 频率 | 说明 |
|---|---|---|
| 请假额度年度重置 | 每年 1 月 1 日 | 按入职年限生成 `crm_leave_quotas`，老员工额度不同 |
| 借款超期提醒 | 每日 09:00 | 过 `due_date` 仍未清的，通知申请人与财务 |
| 报销压单提醒 | 每日 09:00 | 提交超 3 天未处理的，提醒审批人（审批中心 KPI 就是按这个算的） |
| 一致性校验 | 每日 02:00 | 见第六节两条 SQL |
| 附件清理 | 每周日 | 报销单被撤回/驳回超 30 天且未重提的附件，转冷存储 |

---

## 八、上线顺序

1. **建表 + 权限脚本**：跑 DDL 与 `crm-office-perms.sql`。
2. **请假**：最简单，不依赖别的单据，可以先把 `/finance/leaves` 切真实数据。
3. **借款**：`crm_loans` + `writeoffs` 表先建，但核销逻辑先空着（还没报销）。
4. **报销**：明细 + 附件上传，先不接借款抵扣。此时 `/finance/expenses` 可切。
5. **报销 ⇄ 借款核销**：审批通过生成 `writeoff`，借款余额开始对得上。
6. **审批中心**：三类单据都稳定之后再做，它是个只读聚合 + 统一 decide 入口。
7. **切前端**：`src/data/office.js` 的引用逐页换成 `officeApi.*`，一页一页切。

数据迁移：老系统的费用记录如果是「一条一行、没有明细」的，迁移时每条生成一条 `crm_expense_items`
（type 取原类型、note 取原说明、bills 置 0 并打标记），**不要丢弃历史记录**，财务年底要对账。

---

## 九、工作量估算（1 名后端，含自测）

| 阶段 | 内容 | 人日 |
|---|---|---|
| 1 | 7 张表 DDL + 权限脚本 | 1 |
| 2 | 请假（额度、重叠校验、审批） | 2.5 |
| 3 | 借款（申请、审批、核销、余额计算） | 3 |
| 4 | 报销（明细、行程、附件上传、审批） | 4 |
| 5 | 报销 ⇄ 借款核销联动 | 1.5 |
| 6 | 审批中心（UNION 查询 + 统一 decide + 流水） | 2.5 |
| 7 | 导出 + 5 个定时任务 | 2 |
| 8 | 前端逐页切换 + 联调 | 2.5 |
| | **合计** | **19 人日** |

如果只做报销 + 请假（不做借款、不做审批中心），约 8 人日。但**借款这 3 人日别省** ——
差旅场景八成是先借钱后报销，没有预支，财务还是要拿 Excel 记「谁欠公司多少」。

---

## 十、演示数据的可验算关系（后端可当单测期望值）

`src/data/office.js` 里的数字都是真算的：

- 报销：`total_amount = Σ items.amount`，`bill_count = Σ items.bills`
- 借款：`open = amount − Σ writeoffs.amount`；只有 `status=已通过` 的借款才有 `open > 0`
- 抵扣一致：`FY-2026-0611 → JK-2026-0033 ¥3,000`、`FY-2026-0607 → JK-2026-0029 ¥2,500`
  两笔都能在借款详情的「抵扣记录」里查到
- 请假：`days` 已排除周末（`2026-11-18` 至 `2026-11-20` = 3 天；`2026-11-05` 至 `2026-11-07` = 2 天，含周六）
- 审批中心「待我审批」= 三类单据里 `status=待审批` 的合计，不另存

> 一个已知的演示限制：数据只在前端内存里，**刷新页面会回到初始状态**。
> 这是假数据的必然结果，真实后端接上后不会出现。

---

## 十一、联调发现的后端遗留项（2026-11-14）

### 1. 单号生成器还是占位实现，会生成 UUID 单号

`OfficeService.create()` 第 126 行：

```java
String code = kind.prefix + "-" + UUID.randomUUID().toString().substring(0, 23);
```

新建请假/借款/报销拿到的是 `QJ-fa8d8711-caa2-436b-b389`，跟种子数据的
`QJ-2026-0098` 完全不是一套，列表里一眼就能看出是假的。
同样的写法还在两处：

| 位置 | 生成的前缀 |
|---|---|
| `OrderWriteService:103` | `SO-`（订单） |
| `BillingService:215` | `FH-` / `DZ-` / `FP-` / `SK-`（发货、对账、发票、收款） |

**改法**：抽一个 `DocCode.next(prefix, table)`，按月流水：

```sql
SELECT COALESCE(MAX(CAST(SUBSTRING(code, 9) AS UNSIGNED)), 0) + 1
FROM crm_orders WHERE code LIKE 'SO-2026-%'
```

返回 `SO-2026-1023`。`code` 上有唯一索引，并发撞号时捕获 `DuplicateKeyException` 重试一次即可。
改完之后把已有 UUID 单号的历史数据一并刷掉，否则新老两种格式会长期共存。

### 2. `/leaves/quota` 的口径和后端校验不一致（前端已自行补算）

- `/leaves/quota` 返回 `left = quota - used`
- `OfficeService.remaining()`（创建请假时校验用）算的是 `quota - used - 该年度待审批`

于是「额度 5 天、已用 0、待审批 3 天」的用户，弹窗说还剩 5 天，提交却被 422 打回。
前端现在自己在 `balanceOf()` 里减掉了待审批，能对上，但**接口口径应该在后端统一**：
给 `left` 补上待审批，或额外返回 `pending` 字段让前端自己算。两者选一，别让两边各猜一套。

### 3. POST /leaves 的 400 无法区分具体原因

`bad()` 是同一个异常，覆盖「日期缺失/倒挂/跨年、事由为空、类型不合法、天数为 0」五种情况。
前端以前把它统一翻译成「请假天数为 0」，用户明明填了 4 天，被这句话彻底带偏。

建议返回结构化错误：

```json
{ "code": "LEAVE_REASON_REQUIRED", "field": "reason", "message": "请填写请假事由" }
```

前端已经做了提交前自查（日期是否倒挂、区间内有没有工作日、事由是否为空、额度是否够），
能走到 400 的场景会越来越少，但错误码分清楚对后面接入审批流也有用。

---

## 十二、审批权限的两条隐性规则（2026-11-14 补）

### 1. 后端禁止自审，前端必须同步隐藏按钮

`OfficeService.decide()` 第 212 行：

```java
if (applicant == employee || !inScope(employee, number(row,"dept_id"), grants))
    throw error(HttpStatus.FORBIDDEN);
```

两个条件任一成立都是 403：

| 情况 | 说明 |
|---|---|
| `applicant == employee` | 不能审批自己提的单，哪怕你是超管 |
| `!inScope(...)` | 只能审批「本部门及下级部门」的单（`data.scope.all` 除外） |

**问题**：请假 / 报销 / 借款三个列表页以前只要「有 `xxx.approve` 权限 + 状态待审批」就渲染
通过/驳回，连自己提的那张也渲染。销售经理点自己那张必然 403，而 `http.js` 把 403 统一翻成
「没有权限执行该操作」——用户看到这句话只会去查角色配置，那里一个字都没错。

**现在的做法**：`src/store/permissions.js` 新增 `canAudit(perm, row)`：

```js
export function canAudit(perm, row) {
  if (!can(perm)) return false
  return !isMine(row)   // row.applicantId === session.user.id
}
```

四个页面（请假、报销、借款、审批中心）全部改用它；自己的待审批单在状态列补一行
「本人申请 / 本人提交」，操作列只留「明细」。

**建议后端再往前走一步**：列表直接返回 `canApprove: boolean`，把「自审」和「范围」两个
判断留在服务端一处。前端现在是靠「列表已经按 canRead 过滤过」来推断范围安全的，
规则一旦变化（比如加代理审批、跨部门授权）前端就会漏判。

### 2. 审批中心的按钮权限要按单据类型取

`Approvals.vue` 以前三个类型的按钮统一写 `v-can="'expense.approve'"`。
销售经理只有 `leave.approve`，于是审批中心里请假单**没有同意/驳回按钮**；
绕过去点了，后端 `decide()` 也会按 `kind.permission + ".approve"` 再查一次，照样 403。

改成按行取：

```js
const APPROVE_PERM = { 费用报销: 'expense.approve', 借款预支: 'loan.approve', 请假申请: 'leave.approve' }
const canReview = (row) => canAudit(APPROVE_PERM[row.kind], row)
```

### 3. 角色权限的现状（数据层，不是代码问题）

`database/crm-office-perms.sql` 的设计是「主管以上可审批报销与借款」，但库里
`sales_manager` 实际只有 `leave.approve`、`order.approve`，没有
`expense.approve` / `loan.approve`（推测是有人在角色配置页重新保存过，整体替换掉了）。
本次只补回了 `loan.view`——因为「能申请借款却看不到借款列表」是硬伤（接口 403，页面空白）。
是否要恢复报销/借款审批权，属于业务口径，等确认。

### 4. 隐患：角色权限用 GROUP_CONCAT 拼，有 1024 字节上限

`RoleMapper.findAll()` 用 `GROUP_CONCAT(p.code ORDER BY p.code)` 把权限码拼成一个字符串，
MySQL 默认 `group_concat_max_len = 1024`。当前：

| 角色 | 权限数 | 拼出来的长度 |
|---|---|---|
| sales_manager | 50 | 696 |
| super_admin | 74 | **1003** |

超管只剩 21 字节余量。再加两个权限点，字符串就会被截断成半个权限码，
角色配置页拿到一个不存在的 code，保存时 `addPermission` 返回 0 → 400 Unknown permission，
超级管理员这个角色从此存不进去。改法三选一：单独查一次权限返回 `List<String>`；
`SUBSTRING_INDEX` 分段；或者启动时 `SET SESSION group_concat_max_len = 65535`。
