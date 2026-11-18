CREATE DATABASE IF NOT EXISTS crm CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE crm;

CREATE TABLE IF NOT EXISTS crm_departments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    parent_id BIGINT UNSIGNED NULL,
    name VARCHAR(100) NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    INDEX idx_department_tree (parent_id, sort_order, id),
    CONSTRAINT fk_department_parent FOREIGN KEY (parent_id) REFERENCES crm_departments (id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS crm_employees (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    employee_no VARCHAR(32) NOT NULL UNIQUE,
    username VARCHAR(64) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    department_id BIGINT UNSIGNED NOT NULL,
    phone VARCHAR(32) NULL,
    email VARCHAR(254) NULL,
    hire_date DATE NOT NULL,
    status ENUM('active', 'disabled') NOT NULL DEFAULT 'active',
    deleted_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_employee_department_status (department_id, deleted_at, status),
    CONSTRAINT fk_employee_department FOREIGN KEY (department_id) REFERENCES crm_departments (id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS crm_department_managers (
    department_id BIGINT UNSIGNED PRIMARY KEY,
    employee_id BIGINT UNSIGNED NOT NULL,
    CONSTRAINT fk_manager_department FOREIGN KEY (department_id) REFERENCES crm_departments (id) ON DELETE CASCADE,
    CONSTRAINT fk_manager_employee FOREIGN KEY (employee_id) REFERENCES crm_employees (id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS crm_roles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(64) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500) NULL,
    is_builtin BOOLEAN NOT NULL DEFAULT FALSE,
    data_scope ENUM('self', 'department', 'department_tree', 'all') NOT NULL DEFAULT 'department',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS crm_permissions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS crm_employee_roles (
    employee_id BIGINT UNSIGNED NOT NULL,
    role_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (employee_id, role_id),
    CONSTRAINT fk_employee_role_employee FOREIGN KEY (employee_id) REFERENCES crm_employees (id) ON DELETE CASCADE,
    CONSTRAINT fk_employee_role_role FOREIGN KEY (role_id) REFERENCES crm_roles (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS crm_role_permissions (
    role_id BIGINT UNSIGNED NOT NULL,
    permission_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_role_permission_role FOREIGN KEY (role_id) REFERENCES crm_roles (id) ON DELETE CASCADE,
    CONSTRAINT fk_role_permission_permission FOREIGN KEY (permission_id) REFERENCES crm_permissions (id)
) ENGINE=InnoDB;

INSERT INTO crm_permissions (code, name) VALUES
    ('dashboard', '工作台'),
    ('leads', '线索'),
    ('customers', '客户'),
    ('orders', '订单'),
    ('settings', '设置')
ON DUPLICATE KEY UPDATE id = crm_permissions.id;
