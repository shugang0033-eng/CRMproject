/* ============================================================
 * 行政财务 · 权限点
 * ------------------------------------------------------------
 * 原「财务」板块只有费用报销一项，现扩成四项并改名「行政财务」：
 *   费用报销（报销单升级为多行明细 + 差旅行程 + 借款抵扣）
 *   借款预支（新增，与报销抵扣打通）
 *   请假申请（新增）
 *   审批中心（新增，三类单据统一待办）
 *
 * 新增 7 个权限码（expense.* 三个早已存在，这里只改文案）：
 *   loan.view / loan.create / loan.approve
 *   leave.view / leave.create / leave.approve
 *   approval.view
 *
 * 幂等，可重复执行。
 * ⚠️ 本轮前端交付时【未执行】此脚本 —— 用户要求先只做前端，
 *    后端建表时一起跑。执行前请确认 crm_roles 里存在下列 role_code。
 * ============================================================ */
USE crm;

/* 1. 新增权限点 */
INSERT INTO crm_permissions (code, name)
SELECT t.code, t.name FROM (
  SELECT 'loan.view'      AS code, '查看借款预支' AS name UNION ALL
  SELECT 'loan.create',    '申请借款'      UNION ALL
  SELECT 'loan.approve',   '审批借款'      UNION ALL
  SELECT 'leave.view',     '查看请假'      UNION ALL
  SELECT 'leave.create',   '发起请假'      UNION ALL
  SELECT 'leave.approve',  '审批请假'      UNION ALL
  SELECT 'approval.view',  '查看审批中心'
) t
WHERE NOT EXISTS (SELECT 1 FROM crm_permissions p WHERE p.code = t.code);

/* 2. 文案对齐：报销单现在带明细与行程，不再是「提交费用」这么笼统 */
UPDATE crm_permissions SET name = '查看费用报销' WHERE code = 'expense.view';
UPDATE crm_permissions SET name = '提交报销单'   WHERE code = 'expense.create';
UPDATE crm_permissions SET name = '审批费用'     WHERE code = 'expense.approve';

/* 3. 授权矩阵
 *  - 全员：能看能提（view + create + 审批中心入口），这是员工自助的底线
 *  - 主管 / 运营：加审批权
 *  - 财务：审报销与借款，请假只看不批（请假是行政口径，不是财务口径）
 *  - 超管：全给
 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT DISTINCT r.id, p.id
FROM (
  /* 报销：查看 */
  SELECT 'expense.view' AS code, 'super_admin' AS role_code UNION ALL
  SELECT 'expense.view', 'sales_director'  UNION ALL
  SELECT 'expense.view', 'sales_manager'   UNION ALL
  SELECT 'expense.view', 'account_manager' UNION ALL
  SELECT 'expense.view', 'finance'         UNION ALL
  SELECT 'expense.view', 'sales_operations' UNION ALL
  SELECT 'expense.view', 'demo_sales'      UNION ALL
  SELECT 'expense.view', 'demo_ops'        UNION ALL
  SELECT 'expense.view', 'demo_finance'    UNION ALL

  /* 报销：提交 */
  SELECT 'expense.create', 'super_admin' UNION ALL
  SELECT 'expense.create', 'sales_director' UNION ALL
  SELECT 'expense.create', 'sales_manager' UNION ALL
  SELECT 'expense.create', 'account_manager' UNION ALL
  SELECT 'expense.create', 'finance' UNION ALL
  SELECT 'expense.create', 'demo_sales' UNION ALL
  SELECT 'expense.create', 'demo_finance' UNION ALL

  /* 报销：审批（主管以上 + 运营 + 财务） */
  SELECT 'expense.approve', 'super_admin' UNION ALL
  SELECT 'expense.approve', 'sales_director' UNION ALL
  SELECT 'expense.approve', 'sales_manager' UNION ALL
  SELECT 'expense.approve', 'sales_operations' UNION ALL
  SELECT 'expense.approve', 'finance' UNION ALL
  SELECT 'expense.approve', 'demo_ops' UNION ALL
  SELECT 'expense.approve', 'demo_finance' UNION ALL

  /* 借款：查看 */
  SELECT 'loan.view', 'super_admin' UNION ALL
  SELECT 'loan.view', 'sales_director' UNION ALL
  SELECT 'loan.view', 'sales_manager' UNION ALL
  SELECT 'loan.view', 'account_manager' UNION ALL
  SELECT 'loan.view', 'finance' UNION ALL
  SELECT 'loan.view', 'sales_operations' UNION ALL
  SELECT 'loan.view', 'demo_sales' UNION ALL
  SELECT 'loan.view', 'demo_ops' UNION ALL
  SELECT 'loan.view', 'demo_finance' UNION ALL

  /* 借款：申请 */
  SELECT 'loan.create', 'super_admin' UNION ALL
  SELECT 'loan.create', 'sales_director' UNION ALL
  SELECT 'loan.create', 'sales_manager' UNION ALL
  SELECT 'loan.create', 'account_manager' UNION ALL
  SELECT 'loan.create', 'demo_sales' UNION ALL

  /* 借款：审批 */
  SELECT 'loan.approve', 'super_admin' UNION ALL
  SELECT 'loan.approve', 'sales_director' UNION ALL
  SELECT 'loan.approve', 'sales_manager' UNION ALL
  SELECT 'loan.approve', 'sales_operations' UNION ALL
  SELECT 'loan.approve', 'finance' UNION ALL
  SELECT 'loan.approve', 'demo_ops' UNION ALL
  SELECT 'loan.approve', 'demo_finance' UNION ALL

  /* 请假：查看 */
  SELECT 'leave.view', 'super_admin' UNION ALL
  SELECT 'leave.view', 'sales_director' UNION ALL
  SELECT 'leave.view', 'sales_manager' UNION ALL
  SELECT 'leave.view', 'account_manager' UNION ALL
  SELECT 'leave.view', 'finance' UNION ALL
  SELECT 'leave.view', 'sales_operations' UNION ALL
  SELECT 'leave.view', 'demo_sales' UNION ALL
  SELECT 'leave.view', 'demo_ops' UNION ALL
  SELECT 'leave.view', 'demo_finance' UNION ALL

  /* 请假：发起 */
  SELECT 'leave.create', 'super_admin' UNION ALL
  SELECT 'leave.create', 'sales_director' UNION ALL
  SELECT 'leave.create', 'sales_manager' UNION ALL
  SELECT 'leave.create', 'account_manager' UNION ALL
  SELECT 'leave.create', 'sales_operations' UNION ALL
  SELECT 'leave.create', 'demo_sales' UNION ALL
  SELECT 'leave.create', 'demo_ops' UNION ALL

  /* 请假：审批（行政口径，财务不给） */
  SELECT 'leave.approve', 'super_admin' UNION ALL
  SELECT 'leave.approve', 'sales_director' UNION ALL
  SELECT 'leave.approve', 'sales_manager' UNION ALL
  SELECT 'leave.approve', 'sales_operations' UNION ALL
  SELECT 'leave.approve', 'demo_ops'

) m
JOIN crm_permissions p ON p.code = m.code
JOIN crm_roles r ON r.code = m.role_code
WHERE NOT EXISTS (
  SELECT 1 FROM crm_role_permissions rp
  WHERE rp.role_id = r.id AND rp.permission_id = p.id
);

/* 4. 审批中心入口：所有能进系统的人都给，不然员工看不到自己单据走到哪了 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r
JOIN crm_permissions p ON p.code = 'approval.view'
WHERE NOT EXISTS (
  SELECT 1 FROM crm_role_permissions rp
  WHERE rp.role_id = r.id AND rp.permission_id = p.id
);

/* 5. 复核：各角色在行政财务板块的能力矩阵 */
SELECT r.code AS role_code, r.name AS role_name,
       MAX(p.code = 'expense.create')  AS can_expense,
       MAX(p.code = 'expense.approve') AS can_approve_expense,
       MAX(p.code = 'loan.create')     AS can_loan,
       MAX(p.code = 'loan.approve')    AS can_approve_loan,
       MAX(p.code = 'leave.create')    AS can_leave,
       MAX(p.code = 'leave.approve')   AS can_approve_leave,
       MAX(p.code = 'approval.view')   AS can_approval
FROM crm_roles r
LEFT JOIN crm_role_permissions rp ON rp.role_id = r.id
LEFT JOIN crm_permissions p ON p.id = rp.permission_id
GROUP BY r.id, r.code, r.name
ORDER BY can_approval DESC, r.id;
