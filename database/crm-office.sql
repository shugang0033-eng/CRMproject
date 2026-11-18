USE crm;
CREATE TABLE IF NOT EXISTS crm_expenses (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code           VARCHAR(32) NOT NULL COMMENT 'FY-2026-0612',
  applicant_id   BIGINT UNSIGNED NOT NULL,
  dept_id        BIGINT UNSIGNED NOT NULL COMMENT '承担部门，进部门成本',
  project_name   VARCHAR(120) NOT NULL DEFAULT '' COMMENT '关联客户/项目，自由文本',
  apply_date     DATE NOT NULL,
  total_amount   DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT '明细汇总缓存，事务内同步',
  bill_count     INT NOT NULL DEFAULT 0 COMMENT '票据张数，缺票要退单',
  trip_from      VARCHAR(60) NOT NULL DEFAULT '',
  trip_to        VARCHAR(60) NOT NULL DEFAULT '',
  trip_start     DATE NULL,
  trip_end       DATE NULL,
  trip_days      INT NOT NULL DEFAULT 0 COMMENT '自然日，不跳周末',
  deduct_loan_id BIGINT UNSIGNED NULL COMMENT '意向抵扣的借款，审批通过才落 writeoff',
  deduct_amount  DECIMAL(12,2) NOT NULL DEFAULT 0,
  remark         VARCHAR(500) NOT NULL DEFAULT '',
  status         ENUM('审批中','已通过','已驳回','已撤回') NOT NULL DEFAULT '审批中',
  approver_id    BIGINT UNSIGNED NULL,
  approved_at    DATETIME NULL,
  reject_reason  VARCHAR(200) NOT NULL DEFAULT '',
  request_id     VARCHAR(64) NULL COMMENT '幂等键',
  created_by     BIGINT UNSIGNED NOT NULL,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  UNIQUE KEY uk_request (request_id),
  KEY idx_applicant (applicant_id, apply_date),
  KEY idx_status (status, apply_date),
  KEY idx_dept (dept_id, apply_date)
) COMMENT='费用报销单';

CREATE TABLE IF NOT EXISTS crm_expense_items (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  expense_id   BIGINT UNSIGNED NOT NULL,
  occur_date   DATE NOT NULL COMMENT '发生日期，不是申请日期',
  type         ENUM('差旅','客户招待','市场活动','物流运费','样品费','办公用品','其他') NOT NULL,
  amount       DECIMAL(12,2) NOT NULL,
  note         VARCHAR(300) NOT NULL COMMENT '必填，审批人要据此判断该不该批',
  bills        INT NOT NULL DEFAULT 0 COMMENT '票据张数',
  sort_no      INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_expense (expense_id)
) COMMENT='报销明细，金额唯一事实来源';

CREATE TABLE IF NOT EXISTS crm_expense_attachments (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  expense_id  BIGINT UNSIGNED NOT NULL,
  file_id     VARCHAR(64) NOT NULL COMMENT '对象存储 fileId，不要存路径',
  file_name   VARCHAR(160) NOT NULL,
  file_size   INT UNSIGNED NOT NULL DEFAULT 0,
  mime_type   VARCHAR(60) NOT NULL DEFAULT '',
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_expense (expense_id)
) COMMENT='报销票据，一张单可多张';

CREATE TABLE IF NOT EXISTS crm_loans (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code         VARCHAR(32) NOT NULL COMMENT 'JK-2026-0034',
  applicant_id BIGINT UNSIGNED NOT NULL,
  dept_id      BIGINT UNSIGNED NOT NULL,
  type         ENUM('差旅预支','备用金','采购垫付') NOT NULL DEFAULT '差旅预支',
  amount       DECIMAL(12,2) NOT NULL,
  purpose      VARCHAR(300) NOT NULL COMMENT '必填，财务据此判断该不该借',
  apply_date   DATE NOT NULL,
  pay_date     DATE NULL COMMENT '实际打款日，未打款为 NULL',
  due_date     DATE NULL COMMENT '应清账日',
  status       ENUM('待审批','已通过','已驳回') NOT NULL DEFAULT '待审批',
  approver_id  BIGINT UNSIGNED NULL,
  approved_at  DATETIME NULL,
  reject_reason VARCHAR(200) NOT NULL DEFAULT '',
  request_id   VARCHAR(64) NULL,
  created_by   BIGINT UNSIGNED NOT NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  UNIQUE KEY uk_request (request_id),
  KEY idx_applicant (applicant_id, status),
  KEY idx_due (status, due_date)
) COMMENT='借款/预支单。金额是本金，余额靠 writeoffs 现算，不存字段';

CREATE TABLE IF NOT EXISTS crm_loan_writeoffs (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  loan_id    BIGINT UNSIGNED NOT NULL,
  source     ENUM('expense','cash') NOT NULL COMMENT 'expense=报销抵扣，cash=现金退回',
  expense_id BIGINT UNSIGNED NULL COMMENT 'source=expense 时必填，且唯一',
  amount     DECIMAL(12,2) NOT NULL,
  note       VARCHAR(200) NOT NULL DEFAULT '',
  created_by BIGINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  /* 同一张报销单对同一笔借款只能核销一次，防重复提交把余额冲成负数 */
  UNIQUE KEY uk_expense_loan (expense_id, loan_id),
  request_id VARCHAR(64) NULL,
  UNIQUE KEY uk_writeoff_request (loan_id,request_id),
  KEY idx_loan (loan_id)
) COMMENT='借款核销明细 —— 没有这张表，借款余额永远算不清';

CREATE TABLE IF NOT EXISTS crm_leaves (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code         VARCHAR(32) NOT NULL COMMENT 'QJ-2026-0092',
  applicant_id BIGINT UNSIGNED NOT NULL,
  dept_id      BIGINT UNSIGNED NOT NULL,
  type         ENUM('年假','病假','事假','调休') NOT NULL,
  start_date   DATE NOT NULL,
  end_date     DATE NOT NULL,
  days         DECIMAL(5,1) NOT NULL COMMENT '后端按工作日重算，半天用 .5',
  reason       VARCHAR(300) NOT NULL,
  handover_id  BIGINT UNSIGNED NULL COMMENT '工作交接人',
  apply_date   DATE NOT NULL,
  status       ENUM('待审批','已通过','已驳回','已撤销') NOT NULL DEFAULT '待审批',
  approver_id  BIGINT UNSIGNED NULL,
  approved_at  DATETIME NULL,
  reject_reason VARCHAR(200) NOT NULL DEFAULT '',
  request_id   VARCHAR(64) NULL,
  created_by   BIGINT UNSIGNED NOT NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  UNIQUE KEY uk_request (request_id),
  KEY idx_applicant (applicant_id, start_date),
  /* 同一个人同一时间段只能有一条有效请假，重叠提交直接拒 */
  KEY idx_range (applicant_id, start_date, end_date, status)
) COMMENT='请假单';

CREATE TABLE IF NOT EXISTS crm_leave_quotas (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  employee_id  BIGINT UNSIGNED NOT NULL,
  year         SMALLINT UNSIGNED NOT NULL,
  type         ENUM('年假','病假','调休') NOT NULL COMMENT '事假不设额度，不落这张表',
  quota_days   DECIMAL(5,1) NOT NULL DEFAULT 0,
  used_days    DECIMAL(5,1) NOT NULL DEFAULT 0 COMMENT '已通过的天数缓存，每日校一次',
  PRIMARY KEY (id),
  UNIQUE KEY uk_emp_year_type (employee_id, year, type)
) COMMENT='年度额度。额度按入职年限给，所以必须落到人，不能全局配置';

CREATE TABLE IF NOT EXISTS crm_approval_logs (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  kind        ENUM('费用报销','借款预支','请假申请','合同','订单') NOT NULL,
  doc_id      BIGINT UNSIGNED NOT NULL,
  action      ENUM('提交','同意','驳回','撤回','转交') NOT NULL,
  operator_id BIGINT UNSIGNED NOT NULL,
  note        VARCHAR(300) NOT NULL DEFAULT '',
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_doc (kind, doc_id, created_at)
) COMMENT='审批流水。只追加不修改，用来回答「谁在什么时候批的」';


