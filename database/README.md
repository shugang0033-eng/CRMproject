# 数据库脚本说明

按下面的顺序执行，可从一个空库得到「能真实点、真实流转」的演示环境。
所有脚本都用 `utf8mb4`，连接串统一：

```bash
mysql -uroot -p --default-character-set=utf8mb4 crm < 某脚本.sql
```

## 一、建表与基础档案（按依赖顺序）

| 顺序 | 脚本 | 内容 |
|---|---|---|
| 1 | `crm-customers.sql` | 客户、联系人、跟进记录 |
| 2 | `crm-products.sql` | 产品、品类、单位、阶梯价 |
| 3 | `crm-settings.sql` | 部门、员工、角色、权限、业绩目标 |
| 4 | `crm-leads.sql` | 线索与线索池 |
| 5 | `crm-orders.sql` | 合同、订单、发货、对账、发票、回款（第一批表） |
| 6 | `crm-orders-batch23.sql` | 退货、核销、费用报销等第二/三批表 |
| 7 | `crm-office.sql` | 借款预支、请假、年度额度、审批流水 |
| 8 | `crm-analytics.sql` | 分析板块的视图/汇总表 |
| 9 | `crm-profile.sql` | 个人资料相关字段 |

权限类脚本（`*-perms*.sql`）在对应模块建表之后跑，可重复执行。

## 二、演示数据（两批，可重复跑）

| 脚本 | 覆盖模块 | 幂等判重键 |
|---|---|---|
| `crm-demo-seed.sql` | 客户、产品、员工、线索等基础档案 | 业务主键 / name |
| `crm-seed-business.sql` | 合同 → 订单 → 发货 → 签收 → 退货 → 对账 → 开票 → 收款 → 核销，另含联系人、跟进、客户待办、线索跟进、库存 | 各类单号（`HT-` `SO-` `FH-` `RT-` `DZ-` `FP-` `SK-`） |
| `crm-seed-office.sql` | 借款、报销（含明细/行程/附件/抵扣）、借款核销、请假、额度、审批流水 | 各类单号（`JK-` `BX-` `QJ-`） |

三个脚本都用 `INSERT ... SELECT ... FROM DUAL WHERE NOT EXISTS(...)` 按单号判重，
**连跑两次行数不变**，可以放心重跑。

还有一份补充脚本：

| 脚本 | 作用 | 幂等判重键 |
|---|---|---|
| `crm-approval-demo.sql` | 给「销售一组」补两张待审批请假单，让销售经理登录后有东西可审 | `request_id`（`seed-approval-leave-01/02`） |

为什么需要它：`crm-seed-office.sql` 里组内成员的请假全是「已通过」，销售经理登录后
「待审批」只剩他自己那张；而按规则**不能审批自己的单**（后端直接 403），
审批功能就成了摆设。跑完这份，李四（E09）能审张三、林致远的两张。

### 重跑前请注意

1. **库存是覆盖式写入**：`crm_seed_business.sql` 里的 `crm_product_inventory`
   按「已发货量 × 1.6 + 1500」重算可用量。如果你手动调过库存，重跑会被覆盖。
2. 两批数据之间有前后依赖：`crm-seed-office.sql` 里的报销抵扣借款，依赖
   `crm-seed-business.sql` 建好的客户与员工，必须先跑业务批次。
3. 建议先备份：`mysqldump -uroot -p --default-character-set=utf8mb4 crm > backup/crm-YYYYMMDD.sql`

## 三、自检 SQL

两个种子脚本末尾都带自检语句，跑完应全部返回 `0`：

```sql
-- 对账恒等式：close = open + shipped - received，且 open = 上一期 close
-- 核销超额：Σ核销金额 > 收款单金额
-- 收款超额：收款单金额 > 对账单应收
```

```bash
mysql -uroot -p --default-character-set=utf8mb4 crm < crm-seed-business.sql
mysql -uroot -p --default-character-set=utf8mb4 crm -e "
select count(*) as 对账不平 from crm_statements
 where close_amount <> open_amount + shipped_amount - received_amount;"
```

## 四、数据规模（当前种子）

| 表 | 行数 | 表 | 行数 |
|---|---|---|---|
| crm_contracts | 8 | crm_receipts | 9 |
| crm_contract_items | 25 | crm_receipt_allocations | 8 |
| crm_orders | 18 | crm_invoices | 10 |
| crm_order_items | 34 | crm_loans | 7 |
| crm_shipments | 15 | crm_loan_writeoffs | 3 |
| crm_shipment_items | 31 | crm_expenses | 8 |
| crm_returns | 3 | crm_expense_items | 22 |
| crm_statements | 12 | crm_leaves | 11 |
| crm_statement_lines | 19 | crm_approval_logs | 64 |

订单状态覆盖：待审批、待发货、部分发货、已签收、已退货、已取消；
对账单覆盖：待确认、已确认待开票、已开票、已回款。
