USE crm;
CREATE TABLE IF NOT EXISTS crm_statement_lines (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, statement_id BIGINT UNSIGNED NOT NULL,
 kind ENUM('shipment','return','receipt') NOT NULL, order_id BIGINT UNSIGNED NULL,
 code VARCHAR(32) NOT NULL, date DATE NOT NULL, amount DECIMAL(12,2) NOT NULL,
 FOREIGN KEY(statement_id) REFERENCES crm_statements(id), INDEX(order_id,statement_id)
);
CREATE TABLE IF NOT EXISTS crm_product_inventory (
 product_id BIGINT PRIMARY KEY, available DECIMAL(14,2) NOT NULL DEFAULT 0,
 FOREIGN KEY(product_id) REFERENCES crm_products(id), CHECK(available>=0)
);
ALTER TABLE crm_returns ADD confirmed_at DATETIME NULL;
ALTER TABLE crm_order_items ADD unit_factor INT NULL;
ALTER TABLE crm_receipt_allocations MODIFY target_type ENUM('invoice','statement','order') NOT NULL DEFAULT 'invoice';
ALTER TABLE crm_invoices ADD issued_no VARCHAR(40) GENERATED ALWAYS AS (NULLIF(no,'')) STORED,
 ADD UNIQUE KEY uk_invoice_issued_no(issued_no);
