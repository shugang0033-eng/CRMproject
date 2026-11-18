USE crm;
CREATE TABLE IF NOT EXISTS crm_customer_changes (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 customer_id BIGINT UNSIGNED NOT NULL,
 field VARCHAR(32) NOT NULL,
 before_value TEXT, after_value TEXT,
 operator_id BIGINT UNSIGNED NOT NULL,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY(customer_id) REFERENCES crm_customers(id)
);
CREATE OR REPLACE VIEW crm_customer_trade AS
SELECT c.id, COALESCE(o.amount,0) AS amount, COALESCE(o.orders,0) AS orders,
 o.lastOrderAt, COALESCE(o.signed,0) AS signed, COALESCE(o.net90,0) AS net90,
 o.cycle, COALESCE(r.received,0) AS received,
 GREATEST(0,COALESCE(o.signed,0)-COALESCE(r.received,0)) AS receivable,
 GREATEST(0,COALESCE(o.pastDue,0)-COALESCE(r.received,0)) AS overdue,
 (COALESCE(o.deals,0)>0 OR EXISTS(SELECT 1 FROM crm_contracts t WHERE t.customer_id=c.id
  AND t.deleted_at IS NULL AND t.status IN ('执行中','已完成'))) AS hasDeal
FROM crm_customers c
LEFT JOIN (
 SELECT o.customer_id,SUM(o.amount) amount,COUNT(*) orders,MAX(o.order_date) lastOrderAt,
 SUM(IF(o.status='已签收',o.amount,0)) signed,
 SUM(IF(o.status='已签收' AND DATEDIFF(CURDATE(),o.order_date)>c.payment_term,o.amount,0)) pastDue,
 SUM(IF(DATEDIFF(CURDATE(),o.order_date) BETWEEN 0 AND 90,o.amount,0)) net90,
 ROUND(DATEDIFF(MAX(o.order_date),MIN(o.order_date))/NULLIF(COUNT(*)-1,0)) cycle,
 SUM(o.status IN ('待发货','部分发货','已签收')) deals
 FROM crm_orders o JOIN crm_customers c ON c.id=o.customer_id
 WHERE o.deleted_at IS NULL AND o.status NOT IN ('草稿','已取消','已退货') GROUP BY o.customer_id
) o ON o.customer_id=c.id
LEFT JOIN (SELECT customer_id,SUM(amount) received FROM crm_receipts GROUP BY customer_id) r ON r.customer_id=c.id;
