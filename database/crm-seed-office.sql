/* ============================================================================
   北辰装配 CRM · 行政财务测试数据
   ----------------------------------------------------------------------------
   覆盖：借款预支 / 费用报销（含明细、行程、附件、抵扣）/ 请假 / 年度额度 / 审批流水

   执行：mysql --default-character-set=utf8mb4 -uroot -p crm < database/crm-seed-office.sql

   幂等：按业务单号判重，可重复执行。
   约定：
     - 借款余额不落字段，靠 crm_loan_writeoffs 现算；只有「已通过」的借款才有余额。
     - 报销抵扣是「审批通过才生效」：FY-2026-0615 审批中，只填 deduct_amount（意向），
       不写 writeoff，避免被驳回的单白占员工借款额度。
     - 请假天数按工作日计，额度 = 已通过 + 待审批 之和不超过 quota_days。
============================================================================ */

SET NAMES utf8mb4;
USE crm;

START TRANSACTION;



/* ---------------- 1. 借款预支 ---------------- */

INSERT INTO crm_loans(code,applicant_id,dept_id,type,amount,purpose,apply_date,pay_date,due_date,
  status,approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'JK-2026-0028',14,6,'差旅预支',2000.00,'无锡运通、常州瑞虎两站跑店，3 天差旅预支',
  '2026-09-20','2026-09-22','2026-10-20','已通过',19,'2026-09-20 17:30:00','',
  14,'2026-09-20 09:40:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_loans WHERE code='JK-2026-0028');

INSERT INTO crm_loans(code,applicant_id,dept_id,type,amount,purpose,apply_date,pay_date,due_date,
  status,approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'JK-2026-0029',13,5,'差旅预支',8000.00,'南京依维柯年框对接，含招待与往返高铁',
  '2026-10-08','2026-10-10','2026-11-08','已通过',19,'2026-10-08 17:30:00','',
  13,'2026-10-08 09:40:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_loans WHERE code='JK-2026-0029');

INSERT INTO crm_loans(code,applicant_id,dept_id,type,amount,purpose,apply_date,pay_date,due_date,
  status,approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'JK-2026-0030',8,6,'备用金',3000.00,'安驰 4S 店门店驻场两周，备用金周转',
  '2026-10-15','2026-10-16','2026-11-15','已通过',19,'2026-10-15 17:30:00','',
  8,'2026-10-15 09:40:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_loans WHERE code='JK-2026-0030');

INSERT INTO crm_loans(code,applicant_id,dept_id,type,amount,purpose,apply_date,pay_date,due_date,
  status,approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'JK-2026-0031',10,6,'差旅预支',12000.00,'宁波、台州汽配城扫街，计划 10 天',
  '2026-09-25','2026-09-27','2026-10-27','已通过',19,'2026-09-25 17:30:00','',
  10,'2026-09-25 09:40:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_loans WHERE code='JK-2026-0031');

INSERT INTO crm_loans(code,applicant_id,dept_id,type,amount,purpose,apply_date,pay_date,due_date,
  status,approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'JK-2026-0032',15,10,'采购垫付',6000.00,'上海国际汽配展物料垫付，展后统一报销',
  '2026-10-20','2026-10-22','2026-11-21','已通过',20,'2026-10-20 17:30:00','',
  15,'2026-10-20 09:40:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_loans WHERE code='JK-2026-0032');

INSERT INTO crm_loans(code,applicant_id,dept_id,type,amount,purpose,apply_date,pay_date,due_date,
  status,approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'JK-2026-0033',21,16,'备用金',2000.00,'双十一仓配加班餐与临时用工垫付',
  '2026-11-10',NULL,NULL,'待审批',NULL,NULL,'',
  21,'2026-11-10 09:40:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_loans WHERE code='JK-2026-0033');

INSERT INTO crm_loans(code,applicant_id,dept_id,type,amount,purpose,apply_date,pay_date,due_date,
  status,approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'JK-2026-0034',23,18,'差旅预支',4000.00,'金凤凰门店巡检差旅',
  '2026-11-12',NULL,NULL,'已驳回',11,'2026-11-12 17:30:00','上月同类预支尚未清账，先清后借',
  23,'2026-11-12 09:40:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_loans WHERE code='JK-2026-0034');


/* ---------------- 2. 费用报销单 ---------------- */

INSERT INTO crm_expenses(code,applicant_id,dept_id,project_name,apply_date,total_amount,bill_count,
  trip_from,trip_to,trip_start,trip_end,trip_days,deduct_loan_id,deduct_amount,remark,status,
  approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'FY-2026-0613',14,6,'无锡运通物流车队 / 常州瑞虎维修中心','2026-09-25',2000.00,9,
  '杭州','无锡','2026-09-22','2026-09-24',3,
  (SELECT id FROM crm_loans WHERE code='JK-2026-0028'),2000.00,'','已通过',19,'2026-09-25 16:20:00','',
  14,'2026-09-25 10:15:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expenses WHERE code='FY-2026-0613');

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0613'),'2026-09-22','差旅',620.00,'杭州东—无锡东 高铁二等座往返',2,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0613') AND sort_no=1);

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0613'),'2026-09-22','差旅',960.00,'无锡住宿 2 晚 × ¥480',1,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0613') AND sort_no=2);

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0613'),'2026-09-23','差旅',280.00,'跑店期间工作餐 4 人',2,3 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0613') AND sort_no=3);

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0613'),'2026-09-24','差旅',140.00,'市内打车 4 次',4,4 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0613') AND sort_no=4);

INSERT INTO crm_expense_attachments(expense_id,file_id,file_name,file_size,mime_type)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0613'),'demo/FY-2026-0613/高铁电子发票.pdf','高铁电子发票.pdf',130000,
  'application/pdf' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_attachments WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0613') AND file_name='高铁电子发票.pdf');

INSERT INTO crm_expense_attachments(expense_id,file_id,file_name,file_size,mime_type)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0613'),'demo/FY-2026-0613/住宿发票.pdf','住宿发票.pdf',128000,
  'application/pdf' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_attachments WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0613') AND file_name='住宿发票.pdf');

INSERT INTO crm_expenses(code,applicant_id,dept_id,project_name,apply_date,total_amount,bill_count,
  trip_from,trip_to,trip_start,trip_end,trip_days,deduct_loan_id,deduct_amount,remark,status,
  approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'FY-2026-0614',13,5,'南京依维柯配件部','2026-10-12',6800.00,7,
  '杭州','南京','2026-10-09','2026-10-11',3,
  (SELECT id FROM crm_loans WHERE code='JK-2026-0029'),6800.00,'','已通过',19,'2026-10-12 16:20:00','',
  13,'2026-10-12 10:15:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expenses WHERE code='FY-2026-0614');

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0614'),'2026-10-09','差旅',1180.00,'杭州—南京 高铁往返，含市内接驳',2,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0614') AND sort_no=1);

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0614'),'2026-10-09','差旅',3600.00,'南京住宿 3 晚 × ¥1200',1,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0614') AND sort_no=2);

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0614'),'2026-10-10','客户招待',1400.00,'依维柯采购部商务宴请 6 人',1,3 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0614') AND sort_no=3);

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0614'),'2026-10-11','差旅',620.00,'驻场期间工作餐',3,4 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0614') AND sort_no=4);

INSERT INTO crm_expense_attachments(expense_id,file_id,file_name,file_size,mime_type)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0614'),'demo/FY-2026-0614/高铁票.pdf','高铁票.pdf',127000,
  'application/pdf' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_attachments WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0614') AND file_name='高铁票.pdf');

INSERT INTO crm_expense_attachments(expense_id,file_id,file_name,file_size,mime_type)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0614'),'demo/FY-2026-0614/住宿发票.pdf','住宿发票.pdf',128000,
  'application/pdf' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_attachments WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0614') AND file_name='住宿发票.pdf');

INSERT INTO crm_expense_attachments(expense_id,file_id,file_name,file_size,mime_type)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0614'),'demo/FY-2026-0614/餐饮发票.pdf','餐饮发票.pdf',128000,
  'application/pdf' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_attachments WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0614') AND file_name='餐饮发票.pdf');

INSERT INTO crm_expenses(code,applicant_id,dept_id,project_name,apply_date,total_amount,bill_count,
  trip_from,trip_to,trip_start,trip_end,trip_days,deduct_loan_id,deduct_amount,remark,status,
  approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'FY-2026-0615',15,10,'上海国际汽配展','2026-10-26',29800.00,3,
  '','',NULL,NULL,0,
  (SELECT id FROM crm_loans WHERE code='JK-2026-0032'),2000.00,'','审批中',NULL,NULL,'',
  15,'2026-10-26 10:15:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expenses WHERE code='FY-2026-0615');

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0615'),'2026-10-24','市场活动',26000.00,'展位租赁 9 ㎡，含标准搭建',1,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0615') AND sort_no=1);

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0615'),'2026-10-25','市场活动',2600.00,'易拉宝、样品册与展台物料',2,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0615') AND sort_no=2);

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0615'),'2026-10-26','样品费',1200.00,'展会现场赠送样品 30 套',0,3 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0615') AND sort_no=3);

INSERT INTO crm_expense_attachments(expense_id,file_id,file_name,file_size,mime_type)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0615'),'demo/FY-2026-0615/展位合同.pdf','展位合同.pdf',128000,
  'application/pdf' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_attachments WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0615') AND file_name='展位合同.pdf');

INSERT INTO crm_expense_attachments(expense_id,file_id,file_name,file_size,mime_type)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0615'),'demo/FY-2026-0615/物料清单.xlsx','物料清单.xlsx',129000,
  'application/vnd.ms-excel' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_attachments WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0615') AND file_name='物料清单.xlsx');

INSERT INTO crm_expenses(code,applicant_id,dept_id,project_name,apply_date,total_amount,bill_count,
  trip_from,trip_to,trip_start,trip_end,trip_days,deduct_loan_id,deduct_amount,remark,status,
  approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'FY-2026-0616',19,14,'财务部日常','2026-10-30',1280.00,3,
  '','',NULL,NULL,0,
  NULL,0.00,'','已通过',11,'2026-10-30 16:20:00','',
  19,'2026-10-30 10:15:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expenses WHERE code='FY-2026-0616');

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0616'),'2026-10-28','办公用品',780.00,'凭证打印纸与装订耗材',2,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0616') AND sort_no=1);

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0616'),'2026-10-29','办公用品',500.00,'档案盒、标签纸',1,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0616') AND sort_no=2);

INSERT INTO crm_expense_attachments(expense_id,file_id,file_name,file_size,mime_type)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0616'),'demo/FY-2026-0616/办公用品发票.pdf','办公用品发票.pdf',130000,
  'application/pdf' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_attachments WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0616') AND file_name='办公用品发票.pdf');

INSERT INTO crm_expenses(code,applicant_id,dept_id,project_name,apply_date,total_amount,bill_count,
  trip_from,trip_to,trip_start,trip_end,trip_days,deduct_loan_id,deduct_amount,remark,status,
  approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'FY-2026-0617',21,16,'运营部仓配','2026-11-04',4860.00,7,
  '','',NULL,NULL,0,
  NULL,0.00,'','审批中',NULL,NULL,'',
  21,'2026-11-04 10:15:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expenses WHERE code='FY-2026-0617');

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0617'),'2026-11-01','物流运费',3600.00,'双十一备货干线运费，杭州—合肥',1,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0617') AND sort_no=1);

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0617'),'2026-11-03','物流运费',1260.00,'同城配送 6 车次',6,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0617') AND sort_no=2);

INSERT INTO crm_expense_attachments(expense_id,file_id,file_name,file_size,mime_type)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0617'),'demo/FY-2026-0617/运费结算单.pdf','运费结算单.pdf',129000,
  'application/pdf' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_attachments WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0617') AND file_name='运费结算单.pdf');

INSERT INTO crm_expenses(code,applicant_id,dept_id,project_name,apply_date,total_amount,bill_count,
  trip_from,trip_to,trip_start,trip_end,trip_days,deduct_loan_id,deduct_amount,remark,status,
  approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'FY-2026-0618',8,6,'上海嘉定安驰 4S 店','2026-11-06',3860.00,1,
  '','',NULL,NULL,0,
  NULL,0.00,'','已驳回',19,'2026-11-06 16:20:00','宴请无客户陪同人员签字，补签后重提',
  8,'2026-11-06 10:15:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expenses WHERE code='FY-2026-0618');

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0618'),'2026-11-05','客户招待',3860.00,'安驰配件部年度合作宴请',1,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0618') AND sort_no=1);

INSERT INTO crm_expense_attachments(expense_id,file_id,file_name,file_size,mime_type)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0618'),'demo/FY-2026-0618/餐饮发票.pdf','餐饮发票.pdf',128000,
  'application/pdf' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_attachments WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0618') AND file_name='餐饮发票.pdf');

INSERT INTO crm_expenses(code,applicant_id,dept_id,project_name,apply_date,total_amount,bill_count,
  trip_from,trip_to,trip_start,trip_end,trip_days,deduct_loan_id,deduct_amount,remark,status,
  approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'FY-2026-0619',11,5,'合肥皖通汽配贸易','2026-11-10',3240.00,4,
  '杭州','合肥','2026-11-06','2026-11-08',3,
  NULL,0.00,'','审批中',NULL,NULL,'',
  11,'2026-11-10 10:15:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expenses WHERE code='FY-2026-0619');

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0619'),'2026-11-06','差旅',980.00,'杭州东—合肥南 高铁往返',2,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0619') AND sort_no=1);

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0619'),'2026-11-06','差旅',1600.00,'合肥住宿 2 晚 × ¥800',1,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0619') AND sort_no=2);

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0619'),'2026-11-08','客户招待',660.00,'皖通采购部便餐 4 人',1,3 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0619') AND sort_no=3);

INSERT INTO crm_expense_attachments(expense_id,file_id,file_name,file_size,mime_type)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0619'),'demo/FY-2026-0619/高铁票.pdf','高铁票.pdf',127000,
  'application/pdf' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_attachments WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0619') AND file_name='高铁票.pdf');

INSERT INTO crm_expense_attachments(expense_id,file_id,file_name,file_size,mime_type)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0619'),'demo/FY-2026-0619/住宿发票.pdf','住宿发票.pdf',128000,
  'application/pdf' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_attachments WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0619') AND file_name='住宿发票.pdf');

INSERT INTO crm_expenses(code,applicant_id,dept_id,project_name,apply_date,total_amount,bill_count,
  trip_from,trip_to,trip_start,trip_end,trip_days,deduct_loan_id,deduct_amount,remark,status,
  approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'FY-2026-0620',10,6,'宁波甬安汽修厂','2026-11-12',2680.00,6,
  '杭州','宁波','2026-10-29','2026-10-30',2,
  (SELECT id FROM crm_loans WHERE code='JK-2026-0031'),2680.00,'','已通过',19,'2026-11-12 16:20:00','',
  10,'2026-11-12 10:15:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expenses WHERE code='FY-2026-0620');

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0620'),'2026-10-29','差旅',760.00,'杭州—宁波 高铁往返',2,1 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0620') AND sort_no=1);

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0620'),'2026-10-29','差旅',1600.00,'宁波住宿 1 晚 × ¥800',1,2 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0620') AND sort_no=2);

INSERT INTO crm_expense_items(expense_id,occur_date,type,amount,note,bills,sort_no)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0620'),'2026-10-30','差旅',320.00,'市内交通与餐费',3,3 FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_items WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0620') AND sort_no=3);

INSERT INTO crm_expense_attachments(expense_id,file_id,file_name,file_size,mime_type)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0620'),'demo/FY-2026-0620/高铁票.pdf','高铁票.pdf',127000,
  'application/pdf' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_attachments WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0620') AND file_name='高铁票.pdf');

INSERT INTO crm_expense_attachments(expense_id,file_id,file_name,file_size,mime_type)
SELECT (SELECT id FROM crm_expenses WHERE code='FY-2026-0620'),'demo/FY-2026-0620/住宿发票.pdf','住宿发票.pdf',128000,
  'application/pdf' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_expense_attachments WHERE expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0620') AND file_name='住宿发票.pdf');


/* ---------------- 3. 借款核销（只对已通过的报销落账） ---------------- */

INSERT INTO crm_loan_writeoffs(loan_id,source,expense_id,amount,note,created_by,created_at)
SELECT (SELECT id FROM crm_loans WHERE code='JK-2026-0028'),'expense',(SELECT id FROM crm_expenses WHERE code='FY-2026-0613'),2000.00,'报销全额抵扣，借款清零',19,
  '2026-09-25 16:25:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_loan_writeoffs WHERE loan_id=(SELECT id FROM crm_loans WHERE code='JK-2026-0028')
  AND expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0613'));

INSERT INTO crm_loan_writeoffs(loan_id,source,expense_id,amount,note,created_by,created_at)
SELECT (SELECT id FROM crm_loans WHERE code='JK-2026-0029'),'expense',(SELECT id FROM crm_expenses WHERE code='FY-2026-0614'),6800.00,'报销抵扣 6800，余 1200 待还',19,
  '2026-10-12 16:25:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_loan_writeoffs WHERE loan_id=(SELECT id FROM crm_loans WHERE code='JK-2026-0029')
  AND expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0614'));

INSERT INTO crm_loan_writeoffs(loan_id,source,expense_id,amount,note,created_by,created_at)
SELECT (SELECT id FROM crm_loans WHERE code='JK-2026-0031'),'expense',(SELECT id FROM crm_expenses WHERE code='FY-2026-0620'),2680.00,'宁波差旅报销抵扣',19,
  '2026-11-12 16:25:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_loan_writeoffs WHERE loan_id=(SELECT id FROM crm_loans WHERE code='JK-2026-0031')
  AND expense_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0620'));


/* ---------------- 4. 请假申请 ---------------- */

INSERT INTO crm_leaves(code,applicant_id,dept_id,type,start_date,end_date,days,reason,handover_id,
  apply_date,status,approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'QJ-2026-0090',13,5,'年假','2026-10-12','2026-10-14',
  3,'年假陪家人出行',14,'2026-10-08','已通过',11,'2026-10-08 18:00:00',
  '',13,'2026-10-08 20:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_leaves WHERE code='QJ-2026-0090');

INSERT INTO crm_leaves(code,applicant_id,dept_id,type,start_date,end_date,days,reason,handover_id,
  apply_date,status,approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'QJ-2026-0091',8,6,'病假','2026-10-20','2026-10-21',
  2,'感冒发烧，医院开了两天病假条',10,'2026-10-19','已通过',11,'2026-10-19 18:00:00',
  '',8,'2026-10-19 20:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_leaves WHERE code='QJ-2026-0091');

INSERT INTO crm_leaves(code,applicant_id,dept_id,type,start_date,end_date,days,reason,handover_id,
  apply_date,status,approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'QJ-2026-0092',14,6,'调休','2026-11-05','2026-11-06',
  2,'10 月展会加班调休',8,'2026-11-02','已通过',11,'2026-11-02 18:00:00',
  '',14,'2026-11-02 20:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_leaves WHERE code='QJ-2026-0092');

INSERT INTO crm_leaves(code,applicant_id,dept_id,type,start_date,end_date,days,reason,handover_id,
  apply_date,status,approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'QJ-2026-0093',11,5,'年假','2026-11-20','2026-11-24',
  3,'年假，带孩子体检',23,'2026-11-13','待审批',NULL,NULL,
  '',11,'2026-11-13 20:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_leaves WHERE code='QJ-2026-0093');

INSERT INTO crm_leaves(code,applicant_id,dept_id,type,start_date,end_date,days,reason,handover_id,
  apply_date,status,approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'QJ-2026-0094',10,6,'事假','2026-11-17','2026-11-17',
  1,'处理房屋过户手续',8,'2026-11-12','待审批',NULL,NULL,
  '',10,'2026-11-12 20:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_leaves WHERE code='QJ-2026-0094');

INSERT INTO crm_leaves(code,applicant_id,dept_id,type,start_date,end_date,days,reason,handover_id,
  apply_date,status,approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'QJ-2026-0095',15,10,'病假','2026-11-11','2026-11-12',
  2,'急性肠胃炎，居家休息',21,'2026-11-10','已通过',11,'2026-11-10 18:00:00',
  '',15,'2026-11-10 20:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_leaves WHERE code='QJ-2026-0095');

INSERT INTO crm_leaves(code,applicant_id,dept_id,type,start_date,end_date,days,reason,handover_id,
  apply_date,status,approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'QJ-2026-0096',21,16,'年假','2026-11-25','2026-11-27',
  3,'年假，回老家',23,'2026-11-13','待审批',NULL,NULL,
  '',21,'2026-11-13 20:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_leaves WHERE code='QJ-2026-0096');

INSERT INTO crm_leaves(code,applicant_id,dept_id,type,start_date,end_date,days,reason,handover_id,
  apply_date,status,approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'QJ-2026-0097',23,18,'事假','2026-10-28','2026-10-28',
  1,'临时有事',22,'2026-10-27','已驳回',11,'2026-10-27 18:00:00',
  '当天有门店巡检，事由不充分',23,'2026-10-27 20:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_leaves WHERE code='QJ-2026-0097');

INSERT INTO crm_leaves(code,applicant_id,dept_id,type,start_date,end_date,days,reason,handover_id,
  apply_date,status,approver_id,approved_at,reject_reason,created_by,created_at)
SELECT 'QJ-2026-0098',19,14,'调休','2026-11-13','2026-11-13',
  1,'月末结账加班调休',20,'2026-11-11','已通过',11,'2026-11-11 18:00:00',
  '',19,'2026-11-11 20:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_leaves WHERE code='QJ-2026-0098');


/* ---------------- 5. 2026 年度额度（已用天数按已通过的请假汇总） ---------------- */

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(11,2026,'年假',5.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(11,2026,'病假',10.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(11,2026,'调休',3.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(8,2026,'年假',5.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(8,2026,'病假',10.00,2.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(8,2026,'调休',3.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(10,2026,'年假',5.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(10,2026,'病假',10.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(10,2026,'调休',3.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(13,2026,'年假',5.00,3.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(13,2026,'病假',10.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(13,2026,'调休',3.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(14,2026,'年假',5.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(14,2026,'病假',10.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(14,2026,'调休',3.00,2.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(15,2026,'年假',5.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(15,2026,'病假',10.00,2.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(15,2026,'调休',3.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(16,2026,'年假',5.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(16,2026,'病假',10.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(16,2026,'调休',3.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(17,2026,'年假',5.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(17,2026,'病假',10.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(17,2026,'调休',3.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(18,2026,'年假',5.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(18,2026,'病假',10.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(18,2026,'调休',3.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(19,2026,'年假',5.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(19,2026,'病假',10.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(19,2026,'调休',3.00,1.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(20,2026,'年假',5.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(20,2026,'病假',10.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(20,2026,'调休',3.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(21,2026,'年假',5.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(21,2026,'病假',10.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(21,2026,'调休',3.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(22,2026,'年假',5.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(22,2026,'病假',10.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(22,2026,'调休',3.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(23,2026,'年假',5.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(23,2026,'病假',10.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);

INSERT INTO crm_leave_quotas(employee_id,year,type,quota_days,used_days)
VALUES(23,2026,'调休',3.00,0.00)
ON DUPLICATE KEY UPDATE quota_days=VALUES(quota_days), used_days=VALUES(used_days);


/* ---------------- 6. 审批流水（只追加，不改） ---------------- */

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '借款预支',(SELECT id FROM crm_loans WHERE code='JK-2026-0028'),'提交',14,'','2026-09-20 09:40:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='借款预支' AND doc_id=(SELECT id FROM crm_loans WHERE code='JK-2026-0028') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '借款预支',(SELECT id FROM crm_loans WHERE code='JK-2026-0028'),'同意',19,'同意，按应清账日归还',
  '2026-09-20 17:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='借款预支' AND doc_id=(SELECT id FROM crm_loans WHERE code='JK-2026-0028') AND action='同意');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '借款预支',(SELECT id FROM crm_loans WHERE code='JK-2026-0029'),'提交',13,'','2026-10-08 09:40:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='借款预支' AND doc_id=(SELECT id FROM crm_loans WHERE code='JK-2026-0029') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '借款预支',(SELECT id FROM crm_loans WHERE code='JK-2026-0029'),'同意',19,'同意，按应清账日归还',
  '2026-10-08 17:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='借款预支' AND doc_id=(SELECT id FROM crm_loans WHERE code='JK-2026-0029') AND action='同意');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '借款预支',(SELECT id FROM crm_loans WHERE code='JK-2026-0030'),'提交',8,'','2026-10-15 09:40:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='借款预支' AND doc_id=(SELECT id FROM crm_loans WHERE code='JK-2026-0030') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '借款预支',(SELECT id FROM crm_loans WHERE code='JK-2026-0030'),'同意',19,'同意，按应清账日归还',
  '2026-10-15 17:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='借款预支' AND doc_id=(SELECT id FROM crm_loans WHERE code='JK-2026-0030') AND action='同意');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '借款预支',(SELECT id FROM crm_loans WHERE code='JK-2026-0031'),'提交',10,'','2026-09-25 09:40:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='借款预支' AND doc_id=(SELECT id FROM crm_loans WHERE code='JK-2026-0031') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '借款预支',(SELECT id FROM crm_loans WHERE code='JK-2026-0031'),'同意',19,'同意，按应清账日归还',
  '2026-09-25 17:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='借款预支' AND doc_id=(SELECT id FROM crm_loans WHERE code='JK-2026-0031') AND action='同意');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '借款预支',(SELECT id FROM crm_loans WHERE code='JK-2026-0032'),'提交',15,'','2026-10-20 09:40:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='借款预支' AND doc_id=(SELECT id FROM crm_loans WHERE code='JK-2026-0032') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '借款预支',(SELECT id FROM crm_loans WHERE code='JK-2026-0032'),'同意',20,'同意，按应清账日归还',
  '2026-10-20 17:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='借款预支' AND doc_id=(SELECT id FROM crm_loans WHERE code='JK-2026-0032') AND action='同意');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '借款预支',(SELECT id FROM crm_loans WHERE code='JK-2026-0033'),'提交',21,'','2026-11-10 09:40:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='借款预支' AND doc_id=(SELECT id FROM crm_loans WHERE code='JK-2026-0033') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '借款预支',(SELECT id FROM crm_loans WHERE code='JK-2026-0034'),'提交',23,'','2026-11-12 09:40:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='借款预支' AND doc_id=(SELECT id FROM crm_loans WHERE code='JK-2026-0034') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '借款预支',(SELECT id FROM crm_loans WHERE code='JK-2026-0034'),'驳回',11,'上月同类预支尚未清账，先清后借',
  '2026-11-12 17:30:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='借款预支' AND doc_id=(SELECT id FROM crm_loans WHERE code='JK-2026-0034') AND action='驳回');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '费用报销',(SELECT id FROM crm_expenses WHERE code='FY-2026-0613'),'提交',14,'','2026-09-25 10:15:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='费用报销' AND doc_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0613') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '费用报销',(SELECT id FROM crm_expenses WHERE code='FY-2026-0613'),'同意',19,'票据齐全，同意报销',
  '2026-09-25 16:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='费用报销' AND doc_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0613') AND action='同意');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '费用报销',(SELECT id FROM crm_expenses WHERE code='FY-2026-0614'),'提交',13,'','2026-10-12 10:15:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='费用报销' AND doc_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0614') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '费用报销',(SELECT id FROM crm_expenses WHERE code='FY-2026-0614'),'同意',19,'票据齐全，同意报销',
  '2026-10-12 16:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='费用报销' AND doc_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0614') AND action='同意');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '费用报销',(SELECT id FROM crm_expenses WHERE code='FY-2026-0615'),'提交',15,'','2026-10-26 10:15:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='费用报销' AND doc_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0615') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '费用报销',(SELECT id FROM crm_expenses WHERE code='FY-2026-0616'),'提交',19,'','2026-10-30 10:15:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='费用报销' AND doc_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0616') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '费用报销',(SELECT id FROM crm_expenses WHERE code='FY-2026-0616'),'同意',11,'票据齐全，同意报销',
  '2026-10-30 16:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='费用报销' AND doc_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0616') AND action='同意');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '费用报销',(SELECT id FROM crm_expenses WHERE code='FY-2026-0617'),'提交',21,'','2026-11-04 10:15:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='费用报销' AND doc_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0617') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '费用报销',(SELECT id FROM crm_expenses WHERE code='FY-2026-0618'),'提交',8,'','2026-11-06 10:15:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='费用报销' AND doc_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0618') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '费用报销',(SELECT id FROM crm_expenses WHERE code='FY-2026-0618'),'驳回',19,'宴请无客户陪同人员签字，补签后重提',
  '2026-11-06 16:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='费用报销' AND doc_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0618') AND action='驳回');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '费用报销',(SELECT id FROM crm_expenses WHERE code='FY-2026-0619'),'提交',11,'','2026-11-10 10:15:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='费用报销' AND doc_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0619') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '费用报销',(SELECT id FROM crm_expenses WHERE code='FY-2026-0620'),'提交',10,'','2026-11-12 10:15:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='费用报销' AND doc_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0620') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '费用报销',(SELECT id FROM crm_expenses WHERE code='FY-2026-0620'),'同意',19,'票据齐全，同意报销',
  '2026-11-12 16:20:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='费用报销' AND doc_id=(SELECT id FROM crm_expenses WHERE code='FY-2026-0620') AND action='同意');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '请假申请',(SELECT id FROM crm_leaves WHERE code='QJ-2026-0090'),'提交',13,'','2026-10-08 20:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='请假申请' AND doc_id=(SELECT id FROM crm_leaves WHERE code='QJ-2026-0090') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '请假申请',(SELECT id FROM crm_leaves WHERE code='QJ-2026-0090'),'同意',11,'已安排交接，同意',
  '2026-10-08 18:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='请假申请' AND doc_id=(SELECT id FROM crm_leaves WHERE code='QJ-2026-0090') AND action='同意');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '请假申请',(SELECT id FROM crm_leaves WHERE code='QJ-2026-0091'),'提交',8,'','2026-10-19 20:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='请假申请' AND doc_id=(SELECT id FROM crm_leaves WHERE code='QJ-2026-0091') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '请假申请',(SELECT id FROM crm_leaves WHERE code='QJ-2026-0091'),'同意',11,'已安排交接，同意',
  '2026-10-19 18:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='请假申请' AND doc_id=(SELECT id FROM crm_leaves WHERE code='QJ-2026-0091') AND action='同意');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '请假申请',(SELECT id FROM crm_leaves WHERE code='QJ-2026-0092'),'提交',14,'','2026-11-02 20:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='请假申请' AND doc_id=(SELECT id FROM crm_leaves WHERE code='QJ-2026-0092') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '请假申请',(SELECT id FROM crm_leaves WHERE code='QJ-2026-0092'),'同意',11,'已安排交接，同意',
  '2026-11-02 18:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='请假申请' AND doc_id=(SELECT id FROM crm_leaves WHERE code='QJ-2026-0092') AND action='同意');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '请假申请',(SELECT id FROM crm_leaves WHERE code='QJ-2026-0093'),'提交',11,'','2026-11-13 20:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='请假申请' AND doc_id=(SELECT id FROM crm_leaves WHERE code='QJ-2026-0093') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '请假申请',(SELECT id FROM crm_leaves WHERE code='QJ-2026-0094'),'提交',10,'','2026-11-12 20:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='请假申请' AND doc_id=(SELECT id FROM crm_leaves WHERE code='QJ-2026-0094') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '请假申请',(SELECT id FROM crm_leaves WHERE code='QJ-2026-0095'),'提交',15,'','2026-11-10 20:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='请假申请' AND doc_id=(SELECT id FROM crm_leaves WHERE code='QJ-2026-0095') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '请假申请',(SELECT id FROM crm_leaves WHERE code='QJ-2026-0095'),'同意',11,'已安排交接，同意',
  '2026-11-10 18:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='请假申请' AND doc_id=(SELECT id FROM crm_leaves WHERE code='QJ-2026-0095') AND action='同意');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '请假申请',(SELECT id FROM crm_leaves WHERE code='QJ-2026-0096'),'提交',21,'','2026-11-13 20:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='请假申请' AND doc_id=(SELECT id FROM crm_leaves WHERE code='QJ-2026-0096') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '请假申请',(SELECT id FROM crm_leaves WHERE code='QJ-2026-0097'),'提交',23,'','2026-10-27 20:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='请假申请' AND doc_id=(SELECT id FROM crm_leaves WHERE code='QJ-2026-0097') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '请假申请',(SELECT id FROM crm_leaves WHERE code='QJ-2026-0097'),'驳回',11,'当天有门店巡检，事由不充分',
  '2026-10-27 18:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='请假申请' AND doc_id=(SELECT id FROM crm_leaves WHERE code='QJ-2026-0097') AND action='驳回');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '请假申请',(SELECT id FROM crm_leaves WHERE code='QJ-2026-0098'),'提交',19,'','2026-11-11 20:10:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='请假申请' AND doc_id=(SELECT id FROM crm_leaves WHERE code='QJ-2026-0098') AND action='提交');

INSERT INTO crm_approval_logs(kind,doc_id,action,operator_id,note,created_at)
SELECT '请假申请',(SELECT id FROM crm_leaves WHERE code='QJ-2026-0098'),'同意',11,'已安排交接，同意',
  '2026-11-11 18:00:00' FROM DUAL
WHERE NOT EXISTS(SELECT 1 FROM crm_approval_logs WHERE kind='请假申请' AND doc_id=(SELECT id FROM crm_leaves WHERE code='QJ-2026-0098') AND action='同意');


COMMIT;


/* 自检：三行都应为 0 */
-- 1) 借款核销超过本金
SELECT COUNT(*) AS over_writeoff FROM (
  SELECT l.id, l.amount, COALESCE(SUM(w.amount),0) s FROM crm_loans l
  LEFT JOIN crm_loan_writeoffs w ON w.loan_id=l.id GROUP BY l.id HAVING s > l.amount) t;
-- 2) 报销合计与明细不符
SELECT COUNT(*) AS bad_expense FROM crm_expenses e
WHERE e.total_amount <> (SELECT COALESCE(SUM(amount),0) FROM crm_expense_items WHERE expense_id=e.id);
-- 3) 额度超用
SELECT COUNT(*) AS over_quota FROM crm_leave_quotas WHERE used_days > quota_days;
