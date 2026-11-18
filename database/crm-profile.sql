USE crm;

ALTER TABLE crm_employees
    ADD COLUMN avatar MEDIUMTEXT NULL,
    ADD COLUMN password_updated_at DATETIME NULL;

CREATE TABLE crm_employee_logins (
    id CHAR(36) PRIMARY KEY,
    employee_id BIGINT UNSIGNED NOT NULL,
    device VARCHAR(255) NOT NULL,
    ip VARCHAR(45) NOT NULL,
    logged_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    INDEX idx_employee_logins (employee_id, logged_at),
    FOREIGN KEY (employee_id) REFERENCES crm_employees (id)
);
