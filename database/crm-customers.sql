USE crm;
CREATE TABLE IF NOT EXISTS crm_customers (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    source_lead_id BIGINT UNSIGNED NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL,
    industry VARCHAR(100),
    level VARCHAR(20) NOT NULL,
    owner_id BIGINT UNSIGNED NOT NULL,
    created_by BIGINT UNSIGNED NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (source_lead_id) REFERENCES crm_leads(id),
    FOREIGN KEY (owner_id) REFERENCES crm_employees(id),
    FOREIGN KEY (created_by) REFERENCES crm_employees(id)
);
CREATE TABLE IF NOT EXISTS crm_customer_contacts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(32),
    FOREIGN KEY (customer_id) REFERENCES crm_customers(id)
);
CREATE TABLE IF NOT EXISTS crm_customer_transfers (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id BIGINT UNSIGNED NOT NULL,
    previous_owner_id BIGINT UNSIGNED NOT NULL,
    owner_id BIGINT UNSIGNED NOT NULL,
    operator_id BIGINT UNSIGNED NOT NULL,
    reason VARCHAR(255),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES crm_customers(id),
    FOREIGN KEY (previous_owner_id) REFERENCES crm_employees(id),
    FOREIGN KEY (owner_id) REFERENCES crm_employees(id),
    FOREIGN KEY (operator_id) REFERENCES crm_employees(id)
);
