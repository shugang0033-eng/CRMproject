USE crm;
ALTER TABLE crm_returns ADD COLUMN reject_reason VARCHAR(500), ADD COLUMN confirmed_by BIGINT UNSIGNED;
CREATE TABLE IF NOT EXISTS crm_targets (
  period CHAR(7) NOT NULL,
  department_id BIGINT UNSIGNED NOT NULL,
  amount DECIMAL(14,2) NOT NULL,
  note VARCHAR(500) NOT NULL DEFAULT '',
  PRIMARY KEY (period, department_id)
);
