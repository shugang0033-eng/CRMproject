USE crm;
ALTER TABLE crm_customers
  ADD COLUMN phone          VARCHAR(32)   NULL COMMENT '主电话号码',
  ADD COLUMN address        VARCHAR(255)  NULL COMMENT '注册/收货地址',
  ADD COLUMN region         VARCHAR(64)   NULL COMMENT '省 · 市，列表筛选用',
  ADD COLUMN status         VARCHAR(20)   NOT NULL DEFAULT '跟进中'
               COMMENT '合作中 / 跟进中 / 待回款 / 流失风险，由交易事实推导',
  ADD COLUMN status_at      DATETIME      NULL COMMENT '状态变更时间，用于「30 天无变化」预警',
  ADD COLUMN credit_limit   DECIMAL(14,2) NOT NULL DEFAULT 0 COMMENT '信用额度（元）',
  ADD COLUMN credit_used    DECIMAL(14,2) NOT NULL DEFAULT 0
               COMMENT '已用额度，只统计未结清合同，不许手工填',
  ADD COLUMN payment_term   SMALLINT      NOT NULL DEFAULT 0 COMMENT '账期天数，0 = 现款',
  ADD COLUMN source         VARCHAR(64)   NULL COMMENT '线索来源快照',
  ADD COLUMN note           VARCHAR(500)  NULL COMMENT '客户画像备注',
  ADD COLUMN last_follow_at DATETIME      NULL COMMENT '写跟进时同步更新，客户池回池判定依据',
  ADD COLUMN last_order_at  DATETIME      NULL COMMENT '最近下单时间',
  ADD COLUMN merged_into_id BIGINT UNSIGNED NULL COMMENT '合并后指向主档，非空即作废',
  ADD INDEX idx_cust_status (status),
  ADD INDEX idx_cust_last_follow (last_follow_at),
  ADD INDEX idx_cust_merged (merged_into_id);

ALTER TABLE crm_customer_contacts
  ADD COLUMN title           VARCHAR(64)  NULL COMMENT '职位',
  ADD COLUMN email           VARCHAR(128) NULL,
  ADD COLUMN role            VARCHAR(16)  NOT NULL DEFAULT 'user'
               COMMENT 'decision 决策人 / user 使用人 / payer 付款人',
  ADD COLUMN is_primary      TINYINT(1)   NOT NULL DEFAULT 0,
  ADD COLUMN last_contact_at DATETIME     NULL,
  ADD INDEX idx_contact_primary (customer_id, is_primary);

ALTER TABLE crm_customer_contacts
  ADD COLUMN primary_key BIGINT UNSIGNED
      GENERATED ALWAYS AS (IF(is_primary = 1, customer_id, NULL)) STORED,
  ADD UNIQUE KEY uk_contact_primary (primary_key);

CREATE TABLE IF NOT EXISTS crm_customer_follow_tasks (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  customer_id BIGINT UNSIGNED NOT NULL,
  owner_id    BIGINT UNSIGNED NOT NULL COMMENT '看板上按这个人分组',
  state       VARCHAR(16)     NOT NULL DEFAULT 'plan'
              COMMENT 'plan 计划 / due 今日到期 / overdue 超期 / done 已完成',
  due_date    DATE            NOT NULL COMMENT '约定跟进日',
  content     VARCHAR(500)    NULL COMMENT '这次要谈什么',
  source      VARCHAR(16)     NOT NULL DEFAULT 'manual'
              COMMENT 'manual 手工建 / followup 跟进时留的 next / contract 合同节点',
  done_at     DATETIME        NULL,
  done_by     BIGINT UNSIGNED NULL,
  created_by  BIGINT UNSIGNED NOT NULL,
  created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_task_owner_state (owner_id, state, due_date),
  KEY idx_task_customer (customer_id),
  CONSTRAINT fk_task_customer FOREIGN KEY (customer_id) REFERENCES crm_customers (id),
  CONSTRAINT fk_task_owner FOREIGN KEY (owner_id) REFERENCES crm_employees (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS crm_customer_attachments (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  customer_id BIGINT UNSIGNED NOT NULL,
  name        VARCHAR(200)    NOT NULL,
  type        VARCHAR(16)     NOT NULL COMMENT '资质 / 合同 / 财务',
  size_bytes  INT UNSIGNED    NOT NULL DEFAULT 0,
  url         VARCHAR(500)    NOT NULL COMMENT '对象存储地址，不要存二进制',
  uploaded_by BIGINT UNSIGNED NOT NULL,
  created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_att_customer (customer_id),
  CONSTRAINT fk_att_customer FOREIGN KEY (customer_id) REFERENCES crm_customers (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS crm_customer_merges (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  from_id         BIGINT UNSIGNED NOT NULL COMMENT '被作废的档案',
  to_id           BIGINT UNSIGNED NOT NULL COMMENT '主档',
  operator_id     BIGINT UNSIGNED NOT NULL,
  moved_contacts  INT NOT NULL DEFAULT 0,
  moved_followups INT NOT NULL DEFAULT 0,
  moved_contracts INT NOT NULL DEFAULT 0,
  note            VARCHAR(255) NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_merge_from (from_id),
  CONSTRAINT fk_merge_from FOREIGN KEY (from_id) REFERENCES crm_customers (id),
  CONSTRAINT fk_merge_to FOREIGN KEY (to_id) REFERENCES crm_customers (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE crm_customers MODIFY owner_id BIGINT UNSIGNED NULL,
 ADD pool_entered_at DATETIME NULL, ADD pool_reason VARCHAR(255) NULL;
ALTER TABLE crm_customer_transfers MODIFY owner_id BIGINT UNSIGNED NULL,
 MODIFY previous_owner_id BIGINT UNSIGNED NULL;
CREATE TABLE crm_customer_followups (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 customer_id BIGINT UNSIGNED NOT NULL,
 employee_id BIGINT UNSIGNED NOT NULL,
 type VARCHAR(32) NOT NULL,
 result VARCHAR(32) NOT NULL,
 content VARCHAR(500) NOT NULL,
 next_date DATE NULL,
 created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 INDEX (customer_id, created_at),
 FOREIGN KEY (customer_id) REFERENCES crm_customers(id),
 FOREIGN KEY (employee_id) REFERENCES crm_employees(id)
);
