-- ============================================================================
-- 审批演示数据：给「销售经理」留两张组内待办
-- ============================================================================
-- 为什么要单独一份：
--   crm-seed-office.sql 里 9 张请假单，组内成员（销售一组）的都已经「已通过」，
--   销售经理登录后「待审批」里只剩他自己那张。而他自己那张按规则不能自审
--   （OfficeService.decide：applicant == 审批人 直接 403），于是审批功能永远没东西可点。
--
-- 这份脚本补两张「销售一组」成员发起的待审批请假单：
--   林致远（E11，销售顾问） 调休 1 天
--   张三  （E08，销售经理） 年假 2 天
-- 销售经理李四（E09，销售一组）登录后：
--   请假申请页 → 两张都能看到「通过 / 驳回」
--   审批中心   → 待办里能看到这两张
--
-- 幂等：按 request_id 判重，可以反复执行。
-- 额度：待审批不扣额度，审批通过后才扣（与后端一致），所以这里不用改 crm_leave_quotas。
-- ============================================================================

USE crm;

INSERT INTO crm_leaves
  (code, applicant_id, dept_id, type, start_date, end_date, days, reason, status,
   apply_date, handover_id, request_id, created_by)
SELECT 'QJ-2026-0099', 14, 6, '调休', '2026-11-24', '2026-11-24', 1.0,
       '上周六门店盘点加班，申请调休一天', '待审批', '2026-11-13', 8,
       'seed-approval-leave-01', 14
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM crm_leaves WHERE request_id = 'seed-approval-leave-01');

INSERT INTO crm_leaves
  (code, applicant_id, dept_id, type, start_date, end_date, days, reason, status,
   apply_date, handover_id, request_id, created_by)
SELECT 'QJ-2026-0100', 8, 6, '年假', '2026-11-25', '2026-11-26', 2.0,
       '陪家人出行，已安排好渠道交接', '待审批', '2026-11-13', 14,
       'seed-approval-leave-02', 8
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM crm_leaves WHERE request_id = 'seed-approval-leave-02');

-- ---------------------------------------------------------------------------
-- 自检：销售经理（E09）应当看到 2 张待审批、且都不是自己提的
-- ---------------------------------------------------------------------------
SELECT l.code, e.name AS 申请人, d.name AS 部门, l.type, l.days, l.status
FROM crm_leaves l
JOIN crm_employees e ON e.id = l.applicant_id
JOIN crm_departments d ON d.id = l.dept_id
WHERE l.status = '待审批'
ORDER BY l.id;
