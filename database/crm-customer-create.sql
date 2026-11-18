USE crm;
ALTER TABLE crm_customers MODIFY source_lead_id BIGINT UNSIGNED NULL,
 ADD COLUMN code VARCHAR(32) NULL AFTER id, ADD UNIQUE KEY uk_customer_code(code);
UPDATE crm_customers c JOIN (
 SELECT id, YEAR(created_at) AS yr, ROW_NUMBER() OVER(PARTITION BY YEAR(created_at) ORDER BY created_at,id) AS seq
 FROM crm_customers
) n ON n.id=c.id
SET c.code=CONCAT('C-',n.yr,'-',LPAD(n.seq,GREATEST(4,LENGTH(n.seq)),'0'))
WHERE c.code IS NULL;
