USE crm;

ALTER TABLE crm_employees ADD COLUMN password_hash VARCHAR(128) NULL;
