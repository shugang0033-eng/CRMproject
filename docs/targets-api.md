# 业绩目标 —— 数据模型、接口与后端待办

> 更新：2026-11-16（本轮把「个人目标」做完了）
> 对应前端：`src/store/targets.js`、`src/composables/useTargetProgress.js`、
> `src/views/settings/Targets.vue`、`src/views/Dashboard.vue`
> 对应后端：`com.crm.target.service.TargetService`、`com.crm.target.controller.TargetController`
> 建表脚本：`database/crm-targets-employee.sql`

## 一、两层目标，一张表

| 口径 | scope | scope_id | period 格式 | 谁用 |
|---|---|---|---|---|
| 部门季度目标 | `dept` | 部门 id | `2026-Q4` | 对老板的季度承诺，部门负责人看团队 |
| 个人月度目标 | `employee` | 员工 id | `2026-11` | 每月考核 / 算提成，销售看自己 |

**为什么周期不统一**：部门目标是季度承诺，个人目标是按月冲刺。两者靠一条规则对齐——
`季度个人目标 = 该季度三个月的个人目标之和`（`quarterEmployeeTarget()`），不单独存季度个人行，
这样月底给某个人调目标不会牵动整张季度表。

> ⚠️ **不要给同一个人同时设季度和月度个人目标**，否则季度数会算成两份。
> 前端只写月度，后端也接受季度（`2026-Q4` + `scope='employee'`），但那是给自己埋坑。

### 表结构（已于 2026-11-16 迁移）

```sql
CREATE TABLE crm_targets (
  period   char(7)        NOT NULL,              -- '2026-Q4' 或 '2026-11'
  scope    varchar(16)    NOT NULL DEFAULT 'dept',
  scope_id bigint unsigned NOT NULL,             -- 部门 id 或员工 id，按 scope 解释
  amount   decimal(14,2)  NOT NULL,
  note     varchar(500)   NOT NULL DEFAULT '',
  PRIMARY KEY (period, scope, scope_id),
  KEY idx_targets_scope (scope, scope_id, period)
);
```

迁移前的备份留在 `crm_targets_bak_20261116`（`department_id` 原样），确认无问题后可删。

## 二、接口（均已实现）

| 能力 | 接口 | 权限 | 说明 |
|---|---|---|---|
| 读目标 | `GET /api/targets?period=&scope=` | `target.view` | 两个参数都可空；**只返回当前账号范围内的行** |
| 读我的范围 | `GET /api/targets/scope` | `target.view` | `{all:true}` 或 `{all:false,deptIds:[...]}` |
| 读我的目标 | `GET /api/targets/mine?period=2026-11` | `target.view` | 没设返回 `{}`，不是 `{amount:0}` |
| 完成额 | `GET /api/targets/progress?period=&scope=` | `target.view` | 行与完成额都按同一范围过滤 |
| 批量保存 | `PUT /api/targets` | `target.manage` | 数组，事务内逐条 upsert，`amount:0` 即删除 |

`PUT` 请求体：

```json
[{ "period": "2026-11", "scope": "employee", "scopeId": 10,
   "metric": "signed", "amount": 280000, "note": "重点客户已锁定" }]
```

校验（`TargetService.save`）：

- `period` 必须匹配 `[0-9]{4}-(Q[1-4]|0[1-9]|1[0-2])`，否则 400「季度或月份格式无效」
- `scope` 只能是 `dept` / `employee`
- `dept` 要校验部门存在；`employee` 要校验员工存在且 `deleted_at IS NULL`
  （已离职的人再设目标，工作台永远算不出完成率）
- `amount >= 0`，`note <= 500`
- **每条都在账号范围内**，否则整批 403 回滚（不会「存进去一半」）：
  - 部门：`只能调整本部门及下级部门的目标`
  - 个人：`只能调整本部门员工的目标`

### 数据范围（2026-11-16 定稿）

「有按钮」和「能改谁」是两件事。范围由 `TargetService.scopeOf` 算：

```
all = 有 target.manage 且 有 data.scope.all        → 全公司
否则  = 本人所在部门子树 ∪ 本人担任负责人的部门子树
```

- 「部门负责人」取 `crm_department_managers`（部门管理页里指定的那个人），不按角色名猜
- 只看不写的人（销售顾问、市场专员）：范围仍是本部门子树，只读
- **市场推广专员虽然有 `data.scope.all`（营销要看全公司客户），但没有 `target.manage`，
  所以不会被当成「全公司目标管理员」**——这个组合判断是必须的，单看 `data.scope.all` 会漏

后端在 `list` / `progress` / `save` 三处统一用这套范围，前端只是把「改不了的部分」不显示：

| 账号 | 范围 |
|---|---|
| 宋江（超管） | 全公司 11 个部门 |
| 李四（销售主管，兼销售部负责人） | 销售部 + 销售一组 |
| 张三（销售主管，未指定负责人） | 销售一组 |
| 苏晚（销售顾问） | 销售部 + 销售一组（只读） |
| 沈昀（市场推广专员） | 市场部（只读） |
| 李磊（财务总监） | 财务一部 |

> 想让某人管整个部门：去「设置 › 部门管理」把该部门负责人指定为他，
> 不用改代码，也不用加角色。

## 三、完成额口径（服务端统一算，前端不再拉合同）

```
合同计入业绩的条件：
  1. sign_date 落在区间内（季度 10-01~12-31 / 月份 11-01~11-30）
  2. status 不在 { 待审批, 已作废, 已终止, 草稿 }
  3. 金额取 amount（签约额）

部门归集：owner_id → 员工表 → department_id，再沿 parent_id 逐级累加给祖先部门
个人归集：owner_id === 员工 id（精确匹配，不按姓名——重名/改名会归错人）
```

**个人目标的汇总口径**：分母只算「设了目标的人」，分子也只算这些人的合同额。
未设目标的人另算一行提示（「另 8 人未设目标，已签 ¥X」），
否则没目标的人业绩会白送进完成率，人越缺完成率越虚高。

## 四、后端待办

### P0-1 服务端出完成额 —— 已完成（2026-11-16）

前端已切到这个接口（`useTargetProgress.loadProgress`），不再 `GET /contracts?pageSize=500`
自己算。当初的两个坑也随之消失：合同超过 500 条不会静默少算；没有 `contract.view`
的角色（市场专员）靠服务端出数也能看到自己部门的完成额。

```
GET /api/targets/progress?period=2026-Q4            # 部门（默认）
GET /api/targets/progress?period=2026-11&scope=employee
→ {
    "period": "2026-11",
    "scope": "employee",
    "rows": [
      { "scopeId": 10, "name": "李四", "deptId": 6, "deptName": "销售一组",
        "target": 280000, "achieved": 271920, "pct": 97,
        "gap": 8080, "timePct": 52, "pace": "ahead" }
    ],
    "summary": { "target": 463000, "achieved": 271920, "pct": 59, "timePct": 52,
                 "configuredCount": 7, "unsetCount": 8 }
  }
```

- `rows[].achieved`：部门口径是「含下属部门」的滚动值；个人口径是本人合同额
- `pace` 由服务端给（`ahead` / `ontrack` / `behind` / `null`），免得前后端各算一套阈值
- `null` 表示「没设目标」，不要返回 0（前端靠这个区分「没设」和「完成 0」）

```sql
-- 个人完成额
SELECT c.owner_id AS scopeId, SUM(c.amount) AS achieved
FROM crm_contracts c
WHERE c.deleted_at IS NULL
  AND c.sign_date BETWEEN ? AND ?
  AND c.status NOT IN ('待审批','已作废','已终止','草稿')
GROUP BY c.owner_id;
```

部门滚动汇总在 Java 里按部门树累加（部门数量很少，别写递归 SQL）。
`owner_id` 为空的老合同要兜底按 `owner` 姓名匹配一次，否则早期数据算不进去。

### P0-2 `crm_targets` 补审计列

```sql
ALTER TABLE crm_targets
  ADD COLUMN updated_by BIGINT NULL AFTER note,
  ADD COLUMN updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER updated_by;
```

`PUT` 写入时落 `updated_by = employeeId`。业绩目标是考核依据，年底对账必须答得上「这个数谁什么时候改的」。

### P0-3 `crm_targets` 补 `metric`

现在硬校验 `metric == "signed"`。业务上常见两种：`signed` 签约额、`received` 回款额。

```sql
ALTER TABLE crm_targets
  ADD COLUMN metric VARCHAR(16) NOT NULL DEFAULT 'signed' AFTER scope_id,
  DROP PRIMARY KEY, ADD PRIMARY KEY (period, scope, scope_id, metric);
```

前端已经在 body 里带 `metric: 'signed'`，改成可选参数即可。

### P1-1 目标变更历史

```sql
CREATE TABLE crm_target_history (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  period CHAR(7) NOT NULL,
  scope VARCHAR(16) NOT NULL,
  scope_id BIGINT UNSIGNED NOT NULL,
  old_amount DECIMAL(14,2) NULL,
  new_amount DECIMAL(14,2) NOT NULL,
  changed_by BIGINT UNSIGNED NOT NULL,
  changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_target (period, scope, scope_id, changed_at)
);
```

### P1-2 个人目标的权限收紧 —— 已完成（2026-11-16）

原状：7 个角色全都有 `target.manage`，包括「销售顾问」「市场推广专员」——
一线可以改自己和同事的目标，与「由部门负责人统一设」的设定不符。

已执行（备份表 `crm_role_permissions_bak_20261116b`，回滚时把两行插回即可）：

```sql
DELETE rp FROM crm_role_permissions rp
JOIN crm_roles r ON r.id = rp.role_id
JOIN crm_permissions p ON p.id = rp.permission_id
WHERE p.code = 'target.manage' AND r.code IN ('demo_sales', 'demo_market');
```

改后拥有 `target.manage` 的：超级管理员、销售主管、运营总监、销售运营专员、财务总监；
持有 `target.view` 的另外加上销售顾问、市场推广专员。

配套前端改动（不改代码只看得到按钮藏起来还不够）：

1. `GET /api/targets` 对无 `target.manage` 的人只返回他自己那一行，
   所以个人视图的列表也必须按权限收，否则同事故意显示成「未设目标」= 假信息。
   见 `useTargetProgress.goalRows`。
2. 「目标还没拆到人」黄条是管理视角判断，一线看到只会误解为全公司都没设，已按权限关闭。
3. 侧栏/工作台原来用 `contract.view` 作为「要不要拉目标」的门槛——
   市场专员没有合同权限，于是目标根本没拉，页面显示「还没给你设目标」。
   已改为按 `target.view` 拉取；完成额拿不到时如实说「需要合同查看权限」。



### P2 其它

1. `GET /api/targets` 返回 `updatedAt` / `updatedBy`，页面可在备注旁显示「11-16 宋江 修改」。
2. 部门目标与个人目标的**月度合计对账**：现在是页面提示「还没拆到人」，后续可做成硬校验或审批流。

## 五、前端已留好的接口位

| 位置 | 现在 | 后端就绪后改什么 |
|---|---|---|
| `store/targets.js` | `GET /targets` + `PUT /targets` | 不用改 |
| `useTargetProgress.loadTargetBase` | 拉 500 条合同自己算 | 换成 `GET /targets/progress` |
| `targetProgress` / `monthGoalRows` | 前端按部门树 / 员工归集 | 换成接口 `rows` 直接映射 |
| `summaryOf` / `myMonthGoal` | 前端算 target / achieved / pace | 换成用接口的 `summary` |
| 侧栏目标卡 | 复用 `currentQuarterSummary`（部门口径） | 不用改 |

**切换成本很低**：`loadTargetBase` 一处取数、`targetProgress` / `monthGoalRows` / `summaryOf` / `myMonthGoal`
四处计算，其它页面都只读这几个导出。

## 六、复核 SQL

```sql
-- 1. 目标层级是否合理（父部门目标应 ≥ 子部门目标之和，否则完成率会超 100%）
SELECT p.name AS parent, pt.amount AS parent_target, SUM(ct.amount) AS child_sum
FROM crm_targets pt
JOIN crm_departments p ON p.id = pt.scope_id AND pt.scope = 'dept'
JOIN crm_departments c ON c.parent_id = p.id
LEFT JOIN crm_targets ct ON ct.scope = 'dept' AND ct.scope_id = c.id AND ct.period = pt.period
WHERE pt.period = '2026-Q4'
GROUP BY p.id, pt.amount
HAVING child_sum > parent_target;

-- 2. 设了部门季度目标、但本月没有任何个人目标（目标没拆到人）
SELECT t.period, d.name, t.amount
FROM crm_targets t
JOIN crm_departments d ON d.id = t.scope_id AND t.scope = 'dept'
WHERE t.period = '2026-Q4'
  AND NOT EXISTS (
    SELECT 1 FROM crm_targets et
    JOIN crm_employees e ON e.id = et.scope_id
    WHERE et.scope = 'employee' AND et.period = '2026-11'
      AND e.department_id = d.id
  );

-- 3. 个人目标指向了已离职/已删除员工（工作台永远算不出完成率）
SELECT t.* FROM crm_targets t
LEFT JOIN crm_employees e ON e.id = t.scope_id AND t.scope = 'employee'
WHERE t.scope = 'employee' AND (e.id IS NULL OR e.deleted_at IS NOT NULL);

-- 4. 同一个人同时设了季度和月度个人目标（季度数会翻倍）
SELECT scope_id, COUNT(DISTINCT period) AS n
FROM crm_targets WHERE scope = 'employee' AND period LIKE '%-Q%'
GROUP BY scope_id;
```
