# 线索流转接口（转移 / 分配）

前端已完成「转移线索（单条 / 批量）」「分配线索（单条 / 批量）」与「分配 / 转移前的撞单核对」三套功能，后端接口按本文实现即可，前端代码不用再改。

> 现状：后端 `/api/leads/**` 已实现，前端已全部切到真实接口（不再有演示数据兜底）。
> 接收人名单统一取 `GET /api/employees`，与「设置 › 员工管理」同源，支持按部门筛选、按姓名 / 工号搜索。

---

## 业务流程口径（先看这段）

线索流转分三段，**分配和线索池是两件事**：

| 阶段 | 谁做 | 线索状态 | 前端入口 |
|---|---|---|---|
| 1. 新线索进来 | 市场 / 系统导入 | `owner_id IS NULL`、`pool_entered_at IS NULL` | 销售线索 ›「待分配」Tab |
| 2. 派给销售 | 销售运营专员、销售主管（`lead.pool.assign`） | 写入 `owner_id` | 行内「分配」/ 顶部「批量分配」 |
| 3. 超期回收 | 定时任务（**后端待实现**，见第六节） | 写 `pool_entered_at`、`pool_reason` | 线索池 |

- **分配不需要线索先入池**：运营在「销售线索」页看到无主线索就能直接派给销售，这是主路径。
- 线索池只有两种来源：超过 **7 天**没有跟进记录被系统回收、负责人主动放弃。池里的线索销售可以领（`lead.pool.claim`），运营 / 主管可以再分配（`lead.pool.assign`）。
- **转客户（`lead.convert`）是角色级开关，代码里不写死**：在「设置 › 角色管理 › 线索」勾选「转为客户」的角色，成员才会在销售线索的行内看到「转客户」按钮；取消勾选，按钮立即不渲染（重新进入页面生效）。是否给销售顾问开这一项由管理员决定，脚本不会替角色做默认。
- **改负责人（`lead.transfer`）才是要收权的**：销售离职、区域调整、组长调派时，把线索 / 客户从 A 改到 B，由运营或主管操作；一线销售没有这个权限，避免两个人之间互相甩客户。客户列表的「转负责人」用同一个权限点。权限调整脚本见 `database/crm-lead-perms-fix.sql`。

| 角色 | `lead.convert`（转客户） | `lead.transfer`（改负责人） |
|---|---|---|
| 销售顾问 `demo_sales` | 按需（演示库默认 ❌，可在角色管理勾选） | ❌ |
| 销售运营专员 `sales_operations` | ✅ | ✅ |
| 销售主管 / 经理 `sales_manager` | ✅ | ✅ |
| 运营总监 `demo_ops` | ✅ | ✅ |
| 超级管理员 `super_admin` | ✅ | ✅ |

---

## 零、数据范围与「我的线索」

线索页顶部有「我的线索 / 全部线索」切换，判断依据不是写死的角色，而是**当前账号实际能看到多少数据**：

- 有 `lead.pool.assign` → 默认「全部线索」（主管 / 运营视角）
- 没有分配权，但返回的列表里出现了别人的线索（部门范围角色）→ 同样给出切换
- 纯销售（`data_scope = self`）→ 只有「我的线索」，页面标题也随之变化，默认落在「待联系」

**后端要注意的一点**：`LeadMapper.list()` 的范围子查询要求当前账号的角色里存在 `p.code = 'lead.view'` 这条授权记录，否则整条 SQL 的 `EXISTS` 不成立，直接返回空数组。销售顾问角色起初漏了这个权限点，表现就是「分配了但销售登录什么都看不到」，且 `GET /api/leads` 返回 403。给角色补上 `lead.view` 即可，不需要改代码：

```sql
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM crm_roles r JOIN crm_permissions p ON p.code = 'lead.view'
WHERE r.code = 'demo_sales'
  AND NOT EXISTS (SELECT 1 FROM crm_role_permissions rp WHERE rp.role_id = r.id AND rp.permission_id = p.id);
```

另外：`GET /api/auth/me` 返回的 `dept` 目前是**人名**而不是部门名（`crm_employees` 与 `crm_departments` 的 `name` 同名列没有起别名），建议顺手改成 `d.name AS dept`。

---

## 一、转移线索（销售线索页 › 行内「转移」）

把线索从当前负责人改派给另一位员工，权限点 `lead.transfer`（**不是** `lead.edit`：编辑联系人、等级和改派是两件事，销售能改自己线索的联系人，但不能把线索甩给别人）。

### 1. 单条转移

```
POST /api/leads/{leadId}/transfer
Content-Type: application/json
```

```json
{
  "ownerId": "12",
  "ownerName": "林致远",
  "reason": "区域调整",
  "note": "客户在临平，交接给片区负责人继续跟",
  "notify": true
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| ownerId | string | 接收人员工 id。**注意**：演示数据里没有员工 id，当前前端把姓名放在这个字段里；接入 `GET /api/leads/assignees` 后会自动换成真实 id，后端开发时以 id 为准 |
| ownerName | string | 接收人姓名，冗余字段，便于后端日志 |
| reason | string | 转移原因，见下方枚举 |
| note | string | 交接备注，可为空字符串 |
| notify | boolean | 是否站内通知原负责人与接收人 |

**响应**

| 状态 | 含义 | 前端表现 |
|---|---|---|
| 204 | 成功 | 行内负责人更新，toast「已转给 XXX」 |
| 400 | 接收人不存在 / 已停用 / 与当前负责人相同 | 弹窗内 toast 错误，不关闭弹窗 |
| 404 | 线索不存在 | toast「数据不存在，可能已被删除」 |
| 409 | 线索已转为客户或已标记无效 | toast 提示，行数据不变 |
| 403 | 无 `lead.transfer` 权限 | toast「没有权限执行该操作」 |

### 2. 批量转移（前端已接：列表多选 → 顶部「批量转移」）

```
POST /api/leads/transfer
```

```json
{ "ids": ["LD-2605", "LD-2604"], "ownerId": "12", "reason": "人员离职 / 调岗", "note": "", "notify": true }
```

- 响应约定同单条（204 / 400 / 404 / 409 / 403）。
- 前端从「销售线索」页勾选任意条数后点顶部「批量转移」调用；**单条仍走 `POST /api/leads/{id}/transfer`**，批量接口只负责 2 条及以上（前端在批量入口只勾中 1 条时也会调这个接口，`ids` 长度 1 请一并支持）。
- 已转化 / 无效的线索前端会在提交前剔除，`ids` 里不会出现；后端仍需按 409 兜底。
- **只转移「有负责人」的线索**：`owner_id` 为空的线索在行内显示的是「分配」而不是「转移」，批量转移也会把它们排除并提示改用「批量分配」。
- **建议整体事务**：任一 id 不合法就整体失败回滚（400/409 里带上失败的 id 列表），不要部分成功——否则前端列表和后端会不一致。

---

## 二、分配线索（销售线索 › 行内「分配」/ 顶部「批量分配」，线索池同款接口）

把无归属的线索指派给指定员工，单条与批量走同一接口，权限点 `lead.pool.assign`。

入口有两个，页面不同、数据同源：

- **线索池**：`pool_entered_at IS NOT NULL` 的线索（被退回公海的）
- **销售线索 › 待分配**：`owner_id IS NULL AND pool_entered_at IS NULL` 的新线索（刚进系统、还没派给谁）

```
POST /api/leads/assign
Content-Type: application/json
```

```json
{
  "ids": ["LD-2590", "LD-2588"],
  "ownerId": "12",
  "ownerName": "林致远",
  "reason": "区域匹配",
  "note": "这家在临平，离你片区近，本周内先电话确认补货频次",
  "notify": true
}
```

| 状态 | 含义 | 前端表现 |
|---|---|---|
| 204 | 成功 | 被分配的线索从列表移除，选中态清空，负责人更新 |
| 400 | 接收人不存在 / 已停用 | toast 报错，弹窗保留 |
| 409 | 其中若干条已被他人领取、或状态已变化 | toast 报错，提示刷新（**建议整体失败回滚，不要部分成功**，否则前端列表会和后端不一致） |
| 403 | 无 `lead.pool.assign` 权限 | toast |

> ✅ **已修（2026-11-13）**：`LeadService.move()` 原来有一行 `if (assign != lead.inPool() || ...)`，
> 要求 `assign=true` 时线索必须已入池，导致「待分配」的新线索永远 409。现在判据改为：
>
> - `assign`：`owner_id IS NULL`，且状态不是 converted / invalid；
> - `transfer`：`owner_id IS NOT NULL`，同样排除终态；
> - 两者都按各自权限（`lead.pool.assign` / `lead.transfer`）走一次 `canAccess` 数据范围校验。
>   改派用 `lead.transfer` 判定；后端目前 `move()` 里 transfer 分支仍写着 `lead.edit`，需要一起改成 `lead.transfer`，否则销售拿 `lead.edit` 直接调接口仍能改派（前端已隐藏按钮）。
>
> 前端代码里保留了 409 / 405 兜底（不会静默假成功），正常情况不会再触发。

分配成功后建议同时写入一条线索流转记录（谁在什么时候把哪些线索指派给谁），便于后续审计。

---

## 三、撞单核对（前端已接，接口待实现）

分配 / 转移之前先查一遍：这家店是不是已经是某个销售的客户档案，或者已经有一条同名线索（含公海里的）在别人名下。汽配这行一个集团常有多个门店、多个采购联系人，不核对就分下去，两个销售会各自去报一遍价。

```
POST /api/leads/conflicts
Content-Type: application/json
```

```json
{ "ids": ["LD-2605", "LD-2604"], "ownerId": 14 }
```

```json
{
  "items": [
    { "leadId": "LD-2605", "type": "customer", "code": "CU-1024",
      "name": "杭州驰远汽车服务连锁", "owner": "林致远", "ownerId": 14,
      "status": "合作中", "detail": "战略客户 · 汽修连锁" },
    { "leadId": "LD-2605", "type": "lead", "code": "LD-2599",
      "name": "杭州驰远汽车服务连锁", "owner": "苏晚", "ownerId": 13,
      "status": "contacted", "detail": "已联系 · 汽配展" }
  ]
}
```

- `type`：`customer`（客户档案）/ `lead`（别人名下的线索）/ `pool`（公海线索）/ `duplicate`（同一批里重复）
- **只用于提醒，不阻断**：前端把结果列在弹窗里，勾选「已知悉」后仍可提交，不会因为撞单拒绝请求
- 接收人与冲突项的 `ownerId` 相同（分回给本来就是负责人的人）时，前端会自动过滤掉，不弹提示
- 返回空数组即视为无撞单
- **未实现时前端会本地兜底**：客户档案（当前还是前端 mock）+ `/api/leads` + 线索池按公司名归一化比对，所以这个功能现在就能用；接口上了之后自动切到服务端结果（服务端能匹配别名、集团关系，比字符串比对准得多）
- 建议后端比对时忽略空白与大小写，并支持「同一集团 / 同一手机号」的匹配，避免 `杭州驰远汽车服务连锁` 与 `杭州驰远（滨江店）` 漏判

---

## 四、接收人候选（前端已改用 `/api/employees`）

```
GET /api/leads/assignees?keyword=
```

```json
[
  { "id": "12", "name": "林致远", "department": "汽配渠道部", "role": "客户经理", "activeLeads": 14, "capacity": 30 }
]
```

**前端现状**：分配 / 转移弹窗的接收人选择器现在直接读 `GET /api/employees`（与「设置 › 员工管理」同一份数据），原因：

1. 选择器要显示并支持搜索**工号**（`employeeNo`），`assignees` 不返回这个字段；
2. 用户要求这里的名单必须和设置里的员工对得上，直接复用同一接口最稳；
3. `assignees` 的 `department` 目前返回的是**人名**而不是部门名——SQL 里 `SELECT e.id, e.name, d.name` 两个列都叫 `name`，没有起别名。建议改成 `SELECT e.id, e.name, d.name AS department, ...`，顺便把 `e.employee_no` 也带上，改完前端可以再切回这个接口（现在它会按部门 + 负载给出更合适的默认排序）。

- `activeLeads` / `capacity`：当前在跟线索数与上限；接入后可在选择器里展示「林致远 · 14/30」并置灰超限的人
- 不论用哪个接口，`POST /api/leads/assign` 的 `ownerId` 必须是能解析成在职员工的 id

### 4.1 接收人负载（前端已做，等后端给准数）

选择器每一行右侧现在会显示 **在跟 N / 客户 M**，主管据此判断「这个人还接不接得住」。数据来源与建议：

| 字段 | 前端现在怎么算 | 建议后端提供 |
|---|---|---|
| 在跟线索 | 拉 `GET /api/leads?pool=false`，按 `ownerId` 统计 `status ∉ (converted, invalid)` | 直接在员工接口返回 `activeLeads`，避免前端为了几个数字拉全量线索 |
| 客户档案 | 客户模块目前是前端数据，按负责人姓名匹配（`useAssigneeLoad.js`） | 客户模块上后端后，返回 `customers` 计数 |
| 容量 | 前端常量 `LEAD_CAPACITY = 30` | 员工或角色上的 `capacity`，没有就沿用 30 |

建议把这三个数加到 `GET /api/employees`（或 `/api/leads/assignees`）的返回里：

```json
{ "id": 14, "name": "林致远", "employeeNo": "DEMO-testSales2", "departmentName": "销售一组",
  "activeLeads": 12, "customers": 8, "capacity": 30 }
```

前端会把 `capacity` 覆盖到默认值上，`activeLeads` 到了 `capacity` 就标红「已满」，但在前端**不硬拦**——临时插一条急单是常态，拦了反而逼人绕过系统。

> ⚠️ 现在库里的 16 条线索 `owner_id` 全是 NULL（10 条「待分配」+ 6 条在池），所以负载列现在都显示 0，这是数据状态而不是计算错误。等线索分出去、或者后端直接给计数就正常了。


---

## 五、枚举

**转移原因**（`REASON_TRANSFER`）

`区域调整`、`人员离职 / 调岗`、`客户意向变更`、`工作量再平衡`、`跨部门协作`、`其他`

**分配依据**（`REASON_ASSIGN`）

`区域匹配`、`行业匹配`、`新人练手`、`主管指派`、`客户指定`、`其他`

建议后端只做长度校验（≤50 字），不要硬编码枚举值，否则前端加一项就要改两处。

---

## 六、几个实现要点

1. **并发领取 / 分配**：线索池分配建议 `UPDATE ... WHERE id IN (...) AND owner_id IS NULL`，受影响行数不等于 `ids.length` 就抛 409 回滚。
2. **状态限制**：`status` 为「商机转化」「无效」的线索，前端已经禁用「转移 / 转客户」按钮，后端也要拦一次（409），别只靠前端。
3. **每日领取上限**：线索池页写着「单账号每日最多领取 20 条」，前端只做了本地计数提示，真实校验要在后端。
4. **通知**：`notify=true` 时给原负责人与接收人各发一条站内信；前端没有消息中心页，先落在你已有的通知机制里即可。
5. **权限码**：如果沿用 `crm_roles.permission_code`，请把 `lead.edit`、`lead.transfer`、`lead.pool.assign` 加进去，否则角色管理页勾了也拦不住接口。
6. **7 天未跟进自动入池（后端待实现）**：目前没有任何定时任务会写 `pool_entered_at`，池子只会因「负责人主动放弃」而增长。判断依据要取「最后一条有效动作」——跟进记录 > 分配 / 领取记录 > 入库时间，否则一条 10 天前入库、昨天才分配的线索会被立刻回收：

```sql
UPDATE crm_leads l
SET pool_entered_at = NOW(), pool_reason = '超期未跟进', owner_id = NULL
WHERE l.pool_entered_at IS NULL
  AND l.status IN ('pending', 'contacted')
  AND COALESCE(
        (SELECT MAX(f.created_at) FROM crm_lead_followups f WHERE f.lead_id = l.id),
        (SELECT MAX(h.created_at) FROM crm_lead_owner_history h
          WHERE h.lead_id = l.id AND h.action IN ('assign', 'claim', 'transfer')),
        l.created_at
      ) < NOW() - INTERVAL 7 DAY;
```

配 `@EnableScheduling` + `@Scheduled(cron = "0 30 2 * * *")`，回收时往 `crm_lead_owner_history` 写一条记录。注意该表 `action` 是 enum（`assign/claim/return/transfer`），没有 `recycle`：要么复用 `return`，要么先 `ALTER TABLE ... MODIFY action ENUM(...,'recycle')`。这样前端「我的线索」里线索消失时能解释清楚是被回收了。

---

## 七、前端已做的拦截

| 层 | 表现 |
|---|---|
| 菜单 / 路由 | 线索相关页面需 `lead.view`，线索池需 `lead.pool` |
| 按钮 | 「转移 / 批量转移」「客户 › 转负责人」需 `lead.transfer`，「分配 / 批量分配」需 `lead.pool.assign`，「领取 / 批量领取」需 `lead.pool.claim`，「转客户」需 `lead.convert`（角色管理里勾选才出现） |
| 转客户 | 「转客户」需 `lead.convert`，**完全由角色配置决定**：设置 › 角色管理勾上才渲染，取消勾选立即消失；无负责人的线索不显示该按钮（先分配再谈转化）；已转化 / 无效的置灰 |
| 改负责人 | 「转移 / 批量转移」「客户列表 › 转负责人」需 `lead.transfer`：运营 / 主管 / 总监可见，销售顾问不显示（离职交接由运营接手） |
| 默认视角 | 有分配权的账号默认落在「全部线索 › 待分配」（进来先看待办）；一条待分配都没有时自动退回「全部线索」。销售只有「我的线索」，默认「待联系」 |
| 行状态 | 商机转化、无效的线索，「转移」「转客户」置灰；批量转移会自动剔除这类线索并 toast 提示剔除了几条 |
| 无负责人 | 行内操作把「转移」换成「分配」（没主的人谈不上转移）；批量转移会自动排除并提示用「批量分配」 |
| 撞单 | 弹窗里列出客户档案 / 在跟线索 / 公海线索的重复项；**有重复时必须勾选「已知悉」才能提交**，否则 toast 拦下 |
| 空选 | 未勾选就点「批量转移」→ toast「请先勾选要转移的线索」；「批量分配」同理 |
| 多选 | 全选只作用于当前页；换 Tab 或改筛选会清空已选，避免批量操作打到看不见的行 |

### Tab 结构

`全部线索 / 待分配 / 待联系 / 已联系 / 商机转化 / 无效线索`

「待分配」是流程状态而不是线索状态（`owner_id IS NULL` 且未进入终态），后端不需要新增字段，前端算出来的。
