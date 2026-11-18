USE crm;
ALTER TABLE crm_receipt_allocations MODIFY target_type ENUM('invoice','statement','order','contract') NOT NULL DEFAULT 'invoice';
ALTER TABLE crm_customer_transfers MODIFY operator_id BIGINT UNSIGNED NULL;
