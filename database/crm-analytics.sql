/* ============================================================
 * 数据模块：权限点 + 线索状态扩展
 * ------------------------------------------------------------
 * 两件事，互相独立，可分开执行：
 *   A. 新增 data.* 权限点并发给角色（前端菜单靠它显示）
 *   B. 线索状态从 4 态扩到 6 态，为漏斗分析打基础
 *
 * 业务口径（与 docs/analytics-api.md 保持一致）：
 *   - 业绩一律按「签约额」（合同签订金额），不按回款额；
 *   - 数据范围由 data.scope.dept / data.scope.all 控制：
 *       两个都不勾 = 只能看本人（self）
 *       只勾 dept   = 本部门及下级（dept）
 *       勾了 all    = 全公司（all，隐含 dept）
 *
 * 执行：mysql -uroot -p crm < database/crm-analytics.sql
 * 注意：B 段的 ALTER 只建议执行一次；A 段幂等可重复执行。
 * ============================================================ */
USE crm;

/* ============================================================
 * A. 数据模块权限
 * ============================================================ */

/* A1. 权限点（幂等） */
INSERT INTO crm_permissions (code, name)
SELECT t.code, t.name
FROM (
  SELECT 'data.overview'    AS code, '销售概况'   AS name UNION ALL
  SELECT 'data.funnel',      '销售漏斗'   UNION ALL
  SELECT 'data.customers',   '客户分析'   UNION ALL
  SELECT 'data.performance', '业绩分析'   UNION ALL
  SELECT 'data.payments',    '回款分析'   UNION ALL
  SELECT 'data.products',    '产品分析'   UNION ALL
  SELECT 'data.sources',     '来源 ROI'   UNION ALL
  SELECT 'data.scope.dept',  '查看本部门数据' UNION ALL
  SELECT 'data.scope.all',   '查看全公司数据'
) t
WHERE NOT EXISTS (SELECT 1 FROM crm_permissions p WHERE p.code = t.code);

/* A2. 全公司视角：超管 / 总监 / 运营 —— 看全部数据 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r
JOIN crm_permissions p ON p.code LIKE 'data.%'
WHERE r.code IN ('super_admin', 'admin', 'sales_director', 'demo_director', 'sales_operations', 'demo_ops')
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* A3. 销售主管：本部门数据，看经营也看产品结构，但不看市场预算 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r
JOIN crm_permissions p ON p.code IN (
  'data.overview', 'data.funnel', 'data.customers', 'data.performance',
  'data.payments', 'data.products', 'data.scope.dept'
)
WHERE r.code IN ('sales_manager', 'demo_manager')
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* A4. 一线销售：只看自己，不勾 scope，后端按 owner_id = 当前用户裁剪 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r
JOIN crm_permissions p ON p.code IN (
  'data.overview', 'data.funnel', 'data.customers', 'data.performance', 'data.payments'
)
WHERE r.code IN ('account_manager', 'demo_sales', 'demo_account_manager')
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* A5. 财务：全公司回款与产品毛利，不给漏斗和客户跟进 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r
JOIN crm_permissions p ON p.code IN (
  'data.overview', 'data.payments', 'data.products', 'data.scope.dept', 'data.scope.all'
)
WHERE r.code IN ('finance', 'demo_finance')
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* A6. 市场：渠道 ROI 是他主场，看全公司来源与转化 */
INSERT INTO crm_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM crm_roles r
JOIN crm_permissions p ON p.code IN (
  'data.overview', 'data.funnel', 'data.sources', 'data.scope.all'
)
WHERE r.code IN ('marketing', 'demo_market')
  AND NOT EXISTS (
    SELECT 1 FROM crm_role_permissions rp WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

/* ============================================================
 * B. 线索状态：4 态 → 6 态
 *    pending → contacted → quoted → negotiating → won / invalid
 * ------------------------------------------------------------
 * 先加值、再迁移数据、最后收窄枚举，避免历史 converted 被清成空串。
 * ============================================================ */

/* B1. 扩枚举（保留 converted 以承接老数据） */
ALTER TABLE crm_leads
  MODIFY COLUMN status ENUM('pending', 'contacted', 'quoted', 'negotiating', 'won', 'converted', 'invalid')
  NOT NULL DEFAULT 'pending';

/* B2. 老数据迁移：「转为客户」等同成交 */
UPDATE crm_leads SET status = 'won' WHERE status = 'converted';

/* B3. 收窄枚举，converted 正式退出 */
ALTER TABLE crm_leads
  MODIFY COLUMN status ENUM('pending', 'contacted', 'quoted', 'negotiating', 'won', 'invalid')
  NOT NULL DEFAULT 'pending';

/* B4. 阶段进入时间：漏斗的「平均停留」靠它算，没有这个字段只能硬编码
       建议后端在状态变更时写入，索引用于按阶段统计时长 */
ALTER TABLE crm_leads
  ADD COLUMN stage_entered_at DATETIME NULL COMMENT '进入当前阶段的时刻，状态变更时刷新';

UPDATE crm_leads SET stage_entered_at = created_at WHERE stage_entered_at IS NULL;

/* B5. 渠道 ROI 需要知道每条线索的市场成本，按渠道单独记账，
       不在线索表上放金额，避免每行重复存同一个数 */
CREATE TABLE IF NOT EXISTS crm_channel_costs (
  id            BIGINT       NOT NULL AUTO_INCREMENT,
  channel       VARCHAR(32)  NOT NULL COMMENT '汽配展 / 1688 询盘 / 官网询盘 / 汽配城拜访 / 客户转介绍 / 电话外呼',
  period_month  CHAR(7)      NOT NULL COMMENT 'YYYY-MM',
  amount        DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '该月该渠道市场投入（元）',
  remark        VARCHAR(255) NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_channel_month (channel, period_month)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '渠道市场投入，用于计算获客成本与 ROI';
