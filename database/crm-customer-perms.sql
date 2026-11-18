/* ============================================================
 * 客户 360 · 权限点
 * ------------------------------------------------------------
 * 客户板块从 4 个菜单收敛成 3 个：
 *   联系人、跟进记录 → 收进「客户详情」的 tab
 *   公海客户        → 改名「客户池」
 *   新增「团队跟进」看板（主管 / 运营视角）
 *
 * 新增两个权限码：
 *   customer.merge   合并重复客户（运营日常，线索转客户会产生重复档）
 *   followup.board   团队跟进看板（按人看全组待跟进与超期）
 *
 * 幂等，可重复执行。
 * ============================================================ */
USE crm;

/* 1. 新增权限点 */
INSERT INTO crm_permissions (code, name)
SELECT 'customer.merge', '合并重复客户' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM crm_permissions WHERE code = 'customer.merge');

INSERT INTO crm_permissions (code, name)
SELECT 'followup.board', '团队跟进看板' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM crm_permissions WHERE code = 'followup.board');

/* 2. 文案跟着改名走：菜单叫「客户池」，权限面板里不能还写「公海」 */
UPDATE crm_permissions SET name = '查看客户池' WHERE code = 'customer.public';
UPDATE crm_permissions SET name = '领取 / 退回客户池' WHERE code = 'customer.public.claim';

/* 3. 合并客户：运营 + 主管 + 总监 + 超管。
      销售不给——合并会作废一份档案，不该由一线自己决定 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r JOIN crm_permissions p ON p.code = 'customer.merge'
WHERE r.code IN ('super_admin', 'demo_ops', 'sales_manager', 'sales_operations')
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* 4. 团队跟进看板：同上四个角色。销售只能看自己名下，看板是管理视角 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r JOIN crm_permissions p ON p.code = 'followup.board'
WHERE r.code IN ('super_admin', 'demo_ops', 'sales_manager', 'sales_operations')
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* 5. 销售运营原来连 customer.edit 都没有，转客户后改不了档案。
       合并重复客户是同一个动作链上的事，一起补 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r JOIN crm_permissions p ON p.code IN ('customer.edit', 'contact.edit')
WHERE r.code = 'sales_operations'
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* 6. 运营总监：原来连客户池都进不去，但他要盯滞留客户、退回问题客户。
       给查看 + 退回，不给他「领取」也无所谓——运营不自己跟单，
       但权限码是「领取 / 退回」合一的，给了才能退回 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r JOIN crm_permissions p
  ON p.code IN ('customer.public', 'customer.public.claim')
WHERE r.code IN ('demo_ops', 'sales_operations')
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* 7. 账期与信用额度：单独一个权限点。
      账期 / 额度直接决定能不能赊销下单，销售自己改等于绕过审批，
      所以从 customer.edit 里拆出来，只发主管及以上。 */
INSERT INTO crm_permissions (code, name)
SELECT 'customer.credit', '调整账期与信用额度' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM crm_permissions WHERE code = 'customer.credit');

INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r JOIN crm_permissions p ON p.code = 'customer.credit'
WHERE r.code IN ('super_admin', 'sales_manager', 'demo_ops')
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* 8. 销售顾问看自己客户的回款。
      原来只有财务 / 管理层有 payment.view，销售打开自己客户详情页
      「应收余额」「回款记录」全是空的（/receipts 403），等于让人闭眼催款。
      数据范围仍由 owner / 部门树限制，看不到别家的 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r JOIN crm_permissions p ON p.code = 'payment.view'
WHERE r.code IN ('demo_sales')
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* 9. 复核：客户编辑与商务条件 */
SELECT r.code AS role_code,
       MAX(p.code = 'customer.edit')   AS can_edit,
       MAX(p.code = 'customer.credit') AS can_credit,
       MAX(p.code = 'payment.view')    AS can_payment
FROM crm_roles r
LEFT JOIN crm_role_permissions rp ON rp.role_id = r.id
LEFT JOIN crm_permissions p ON p.id = rp.permission_id
GROUP BY r.id, r.code
ORDER BY can_edit DESC, r.code;

/* 10. 复核：谁有合并、谁有看板 */
SELECT r.code AS role_code, r.name AS role_name,
       MAX(p.code = 'customer.view')   AS can_view,
       MAX(p.code = 'customer.merge')  AS can_merge,
       MAX(p.code = 'followup.board')  AS can_board,
       MAX(p.code = 'followup.create') AS can_follow
FROM crm_roles r
LEFT JOIN crm_role_permissions rp ON rp.role_id = r.id
LEFT JOIN crm_permissions p ON p.id = rp.permission_id
GROUP BY r.id, r.code, r.name
ORDER BY can_merge DESC, can_view DESC, r.id;
