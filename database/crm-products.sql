USE crm;
-- 品类与属性模板
CREATE TABLE IF NOT EXISTS crm_product_categories (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  name         VARCHAR(100) NOT NULL UNIQUE,
  icon         VARCHAR(32)  DEFAULT 'box',
  description  VARCHAR(255) DEFAULT '',
  status       ENUM('active','disabled') DEFAULT 'active',
  sort         INT DEFAULT 0,
  created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS crm_product_category_attrs (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  category_id  BIGINT NOT NULL,
  attr_key     VARCHAR(64) NOT NULL,      -- size / weight / material
  label        VARCHAR(64) NOT NULL,      -- 尺寸 / 克重 / 材质
  type         ENUM('text','number','select') DEFAULT 'text',
  unit         VARCHAR(16) DEFAULT '',    -- cm / g/m² / ml
  options_json JSON NULL,                 -- type=select 时的选项
  sort         INT DEFAULT 0,
  UNIQUE KEY uk_cat_key (category_id, attr_key)
);

-- 产品
CREATE TABLE IF NOT EXISTS crm_products (
  id              BIGINT PRIMARY KEY AUTO_INCREMENT,
  code            VARCHAR(64) NOT NULL UNIQUE,      -- 物料编码
  name            VARCHAR(200) NOT NULL,
  category_id     BIGINT NOT NULL,
  brand           VARCHAR(64) DEFAULT '',
  specs_json      JSON NULL,                        -- { size: '40×40', weight: '300' }
  sale_unit       VARCHAR(16) NOT NULL,             -- 报价单位：箱
  base_price      DECIMAL(20,8) NOT NULL,           -- 最小单位价（元/条）
  dealer_price    DECIMAL(20,8) DEFAULT NULL,       -- 最小单位价
  cost_price      DECIMAL(20,8) DEFAULT NULL,       -- 最小单位成本价
  moq             INT DEFAULT 1,                    -- 起订量，按 sale_unit
  production_days INT DEFAULT 0,
  produce_mode    ENUM('self','outsource') DEFAULT 'self',
  customizable    TINYINT(1) DEFAULT 0,             -- 支持贴牌
  stock_status    ENUM('enough','low','made_to_order') DEFAULT 'enough',
  status          ENUM('on','off') DEFAULT 'on',
  remark          VARCHAR(500) DEFAULT '',
  created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (category_id) REFERENCES crm_product_categories(id),
  KEY idx_status (status)
);

-- 单位换算（一个产品 2~3 行）
CREATE TABLE IF NOT EXISTS crm_product_units (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  product_id BIGINT NOT NULL,
  unit_name  VARCHAR(16) NOT NULL,     -- 条 / 包 / 箱
  factor     INT NOT NULL,             -- 1 个该单位 = 多少个最小单位
  is_sale    TINYINT(1) DEFAULT 0,     -- 是否报价单位
  UNIQUE KEY uk_product_unit (product_id, unit_name)
);

-- 阶梯价（按 sale_unit 的数量）
CREATE TABLE IF NOT EXISTS crm_product_tiers (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  product_id BIGINT NOT NULL,
  min_qty    INT NOT NULL,
  unit_price DECIMAL(20,8) NOT NULL,   -- 最小单位价
  KEY idx_product (product_id)
);

-- 套装
CREATE TABLE IF NOT EXISTS crm_product_bundles (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  code         VARCHAR(64) NOT NULL UNIQUE,
  name         VARCHAR(200) NOT NULL,
  bundle_price DECIMAL(20,8) NOT NULL,
  status       ENUM('on','off') DEFAULT 'on',
  remark       VARCHAR(500) DEFAULT ''
);
CREATE TABLE IF NOT EXISTS crm_product_bundle_items (
  bundle_id  BIGINT NOT NULL,
  product_id BIGINT NOT NULL,
  qty        INT NOT NULL,
  unit_name  VARCHAR(16) NOT NULL,
  PRIMARY KEY (bundle_id, product_id, unit_name), FOREIGN KEY (product_id) REFERENCES crm_products(id)
);

-- 客户协议价
CREATE TABLE IF NOT EXISTS crm_customer_prices (
  customer_id BIGINT NOT NULL,
  discount    DECIMAL(4,3) NOT NULL,   -- 0.880 = 8.8 折
  product_ids JSON NULL,               -- 为空表示全品类
  updated_by  BIGINT NOT NULL,
  updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (customer_id)
);

