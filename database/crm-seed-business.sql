/* ============================================================================
   北辰装配 CRM · 全板块测试数据
   ----------------------------------------------------------------------------
   覆盖：客户档案 / 库存 / 联系人 / 跟进与待办 / 线索跟进 / 合同 / 订单 /
         发货 / 退货 / 对账单 / 发票 / 收款核销 / 报销 / 借款 / 请假 / 审批流水

   前置：已执行 database/crm-demo-seed.sql（客户、产品、线索、员工已存在）

   执行：mysql --default-character-set=utf8mb4 -uroot -p crm < database/crm-seed-business.sql

   幂等：全部按业务单号判重，可重复执行，行数不变。
        唯独 crm_product_inventory 是「覆盖式」写入（库存是时点值），
         重跑会把库存重置到初始量；发货扣减过的库存请勿重跑这一段。

   金额口径：
     - 单据汇总字段（orders.amount / statements.close_amount 等）都由明细汇总，
       与后端 OrderWriteService 的写入逻辑一致。
     - 对账单严格 open(上期 close) + shipped - received = close，逐张可验算。
============================================================================ */

SET NAMES utf8mb4;
USE crm;

START TRANSACTION;



/* ---------------- 1. 客户档案：授信、账期、地区、最近下单 ---------------- */

UPDATE crm_customers SET credit_limit=800000, payment_term=45,
  region='浙江杭州', source='官网询盘',
  last_order_at='2026-11-03 10:00:00',
  last_follow_at='2026-10-10 15:30:00'
WHERE id=4;

UPDATE crm_customers SET credit_limit=500000, payment_term=30,
  region='上海嘉定', source='汽配展',
  last_order_at='2026-10-16 10:00:00',
  last_follow_at='2026-10-17 15:30:00'
WHERE id=5;

UPDATE crm_customers SET credit_limit=300000, payment_term=30,
  region='江苏无锡', source='客户转介绍',
  last_order_at='2026-11-13 10:00:00',
  last_follow_at='2026-11-13 15:30:00'
WHERE id=6;

UPDATE crm_customers SET credit_limit=200000, payment_term=30,
  region='江苏苏州', source='1688 询盘',
  last_order_at='2026-10-24 10:00:00',
  last_follow_at='2026-11-09 15:30:00'
WHERE id=7;

UPDATE crm_customers SET credit_limit=1000000, payment_term=60,
  region='江苏南京', source='电话外呼',
  last_order_at='2026-10-14 10:00:00',
  last_follow_at='2026-10-15 15:30:00'
WHERE id=8;

UPDATE crm_customers SET credit_limit=120000, payment_term=15,
  region='江苏常州', source='官网询盘',
  last_order_at='2026-10-27 10:00:00',
  last_follow_at='2026-10-28 15:30:00'
WHERE id=9;

UPDATE crm_customers SET credit_limit=150000, payment_term=30,
  region='安徽合肥', source='汽配展',
  last_order_at='2026-10-20 10:00:00',
  last_follow_at='2026-11-03 15:30:00'
WHERE id=10;

UPDATE crm_customers SET credit_limit=100000, payment_term=15,
  region='浙江嘉兴', source='汽配城拜访',
  last_order_at='2026-11-12 10:00:00',
  last_follow_at='2026-11-12 15:30:00'
WHERE id=11;

UPDATE crm_customers SET credit_limit=80000, payment_term=15,
  region='浙江金华', source='客户转介绍',
  last_order_at='2026-11-10 10:00:00',
  last_follow_at='2026-11-10 15:30:00'
WHERE id=12;

UPDATE crm_customers SET credit_limit=250000, payment_term=30,
  region='浙江宁波', source='电话外呼',
  last_order_at='2026-11-06 10:00:00',
  last_follow_at='2026-10-09 15:30:00'
WHERE id=13;


/* ---------------- 2. 成品库存（按最小单位计） ---------------- */

INSERT INTO crm_product_inventory(product_id,available) VALUES(4,1500) ON DUPLICATE KEY UPDATE available=VALUES(available);

INSERT INTO crm_product_inventory(product_id,available) VALUES(5,48500) ON DUPLICATE KEY UPDATE available=VALUES(available);

INSERT INTO crm_product_inventory(product_id,available) VALUES(6,7400) ON DUPLICATE KEY UPDATE available=VALUES(available);

INSERT INTO crm_product_inventory(product_id,available) VALUES(7,8700) ON DUPLICATE KEY UPDATE available=VALUES(available);

INSERT INTO crm_product_inventory(product_id,available) VALUES(8,2600) ON DUPLICATE KEY UPDATE available=VALUES(available);

INSERT INTO crm_product_inventory(product_id,available) VALUES(9,3300) ON DUPLICATE KEY UPDATE available=VALUES(available);

INSERT INTO crm_product_inventory(product_id,available) VALUES(10,2600) ON DUPLICATE KEY UPDATE available=VALUES(available);

INSERT INTO crm_product_inventory(product_id,available) VALUES(11,2900) ON DUPLICATE KEY UPDATE available=VALUES(available);

INSERT INTO crm_product_inventory(product_id,available) VALUES(12,3200) ON DUPLICATE KEY UPDATE available=VALUES(available);

INSERT INTO crm_product_inventory(product_id,available) VALUES(13,2400) ON DUPLICATE KEY UPDATE available=VALUES(available);

INSERT INTO crm_product_inventory(product_id,available) VALUES(14,30300) ON DUPLICATE KEY UPDATE available=VALUES(available);

INSERT INTO crm_product_inventory(product_id,available) VALUES(3,800) ON DUPLICATE KEY UPDATE available=VALUES(available);


/* ---------------- 3. 客户联系人（每家补 2 人） ---------------- */

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 4,'周书宁','137****4412','运营总监','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=4 AND name='周书宁');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 4,'邵岩','135****8890','仓储主管','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=4 AND name='邵岩');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 5,'卢明','139****2210','配件经理','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=5 AND name='卢明');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 5,'汤倩','188****3374','财务主管','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=5 AND name='汤倩');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 6,'钱伟','136****7728','车队队长','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=6 AND name='钱伟');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 6,'孙琳','150****6613','采购专员','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=6 AND name='孙琳');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 7,'吴海','138****9930','总经理','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=7 AND name='吴海');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 7,'蒋芸','189****4408','采购主管','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=7 AND name='蒋芸');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 8,'罗建军','186****1129','采购主管','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=8 AND name='罗建军');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 8,'曾莉','133****7782','质量工程师','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=8 AND name='曾莉');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 9,'范磊','137****5561','店长','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=9 AND name='范磊');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 9,'邱敏','158****3302','仓管','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=9 AND name='邱敏');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 10,'万辉','139****8827','总经理','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=10 AND name='万辉');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 10,'柯云','151****2245','采购经理','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=10 AND name='柯云');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 11,'石磊','135****6673','老板','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=11 AND name='石磊');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 11,'虞婷','187****9904','会计','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=11 AND name='虞婷');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 12,'包志强','138****1193','采购经理','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=12 AND name='包志强');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 12,'江珊','159****5520','运营','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=12 AND name='江珊');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 13,'薛涛','136****4438','厂长','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=13 AND name='薛涛');

INSERT INTO crm_customer_contacts(customer_id,name,phone,title,role,is_primary)
SELECT 13,'阮玲','137****7726','采购','user',0 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_contacts WHERE customer_id=13 AND name='阮玲');


/* ---------------- 4. 客户跟进记录 ---------------- */

INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date,created_at)
SELECT 4,14,'电话','推进','确认 8 月补货计划，毛巾按 40 箱备','2026-08-12','2026-08-06 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_followups WHERE customer_id=4 AND created_at='2026-08-06 15:30:00');

INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date,created_at)
SELECT 4,14,'客户拜访','推进','到杭州总部复盘 8 月动销，反馈毛巾复购快，追加 9 月集采','2026-09-15','2026-09-04 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_followups WHERE customer_id=4 AND created_at='2026-09-04 15:30:00');

INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date,created_at)
SELECT 4,14,'微信','待回款','提醒 9 月对账单已出，财务确认月底付款','2026-10-16','2026-10-10 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_followups WHERE customer_id=4 AND created_at='2026-10-10 15:30:00');

INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date,created_at)
SELECT 5,8,'电话','推进','安驰临时补货，毛巾 20 箱、轮毂刷 5 箱，当天报价','2026-09-14','2026-09-09 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_followups WHERE customer_id=5 AND created_at='2026-09-09 15:30:00');

INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date,created_at)
SELECT 5,8,'客户拜访','待回款','谈四季度精品套餐，顺便催 9 月货款','2026-10-31','2026-10-17 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_followups WHERE customer_id=5 AND created_at='2026-10-17 15:30:00');

INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date,created_at)
SELECT 6,14,'电话','推进','运通季度末补货 80 箱海绵，走月结','2026-09-28','2026-09-23 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_followups WHERE customer_id=6 AND created_at='2026-09-23 15:30:00');

INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date,created_at)
SELECT 6,14,'线上会议','推进','沟通 11 月补货，车队新增 20 台车','2026-11-22','2026-11-13 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_followups WHERE customer_id=6 AND created_at='2026-11-13 15:30:00');

INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date,created_at)
SELECT 7,13,'客户拜访','暂缓','上新款试销不动销，客户要求整单退回','2026-11-08','2026-10-25 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_followups WHERE customer_id=7 AND created_at='2026-10-25 15:30:00');

INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date,created_at)
SELECT 7,13,'微信','待反馈','推荐常规款替代，等客户确认是否重下','2026-11-18','2026-11-09 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_followups WHERE customer_id=7 AND created_at='2026-11-09 15:30:00');

INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date,created_at)
SELECT 8,13,'线上会议','推进','依维柯 8 月计划确认，PVA 巾 30 箱、洗车液 20 箱','2026-08-20','2026-08-13 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_followups WHERE customer_id=8 AND created_at='2026-08-13 15:30:00');

INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date,created_at)
SELECT 8,13,'电话','待回款','10 月计划先发一半，剩余等排产；同时催 9 月货款','2026-10-29','2026-10-15 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_followups WHERE customer_id=8 AND created_at='2026-10-15 15:30:00');

INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date,created_at)
SELECT 9,8,'电话','推进','瑞虎补货细节刷 5 箱、海绵 20 箱','2026-10-31','2026-10-28 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_followups WHERE customer_id=9 AND created_at='2026-10-28 15:30:00');

INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date,created_at)
SELECT 10,10,'客户拜访','推进','皖通首批试销，要求 30 天账期，先按备货走','2026-10-27','2026-10-21 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_followups WHERE customer_id=10 AND created_at='2026-10-21 15:30:00');

INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date,created_at)
SELECT 10,10,'线上会议','推进','谈年度框架，折扣与账期还在磨','2026-11-12','2026-11-03 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_followups WHERE customer_id=10 AND created_at='2026-11-03 15:30:00');

INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date,created_at)
SELECT 11,14,'电话','待反馈','南方汽修压价到成本线以下，需要上级审批','2026-11-20','2026-11-12 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_followups WHERE customer_id=11 AND created_at='2026-11-12 15:30:00');

INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date,created_at)
SELECT 12,13,'微信','待反馈','众诚首次下单超出授信，等风控确认是否放行','2026-11-18','2026-11-10 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_followups WHERE customer_id=12 AND created_at='2026-11-10 15:30:00');

INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date,created_at)
SELECT 13,10,'客户拜访','推进','甬安 9 月订单，鹿皮巾 8 箱、细节刷 10 箱','2026-09-24','2026-09-16 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_followups WHERE customer_id=13 AND created_at='2026-09-16 15:30:00');

INSERT INTO crm_customer_followups(customer_id,employee_id,type,result,content,next_date,created_at)
SELECT 13,10,'电话','待回款','鹿皮巾运输受潮退 1 箱，已安排退款；11 月计划提前到 6 号','2026-10-12','2026-10-09 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_followups WHERE customer_id=13 AND created_at='2026-10-09 15:30:00');


/* ---------------- 5. 客户待办（工作台「今日要跟进」取这里） ---------------- */

INSERT INTO crm_customer_follow_tasks(customer_id,owner_id,state,due_date,content,source,created_by)
SELECT 4,14,'plan','2026-11-18','跟进驰远 10 月 6.1 万应收，账期已过 45 天上限','manual',14 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_follow_tasks WHERE customer_id=4 AND due_date='2026-11-18' AND content='跟进驰远 10 月 6.1 万应收，账期已过 45 天上限');

INSERT INTO crm_customer_follow_tasks(customer_id,owner_id,state,due_date,content,source,created_by)
SELECT 4,14,'plan','2026-11-21','带 11 月新样品到杭州总部做动销复盘','manual',14 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_follow_tasks WHERE customer_id=4 AND due_date='2026-11-21' AND content='带 11 月新样品到杭州总部做动销复盘');

INSERT INTO crm_customer_follow_tasks(customer_id,owner_id,state,due_date,content,source,created_by)
SELECT 5,8,'plan','2026-11-17','催安驰四季度精品合同审批，已挂 3 天','manual',8 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_follow_tasks WHERE customer_id=5 AND due_date='2026-11-17' AND content='催安驰四季度精品合同审批，已挂 3 天');

INSERT INTO crm_customer_follow_tasks(customer_id,owner_id,state,due_date,content,source,created_by)
SELECT 6,14,'plan','2026-11-20','运通 11 月补货 10 箱洗车液，确认排产日期','manual',14 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_follow_tasks WHERE customer_id=6 AND due_date='2026-11-20' AND content='运通 11 月补货 10 箱洗车液，确认排产日期');

INSERT INTO crm_customer_follow_tasks(customer_id,owner_id,state,due_date,content,source,created_by)
SELECT 7,13,'plan','2026-11-19','车之翼退货已入库，确认替代款报价','manual',13 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_follow_tasks WHERE customer_id=7 AND due_date='2026-11-19' AND content='车之翼退货已入库，确认替代款报价');

INSERT INTO crm_customer_follow_tasks(customer_id,owner_id,state,due_date,content,source,created_by)
SELECT 8,13,'plan','2026-11-16','依维柯 10 月剩余一半未发，跟生产确认 11 月排产','manual',13 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_follow_tasks WHERE customer_id=8 AND due_date='2026-11-16' AND content='依维柯 10 月剩余一半未发，跟生产确认 11 月排产');

INSERT INTO crm_customer_follow_tasks(customer_id,owner_id,state,due_date,content,source,created_by)
SELECT 9,8,'plan','2026-11-20','瑞虎月度补货回访，问细节刷动销','manual',8 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_follow_tasks WHERE customer_id=9 AND due_date='2026-11-20' AND content='瑞虎月度补货回访，问细节刷动销');

INSERT INTO crm_customer_follow_tasks(customer_id,owner_id,state,due_date,content,source,created_by)
SELECT 10,10,'plan','2026-11-17','皖通年度框架待审批，跟进客户对折扣的最终意见','manual',10 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_follow_tasks WHERE customer_id=10 AND due_date='2026-11-17' AND content='皖通年度框架待审批，跟进客户对折扣的最终意见');

INSERT INTO crm_customer_follow_tasks(customer_id,owner_id,state,due_date,content,source,created_by)
SELECT 11,14,'plan','2026-11-16','南方汽修低价单等审批，先别承诺交期','manual',14 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_follow_tasks WHERE customer_id=11 AND due_date='2026-11-16' AND content='南方汽修低价单等审批，先别承诺交期');

INSERT INTO crm_customer_follow_tasks(customer_id,owner_id,state,due_date,content,source,created_by)
SELECT 12,13,'plan','2026-11-18','众诚超授信，向风控申请 8 万临时额度','manual',13 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_follow_tasks WHERE customer_id=12 AND due_date='2026-11-18' AND content='众诚超授信，向风控申请 8 万临时额度');

INSERT INTO crm_customer_follow_tasks(customer_id,owner_id,state,due_date,content,source,created_by)
SELECT 13,10,'plan','2026-11-19','甬安 11 月首批已发，剩余 13 箱等客户确认收货时间','manual',10 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_follow_tasks WHERE customer_id=13 AND due_date='2026-11-19' AND content='甬安 11 月首批已发，剩余 13 箱等客户确认收货时间');


-- 已办结的历史待办

INSERT INTO crm_customer_follow_tasks(customer_id,owner_id,state,due_date,content,source,done_at,done_by,created_by)
SELECT 4,14,'done','2026-08-12','寄 8 月新品样品到驰远总部','manual','2026-08-12 18:00:00',14,14 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_follow_tasks WHERE customer_id=4 AND due_date='2026-08-12' AND content='寄 8 月新品样品到驰远总部');

INSERT INTO crm_customer_follow_tasks(customer_id,owner_id,state,due_date,content,source,done_at,done_by,created_by)
SELECT 8,13,'done','2026-10-22','确认依维柯 10 月发货批次','manual','2026-10-22 18:00:00',13,13 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_follow_tasks WHERE customer_id=8 AND due_date='2026-10-22' AND content='确认依维柯 10 月发货批次');

INSERT INTO crm_customer_follow_tasks(customer_id,owner_id,state,due_date,content,source,done_at,done_by,created_by)
SELECT 5,8,'done','2026-09-14','安驰补货报价单盖章回传','manual','2026-09-14 18:00:00',8,8 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_follow_tasks WHERE customer_id=5 AND due_date='2026-09-14' AND content='安驰补货报价单盖章回传');

INSERT INTO crm_customer_follow_tasks(customer_id,owner_id,state,due_date,content,source,done_at,done_by,created_by)
SELECT 13,10,'done','2026-09-24','甬安订单发货并回填运单号','manual','2026-09-24 18:00:00',10,10 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_customer_follow_tasks WHERE customer_id=13 AND due_date='2026-09-24' AND content='甬安订单发货并回填运单号');


/* ---------------- 6. 线索跟进流水（27 条线索各补一条） ---------------- */

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 1,14,'2026-09-19 电话 · 官网询盘当天回访，确认是连锁汽修，主推毛巾与洗车液',1,'2026-09-19 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=1 AND created_at='2026-09-19 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 2,8,'2026-10-10 客户拜访 · 汽配展现场加微信，约到门店看陈列',1,'2026-10-10 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=2 AND created_at='2026-10-10 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 3,14,'2026-09-03 电话 · 转介绍客户，车队 120 台车，用量稳定',1,'2026-09-03 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=3 AND created_at='2026-09-03 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 4,13,'2026-10-01 微信 · 1688 询盘，要 50 箱毛巾试单',1,'2026-10-01 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=4 AND created_at='2026-10-01 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 5,13,'2026-09-13 线上会议 · 主机厂配套走招标流程，先送样检测',1,'2026-09-13 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=5 AND created_at='2026-09-13 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 6,8,'2026-10-16 电话 · 官网询盘，维修中心 3 家店',1,'2026-10-16 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=6 AND created_at='2026-10-16 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 7,10,'2026-08-21 客户拜访 · 汽配展认识，做汽配贸易，渠道广',1,'2026-08-21 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=7 AND created_at='2026-08-21 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 8,14,'2026-10-09 客户拜访 · 汽配城跑店碰到，老板对 PVA 巾感兴趣',1,'2026-10-09 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=8 AND created_at='2026-10-09 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 9,13,'2026-10-21 微信 · 转介绍，连锁 5 家门店，集中采购',1,'2026-10-21 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=9 AND created_at='2026-10-21 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 10,10,'2026-10-29 电话 · 外呼接通，甬安汽修 2 家厂，先小批量试',1,'2026-10-29 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=10 AND created_at='2026-10-29 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 11,14,'2026-11-05 电话 · 台州汽配商行，问年框政策，先寄样',0,'2026-11-05 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=11 AND created_at='2026-11-05 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 12,11,'2026-11-05 微信 · 汽配展名片，东莞养护中心，待加微信',0,'2026-11-05 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=12 AND created_at='2026-11-05 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 13,11,'2026-11-04 电话 · 转介绍，做汽修设备，可搭售耗材',0,'2026-11-04 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=13 AND created_at='2026-11-04 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 14,11,'2026-11-03 电话 · 汽配城商户，只做现金单，暂不跟进',0,'2026-11-03 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=14 AND created_at='2026-11-03 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 15,11,'2026-11-02 微信 · 官网询盘，快修店 2 家，报价已发',0,'2026-11-02 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=15 AND created_at='2026-11-02 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 16,11,'2026-11-01 电话 · 济南连锁，量级够，但要 60 天账期',0,'2026-11-01 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=16 AND created_at='2026-11-01 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 24,11,'2026-11-11 电话 · 官网询盘当天回访，A 类，做汽车美容',0,'2026-11-11 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=24 AND created_at='2026-11-11 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 25,11,'2026-11-11 微信 · 1688 询盘，连锁 8 家店，要样品册',0,'2026-11-11 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=25 AND created_at='2026-11-11 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 26,13,'2026-11-10 客户拜访 · 转介绍，会所定位高端，主推鹿皮巾',0,'2026-11-10 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=26 AND created_at='2026-11-10 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 27,8,'2026-11-10 微信 · 汽配展加的，问洗车液价格',0,'2026-11-10 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=27 AND created_at='2026-11-10 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 28,14,'2026-11-09 客户拜访 · 汽配城跑店，已联系上采购',1,'2026-11-09 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=28 AND created_at='2026-11-09 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 29,10,'2026-11-08 电话 · 外呼接通，合肥车管家 4 家店',1,'2026-11-08 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=29 AND created_at='2026-11-08 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 30,13,'2026-11-07 线上会议 · 官网询盘，已报价，等回复',1,'2026-11-07 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=30 AND created_at='2026-11-07 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 31,14,'2026-11-06 客户拜访 · 汽配展认识，正在谈年框，价格卡在 9 折',1,'2026-11-06 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=31 AND created_at='2026-11-06 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 32,8,'2026-11-05 微信 · 1688 询盘，谈判中，要 30 天账期',1,'2026-11-05 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=32 AND created_at='2026-11-05 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 33,10,'2026-11-04 电话 · 空号，标记无效',0,'2026-11-04 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=33 AND created_at='2026-11-04 11:20:00');

INSERT INTO crm_lead_followups(lead_id,employee_id,content,is_effective,created_at)
SELECT 34,14,'2026-11-03 电话 · 只要 5 箱，起订量不够，标记无效',0,'2026-11-03 11:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_lead_followups WHERE lead_id=34 AND created_at='2026-11-03 11:20:00');


/* ---------------- 7. 合同与协议价 ---------------- */

INSERT INTO crm_contracts(code,name,customer_id,type,amount,discount,term_days,payment_term,
  sign_date,start_date,end_date,owner_id,status,remark,created_by,created_at)
SELECT 'HT-2026-0101','驰远连锁 2026 年度汽车耗材供货框架',4,'年框',1235168.00,0.88,45,'月结 45 天',
  '2026-01-05','2026-01-01','2026-12-31',14,'执行中','协议覆盖 6 个单品，按季度对账',14,'2026-01-05 09:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contracts WHERE code='HT-2026-0101');

INSERT INTO crm_contracts(code,name,customer_id,type,amount,discount,term_days,payment_term,
  sign_date,start_date,end_date,owner_id,status,remark,created_by,created_at)
SELECT 'HT-2026-0102','依维柯售后配件年度框架协议',8,'年框',497094.40,0.92,60,'月结 60 天',
  '2026-01-12','2026-01-01','2026-12-31',13,'执行中','协议覆盖 3 个单品，按季度对账',13,'2026-01-12 09:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contracts WHERE code='HT-2026-0102');

INSERT INTO crm_contracts(code,name,customer_id,type,amount,discount,term_days,payment_term,
  sign_date,start_date,end_date,owner_id,status,remark,created_by,created_at)
SELECT 'HT-2026-0103','安驰 4S 店四季度精品供货合同',5,'季度',186500.00,1.0,30,'月结 30 天',
  '2026-09-28','2026-10-01','2026-12-31',8,'待审批','协议覆盖 3 个单品，按季度对账',8,'2026-09-28 09:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contracts WHERE code='HT-2026-0103');

INSERT INTO crm_contracts(code,name,customer_id,type,amount,discount,term_days,payment_term,
  sign_date,start_date,end_date,owner_id,status,remark,created_by,created_at)
SELECT 'HT-2026-0104','甬安汽修 2026 年度洗护耗材年框',13,'年框',378432.00,0.96,30,'月结 30 天',
  '2026-02-18','2026-03-01','2027-02-28',10,'执行中','协议覆盖 4 个单品，按季度对账',10,'2026-02-18 09:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contracts WHERE code='HT-2026-0104');

INSERT INTO crm_contracts(code,name,customer_id,type,amount,discount,term_days,payment_term,
  sign_date,start_date,end_date,owner_id,status,remark,created_by,created_at)
SELECT 'HT-2026-0105','运通车队三季度清洁用品集中采购',6,'季度',98160.00,1.0,30,'月结 30 天',
  '2026-07-06','2026-07-01','2026-09-30',14,'执行中','协议覆盖 2 个单品，按季度对账',14,'2026-07-06 09:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contracts WHERE code='HT-2026-0105');

INSERT INTO crm_contracts(code,name,customer_id,type,amount,discount,term_days,payment_term,
  sign_date,start_date,end_date,owner_id,status,remark,created_by,created_at)
SELECT 'HT-2026-0106','车之翼秋季上新首批采购',7,'单次',40800.00,1.0,30,'月结 30 天',
  '2026-08-14','2026-08-15','2026-10-31',13,'已完成','协议覆盖 2 个单品，按季度对账',13,'2026-08-14 09:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contracts WHERE code='HT-2026-0106');

INSERT INTO crm_contracts(code,name,customer_id,type,amount,discount,term_days,payment_term,
  sign_date,start_date,end_date,owner_id,status,remark,created_by,created_at)
SELECT 'HT-2026-0107','瑞虎维修中心四季度备货协议',9,'季度',43800.00,1.0,15,'月结 15 天',
  '2026-09-20','2026-10-01','2026-12-31',8,'已作废','协议覆盖 2 个单品，按季度对账',8,'2026-09-20 09:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contracts WHERE code='HT-2026-0107');

INSERT INTO crm_contracts(code,name,customer_id,type,amount,discount,term_days,payment_term,
  sign_date,start_date,end_date,owner_id,status,remark,created_by,created_at)
SELECT 'HT-2026-0108','皖通汽配 2026 年度经销框架',10,'年框',271920.00,1.0,30,'月结 30 天',
  '2026-11-02','2026-11-01','2027-10-31',10,'待审批','协议覆盖 3 个单品，按季度对账',10,'2026-11-02 09:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contracts WHERE code='HT-2026-0108');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0101'),5,'箱',900,563.20 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0101') AND product_id=5 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0101'),6,'箱',300,862.40 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0101') AND product_id=6 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0101'),7,'箱',200,668.80 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0101') AND product_id=7 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0101'),9,'箱',400,295.68 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0101') AND product_id=9 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0101'),10,'箱',200,401.28 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0101') AND product_id=10 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0101'),14,'箱',600,228.80 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0101') AND product_id=14 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0102'),7,'箱',500,699.20 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0102') AND product_id=7 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0102'),9,'箱',260,309.12 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0102') AND product_id=9 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0102'),10,'箱',160,419.52 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0102') AND product_id=10 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0103'),5,'箱',160,640.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0103') AND product_id=5 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0103'),11,'箱',40,540.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0103') AND product_id=11 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0103'),8,'箱',50,1250.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0103') AND product_id=8 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0104'),8,'箱',120,1200.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0104') AND product_id=8 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0104'),13,'箱',90,403.20 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0104') AND product_id=13 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0104'),5,'箱',200,614.40 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0104') AND product_id=5 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0104'),6,'箱',80,940.80 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0104') AND product_id=6 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0105'),14,'箱',300,260.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0105') AND product_id=14 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0105'),9,'箱',60,336.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0105') AND product_id=9 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0106'),11,'箱',40,540.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0106') AND product_id=11 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0106'),12,'箱',40,480.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0106') AND product_id=12 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0107'),13,'箱',30,420.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0107') AND product_id=13 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0107'),14,'箱',120,260.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0107') AND product_id=14 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0108'),5,'箱',240,640.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0108') AND product_id=5 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0108'),14,'箱',300,260.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0108') AND product_id=14 AND unit='箱');

INSERT INTO crm_contract_items(contract_id,product_id,unit,qty,price)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0108'),9,'箱',120,336.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_items WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0108') AND product_id=9 AND unit='箱');

INSERT INTO crm_contract_approvals(contract_id,action,operator_id,note,created_at)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0101'),'提交',14,'发起年框审批，覆盖洗护与擦拭两大类','2026-01-05 09:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_approvals WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0101') AND action='提交' AND created_at='2026-01-05 09:20:00');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '合同',(SELECT id FROM crm_contracts WHERE code='HT-2026-0101'),'提交',14,'发起年框审批，覆盖洗护与擦拭两大类','2026-01-05 09:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='合同' AND doc_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0101') AND action='提交' AND created_at='2026-01-05 09:20:00');

INSERT INTO crm_contract_approvals(contract_id,action,operator_id,note,created_at)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0101'),'审核',13,'价格与去年持平，同意','2026-01-05 15:40:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_approvals WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0101') AND action='审核' AND created_at='2026-01-05 15:40:00');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '合同',(SELECT id FROM crm_contracts WHERE code='HT-2026-0101'),'同意',13,'价格与去年持平，同意','2026-01-05 15:40:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='合同' AND doc_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0101') AND action='同意' AND created_at='2026-01-05 15:40:00');

INSERT INTO crm_contract_approvals(contract_id,action,operator_id,note,created_at)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0101'),'批准',11,'批准执行，按季度考核发货额','2026-01-06 10:05:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_approvals WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0101') AND action='批准' AND created_at='2026-01-06 10:05:00');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '合同',(SELECT id FROM crm_contracts WHERE code='HT-2026-0101'),'同意',11,'批准执行，按季度考核发货额','2026-01-06 10:05:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='合同' AND doc_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0101') AND action='同意' AND created_at='2026-01-06 10:05:00');

INSERT INTO crm_contract_approvals(contract_id,action,operator_id,note,created_at)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0102'),'提交',13,'主机厂配套年框，账期争取到 60 天','2026-01-12 10:12:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_approvals WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0102') AND action='提交' AND created_at='2026-01-12 10:12:00');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '合同',(SELECT id FROM crm_contracts WHERE code='HT-2026-0102'),'提交',13,'主机厂配套年框，账期争取到 60 天','2026-01-12 10:12:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='合同' AND doc_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0102') AND action='提交' AND created_at='2026-01-12 10:12:00');

INSERT INTO crm_contract_approvals(contract_id,action,operator_id,note,created_at)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0102'),'批准',11,'批准，注意回款节点','2026-01-13 09:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_approvals WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0102') AND action='批准' AND created_at='2026-01-13 09:30:00');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '合同',(SELECT id FROM crm_contracts WHERE code='HT-2026-0102'),'同意',11,'批准，注意回款节点','2026-01-13 09:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='合同' AND doc_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0102') AND action='同意' AND created_at='2026-01-13 09:30:00');

INSERT INTO crm_contract_approvals(contract_id,action,operator_id,note,created_at)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0103'),'提交',8,'四季度精品套餐，含毛巾与鹿皮巾','2026-09-28 16:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_approvals WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0103') AND action='提交' AND created_at='2026-09-28 16:20:00');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '合同',(SELECT id FROM crm_contracts WHERE code='HT-2026-0103'),'提交',8,'四季度精品套餐，含毛巾与鹿皮巾','2026-09-28 16:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='合同' AND doc_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0103') AND action='提交' AND created_at='2026-09-28 16:20:00');

INSERT INTO crm_contract_approvals(contract_id,action,operator_id,note,created_at)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0104'),'提交',10,'甬安年框续签，折扣从 95 折放宽到 96 折','2026-02-18 11:05:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_approvals WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0104') AND action='提交' AND created_at='2026-02-18 11:05:00');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '合同',(SELECT id FROM crm_contracts WHERE code='HT-2026-0104'),'提交',10,'甬安年框续签，折扣从 95 折放宽到 96 折','2026-02-18 11:05:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='合同' AND doc_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0104') AND action='提交' AND created_at='2026-02-18 11:05:00');

INSERT INTO crm_contract_approvals(contract_id,action,operator_id,note,created_at)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0104'),'批准',11,'批准，年度目标 30 万','2026-02-19 14:22:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_approvals WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0104') AND action='批准' AND created_at='2026-02-19 14:22:00');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '合同',(SELECT id FROM crm_contracts WHERE code='HT-2026-0104'),'同意',11,'批准，年度目标 30 万','2026-02-19 14:22:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='合同' AND doc_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0104') AND action='同意' AND created_at='2026-02-19 14:22:00');

INSERT INTO crm_contract_approvals(contract_id,action,operator_id,note,created_at)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0105'),'提交',14,'车队季度集采，海绵用量大','2026-07-06 09:40:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_approvals WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0105') AND action='提交' AND created_at='2026-07-06 09:40:00');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '合同',(SELECT id FROM crm_contracts WHERE code='HT-2026-0105'),'提交',14,'车队季度集采，海绵用量大','2026-07-06 09:40:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='合同' AND doc_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0105') AND action='提交' AND created_at='2026-07-06 09:40:00');

INSERT INTO crm_contract_approvals(contract_id,action,operator_id,note,created_at)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0105'),'批准',11,'批准','2026-07-07 10:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_approvals WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0105') AND action='批准' AND created_at='2026-07-07 10:10:00');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '合同',(SELECT id FROM crm_contracts WHERE code='HT-2026-0105'),'同意',11,'批准','2026-07-07 10:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='合同' AND doc_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0105') AND action='同意' AND created_at='2026-07-07 10:10:00');

INSERT INTO crm_contract_approvals(contract_id,action,operator_id,note,created_at)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0106'),'提交',13,'上新首批，试销两个月','2026-08-14 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_approvals WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0106') AND action='提交' AND created_at='2026-08-14 15:30:00');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '合同',(SELECT id FROM crm_contracts WHERE code='HT-2026-0106'),'提交',13,'上新首批，试销两个月','2026-08-14 15:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='合同' AND doc_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0106') AND action='提交' AND created_at='2026-08-14 15:30:00');

INSERT INTO crm_contract_approvals(contract_id,action,operator_id,note,created_at)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0106'),'批准',11,'批准，试销不动销可退','2026-08-15 09:05:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_approvals WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0106') AND action='批准' AND created_at='2026-08-15 09:05:00');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '合同',(SELECT id FROM crm_contracts WHERE code='HT-2026-0106'),'同意',11,'批准，试销不动销可退','2026-08-15 09:05:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='合同' AND doc_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0106') AND action='同意' AND created_at='2026-08-15 09:05:00');

INSERT INTO crm_contract_approvals(contract_id,action,operator_id,note,created_at)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0107'),'提交',8,'四季度备货','2026-09-20 14:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_approvals WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0107') AND action='提交' AND created_at='2026-09-20 14:00:00');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '合同',(SELECT id FROM crm_contracts WHERE code='HT-2026-0107'),'提交',8,'四季度备货','2026-09-20 14:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='合同' AND doc_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0107') AND action='提交' AND created_at='2026-09-20 14:00:00');

INSERT INTO crm_contract_approvals(contract_id,action,operator_id,note,created_at)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0107'),'作废',8,'客户改走单次采购，合同作废','2026-09-24 10:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_approvals WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0107') AND action='作废' AND created_at='2026-09-24 10:30:00');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '合同',(SELECT id FROM crm_contracts WHERE code='HT-2026-0107'),'撤回',8,'客户改走单次采购，合同作废','2026-09-24 10:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='合同' AND doc_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0107') AND action='撤回' AND created_at='2026-09-24 10:30:00');

INSERT INTO crm_contract_approvals(contract_id,action,operator_id,note,created_at)
SELECT (SELECT id FROM crm_contracts WHERE code='HT-2026-0108'),'提交',10,'皖通首年框，要求 30 天账期','2026-11-02 16:45:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_contract_approvals WHERE contract_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0108') AND action='提交' AND created_at='2026-11-02 16:45:00');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '合同',(SELECT id FROM crm_contracts WHERE code='HT-2026-0108'),'提交',10,'皖通首年框，要求 30 天账期','2026-11-02 16:45:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='合同' AND doc_id=(SELECT id FROM crm_contracts WHERE code='HT-2026-0108') AND action='提交' AND created_at='2026-11-02 16:45:00');


/* ---------------- 8. 订单与明细（含已发/已退数量缓存） ---------------- */

INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
  credit_check,amount,remark,created_by,created_at)
SELECT 'SO-2026-0801',4,(SELECT id FROM crm_contracts WHERE code='HT-2026-0101'),'合同订单','2026-08-05','2026-08-12',14,
  '已签收','通过',32876.80,'驰远 8 月补货',14,'2026-08-05 10:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_orders WHERE code='SO-2026-0801');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-0801'),5,'箱',40,563.20,'合同协议价',420.00,22528.00,40,0,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0801') AND product_id=5 AND unit='箱');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-0801'),6,'箱',12,862.40,'合同协议价',645.00,10348.80,12,0,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0801') AND product_id=6 AND unit='箱');

INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
  credit_check,amount,remark,created_by,created_at)
SELECT 'SO-2026-0802',8,(SELECT id FROM crm_contracts WHERE code='HT-2026-0102'),'合同订单','2026-08-12','2026-08-20',13,
  '已签收','通过',27158.40,'依维柯 8 月计划',13,'2026-08-12 10:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_orders WHERE code='SO-2026-0802');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-0802'),7,'箱',30,699.20,'合同协议价',510.00,20976.00,30,0,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0802') AND product_id=7 AND unit='箱');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-0802'),9,'箱',20,309.12,'合同协议价',204.00,6182.40,20,0,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0802') AND product_id=9 AND unit='箱');

INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
  credit_check,amount,remark,created_by,created_at)
SELECT 'SO-2026-0901',4,(SELECT id FROM crm_contracts WHERE code='HT-2026-0101'),'合同订单','2026-09-03','2026-09-15',14,
  '已签收','通过',38811.52,'驰远 9 月集采',14,'2026-09-03 10:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_orders WHERE code='SO-2026-0901');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-0901'),9,'箱',60,295.68,'合同协议价',204.00,17740.80,60,0,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0901') AND product_id=9 AND unit='箱');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-0901'),10,'箱',24,401.28,'合同协议价',288.00,9630.72,24,0,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0901') AND product_id=10 AND unit='箱');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-0901'),14,'箱',50,228.80,'合同协议价',158.00,11440.00,50,0,3 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0901') AND product_id=14 AND unit='箱');

INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
  credit_check,amount,remark,created_by,created_at)
SELECT 'SO-2026-0902',5,NULL,'备货订单','2026-09-08','2026-09-14',8,
  '已签收','通过',13600.00,'安驰临时补货',8,'2026-09-08 10:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_orders WHERE code='SO-2026-0902');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-0902'),5,'箱',20,560.00,'经销价',420.00,11200.00,20,0,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0902') AND product_id=5 AND unit='箱');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-0902'),11,'箱',5,480.00,'经销价',336.00,2400.00,5,0,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0902') AND product_id=11 AND unit='箱');

INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
  credit_check,amount,remark,created_by,created_at)
SELECT 'SO-2026-0903',13,(SELECT id FROM crm_contracts WHERE code='HT-2026-0104'),'合同订单','2026-09-15','2026-09-22',10,
  '已签收','通过',13632.00,'甬安 9 月订单',10,'2026-09-15 10:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_orders WHERE code='SO-2026-0903');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-0903'),8,'箱',8,1200.00,'合同协议价',880.00,9600.00,8,1,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0903') AND product_id=8 AND unit='箱');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-0903'),13,'箱',10,403.20,'合同协议价',258.00,4032.00,10,0,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0903') AND product_id=13 AND unit='箱');

INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
  credit_check,amount,remark,created_by,created_at)
SELECT 'SO-2026-0904',6,(SELECT id FROM crm_contracts WHERE code='HT-2026-0105'),'合同订单','2026-09-22','2026-09-28',14,
  '已签收','通过',20800.00,'运通车队季度末补货',14,'2026-09-22 10:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_orders WHERE code='SO-2026-0904');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-0904'),14,'箱',80,260.00,'合同协议价',158.00,20800.00,80,0,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0904') AND product_id=14 AND unit='箱');

INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
  credit_check,amount,remark,created_by,created_at)
SELECT 'SO-2026-1001',4,(SELECT id FROM crm_contracts WHERE code='HT-2026-0101'),'合同订单','2026-10-09','2026-10-18',14,
  '已签收','通过',61072.00,'驰远 10 月集采',14,'2026-10-09 10:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_orders WHERE code='SO-2026-1001');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1001'),5,'箱',60,563.20,'合同协议价',420.00,33792.00,60,0,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1001') AND product_id=5 AND unit='箱');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1001'),6,'箱',20,862.40,'合同协议价',645.00,17248.00,20,0,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1001') AND product_id=6 AND unit='箱');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1001'),7,'箱',15,668.80,'合同协议价',510.00,10032.00,15,0,3 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1001') AND product_id=7 AND unit='箱');

INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
  credit_check,amount,remark,created_by,created_at)
SELECT 'SO-2026-1002',8,(SELECT id FROM crm_contracts WHERE code='HT-2026-0102'),'合同订单','2026-10-14','2026-10-22',13,
  '部分发货','通过',14307.84,'依维柯 10 月计划，先发一半',13,'2026-10-14 10:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_orders WHERE code='SO-2026-1002');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1002'),9,'箱',30,309.12,'合同协议价',204.00,9273.60,15,0,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1002') AND product_id=9 AND unit='箱');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1002'),10,'箱',12,419.52,'合同协议价',288.00,5034.24,6,0,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1002') AND product_id=10 AND unit='箱');

INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
  credit_check,amount,remark,created_by,created_at)
SELECT 'SO-2026-1003',5,NULL,'备货订单','2026-10-16','2026-10-24',8,
  '已签收','通过',10160.00,'安驰深度养护套装',8,'2026-10-16 10:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_orders WHERE code='SO-2026-1003');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1003'),8,'箱',6,1120.00,'经销价',880.00,6720.00,6,0,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1003') AND product_id=8 AND unit='箱');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1003'),12,'箱',8,430.00,'经销价',300.00,3440.00,8,2,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1003') AND product_id=12 AND unit='箱');

INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
  credit_check,amount,remark,created_by,created_at)
SELECT 'SO-2026-1004',10,NULL,'备货订单','2026-10-20','2026-10-27',10,
  '已签收','通过',15300.00,'皖通首批试销',10,'2026-10-20 10:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_orders WHERE code='SO-2026-1004');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1004'),5,'箱',15,560.00,'经销价',420.00,8400.00,15,0,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1004') AND product_id=5 AND unit='箱');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1004'),14,'箱',30,230.00,'经销价',158.00,6900.00,30,0,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1004') AND product_id=14 AND unit='箱');

INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
  credit_check,amount,remark,created_by,created_at)
SELECT 'SO-2026-1005',7,NULL,'备货订单','2026-10-24','2026-10-31',13,
  '已退货','通过',9100.00,'车之翼上新款试销，客户反馈不对路',13,'2026-10-24 10:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_orders WHERE code='SO-2026-1005');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1005'),11,'箱',10,480.00,'经销价',336.00,4800.00,10,10,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1005') AND product_id=11 AND unit='箱');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1005'),12,'箱',10,430.00,'经销价',300.00,4300.00,10,10,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1005') AND product_id=12 AND unit='箱');

INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
  credit_check,amount,remark,created_by,created_at)
SELECT 'SO-2026-1006',9,NULL,'备货订单','2026-10-27','2026-10-31',8,
  '已签收','通过',6500.00,'瑞虎月度补货',8,'2026-10-27 10:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_orders WHERE code='SO-2026-1006');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1006'),13,'箱',5,380.00,'经销价',258.00,1900.00,5,0,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1006') AND product_id=13 AND unit='箱');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1006'),14,'箱',20,230.00,'经销价',158.00,4600.00,20,0,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1006') AND product_id=14 AND unit='箱');

INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
  credit_check,amount,remark,created_by,created_at)
SELECT 'SO-2026-1007',5,NULL,'备货订单','2026-10-05','2026-10-12',8,
  '已取消','通过',9200.00,'客户改从本地供应商拿货',8,'2026-10-05 10:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_orders WHERE code='SO-2026-1007');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1007'),14,'箱',40,230.00,'经销价',158.00,9200.00,0,0,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1007') AND product_id=14 AND unit='箱');

INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
  credit_check,amount,remark,created_by,created_at)
SELECT 'SO-2026-1101',4,(SELECT id FROM crm_contracts WHERE code='HT-2026-0101'),'合同订单','2026-11-03','2026-11-12',14,
  '待发货','通过',19852.80,'驰远 11 月集采，等排产',14,'2026-11-03 10:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_orders WHERE code='SO-2026-1101');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1101'),9,'箱',40,295.68,'合同协议价',204.00,11827.20,0,0,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1101') AND product_id=9 AND unit='箱');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1101'),10,'箱',20,401.28,'合同协议价',288.00,8025.60,0,0,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1101') AND product_id=10 AND unit='箱');

INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
  credit_check,amount,remark,created_by,created_at)
SELECT 'SO-2026-1102',13,(SELECT id FROM crm_contracts WHERE code='HT-2026-0104'),'合同订单','2026-11-06','2026-11-16',10,
  '部分发货','通过',24768.00,'甬安 11 月订单，首批已发',10,'2026-11-06 10:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_orders WHERE code='SO-2026-1102');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1102'),5,'箱',25,614.40,'合同协议价',420.00,15360.00,12,0,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1102') AND product_id=5 AND unit='箱');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1102'),6,'箱',10,940.80,'合同协议价',645.00,9408.00,5,0,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1102') AND product_id=6 AND unit='箱');

INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
  credit_check,amount,remark,created_by,created_at)
SELECT 'SO-2026-1103',12,NULL,'备货订单','2026-11-10','2026-11-18',13,
  '待审批','超限',10040.00,'众诚首次下单，超出授信额度',13,'2026-11-10 10:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_orders WHERE code='SO-2026-1103');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1103'),7,'箱',8,680.00,'经销价',510.00,5440.00,0,0,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1103') AND product_id=7 AND unit='箱');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1103'),14,'箱',20,230.00,'经销价',158.00,4600.00,0,0,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1103') AND product_id=14 AND unit='箱');

INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
  credit_check,amount,remark,created_by,created_at)
SELECT 'SO-2026-1104',11,NULL,'备货订单','2026-11-12','2026-11-20',14,
  '待审批','待审批',1920.00,'南方汽修压价，低于成本价需上级审批',14,'2026-11-12 10:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_orders WHERE code='SO-2026-1104');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1104'),11,'箱',6,320.00,'手工价',336.00,1920.00,0,0,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1104') AND product_id=11 AND unit='箱');

INSERT INTO crm_orders(code,customer_id,contract_id,type,order_date,expect_date,owner_id,status,
  credit_check,amount,remark,created_by,created_at)
SELECT 'SO-2026-1105',6,NULL,'备货订单','2026-11-13','2026-11-22',14,
  '待发货','通过',3000.00,'运通 11 月补货',14,'2026-11-13 10:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_orders WHERE code='SO-2026-1105');

INSERT INTO crm_order_items(order_id,product_id,unit,qty,price,price_source,floor_price,amount,shipped_qty,returned_qty,sort_no)
SELECT (SELECT id FROM crm_orders WHERE code='SO-2026-1105'),9,'箱',10,300.00,'经销价',204.00,3000.00,0,0,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1105') AND product_id=9 AND unit='箱');


/* ---------------- 9. 发货单与明细 ---------------- */

INSERT INTO crm_shipments(code,order_id,ship_date,logistics,tracking_no,status,signed_at,amount,boxes,created_by,created_at)
SELECT 'FH-2026-0801',(SELECT id FROM crm_orders WHERE code='SO-2026-0801'),'2026-08-08','德邦物流','DB8820145',
  '已签收','2026-08-12 14:00:00',32876.80,52,14,'2026-08-08 09:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipments WHERE code='FH-2026-0801');

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-0801'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0801') AND product_id=5 AND unit='箱'),
  5,'箱',40 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-0801') AND product_id=5);

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-0801'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0801') AND product_id=6 AND unit='箱'),
  6,'箱',12 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-0801') AND product_id=6);

INSERT INTO crm_shipments(code,order_id,ship_date,logistics,tracking_no,status,signed_at,amount,boxes,created_by,created_at)
SELECT 'FH-2026-0802',(SELECT id FROM crm_orders WHERE code='SO-2026-0802'),'2026-08-15','顺丰快运','SF3390142',
  '已签收','2026-08-20 14:00:00',27158.40,50,13,'2026-08-15 09:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipments WHERE code='FH-2026-0802');

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-0802'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0802') AND product_id=7 AND unit='箱'),
  7,'箱',30 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-0802') AND product_id=7);

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-0802'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0802') AND product_id=9 AND unit='箱'),
  9,'箱',20 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-0802') AND product_id=9);

INSERT INTO crm_shipments(code,order_id,ship_date,logistics,tracking_no,status,signed_at,amount,boxes,created_by,created_at)
SELECT 'FH-2026-0901',(SELECT id FROM crm_orders WHERE code='SO-2026-0901'),'2026-09-05','德邦物流','DB8830011',
  '已签收','2026-09-18 14:00:00',13685.76,42,14,'2026-09-05 09:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipments WHERE code='FH-2026-0901');

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-0901'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0901') AND product_id=9 AND unit='箱'),
  9,'箱',30 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-0901') AND product_id=9);

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-0901'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0901') AND product_id=10 AND unit='箱'),
  10,'箱',12 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-0901') AND product_id=10);

INSERT INTO crm_shipments(code,order_id,ship_date,logistics,tracking_no,status,signed_at,amount,boxes,created_by,created_at)
SELECT 'FH-2026-0902',(SELECT id FROM crm_orders WHERE code='SO-2026-0901'),'2026-09-12','德邦物流','DB8830072',
  '已签收','2026-09-18 14:00:00',25125.76,92,14,'2026-09-12 09:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipments WHERE code='FH-2026-0902');

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-0902'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0901') AND product_id=9 AND unit='箱'),
  9,'箱',30 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-0902') AND product_id=9);

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-0902'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0901') AND product_id=10 AND unit='箱'),
  10,'箱',12 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-0902') AND product_id=10);

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-0902'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0901') AND product_id=14 AND unit='箱'),
  14,'箱',50 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-0902') AND product_id=14);

INSERT INTO crm_shipments(code,order_id,ship_date,logistics,tracking_no,status,signed_at,amount,boxes,created_by,created_at)
SELECT 'FH-2026-0903',(SELECT id FROM crm_orders WHERE code='SO-2026-0902'),'2026-09-10','中通快运','ZT7712003',
  '已签收','2026-09-14 14:00:00',13600.00,25,8,'2026-09-10 09:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipments WHERE code='FH-2026-0903');

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-0903'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0902') AND product_id=5 AND unit='箱'),
  5,'箱',20 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-0903') AND product_id=5);

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-0903'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0902') AND product_id=11 AND unit='箱'),
  11,'箱',5 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-0903') AND product_id=11);

INSERT INTO crm_shipments(code,order_id,ship_date,logistics,tracking_no,status,signed_at,amount,boxes,created_by,created_at)
SELECT 'FH-2026-0904',(SELECT id FROM crm_orders WHERE code='SO-2026-0903'),'2026-09-18','顺丰快运','SF3401887',
  '已签收','2026-09-24 14:00:00',13632.00,18,10,'2026-09-18 09:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipments WHERE code='FH-2026-0904');

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-0904'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0903') AND product_id=8 AND unit='箱'),
  8,'箱',8 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-0904') AND product_id=8);

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-0904'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0903') AND product_id=13 AND unit='箱'),
  13,'箱',10 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-0904') AND product_id=13);

INSERT INTO crm_shipments(code,order_id,ship_date,logistics,tracking_no,status,signed_at,amount,boxes,created_by,created_at)
SELECT 'FH-2026-0905',(SELECT id FROM crm_orders WHERE code='SO-2026-0904'),'2026-09-25','安能物流','AN5521004',
  '已签收','2026-09-28 14:00:00',20800.00,80,14,'2026-09-25 09:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipments WHERE code='FH-2026-0905');

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-0905'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0904') AND product_id=14 AND unit='箱'),
  14,'箱',80 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-0905') AND product_id=14);

INSERT INTO crm_shipments(code,order_id,ship_date,logistics,tracking_no,status,signed_at,amount,boxes,created_by,created_at)
SELECT 'FH-2026-1001',(SELECT id FROM crm_orders WHERE code='SO-2026-1001'),'2026-10-12','德邦物流','DB8841220',
  '已签收','2026-10-22 14:00:00',25520.00,40,14,'2026-10-12 09:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipments WHERE code='FH-2026-1001');

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-1001'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1001') AND product_id=5 AND unit='箱'),
  5,'箱',30 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-1001') AND product_id=5);

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-1001'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1001') AND product_id=6 AND unit='箱'),
  6,'箱',10 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-1001') AND product_id=6);

INSERT INTO crm_shipments(code,order_id,ship_date,logistics,tracking_no,status,signed_at,amount,boxes,created_by,created_at)
SELECT 'FH-2026-1002',(SELECT id FROM crm_orders WHERE code='SO-2026-1001'),'2026-10-18','德邦物流','DB8841355',
  '已签收','2026-10-22 14:00:00',35552.00,55,14,'2026-10-18 09:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipments WHERE code='FH-2026-1002');

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-1002'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1001') AND product_id=5 AND unit='箱'),
  5,'箱',30 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-1002') AND product_id=5);

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-1002'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1001') AND product_id=6 AND unit='箱'),
  6,'箱',10 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-1002') AND product_id=6);

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-1002'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1001') AND product_id=7 AND unit='箱'),
  7,'箱',15 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-1002') AND product_id=7);

INSERT INTO crm_shipments(code,order_id,ship_date,logistics,tracking_no,status,signed_at,amount,boxes,created_by,created_at)
SELECT 'FH-2026-1003',(SELECT id FROM crm_orders WHERE code='SO-2026-1002'),'2026-10-16','顺丰快运','SF3412033',
  '运输中',NULL,7153.92,21,13,'2026-10-16 09:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipments WHERE code='FH-2026-1003');

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-1003'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1002') AND product_id=9 AND unit='箱'),
  9,'箱',15 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-1003') AND product_id=9);

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-1003'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1002') AND product_id=10 AND unit='箱'),
  10,'箱',6 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-1003') AND product_id=10);

INSERT INTO crm_shipments(code,order_id,ship_date,logistics,tracking_no,status,signed_at,amount,boxes,created_by,created_at)
SELECT 'FH-2026-1004',(SELECT id FROM crm_orders WHERE code='SO-2026-1003'),'2026-10-18','中通快运','ZT7724110',
  '已签收','2026-10-25 14:00:00',10160.00,14,8,'2026-10-18 09:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipments WHERE code='FH-2026-1004');

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-1004'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1003') AND product_id=8 AND unit='箱'),
  8,'箱',6 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-1004') AND product_id=8);

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-1004'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1003') AND product_id=12 AND unit='箱'),
  12,'箱',8 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-1004') AND product_id=12);

INSERT INTO crm_shipments(code,order_id,ship_date,logistics,tracking_no,status,signed_at,amount,boxes,created_by,created_at)
SELECT 'FH-2026-1005',(SELECT id FROM crm_orders WHERE code='SO-2026-1004'),'2026-10-22','安能物流','AN5531220',
  '已签收','2026-10-28 14:00:00',15300.00,45,10,'2026-10-22 09:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipments WHERE code='FH-2026-1005');

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-1005'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1004') AND product_id=5 AND unit='箱'),
  5,'箱',15 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-1005') AND product_id=5);

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-1005'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1004') AND product_id=14 AND unit='箱'),
  14,'箱',30 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-1005') AND product_id=14);

INSERT INTO crm_shipments(code,order_id,ship_date,logistics,tracking_no,status,signed_at,amount,boxes,created_by,created_at)
SELECT 'FH-2026-1006',(SELECT id FROM crm_orders WHERE code='SO-2026-1005'),'2026-10-26','德邦物流','DB8850113',
  '已签收','2026-11-02 14:00:00',9100.00,20,13,'2026-10-26 09:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipments WHERE code='FH-2026-1006');

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-1006'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1005') AND product_id=11 AND unit='箱'),
  11,'箱',10 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-1006') AND product_id=11);

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-1006'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1005') AND product_id=12 AND unit='箱'),
  12,'箱',10 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-1006') AND product_id=12);

INSERT INTO crm_shipments(code,order_id,ship_date,logistics,tracking_no,status,signed_at,amount,boxes,created_by,created_at)
SELECT 'FH-2026-1007',(SELECT id FROM crm_orders WHERE code='SO-2026-1006'),'2026-10-29','中通快运','ZT7730155',
  '已签收','2026-11-04 14:00:00',6500.00,25,8,'2026-10-29 09:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipments WHERE code='FH-2026-1007');

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-1007'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1006') AND product_id=13 AND unit='箱'),
  13,'箱',5 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-1007') AND product_id=13);

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-1007'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1006') AND product_id=14 AND unit='箱'),
  14,'箱',20 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-1007') AND product_id=14);

INSERT INTO crm_shipments(code,order_id,ship_date,logistics,tracking_no,status,signed_at,amount,boxes,created_by,created_at)
SELECT 'FH-2026-1101',(SELECT id FROM crm_orders WHERE code='SO-2026-1102'),'2026-11-08','顺丰快运','SF3420081',
  '运输中',NULL,12076.80,17,10,'2026-11-08 09:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipments WHERE code='FH-2026-1101');

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-1101'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1102') AND product_id=5 AND unit='箱'),
  5,'箱',12 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-1101') AND product_id=5);

INSERT INTO crm_shipment_items(shipment_id,order_item_id,product_id,unit,qty)
SELECT (SELECT id FROM crm_shipments WHERE code='FH-2026-1101'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1102') AND product_id=6 AND unit='箱'),
  6,'箱',5 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_shipment_items WHERE shipment_id=(SELECT id FROM crm_shipments WHERE code='FH-2026-1101') AND product_id=6);


/* ---------------- 10. 退货单与明细 ---------------- */

INSERT INTO crm_returns(code,order_id,customer_id,return_date,reason,status,amount,note,created_by,created_at,confirmed_at)
SELECT 'RT-2026-0001',(SELECT id FROM crm_orders WHERE code='SO-2026-1003'),5,'2026-10-27','质量问题','已入库',
  860.00,'轮胎刷毛束脱落，客户要求整批退回',8,'2026-10-27 10:00:00','2026-10-30 16:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_returns WHERE code='RT-2026-0001');

INSERT INTO crm_return_items(return_id,order_item_id,product_id,unit,qty,price,amount)
SELECT (SELECT id FROM crm_returns WHERE code='RT-2026-0001'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1003') AND product_id=12 AND unit='箱'),
  12,'箱',2,430.00,860.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_return_items WHERE return_id=(SELECT id FROM crm_returns WHERE code='RT-2026-0001') AND product_id=12);

INSERT INTO crm_returns(code,order_id,customer_id,return_date,reason,status,amount,note,created_by,created_at,confirmed_at)
SELECT 'RT-2026-0002',(SELECT id FROM crm_orders WHERE code='SO-2026-0903'),13,'2026-10-06','运输破损','已退款',
  1200.00,'鹿皮巾外箱受潮，退 1 箱',10,'2026-10-06 10:00:00','2026-10-08 16:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_returns WHERE code='RT-2026-0002');

INSERT INTO crm_return_items(return_id,order_item_id,product_id,unit,qty,price,amount)
SELECT (SELECT id FROM crm_returns WHERE code='RT-2026-0002'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-0903') AND product_id=8 AND unit='箱'),
  8,'箱',1,1200.00,1200.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_return_items WHERE return_id=(SELECT id FROM crm_returns WHERE code='RT-2026-0002') AND product_id=8);

INSERT INTO crm_returns(code,order_id,customer_id,return_date,reason,status,amount,note,created_by,created_at,confirmed_at)
SELECT 'RT-2026-0003',(SELECT id FROM crm_orders WHERE code='SO-2026-1005'),7,'2026-11-05','客户取消','已入库',
  9100.00,'上新款试销不动销，整单退回',13,'2026-11-05 10:00:00','2026-11-08 16:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_returns WHERE code='RT-2026-0003');

INSERT INTO crm_return_items(return_id,order_item_id,product_id,unit,qty,price,amount)
SELECT (SELECT id FROM crm_returns WHERE code='RT-2026-0003'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1005') AND product_id=11 AND unit='箱'),
  11,'箱',10,480.00,4800.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_return_items WHERE return_id=(SELECT id FROM crm_returns WHERE code='RT-2026-0003') AND product_id=11);

INSERT INTO crm_return_items(return_id,order_item_id,product_id,unit,qty,price,amount)
SELECT (SELECT id FROM crm_returns WHERE code='RT-2026-0003'),
  (SELECT id FROM crm_order_items WHERE order_id=(SELECT id FROM crm_orders WHERE code='SO-2026-1005') AND product_id=12 AND unit='箱'),
  12,'箱',10,430.00,4300.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_return_items WHERE return_id=(SELECT id FROM crm_returns WHERE code='RT-2026-0003') AND product_id=12);


/* ---------------- 11. 月度对账单（close = open + shipped - received） ---------------- */

INSERT INTO crm_statements(code,customer_id,period,start_date,end_date,open_amount,shipped_amount,
  received_amount,close_amount,order_count,status,confirmed_at,created_by,created_at)
SELECT 'DZ-2026-08-004',4,'2026-08','2026-08-01','2026-08-31',
  0.00,32876.80,0.00,32876.80,1,
  '已开票','2026-08-28 17:30:00',14,'2026-08-28 10:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statements WHERE code='DZ-2026-08-004');

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-08-004'),'shipment',(SELECT id FROM crm_orders WHERE code='SO-2026-0801'),'FH-2026-0801','2026-08-12',32876.80 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-08-004') AND kind='shipment' AND code='FH-2026-0801');

INSERT INTO crm_statements(code,customer_id,period,start_date,end_date,open_amount,shipped_amount,
  received_amount,close_amount,order_count,status,confirmed_at,created_by,created_at)
SELECT 'DZ-2026-09-004',4,'2026-09','2026-09-01','2026-09-30',
  32876.80,38811.52,32876.80,38811.52,1,
  '已开票','2026-09-28 17:30:00',14,'2026-09-28 10:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statements WHERE code='DZ-2026-09-004');

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-09-004'),'shipment',(SELECT id FROM crm_orders WHERE code='SO-2026-0901'),'FH-2026-0901','2026-09-18',13685.76 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-09-004') AND kind='shipment' AND code='FH-2026-0901');

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-09-004'),'shipment',(SELECT id FROM crm_orders WHERE code='SO-2026-0901'),'FH-2026-0902','2026-09-18',25125.76 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-09-004') AND kind='shipment' AND code='FH-2026-0902');

INSERT INTO crm_statements(code,customer_id,period,start_date,end_date,open_amount,shipped_amount,
  received_amount,close_amount,order_count,status,confirmed_at,created_by,created_at)
SELECT 'DZ-2026-10-004',4,'2026-10','2026-10-01','2026-10-31',
  38811.52,61072.00,38811.52,61072.00,1,
  '已确认','2026-10-28 17:30:00',14,'2026-10-28 10:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statements WHERE code='DZ-2026-10-004');

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-10-004'),'shipment',(SELECT id FROM crm_orders WHERE code='SO-2026-1001'),'FH-2026-1001','2026-10-22',25520.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-10-004') AND kind='shipment' AND code='FH-2026-1001');

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-10-004'),'shipment',(SELECT id FROM crm_orders WHERE code='SO-2026-1001'),'FH-2026-1002','2026-10-22',35552.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-10-004') AND kind='shipment' AND code='FH-2026-1002');

INSERT INTO crm_statements(code,customer_id,period,start_date,end_date,open_amount,shipped_amount,
  received_amount,close_amount,order_count,status,confirmed_at,created_by,created_at)
SELECT 'DZ-2026-09-005',5,'2026-09','2026-09-01','2026-09-30',
  0.00,13600.00,0.00,13600.00,1,
  '已开票','2026-09-28 17:30:00',8,'2026-09-28 10:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statements WHERE code='DZ-2026-09-005');

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-09-005'),'shipment',(SELECT id FROM crm_orders WHERE code='SO-2026-0902'),'FH-2026-0903','2026-09-14',13600.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-09-005') AND kind='shipment' AND code='FH-2026-0903');

INSERT INTO crm_statements(code,customer_id,period,start_date,end_date,open_amount,shipped_amount,
  received_amount,close_amount,order_count,status,confirmed_at,created_by,created_at)
SELECT 'DZ-2026-10-005',5,'2026-10','2026-10-01','2026-10-31',
  13600.00,9300.00,13600.00,9300.00,1,
  '已确认','2026-10-28 17:30:00',8,'2026-10-28 10:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statements WHERE code='DZ-2026-10-005');

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-10-005'),'shipment',(SELECT id FROM crm_orders WHERE code='SO-2026-1003'),'FH-2026-1004','2026-10-25',10160.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-10-005') AND kind='shipment' AND code='FH-2026-1004');

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-10-005'),'return',(SELECT id FROM crm_orders WHERE code='SO-2026-1003'),'RT-2026-0001','2026-10-30',-860.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-10-005') AND kind='return' AND code='RT-2026-0001');

INSERT INTO crm_statements(code,customer_id,period,start_date,end_date,open_amount,shipped_amount,
  received_amount,close_amount,order_count,status,confirmed_at,created_by,created_at)
SELECT 'DZ-2026-09-006',6,'2026-09','2026-09-01','2026-09-30',
  0.00,20800.00,0.00,20800.00,1,
  '已开票','2026-09-28 17:30:00',14,'2026-09-28 10:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statements WHERE code='DZ-2026-09-006');

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-09-006'),'shipment',(SELECT id FROM crm_orders WHERE code='SO-2026-0904'),'FH-2026-0905','2026-09-28',20800.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-09-006') AND kind='shipment' AND code='FH-2026-0905');

INSERT INTO crm_statements(code,customer_id,period,start_date,end_date,open_amount,shipped_amount,
  received_amount,close_amount,order_count,status,confirmed_at,created_by,created_at)
SELECT 'DZ-2026-10-006',6,'2026-10','2026-10-01','2026-10-31',
  20800.00,0.00,20800.00,0.00,0,
  '已回款','2026-10-28 17:30:00',14,'2026-10-28 10:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statements WHERE code='DZ-2026-10-006');

INSERT INTO crm_statements(code,customer_id,period,start_date,end_date,open_amount,shipped_amount,
  received_amount,close_amount,order_count,status,confirmed_at,created_by,created_at)
SELECT 'DZ-2026-08-008',8,'2026-08','2026-08-01','2026-08-31',
  0.00,27158.40,0.00,27158.40,1,
  '已开票','2026-08-28 17:30:00',13,'2026-08-28 10:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statements WHERE code='DZ-2026-08-008');

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-08-008'),'shipment',(SELECT id FROM crm_orders WHERE code='SO-2026-0802'),'FH-2026-0802','2026-08-20',27158.40 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-08-008') AND kind='shipment' AND code='FH-2026-0802');

INSERT INTO crm_statements(code,customer_id,period,start_date,end_date,open_amount,shipped_amount,
  received_amount,close_amount,order_count,status,confirmed_at,created_by,created_at)
SELECT 'DZ-2026-09-008',8,'2026-09','2026-09-01','2026-09-30',
  27158.40,0.00,27158.40,0.00,0,
  '已回款','2026-09-28 17:30:00',13,'2026-09-28 10:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statements WHERE code='DZ-2026-09-008');

INSERT INTO crm_statements(code,customer_id,period,start_date,end_date,open_amount,shipped_amount,
  received_amount,close_amount,order_count,status,confirmed_at,created_by,created_at)
SELECT 'DZ-2026-10-010',10,'2026-10','2026-10-01','2026-10-31',
  0.00,15300.00,0.00,15300.00,1,
  '待确认',NULL,10,'2026-10-28 10:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statements WHERE code='DZ-2026-10-010');

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-10-010'),'shipment',(SELECT id FROM crm_orders WHERE code='SO-2026-1004'),'FH-2026-1005','2026-10-28',15300.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-10-010') AND kind='shipment' AND code='FH-2026-1005');

INSERT INTO crm_statements(code,customer_id,period,start_date,end_date,open_amount,shipped_amount,
  received_amount,close_amount,order_count,status,confirmed_at,created_by,created_at)
SELECT 'DZ-2026-09-013',13,'2026-09','2026-09-01','2026-09-30',
  0.00,13632.00,0.00,13632.00,1,
  '已开票','2026-09-28 17:30:00',10,'2026-09-28 10:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statements WHERE code='DZ-2026-09-013');

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-09-013'),'shipment',(SELECT id FROM crm_orders WHERE code='SO-2026-0903'),'FH-2026-0904','2026-09-24',13632.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-09-013') AND kind='shipment' AND code='FH-2026-0904');

INSERT INTO crm_statements(code,customer_id,period,start_date,end_date,open_amount,shipped_amount,
  received_amount,close_amount,order_count,status,confirmed_at,created_by,created_at)
SELECT 'DZ-2026-10-013',13,'2026-10','2026-10-01','2026-10-31',
  13632.00,-1200.00,12432.00,0.00,0,
  '已回款','2026-10-28 17:30:00',10,'2026-10-28 10:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statements WHERE code='DZ-2026-10-013');

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-10-013'),'return',(SELECT id FROM crm_orders WHERE code='SO-2026-0903'),'RT-2026-0002','2026-10-08',-1200.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-10-013') AND kind='return' AND code='RT-2026-0002');


/* ---------------- 12. 收款单（客户按账期付上一期账单） ---------------- */

INSERT INTO crm_receipts(code,customer_id,amount,pay_date,method,bank,remark,created_by,created_at)
SELECT 'SK-2026-2211',4,32876.80,'2026-09-22','银行转账','招商银行杭州分行',
  '杭州驰远汽车服务连锁 货款',19,'2026-09-22 16:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_receipts WHERE code='SK-2026-2211');

INSERT INTO crm_receipts(code,customer_id,amount,pay_date,method,bank,remark,created_by,created_at)
SELECT 'SK-2026-2212',4,38811.52,'2026-10-16','银行转账','招商银行杭州分行',
  '杭州驰远汽车服务连锁 货款',19,'2026-10-16 16:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_receipts WHERE code='SK-2026-2212');

INSERT INTO crm_receipts(code,customer_id,amount,pay_date,method,bank,remark,created_by,created_at)
SELECT 'SK-2026-2213',4,30000.00,'2026-11-06','银行转账','招商银行杭州分行',
  '杭州驰远汽车服务连锁 货款',19,'2026-11-06 16:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_receipts WHERE code='SK-2026-2213');

INSERT INTO crm_receipts(code,customer_id,amount,pay_date,method,bank,remark,created_by,created_at)
SELECT 'SK-2026-2214',5,13600.00,'2026-10-31','银行转账','建设银行嘉定支行',
  '上海嘉定安驰 4S 店 货款',19,'2026-10-31 16:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_receipts WHERE code='SK-2026-2214');

INSERT INTO crm_receipts(code,customer_id,amount,pay_date,method,bank,remark,created_by,created_at)
SELECT 'SK-2026-2215',5,9300.00,'2026-11-10','银行转账','建设银行嘉定支行',
  '上海嘉定安驰 4S 店 货款',19,'2026-11-10 16:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_receipts WHERE code='SK-2026-2215');

INSERT INTO crm_receipts(code,customer_id,amount,pay_date,method,bank,remark,created_by,created_at)
SELECT 'SK-2026-2216',6,20800.00,'2026-10-28','对公转账','中国银行无锡分行',
  '无锡运通物流车队 货款',19,'2026-10-28 16:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_receipts WHERE code='SK-2026-2216');

INSERT INTO crm_receipts(code,customer_id,amount,pay_date,method,bank,remark,created_by,created_at)
SELECT 'SK-2026-2217',8,27158.40,'2026-09-26','银行承兑','工商银行南京分行',
  '南京依维柯配件部 货款',19,'2026-09-26 16:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_receipts WHERE code='SK-2026-2217');

INSERT INTO crm_receipts(code,customer_id,amount,pay_date,method,bank,remark,created_by,created_at)
SELECT 'SK-2026-2218',10,15300.00,'2026-11-10','银行转账','徽商银行合肥分行',
  '合肥皖通汽配贸易 货款',19,'2026-11-10 16:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_receipts WHERE code='SK-2026-2218');

INSERT INTO crm_receipts(code,customer_id,amount,pay_date,method,bank,remark,created_by,created_at)
SELECT 'SK-2026-2219',13,12432.00,'2026-10-12','银行转账','宁波银行海曙支行',
  '宁波甬安汽修厂 货款',19,'2026-10-12 16:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_receipts WHERE code='SK-2026-2219');


-- 有回款的对账单补一条「收款」流水，让「本期回款」在明细里看得见

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-09-004'),'receipt',NULL,'SK-2026-2211','2026-09-22',32876.80 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-09-004') AND kind='receipt' AND code='SK-2026-2211');

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-10-004'),'receipt',NULL,'SK-2026-2212','2026-10-16',38811.52 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-10-004') AND kind='receipt' AND code='SK-2026-2212');

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-10-005'),'receipt',NULL,'SK-2026-2214','2026-10-31',13600.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-10-005') AND kind='receipt' AND code='SK-2026-2214');

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-10-006'),'receipt',NULL,'SK-2026-2216','2026-10-28',20800.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-10-006') AND kind='receipt' AND code='SK-2026-2216');

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-09-008'),'receipt',NULL,'SK-2026-2217','2026-09-26',27158.40 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-09-008') AND kind='receipt' AND code='SK-2026-2217');

INSERT INTO crm_statement_lines(statement_id,kind,order_id,code,date,amount)
SELECT (SELECT id FROM crm_statements WHERE code='DZ-2026-10-013'),'receipt',NULL,'SK-2026-2219','2026-10-12',12432.00 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_statement_lines WHERE statement_id=(SELECT id FROM crm_statements WHERE code='DZ-2026-10-013') AND kind='receipt' AND code='SK-2026-2219');


/* ---------------- 13. 发票（税额倒算 amount*13%/1.13） ---------------- */

INSERT INTO crm_invoices(code,no,customer_id,contract_id,statement_id,amount,tax_rate,tax_amount,type,
  apply_date,issue_date,status,red_flush_of,red_flush_reason,created_by,created_at)
SELECT 'FP-2026-0302','04412026 0642',4,NULL,(SELECT id FROM crm_statements WHERE code='DZ-2026-08-004'),
  32876.80,0.1300,3782.29,'增值税专用','2026-08-28',
  '2026-08-30','已开票',
  NULL,'',19,'2026-08-28 09:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_invoices WHERE code='FP-2026-0302');

INSERT INTO crm_invoices(code,no,customer_id,contract_id,statement_id,amount,tax_rate,tax_amount,type,
  apply_date,issue_date,status,red_flush_of,red_flush_reason,created_by,created_at)
SELECT 'FP-2026-0303','04412026 0643',4,NULL,(SELECT id FROM crm_statements WHERE code='DZ-2026-09-004'),
  38811.52,0.1300,4465.04,'增值税专用','2026-09-28',
  '2026-09-30','已开票',
  NULL,'',19,'2026-09-28 09:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_invoices WHERE code='FP-2026-0303');

INSERT INTO crm_invoices(code,no,customer_id,contract_id,statement_id,amount,tax_rate,tax_amount,type,
  apply_date,issue_date,status,red_flush_of,red_flush_reason,created_by,created_at)
SELECT 'FP-2026-0304','04412026 0644',4,NULL,(SELECT id FROM crm_statements WHERE code='DZ-2026-10-004'),
  40000.00,0.1300,4601.77,'增值税专用','2026-10-28',
  '2026-10-30','已开票',
  NULL,'',19,'2026-10-28 09:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_invoices WHERE code='FP-2026-0304');

INSERT INTO crm_invoices(code,no,customer_id,contract_id,statement_id,amount,tax_rate,tax_amount,type,
  apply_date,issue_date,status,red_flush_of,red_flush_reason,created_by,created_at)
SELECT 'FP-2026-0305','04412026 0645',5,NULL,(SELECT id FROM crm_statements WHERE code='DZ-2026-09-005'),
  13600.00,0.1300,1564.60,'增值税专用','2026-09-28',
  '2026-09-30','已开票',
  NULL,'',19,'2026-09-28 09:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_invoices WHERE code='FP-2026-0305');

INSERT INTO crm_invoices(code,no,customer_id,contract_id,statement_id,amount,tax_rate,tax_amount,type,
  apply_date,issue_date,status,red_flush_of,red_flush_reason,created_by,created_at)
SELECT 'FP-2026-0306','04412026 0646',5,NULL,(SELECT id FROM crm_statements WHERE code='DZ-2026-10-005'),
  9300.00,0.1300,1069.91,'增值税专用','2026-10-28',
  '2026-10-30','已开票',
  NULL,'',19,'2026-10-28 09:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_invoices WHERE code='FP-2026-0306');

INSERT INTO crm_invoices(code,no,customer_id,contract_id,statement_id,amount,tax_rate,tax_amount,type,
  apply_date,issue_date,status,red_flush_of,red_flush_reason,created_by,created_at)
SELECT 'FP-2026-0307','04412026 0647',6,NULL,(SELECT id FROM crm_statements WHERE code='DZ-2026-09-006'),
  20800.00,0.1300,2392.92,'增值税专用','2026-09-28',
  '2026-09-30','已开票',
  NULL,'',19,'2026-09-28 09:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_invoices WHERE code='FP-2026-0307');

INSERT INTO crm_invoices(code,no,customer_id,contract_id,statement_id,amount,tax_rate,tax_amount,type,
  apply_date,issue_date,status,red_flush_of,red_flush_reason,created_by,created_at)
SELECT 'FP-2026-0308','04412026 0648',8,NULL,(SELECT id FROM crm_statements WHERE code='DZ-2026-08-008'),
  27158.40,0.1300,3124.42,'增值税专用','2026-08-28',
  '2026-08-30','已开票',
  NULL,'',19,'2026-08-28 09:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_invoices WHERE code='FP-2026-0308');

INSERT INTO crm_invoices(code,no,customer_id,contract_id,statement_id,amount,tax_rate,tax_amount,type,
  apply_date,issue_date,status,red_flush_of,red_flush_reason,created_by,created_at)
SELECT 'FP-2026-0309','04412026 0355',13,NULL,(SELECT id FROM crm_statements WHERE code='DZ-2026-09-013'),
  13632.00,0.1300,1568.28,'增值税专用','2026-10-09',
  '2026-10-11','已红冲',
  NULL,'',19,'2026-10-09 09:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_invoices WHERE code='FP-2026-0309');

INSERT INTO crm_invoices(code,no,customer_id,contract_id,statement_id,amount,tax_rate,tax_amount,type,
  apply_date,issue_date,status,red_flush_of,red_flush_reason,created_by,created_at)
SELECT 'FP-2026-0310','04412026 0356',13,NULL,(SELECT id FROM crm_statements WHERE code='DZ-2026-09-013'),
  -13632.00,0.1300,-1568.28,'增值税专用','2026-10-12',
  '2026-10-12','已红冲',
  (SELECT id FROM crm_invoices WHERE code='FP-2026-0309'),'客户名称与开票信息不符，全额红冲',19,'2026-10-12 09:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_invoices WHERE code='FP-2026-0310');

INSERT INTO crm_invoices(code,no,customer_id,contract_id,statement_id,amount,tax_rate,tax_amount,type,
  apply_date,issue_date,status,red_flush_of,red_flush_reason,created_by,created_at)
SELECT 'FP-2026-0311','04412026 0357',13,NULL,(SELECT id FROM crm_statements WHERE code='DZ-2026-09-013'),
  13632.00,0.1300,1568.28,'增值税专用','2026-10-13',
  '2026-10-14','已开票',
  NULL,'',19,'2026-10-13 09:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_invoices WHERE code='FP-2026-0311');


/* ---------------- 14. 收款核销（收款挂到上一期的发票上） ---------------- */

-- 核销规则：客户付的是上一期账单，所以收款冲上期账单上的发票；
-- 皖通 11 月那笔 15,300 故意不核销，用来测「待核销」和财务认领。

INSERT INTO crm_receipt_allocations(receipt_id,target_type,target_id,amount,created_by,created_at)
SELECT (SELECT id FROM crm_receipts WHERE code='SK-2026-2211'),'invoice',(SELECT id FROM crm_invoices WHERE code='FP-2026-0302'),32876.80,19,
  '2026-09-22 17:05:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_receipt_allocations WHERE receipt_id=(SELECT id FROM crm_receipts WHERE code='SK-2026-2211')
  AND target_type='invoice' AND target_id=(SELECT id FROM crm_invoices WHERE code='FP-2026-0302'));

INSERT INTO crm_receipt_allocations(receipt_id,target_type,target_id,amount,created_by,created_at)
SELECT (SELECT id FROM crm_receipts WHERE code='SK-2026-2212'),'invoice',(SELECT id FROM crm_invoices WHERE code='FP-2026-0303'),38811.52,19,
  '2026-10-16 17:05:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_receipt_allocations WHERE receipt_id=(SELECT id FROM crm_receipts WHERE code='SK-2026-2212')
  AND target_type='invoice' AND target_id=(SELECT id FROM crm_invoices WHERE code='FP-2026-0303'));

INSERT INTO crm_receipt_allocations(receipt_id,target_type,target_id,amount,created_by,created_at)
SELECT (SELECT id FROM crm_receipts WHERE code='SK-2026-2213'),'invoice',(SELECT id FROM crm_invoices WHERE code='FP-2026-0304'),30000.00,19,
  '2026-11-06 17:05:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_receipt_allocations WHERE receipt_id=(SELECT id FROM crm_receipts WHERE code='SK-2026-2213')
  AND target_type='invoice' AND target_id=(SELECT id FROM crm_invoices WHERE code='FP-2026-0304'));

INSERT INTO crm_receipt_allocations(receipt_id,target_type,target_id,amount,created_by,created_at)
SELECT (SELECT id FROM crm_receipts WHERE code='SK-2026-2217'),'invoice',(SELECT id FROM crm_invoices WHERE code='FP-2026-0308'),27158.40,19,
  '2026-09-26 17:05:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_receipt_allocations WHERE receipt_id=(SELECT id FROM crm_receipts WHERE code='SK-2026-2217')
  AND target_type='invoice' AND target_id=(SELECT id FROM crm_invoices WHERE code='FP-2026-0308'));

INSERT INTO crm_receipt_allocations(receipt_id,target_type,target_id,amount,created_by,created_at)
SELECT (SELECT id FROM crm_receipts WHERE code='SK-2026-2214'),'invoice',(SELECT id FROM crm_invoices WHERE code='FP-2026-0305'),13600.00,19,
  '2026-10-31 17:05:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_receipt_allocations WHERE receipt_id=(SELECT id FROM crm_receipts WHERE code='SK-2026-2214')
  AND target_type='invoice' AND target_id=(SELECT id FROM crm_invoices WHERE code='FP-2026-0305'));

INSERT INTO crm_receipt_allocations(receipt_id,target_type,target_id,amount,created_by,created_at)
SELECT (SELECT id FROM crm_receipts WHERE code='SK-2026-2215'),'invoice',(SELECT id FROM crm_invoices WHERE code='FP-2026-0306'),9300.00,19,
  '2026-11-10 17:05:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_receipt_allocations WHERE receipt_id=(SELECT id FROM crm_receipts WHERE code='SK-2026-2215')
  AND target_type='invoice' AND target_id=(SELECT id FROM crm_invoices WHERE code='FP-2026-0306'));

INSERT INTO crm_receipt_allocations(receipt_id,target_type,target_id,amount,created_by,created_at)
SELECT (SELECT id FROM crm_receipts WHERE code='SK-2026-2216'),'invoice',(SELECT id FROM crm_invoices WHERE code='FP-2026-0307'),20800.00,19,
  '2026-10-28 17:05:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_receipt_allocations WHERE receipt_id=(SELECT id FROM crm_receipts WHERE code='SK-2026-2216')
  AND target_type='invoice' AND target_id=(SELECT id FROM crm_invoices WHERE code='FP-2026-0307'));

INSERT INTO crm_receipt_allocations(receipt_id,target_type,target_id,amount,created_by,created_at)
SELECT (SELECT id FROM crm_receipts WHERE code='SK-2026-2219'),'invoice',(SELECT id FROM crm_invoices WHERE code='FP-2026-0311'),12432.00,19,
  '2026-10-12 17:05:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_receipt_allocations WHERE receipt_id=(SELECT id FROM crm_receipts WHERE code='SK-2026-2219')
  AND target_type='invoice' AND target_id=(SELECT id FROM crm_invoices WHERE code='FP-2026-0311'));


COMMIT;


/* ============================================================================
   自检：跑完这段看结果，三行都应该返回 0
   ============================================================================ */
-- 1) 对账恒等式不成立的张数
SELECT COUNT(*) AS bad_statement FROM crm_statements
WHERE close_amount <> open_amount + shipped_amount - received_amount;

-- 2) 核销超额（按发票累计）或超过发票金额的条数
SELECT COUNT(*) AS bad_allocation FROM (
  SELECT a.target_id, SUM(a.amount) s, MAX(i.amount) amt
  FROM crm_receipt_allocations a JOIN crm_invoices i ON i.id=a.target_id
  WHERE a.target_type='invoice' AND a.revoked_at IS NULL
  GROUP BY a.target_id HAVING s > amt
) t;

-- 3) 收款核销合计超过到账金额的条数
SELECT COUNT(*) AS over_receipt FROM (
  SELECT a.receipt_id, SUM(a.amount) s, MAX(r.amount) amt
  FROM crm_receipt_allocations a JOIN crm_receipts r ON r.id=a.receipt_id
  WHERE a.revoked_at IS NULL GROUP BY a.receipt_id HAVING s > amt
) t;
