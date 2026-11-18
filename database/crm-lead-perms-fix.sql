/* ============================================================
 * 线索权限调整：转客户按角色配置、转移归属只给运营与主管
 * ------------------------------------------------------------
 * 业务规则（2026-11 修正）：
 *   1. 新线索（无负责人）由运营专员 / 销售主管在「销售线索」页直接分配，
 *      不需要先进线索池；线索池只收「超过 7 天没有跟进记录」的线索；
 *   2. 「转客户」是角色级开关，不写死在代码或本脚本里：
 *      在 设置 › 角色管理 勾选「转为客户」的角色，成员才会在线索行内
 *      看到这个按钮；取消勾选则立即隐藏；
 *   3. 「改负责人」是离职交接 / 区域调整动作，属于运营或主管，
 *      一线销售不能自己把线索甩给别人。故新增 lead.transfer 权限点，
 *      只发给运营、主管、总监与超管。
 *
 * 执行：mysql -uroot -p crm < database/crm-lead-perms-fix.sql
 * 幂等：可重复执行。
 * ============================================================ */
USE crm;

/* 1. 新增权限点：转移负责人（改派） */
INSERT INTO crm_permissions (code, name)
SELECT 'lead.transfer', '转移负责人' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM crm_permissions WHERE code = 'lead.transfer');

/* 2. 「转为客户」不写死。
      是否给某个角色由 设置 › 角色管理 › 线索 › 转为客户 决定：
      勾上，该角色在「销售线索」里就能看到「转客户」按钮；取消，按钮立即消失
      （重新进入页面即按新权限渲染）。
      脚本不再自动补发，否则每次执行都会把管理员手动取消的权限加回来。 */

/* 3. 转移负责人：运营 / 主管 / 总监 / 超管 / 市场（市场初筛后转交销售） */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r JOIN crm_permissions p ON p.code = 'lead.transfer'
WHERE r.code IN ('sales_operations', 'sales_manager', 'demo_ops', 'super_admin', 'demo_market')
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* 4. 销售运营还要能编辑线索：后端 transfer 分支校验的是 lead.edit，
      没这个码接口会 403（见 LeadService.move） */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r JOIN crm_permissions p ON p.code = 'lead.edit'
WHERE r.code = 'sales_operations'
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* 4b. 运营要能看到客户列表，才能做销售离职时的客户交接
       （前端 SALES_OPS 预设里有这三项，数据库漏发了，进 /customers 会 403） */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r JOIN crm_permissions p
  ON p.code IN ('customer.view', 'contact.view', 'followup.view')
WHERE r.code = 'sales_operations'
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* 5. 一线销售不能自己改派（防御：历史上如果有残留一并清掉） */
DELETE rp FROM crm_role_permissions rp
JOIN crm_roles r ON r.id = rp.role_id
JOIN crm_permissions p ON p.id = rp.permission_id
WHERE r.code IN ('demo_sales', 'product_operations') AND p.code = 'lead.transfer';

/* 6. 复核：谁转客户、谁改派 */
SELECT r.code AS role_code, r.name AS role_name,
       MAX(p.code = 'lead.convert')  AS can_convert,
       MAX(p.code = 'lead.transfer') AS can_transfer
FROM crm_roles r
LEFT JOIN crm_role_permissions rp ON rp.role_id = r.id
LEFT JOIN crm_permissions p ON p.id = rp.permission_id
GROUP BY r.id, r.code, r.name
ORDER BY can_transfer DESC, can_convert DESC, r.id;
