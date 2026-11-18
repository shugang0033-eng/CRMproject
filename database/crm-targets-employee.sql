-- ============================================================================
-- 业绩目标：从「只有部门季度目标」扩到「部门季度 + 个人月度」
-- ----------------------------------------------------------------------------
-- 原表：crm_targets(period char(7), department_id bigint, amount, note)
--      主键 (period, department_id) —— 物理上存不了「人」这个维度
-- 新表：crm_targets(period, scope, scope_id, amount, note)
--      scope='dept'     scope_id=部门 id，period 用季度 '2026-Q4'
--      scope='employee' scope_id=员工 id，period 用月份 '2026-11'
--
-- 为什么周期不统一：部门目标是对老板的季度承诺，个人目标是按月冲刺/按月算提成。
-- 两者口径靠「季度个人目标 = 该季度三个月的个人目标之和」对齐，不互相覆盖。
--
-- 执行一次即可；重复执行会因列已存在而报错（先看 information_schema 判断）。
-- 回滚：把 scope_id 改名回 department_id、去掉 scope 列，主键还原。
-- ============================================================================

-- 0) 备份（迁移当天一次性，可留着）
CREATE TABLE IF NOT EXISTS crm_targets_bak_20261116 AS SELECT * FROM crm_targets;

-- 1) 主键先拆掉，否则没法改列名
ALTER TABLE crm_targets DROP PRIMARY KEY;

-- 2) 原 department_id 原地改名为 scope_id，保留数据与类型
ALTER TABLE crm_targets CHANGE COLUMN department_id scope_id BIGINT UNSIGNED NOT NULL;

-- 3) 加 scope，老数据全部是部门目标
ALTER TABLE crm_targets ADD COLUMN scope VARCHAR(16) NOT NULL DEFAULT 'dept' AFTER period;

-- 4) 新主键：一个周期 + 一种范围 + 一个对象，只允许一行
ALTER TABLE crm_targets ADD PRIMARY KEY (period, scope, scope_id);

-- 5) 个人目标要按「季度内三个月」求和，按 scope_id 反查
ALTER TABLE crm_targets ADD KEY idx_targets_scope (scope, scope_id, period);
