USE crm;

CREATE TABLE IF NOT EXISTS crm_leads (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    lead_no VARCHAR(32) NOT NULL UNIQUE,
    company VARCHAR(200) NOT NULL,
    contact VARCHAR(100) NOT NULL,
    phone VARCHAR(32) NULL,
    source VARCHAR(50) NOT NULL,
    level ENUM('A', 'B', 'C') NOT NULL DEFAULT 'B',
    status ENUM('pending', 'contacted', 'converted', 'invalid') NOT NULL DEFAULT 'pending',
    province VARCHAR(50) NULL,
    city VARCHAR(50) NULL,
    industry VARCHAR(100) NULL,
    note TEXT NULL,
    created_by BIGINT UNSIGNED NOT NULL,
    owner_id BIGINT UNSIGNED NULL,
    pool_entered_at DATETIME NULL,
    pool_reason VARCHAR(255) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_lead_owner_status (owner_id, status, id),
    INDEX idx_lead_pool (owner_id, pool_entered_at, id),
    FOREIGN KEY (created_by) REFERENCES crm_employees (id),
    FOREIGN KEY (owner_id) REFERENCES crm_employees (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS crm_lead_owner_history (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    lead_id BIGINT UNSIGNED NOT NULL,
    action ENUM('assign', 'claim', 'return') NOT NULL,
    previous_owner_id BIGINT UNSIGNED NULL,
    new_owner_id BIGINT UNSIGNED NULL,
    operator_id BIGINT UNSIGNED NULL COMMENT '自动退回时为空',
    reason VARCHAR(255) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_lead_owner_history (lead_id, created_at, id),
    INDEX idx_lead_daily_claim (operator_id, action, created_at),
    FOREIGN KEY (lead_id) REFERENCES crm_leads (id),
    FOREIGN KEY (previous_owner_id) REFERENCES crm_employees (id),
    FOREIGN KEY (new_owner_id) REFERENCES crm_employees (id),
    FOREIGN KEY (operator_id) REFERENCES crm_employees (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS crm_lead_followups (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    lead_id BIGINT UNSIGNED NOT NULL,
    employee_id BIGINT UNSIGNED NOT NULL,
    content TEXT NOT NULL,
    is_effective BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_lead_followup (lead_id, is_effective, created_at),
    FOREIGN KEY (lead_id) REFERENCES crm_leads (id),
    FOREIGN KEY (employee_id) REFERENCES crm_employees (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
