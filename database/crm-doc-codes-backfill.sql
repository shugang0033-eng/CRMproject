USE crm;
START TRANSACTION;
UPDATE crm_statements doc
JOIN (
 SELECT id, CONCAT('DZ-', yr, '-', LPAD(seq, GREATEST(4, LENGTH(seq)), '0')) AS next_code
 FROM (
 SELECT t.id,t.yr,ROW_NUMBER() OVER (PARTITION BY t.yr ORDER BY t.id)
 + COALESCE((SELECT MAX(CAST(SUBSTRING(n.code,9) AS UNSIGNED)) FROM crm_statements n
   WHERE n.code REGEXP CONCAT('^DZ-',t.yr,'-[0-9]+$')),0) AS seq
 FROM (SELECT id,LEFT(period,4) AS yr FROM crm_statements WHERE code REGEXP '^DZ-[0-9a-f]{8}-[0-9a-f]{4}-') t
 ) numbered
) numbered_codes ON numbered_codes.id=doc.id SET doc.code=numbered_codes.next_code;
SELECT 'DZ' AS prefix, ROW_COUNT() AS migrated;
UPDATE crm_invoices doc
JOIN (
 SELECT id, CONCAT('FP-', yr, '-', LPAD(seq, GREATEST(4, LENGTH(seq)), '0')) AS next_code
 FROM (
 SELECT t.id,t.yr,ROW_NUMBER() OVER (PARTITION BY t.yr ORDER BY t.id)
 + COALESCE((SELECT MAX(CAST(SUBSTRING(n.code,9) AS UNSIGNED)) FROM crm_invoices n
   WHERE n.code REGEXP CONCAT('^FP-',t.yr,'-[0-9]+$')),0) AS seq
 FROM (SELECT id,YEAR(created_at) AS yr FROM crm_invoices WHERE code REGEXP '^FP-[0-9a-f]{8}-[0-9a-f]{4}-') t
 ) numbered
) numbered_codes ON numbered_codes.id=doc.id SET doc.code=numbered_codes.next_code;
SELECT 'FP' AS prefix, ROW_COUNT() AS migrated;
UPDATE crm_leaves doc
JOIN (
 SELECT id, CONCAT('QJ-', yr, '-', LPAD(seq, GREATEST(4, LENGTH(seq)), '0')) AS next_code
 FROM (
 SELECT t.id,t.yr,ROW_NUMBER() OVER (PARTITION BY t.yr ORDER BY t.id)
 + COALESCE((SELECT MAX(CAST(SUBSTRING(n.code,9) AS UNSIGNED)) FROM crm_leaves n
   WHERE n.code REGEXP CONCAT('^QJ-',t.yr,'-[0-9]+$')),0) AS seq
 FROM (SELECT id,YEAR(created_at) AS yr FROM crm_leaves WHERE code REGEXP '^QJ-[0-9a-f]{8}-[0-9a-f]{4}-') t
 ) numbered
) numbered_codes ON numbered_codes.id=doc.id SET doc.code=numbered_codes.next_code;
SELECT 'QJ' AS prefix, ROW_COUNT() AS migrated;
UPDATE crm_receipts doc
JOIN (
 SELECT id, CONCAT('SK-', yr, '-', LPAD(seq, GREATEST(4, LENGTH(seq)), '0')) AS next_code
 FROM (
 SELECT t.id,t.yr,ROW_NUMBER() OVER (PARTITION BY t.yr ORDER BY t.id)
 + COALESCE((SELECT MAX(CAST(SUBSTRING(n.code,9) AS UNSIGNED)) FROM crm_receipts n
   WHERE n.code REGEXP CONCAT('^SK-',t.yr,'-[0-9]+$')),0) AS seq
 FROM (SELECT id,YEAR(created_at) AS yr FROM crm_receipts WHERE code REGEXP '^SK-[0-9a-f]{8}-[0-9a-f]{4}-') t
 ) numbered
) numbered_codes ON numbered_codes.id=doc.id SET doc.code=numbered_codes.next_code;
SELECT 'SK' AS prefix, ROW_COUNT() AS migrated;
UPDATE crm_orders doc
JOIN (
 SELECT id, CONCAT('SO-', yr, '-', LPAD(seq, GREATEST(4, LENGTH(seq)), '0')) AS next_code
 FROM (
 SELECT t.id,t.yr,ROW_NUMBER() OVER (PARTITION BY t.yr ORDER BY t.id)
 + COALESCE((SELECT MAX(CAST(SUBSTRING(n.code,9) AS UNSIGNED)) FROM crm_orders n
   WHERE n.code REGEXP CONCAT('^SO-',t.yr,'-[0-9]+$')),0) AS seq
 FROM (SELECT id,YEAR(created_at) AS yr FROM crm_orders WHERE code REGEXP '^SO-[0-9a-f]{8}-[0-9a-f]{4}-') t
 ) numbered
) numbered_codes ON numbered_codes.id=doc.id SET doc.code=numbered_codes.next_code;
SELECT 'SO' AS prefix, ROW_COUNT() AS migrated;
UPDATE crm_loans doc
JOIN (
 SELECT id, CONCAT('JK-', yr, '-', LPAD(seq, GREATEST(4, LENGTH(seq)), '0')) AS next_code
 FROM (
 SELECT t.id,t.yr,ROW_NUMBER() OVER (PARTITION BY t.yr ORDER BY t.id)
 + COALESCE((SELECT MAX(CAST(SUBSTRING(n.code,9) AS UNSIGNED)) FROM crm_loans n
   WHERE n.code REGEXP CONCAT('^JK-',t.yr,'-[0-9]+$')),0) AS seq
 FROM (SELECT id,YEAR(created_at) AS yr FROM crm_loans WHERE code REGEXP '^JK-[0-9a-f]{8}-[0-9a-f]{4}-') t
 ) numbered
) numbered_codes ON numbered_codes.id=doc.id SET doc.code=numbered_codes.next_code;
SELECT 'JK' AS prefix, ROW_COUNT() AS migrated;
UPDATE crm_returns doc
JOIN (
 SELECT id, CONCAT('RT-', yr, '-', LPAD(seq, GREATEST(4, LENGTH(seq)), '0')) AS next_code
 FROM (
 SELECT t.id,t.yr,ROW_NUMBER() OVER (PARTITION BY t.yr ORDER BY t.id)
 + COALESCE((SELECT MAX(CAST(SUBSTRING(n.code,9) AS UNSIGNED)) FROM crm_returns n
   WHERE n.code REGEXP CONCAT('^RT-',t.yr,'-[0-9]+$')),0) AS seq
 FROM (SELECT id,YEAR(created_at) AS yr FROM crm_returns WHERE code REGEXP '^RT-[0-9a-f]{8}-[0-9a-f]{4}-') t
 ) numbered
) numbered_codes ON numbered_codes.id=doc.id SET doc.code=numbered_codes.next_code;
SELECT 'RT' AS prefix, ROW_COUNT() AS migrated;
UPDATE crm_expenses doc
JOIN (
 SELECT id, CONCAT('FY-', yr, '-', LPAD(seq, GREATEST(4, LENGTH(seq)), '0')) AS next_code
 FROM (
 SELECT t.id,t.yr,ROW_NUMBER() OVER (PARTITION BY t.yr ORDER BY t.id)
 + COALESCE((SELECT MAX(CAST(SUBSTRING(n.code,9) AS UNSIGNED)) FROM crm_expenses n
   WHERE n.code REGEXP CONCAT('^FY-',t.yr,'-[0-9]+$')),0) AS seq
 FROM (SELECT id,YEAR(created_at) AS yr FROM crm_expenses WHERE code REGEXP '^FY-[0-9a-f]{8}-[0-9a-f]{4}-') t
 ) numbered
) numbered_codes ON numbered_codes.id=doc.id SET doc.code=numbered_codes.next_code;
SELECT 'FY' AS prefix, ROW_COUNT() AS migrated;
UPDATE crm_shipments doc
JOIN (
 SELECT id, CONCAT('FH-', yr, '-', LPAD(seq, GREATEST(4, LENGTH(seq)), '0')) AS next_code
 FROM (
 SELECT t.id,t.yr,ROW_NUMBER() OVER (PARTITION BY t.yr ORDER BY t.id)
 + COALESCE((SELECT MAX(CAST(SUBSTRING(n.code,9) AS UNSIGNED)) FROM crm_shipments n
   WHERE n.code REGEXP CONCAT('^FH-',t.yr,'-[0-9]+$')),0) AS seq
 FROM (SELECT id,YEAR(created_at) AS yr FROM crm_shipments WHERE code REGEXP '^FH-[0-9a-f]{8}-[0-9a-f]{4}-') t
 ) numbered
) numbered_codes ON numbered_codes.id=doc.id SET doc.code=numbered_codes.next_code;
SELECT 'FH' AS prefix, ROW_COUNT() AS migrated;
COMMIT;
