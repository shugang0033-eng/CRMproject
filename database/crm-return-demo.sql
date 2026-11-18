-- ============================================================
-- 退货演示数据：3 条「待审核」退货，覆盖三种最常见原因
--
-- 用途：让「订单 › 退货与售后」页有真实可操作的待办。
--       确认入库 / 驳回都会真实改动 crm_returns、crm_order_items、crm_product_inventory，
--       所以这几条是可直接跑通流程的测试数据，不是展示用的假行。
--
-- 幂等：按 code 判断，重复执行不会重复插入。
-- 执行：mysql -uroot -p123456 --default-character-set=utf8mb4 crm < database/crm-return-demo.sql
--
-- 退货单金额必须等于明细 amount 之和，确认入库时按明细回补库存。
-- ============================================================

USE crm;

/* ---------- 1. 待审核：RT-2026-0004 杭州驰远 · 质量问题 ----------
   订单 SO-2026-0901 / 明细 8：洗车液 24 箱，退 1 箱 × 401.28 */
INSERT INTO crm_returns (code, order_id, customer_id, return_date, reason, status, amount, note, created_by)
SELECT 'RT-2026-0004', o.id, o.customer_id, '2026-11-12', '质量问题', '待审核', 401.28,
       '客户反馈 2 箱桶身渗漏，先退回 1 箱试检', o.owner_id
FROM crm_orders o WHERE o.code = 'SO-2026-0901'
  AND NOT EXISTS (SELECT 1 FROM crm_returns r WHERE r.code = 'RT-2026-0004');

INSERT INTO crm_return_items (return_id, order_item_id, product_id, unit, qty, price, amount)
SELECT r.id, i.id, i.product_id, i.unit, 1, i.price, 401.28
FROM crm_returns r
JOIN crm_order_items i ON i.id = 8
WHERE r.code = 'RT-2026-0004'
  AND NOT EXISTS (SELECT 1 FROM crm_return_items x WHERE x.return_id = r.id);

/* ---------- 2. 待审核：RT-2026-0005 南京依维柯 · 发错规格 ----------
   订单 SO-2026-0802 / 明细 5：抛光机 30 箱，退 2 箱 × 699.20 */
INSERT INTO crm_returns (code, order_id, customer_id, return_date, reason, status, amount, note, created_by)
SELECT 'RT-2026-0005', o.id, o.customer_id, '2026-11-13', '发错规格', '待审核', 1398.40,
       '订的是 15mm 偏心，发成 21mm，整 2 箱退回换货', o.owner_id
FROM crm_orders o WHERE o.code = 'SO-2026-0802'
  AND NOT EXISTS (SELECT 1 FROM crm_returns r WHERE r.code = 'RT-2026-0005');

INSERT INTO crm_return_items (return_id, order_item_id, product_id, unit, qty, price, amount)
SELECT r.id, i.id, i.product_id, i.unit, 2, i.price, 1398.40
FROM crm_returns r
JOIN crm_order_items i ON i.id = 5
WHERE r.code = 'RT-2026-0005'
  AND NOT EXISTS (SELECT 1 FROM crm_return_items x WHERE x.return_id = r.id);

/* ---------- 3. 待审核：RT-2026-0006 杭州驰远 · 运输破损 ----------
   订单 SO-2026-1001 / 明细 17：气动打磨机 15 箱，退 1 箱 × 668.80 */
INSERT INTO crm_returns (code, order_id, customer_id, return_date, reason, status, amount, note, created_by)
SELECT 'RT-2026-0006', o.id, o.customer_id, '2026-11-14', '运输破损', '待审核', 668.80,
       '外箱压瘪 1 箱，客户要求补发', o.owner_id
FROM crm_orders o WHERE o.code = 'SO-2026-1001'
  AND NOT EXISTS (SELECT 1 FROM crm_returns r WHERE r.code = 'RT-2026-0006');

INSERT INTO crm_return_items (return_id, order_item_id, product_id, unit, qty, price, amount)
SELECT r.id, i.id, i.product_id, i.unit, 1, i.price, 668.80
FROM crm_returns r
JOIN crm_order_items i ON i.id = 17
WHERE r.code = 'RT-2026-0006'
  AND NOT EXISTS (SELECT 1 FROM crm_return_items x WHERE x.return_id = r.id);

/* ---------- 复核 ---------- */
SELECT r.code, r.status, r.reason, r.amount,
       CONCAT(o.code, ' / ', c.name) AS orderAndCustomer,
       (SELECT COUNT(*) FROM crm_return_items i WHERE i.return_id = r.id) AS lineCount
FROM crm_returns r
JOIN crm_orders o ON o.id = r.order_id
JOIN crm_customers c ON c.id = r.customer_id
ORDER BY r.id;
