/* ============================================================
 * 订单中心 · 权限点
 * ------------------------------------------------------------
 * 订单板块从 4 项扩到 5 项，并补上真正的「订单」单据：
 *   订单列表（合同订单 / 备货订单）← 新增，模块核心
 *   对账单                          ← 新增，月结客户对账后开票
 *   合同 / 发票 / 回款               沿用，语义按新链路走
 *   费用                            ← 迁出到「财务」菜单
 *
 * 新增 9 个权限码：
 *   order.view / order.create / order.approve / order.ship / order.return
 *   statement.view / statement.create / statement.confirm
 *   invoice.redflush
 *
 * 幂等，可重复执行。业务演示数据不在这里写，等后端建表后单独灌。
 * ============================================================ */
USE crm;

/* 1. 新增权限点 */
INSERT INTO crm_permissions (code, name)
SELECT t.code, t.name FROM (
  SELECT 'order.view' AS code, '查看订单' AS name UNION ALL
  SELECT 'order.create', '新建订单' UNION ALL
  SELECT 'order.approve', '审批订单' UNION ALL
  SELECT 'order.ship', '登记发货' UNION ALL
  SELECT 'order.return', '申请退货' UNION ALL
  SELECT 'statement.view', '查看对账单' UNION ALL
  SELECT 'statement.create', '生成对账单' UNION ALL
  SELECT 'statement.confirm', '确认对账单' UNION ALL
  SELECT 'invoice.redflush', '红冲发票'
) t
WHERE NOT EXISTS (SELECT 1 FROM crm_permissions p WHERE p.code = t.code);

/* 2. 文案对齐新链路：payment.confirm 现在承担「核销」语义 */
UPDATE crm_permissions SET name = '登记收款' WHERE code = 'payment.create';
UPDATE crm_permissions SET name = '核销回款' WHERE code = 'payment.confirm';

/* 3. 授权矩阵
 *  - 销售顾问：能开单、能发货、能提退货，但不能审批自己的单
 *  - 主管 / 运营：能审批（超额度、低于底价），能确认对账单
 *  - 财务：能生成与确认对账单、能红冲发票、能核销回款
 *  - 运营总监：全链路可看可审批，不具体开单
 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT DISTINCT r.id, p.id
FROM (
  /* 查看订单：所有需要看单据的角色 */
  SELECT 'order.view' AS code, 'super_admin' AS role_code UNION ALL
  SELECT 'order.view', 'sales_manager' UNION ALL
  SELECT 'order.view', 'sales_operations' UNION ALL
  SELECT 'order.view', 'demo_ops' UNION ALL
  SELECT 'order.view', 'demo_sales' UNION ALL
  SELECT 'order.view', 'demo_finance' UNION ALL

  /* 新建订单：一线 + 主管 */
  SELECT 'order.create', 'super_admin' UNION ALL
  SELECT 'order.create', 'sales_manager' UNION ALL
  SELECT 'order.create', 'demo_sales' UNION ALL

  /* 审批订单：主管以上，销售不能批自己 */
  SELECT 'order.approve', 'super_admin' UNION ALL
  SELECT 'order.approve', 'sales_manager' UNION ALL
  SELECT 'order.approve', 'sales_operations' UNION ALL
  SELECT 'order.approve', 'demo_ops' UNION ALL

  /* 发货：一线自己发，主管与运营兜底 */
  SELECT 'order.ship', 'super_admin' UNION ALL
  SELECT 'order.ship', 'sales_manager' UNION ALL
  SELECT 'order.ship', 'sales_operations' UNION ALL
  SELECT 'order.ship', 'demo_ops' UNION ALL
  SELECT 'order.ship', 'demo_sales' UNION ALL

  /* 退货申请：一线可提，确认在仓库/财务侧 */
  SELECT 'order.return', 'super_admin' UNION ALL
  SELECT 'order.return', 'sales_manager' UNION ALL
  SELECT 'order.return', 'demo_sales' UNION ALL

  /* 对账单：看 */
  SELECT 'statement.view', 'super_admin' UNION ALL
  SELECT 'statement.view', 'sales_manager' UNION ALL
  SELECT 'statement.view', 'sales_operations' UNION ALL
  SELECT 'statement.view', 'demo_ops' UNION ALL
  SELECT 'statement.view', 'demo_sales' UNION ALL
  SELECT 'statement.view', 'demo_finance' UNION ALL

  /* 对账单：生成（财务与运营，销售不自己出账单） */
  SELECT 'statement.create', 'super_admin' UNION ALL
  SELECT 'statement.create', 'sales_manager' UNION ALL
  SELECT 'statement.create', 'sales_operations' UNION ALL
  SELECT 'statement.create', 'demo_finance' UNION ALL

  /* 对账单：确认（确认后才允许开票） */
  SELECT 'statement.confirm', 'super_admin' UNION ALL
  SELECT 'statement.confirm', 'sales_operations' UNION ALL
  SELECT 'statement.confirm', 'demo_ops' UNION ALL
  SELECT 'statement.confirm', 'demo_finance' UNION ALL

  /* 红冲：只有财务与超管 */
  SELECT 'invoice.redflush', 'super_admin' UNION ALL
  SELECT 'invoice.redflush', 'demo_finance'
) m
JOIN crm_permissions p ON p.code = m.code
JOIN crm_roles r ON r.code = m.role_code
WHERE NOT EXISTS (
  SELECT 1 FROM crm_role_permissions rp
  WHERE rp.role_id = r.id AND rp.permission_id = p.id
);

/* 4. 财务角色要能进订单列表看单据，但不需要开单/发货；
      之前 demo_finance 也没有 contract.view 之外的订单侧入口，这里一并补查看 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r JOIN crm_permissions p ON p.code IN ('contract.view', 'invoice.view', 'payment.view')
WHERE r.code = 'demo_finance'
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* 4.1 销售顾问能建合同却看不到合同：给了 contract.create、漏了 contract.view。
       后果是「新建订单」里选不了合同（合同下拉为空），建完的合同自己也打不开。
       合同列表本身按 owner 过滤（OrderQueryService），补查看权不会看到别人的合同。 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r JOIN crm_permissions p ON p.code = 'contract.view'
WHERE r.code = 'demo_sales'
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* 5. 复核：各角色在订单链路的能力矩阵 */
SELECT r.code AS role_code, r.name AS role_name,
       MAX(p.code = 'order.view')        AS can_view_order,
       MAX(p.code = 'order.create')      AS can_create,
       MAX(p.code = 'order.approve')     AS can_approve,
       MAX(p.code = 'order.ship')        AS can_ship,
       MAX(p.code = 'statement.confirm') AS can_confirm_stmt,
       MAX(p.code = 'invoice.redflush')  AS can_redflush
FROM crm_roles r
LEFT JOIN crm_role_permissions rp ON rp.role_id = r.id
LEFT JOIN crm_permissions p ON p.id = rp.permission_id
GROUP BY r.id, r.code, r.name
ORDER BY can_view_order DESC, r.id;
