USE crm;
CREATE TABLE IF NOT EXISTS crm_contracts (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code          VARCHAR(32)  NOT NULL COMMENT '合同编号 HT-2026-0187',
  name          VARCHAR(120) NOT NULL,
  customer_id   BIGINT UNSIGNED NOT NULL,
  type          ENUM('年框','季度','单次') NOT NULL DEFAULT '单次',
  amount        DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '含税总额，由明细汇总',
  discount      DECIMAL(4,3)  NOT NULL DEFAULT 1.000 COMMENT '协议折扣 0.880 = 88折',
  term_days     INT          NOT NULL DEFAULT 30 COMMENT '账期天数',
  payment_term  VARCHAR(40)  NOT NULL DEFAULT '' COMMENT '展示文案：月结 30 天',
  sign_date     DATE         NULL,
  start_date    DATE         NULL,
  end_date      DATE         NULL,
  owner_id      BIGINT UNSIGNED NOT NULL COMMENT '负责人',
  status        ENUM('草稿','待审批','执行中','已完成','已作废') NOT NULL DEFAULT '草稿',
  remark        VARCHAR(500) NOT NULL DEFAULT '',
  created_by    BIGINT UNSIGNED NOT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at    DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  KEY idx_customer (customer_id, status),
  KEY idx_owner (owner_id, status)
) COMMENT='合同/年框';

CREATE TABLE IF NOT EXISTS crm_contract_items (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  contract_id BIGINT UNSIGNED NOT NULL,
  product_id  BIGINT NOT NULL,
  unit        VARCHAR(16) NOT NULL COMMENT '销售单位，如 箱',
  qty         DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '协议总量',
  price       DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '协议单价（已含折扣）',
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_contract_product (contract_id, product_id, unit),
  FOREIGN KEY (product_id) REFERENCES crm_products(id)
) COMMENT='合同覆盖的商品与协议价';

CREATE TABLE IF NOT EXISTS crm_contract_approvals (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  contract_id BIGINT UNSIGNED NOT NULL,
  action      ENUM('提交','审核','批准','驳回','作废') NOT NULL,
  operator_id BIGINT UNSIGNED NOT NULL,
  note        VARCHAR(500) NOT NULL DEFAULT '',
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_contract (contract_id, created_at)
) COMMENT='合同审批时间线';

CREATE TABLE IF NOT EXISTS crm_orders (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code         VARCHAR(32) NOT NULL COMMENT 'SO-2026-0412',
  customer_id  BIGINT UNSIGNED NOT NULL,
  contract_id  BIGINT UNSIGNED NULL COMMENT '备货订单为空',
  type         ENUM('合同订单','备货订单') NOT NULL DEFAULT '合同订单',
  order_date   DATE NOT NULL,
  expect_date  DATE NULL COMMENT '期望到货',
  owner_id     BIGINT UNSIGNED NOT NULL,
  status       ENUM('草稿','待审批','待发货','部分发货','已签收','已取消','已退货')
               NOT NULL DEFAULT '草稿',
  credit_check ENUM('通过','待审批','超限') NOT NULL DEFAULT '通过',
  amount       DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '含税金额，明细汇总缓存',
  remark       VARCHAR(500) NOT NULL DEFAULT '',
  request_id   VARCHAR(64) NULL COMMENT '幂等键，防重复提交',
  created_by   BIGINT UNSIGNED NOT NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at   DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  UNIQUE KEY uk_request (request_id),
  KEY idx_customer_date (customer_id, order_date),
  KEY idx_status_date (status, order_date),
  KEY idx_contract (contract_id)
) COMMENT='销售订单（要货单）';

CREATE TABLE IF NOT EXISTS crm_order_items (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id     BIGINT UNSIGNED NOT NULL,
  product_id   BIGINT NOT NULL,
  unit         VARCHAR(16) NOT NULL,
  qty          DECIMAL(12,2) NOT NULL,
  price        DECIMAL(12,2) NOT NULL COMMENT '成交单价（含税）',
  price_source VARCHAR(24) NOT NULL DEFAULT '' COMMENT '协议价/阶梯价/经销价/标准价',
  floor_price  DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '下单时成本价快照，审计用',
  amount       DECIMAL(12,2) NOT NULL COMMENT 'qty * price',
  shipped_qty  DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '已发数量缓存',
  returned_qty DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '已退数量缓存',
  sort_no      INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_order (order_id),
  FOREIGN KEY (product_id) REFERENCES crm_products(id)
) COMMENT='订单商品明细';

CREATE TABLE IF NOT EXISTS crm_shipments (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code        VARCHAR(32) NOT NULL COMMENT 'FH-2026-0891',
  order_id    BIGINT UNSIGNED NOT NULL,
  ship_date   DATE NOT NULL,
  logistics   VARCHAR(60) NOT NULL DEFAULT '',
  tracking_no VARCHAR(60) NOT NULL DEFAULT '',
  status      ENUM('已发货','运输中','已签收','已拒收') NOT NULL DEFAULT '已发货',
  signed_at   DATETIME NULL COMMENT '签收时间 —— 收入确认与账龄起算都用它',
  amount      DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '本批含税金额',
  boxes       INT NOT NULL DEFAULT 0 COMMENT '箱数，展示用',
  created_by  BIGINT UNSIGNED NOT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  KEY idx_order (order_id, ship_date)
) COMMENT='发货单';

CREATE TABLE IF NOT EXISTS crm_shipment_items (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  shipment_id   BIGINT UNSIGNED NOT NULL,
  order_item_id BIGINT UNSIGNED NOT NULL,
  product_id    BIGINT NOT NULL,
  unit          VARCHAR(16) NOT NULL,
  qty           DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_shipment (shipment_id),
  KEY idx_order_item (order_item_id)
) COMMENT='发货明细';

CREATE TABLE IF NOT EXISTS crm_returns (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code        VARCHAR(32) NOT NULL COMMENT 'RT-2026-0006',
  order_id    BIGINT UNSIGNED NOT NULL,
  customer_id BIGINT UNSIGNED NOT NULL,
  return_date DATE NOT NULL,
  reason      ENUM('质量问题','发错规格','客户取消','运输破损','其他') NOT NULL,
  status      ENUM('待审核','已入库','已退款','已驳回') NOT NULL DEFAULT '待审核',
  amount      DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '冲减金额，明细汇总',
  note        VARCHAR(500) NOT NULL DEFAULT '',
  created_by  BIGINT UNSIGNED NOT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  KEY idx_order (order_id),
  KEY idx_customer_date (customer_id, return_date)
) COMMENT='退货单';

CREATE TABLE IF NOT EXISTS crm_return_items (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  return_id    BIGINT UNSIGNED NOT NULL,
  order_item_id BIGINT UNSIGNED NOT NULL,
  product_id   BIGINT NOT NULL,
  unit         VARCHAR(16) NOT NULL,
  qty          DECIMAL(12,2) NOT NULL,
  price        DECIMAL(12,2) NOT NULL COMMENT '按原订单单价冲减，不能重新取价',
  amount       DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_return (return_id)
) COMMENT='退货明细';

CREATE TABLE IF NOT EXISTS crm_statements (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code           VARCHAR(32) NOT NULL COMMENT 'DZ-2026-10-001',
  customer_id    BIGINT UNSIGNED NOT NULL,
  period         CHAR(7) NOT NULL COMMENT '2026-10',
  start_date     DATE NOT NULL,
  end_date       DATE NOT NULL,
  open_amount    DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '期初应收',
  shipped_amount DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '本期发货（减退货）',
  received_amount DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '本期回款',
  close_amount   DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '期末应收 = 期初+发货-回款',
  order_count    INT NOT NULL DEFAULT 0,
  status         ENUM('待确认','已确认','已开票','已回款','已作废') NOT NULL DEFAULT '待确认',
  confirmed_at   DATETIME NULL,
  created_by     BIGINT UNSIGNED NOT NULL,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  UNIQUE KEY uk_customer_period (customer_id, period),
  KEY idx_period (period)
) COMMENT='月度对账单，生成即冻结';

CREATE TABLE IF NOT EXISTS crm_receipts (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code       VARCHAR(32) NOT NULL COMMENT 'SK-2026-0231',
  customer_id BIGINT UNSIGNED NOT NULL,
  amount     DECIMAL(12,2) NOT NULL COMMENT '到账金额',
  pay_date   DATE NOT NULL,
  method     ENUM('银行转账','银行承兑','对公转账','现金') NOT NULL DEFAULT '银行转账',
  bank       VARCHAR(80) NOT NULL DEFAULT '',
  remark     VARCHAR(500) NOT NULL DEFAULT '',
  request_id VARCHAR(64) NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  UNIQUE KEY uk_request (request_id),
  KEY idx_customer_date (customer_id, pay_date)
) COMMENT='收款单（银行到账）';

CREATE TABLE IF NOT EXISTS crm_receipt_allocations (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  receipt_id    BIGINT UNSIGNED NOT NULL,
  target_type   ENUM('invoice','statement') NOT NULL DEFAULT 'invoice',
  target_id     BIGINT UNSIGNED NOT NULL,
  amount        DECIMAL(12,2) NOT NULL,
  revoked_at    DATETIME NULL COMMENT '反核销时间，软删，不物理删',
  revoke_reason VARCHAR(200) NOT NULL DEFAULT '',
  created_by    BIGINT UNSIGNED NOT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_receipt (receipt_id),
  KEY idx_target (target_type, target_id)
) COMMENT='核销明细 —— 这张表是回款模块的核心，不能省';

CREATE TABLE IF NOT EXISTS crm_invoices (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code          VARCHAR(32) NOT NULL COMMENT 'FP-2026-0322',
  no            VARCHAR(40) NOT NULL DEFAULT '' COMMENT '税控发票号',
  customer_id   BIGINT UNSIGNED NOT NULL,
  contract_id   BIGINT UNSIGNED NULL,
  statement_id  BIGINT UNSIGNED NULL,
  amount        DECIMAL(12,2) NOT NULL COMMENT '价税合计',
  tax_rate      DECIMAL(5,4) NOT NULL DEFAULT 0.1300,
  tax_amount    DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT 'amount*rate/(1+rate)',
  type          ENUM('增值税专用','增值税普通') NOT NULL DEFAULT '增值税专用',
  apply_date    DATE NOT NULL,
  issue_date    DATE NULL,
  status        ENUM('待开票','已开票','已驳回','已红冲') NOT NULL DEFAULT '待开票',
  red_flush_of  BIGINT UNSIGNED NULL COMMENT '红冲指向的原票 id',
  red_flush_reason VARCHAR(200) NOT NULL DEFAULT '',
  created_by    BIGINT UNSIGNED NOT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  KEY idx_customer (customer_id, status),
  KEY idx_statement (statement_id)
) COMMENT='发票';


