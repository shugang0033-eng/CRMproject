USE crm;
ALTER TABLE crm_receipt_allocations ADD COLUMN revoked_by BIGINT UNSIGNED NULL AFTER revoke_reason;
CREATE TABLE IF NOT EXISTS crm_receipt_allocation_requests (
    receipt_id BIGINT UNSIGNED NOT NULL,
    request_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    PRIMARY KEY (receipt_id,request_id),
    FOREIGN KEY (receipt_id) REFERENCES crm_receipts(id) ON DELETE CASCADE
);
INSERT IGNORE INTO crm_permissions(code,name) VALUES ('payment.revoke','反核销回款');
INSERT IGNORE INTO crm_role_permissions(role_id,permission_id)
SELECT r.id,p.id FROM crm_roles r JOIN crm_permissions p ON p.code='payment.revoke'
WHERE r.code IN ('finance','super_admin');