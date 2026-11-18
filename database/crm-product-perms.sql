/* ============================================================
 * 产品管理权限点
 * ------------------------------------------------------------
 * 产品模块把原来的「配件目录」升级成一级模块，权限从 2 个拆成 5 个：
 *   product.view    查看产品
 *   product.edit    新建 / 编辑 / 上下架 / 维护品类属性
 *   product.price   调价（标准价、经销价、阶梯价）
 *   product.cost    看成本价与毛利率
 *   product.import  Excel 导入导出
 *
 * 其中 view / edit 库里已有，这里只补后三个。
 * 幂等，可重复执行。
 * ============================================================ */
USE crm;

/* 1. 新增权限点 */
INSERT INTO crm_permissions (code, name)
SELECT 'product.price', '调整价格' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM crm_permissions WHERE code = 'product.price');

INSERT INTO crm_permissions (code, name)
SELECT 'product.cost', '查看成本价' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM crm_permissions WHERE code = 'product.cost');

INSERT INTO crm_permissions (code, name)
SELECT 'product.import', '产品导入导出' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM crm_permissions WHERE code = 'product.import');

/* 2. 销售运营专员：产品维护主责（建档、改规格、调价、批量导入） */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r JOIN crm_permissions p
  ON p.code IN ('product.view', 'product.edit', 'product.price', 'product.import')
WHERE r.code = 'sales_operations'
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* 3. 销售主管 / 运营总监：可以调价，但不做批量导入 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r JOIN crm_permissions p
  ON p.code IN ('product.price')
WHERE r.code IN ('sales_manager', 'demo_ops')
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* 3b. 运营总监原来没有「查看产品」，调价却有了会很难解释，一并补上 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r JOIN crm_permissions p
  ON p.code IN ('product.view', 'product.edit')
WHERE r.code = 'demo_ops'
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* 3c. 超管：权限表里也要齐全。前端对超管是放行的，
       但后端接口按权限码鉴权，缺码会让超管自己 403 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r JOIN crm_permissions p
  ON p.code IN ('product.view', 'product.edit', 'product.price', 'product.cost', 'product.import')
WHERE r.code = 'super_admin'
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* 4. 财务：只有成本价可见，没有调价与编辑 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r JOIN crm_permissions p
  ON p.code IN ('product.cost')
WHERE r.code = 'demo_finance'
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* 5. 复核 */
SELECT r.code AS role_code, r.name AS role_name,
       MAX(p.code = 'product.view')   AS can_view,
       MAX(p.code = 'product.edit')   AS can_edit,
       MAX(p.code = 'product.price')  AS can_price,
       MAX(p.code = 'product.cost')   AS can_cost,
       MAX(p.code = 'product.import') AS can_import
FROM crm_roles r
LEFT JOIN crm_role_permissions rp ON rp.role_id = r.id
LEFT JOIN crm_permissions p ON p.id = rp.permission_id
GROUP BY r.id, r.code, r.name
ORDER BY can_edit DESC, can_view DESC, r.id;
