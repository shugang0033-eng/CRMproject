/* ============================================================================
   北辰装配 CRM · 演示数据（与前端 src/data/mock.js、productCatalog.js 一一对应）
   ----------------------------------------------------------------------------
   用途：把前端演示数据落进 MySQL，换成真实接口后页面依然有内容，方便走查与联调。

   执行：mysql -uroot -p crm < database/crm-demo-seed.sql
   特性：幂等。全部走 INSERT ... ON DUPLICATE KEY UPDATE / NOT EXISTS，
        重复执行结果一致，不会产生重复行。

   注意：
     1. 线索、客户、产品会被「重置」为脚本里的初始状态——手工改过的演示数据
        重跑会被覆盖，只在你需要还原演示环境时再跑。
     2. 员工与部门不新建，全部按 username 取现有账号：
        X01 苏晚 / X02 林致远 / E08 张三 / E09 李四 / Y01 陈默 / J02 顾晓 / admin 宋江
     3. 客户必须挂在一条「已成交线索」上（crm_customers.source_lead_id 非空唯一），
        所以线索先建、客户后建，一条线索对应一个客户。
   ============================================================================ */

USE crm;

START TRANSACTION;

/* ---------------------------------------------------------------- 0. 账号变量 */
SET @x01   = (SELECT id FROM crm_employees WHERE username = 'X01');   -- 苏晚   销售部
SET @x02   = (SELECT id FROM crm_employees WHERE username = 'X02');   -- 林致远 销售一组
SET @e08   = (SELECT id FROM crm_employees WHERE username = 'E08');   -- 张三   销售一组
SET @e09   = (SELECT id FROM crm_employees WHERE username = 'E09');   -- 李四   销售一组
SET @ops   = (SELECT id FROM crm_employees WHERE username = 'J02');   -- 顾晓   销售运营
SET @admin = (SELECT id FROM crm_employees WHERE username = 'admin'); -- 宋江   超管

/* ============================================================================
   1. 线索
   ----------------------------------------------------------------------------
   分三类：
     A. 已成交（won）10 条 —— 每条对应下面第 2 节的一个客户，created_at 散布在
        2026-08 ~ 2026-11，让「成交」标签页和客户来源都有历史。
     B. 在跟 11 条 —— 覆盖 待分配 / 待联系 / 已联系 / 已报样报价 / 谈判中 / 无效。
     C. 线索池 6 条 —— pool_entered_at 非空即入池，owner_id 置空。
   ============================================================================ */

INSERT INTO crm_leads
  (lead_no, company, contact, phone, source, level, status, province, city, industry, note,
   created_by, owner_id, pool_entered_at, pool_reason, created_at, stage_entered_at)
VALUES
/* ---- A. 已成交：会转成客户 ---- */
('LD-2605','杭州驰远汽车服务连锁','沈立','138****6621','官网询盘','A','won','浙江','杭州','汽修连锁',
 '年度耗材集采，价格按季度联动',@admin,@x02,NULL,NULL,'2026-09-18 10:12:00','2026-10-28 15:20:00'),
('LD-2604','上海嘉定安驰 4S 店','高彤','139****3382','汽配展','A','won','上海','嘉定','4S 店',
 '展会见客，现场清点线束辅料',@admin,@e08,NULL,NULL,'2026-10-09 09:04:00','2026-10-24 11:10:00'),
('LD-2603','无锡运通物流车队','柳志强','137****7719','客户转介绍','B','won','江苏','无锡','车队物流',
 '46 台车保养耗材按月配送到场',@admin,@x02,NULL,NULL,'2026-09-02 17:36:00','2026-09-18 10:00:00'),
('LD-2602','苏州车之翼汽车用品','闫雪','135****2208','1688 询盘','B','won','江苏','苏州','汽配经销商',
 '密封件专供，附 NBR 材质报告',@admin,@x01,NULL,NULL,'2026-09-30 14:20:00','2026-10-11 16:40:00'),
('LD-2601','南京依维柯配件部','关鹏','186****5510','电话外呼','C','won','江苏','南京','主机厂配套',
 '紧固件年框，走月结 60 天',@admin,@x01,NULL,NULL,'2026-09-12 11:02:00','2026-11-02 09:30:00'),
('LD-2600','常州瑞虎汽车维修中心','钟慧','133****9044','官网询盘','C','won','江苏','常州','二类汽修厂',
 '首单铺货，洗车毛巾与海绵为主',@admin,@e08,NULL,NULL,'2026-10-15 16:45:00','2026-10-23 15:05:00'),
('LD-2599','合肥皖通汽配贸易','傅晨','158****1188','汽配展','B','won','安徽','合肥','汽配经销商',
 '二批商，价格敏感，走量为主',@admin,@e09,NULL,NULL,'2026-08-20 10:30:00','2026-09-01 14:20:00'),
('LD-2598','嘉兴南方汽修','陆瑶','188****6620','汽配城拜访','C','won','浙江','嘉兴','二类汽修厂',
 '跑店签下的小单，线束辅料补货',@admin,@x02,NULL,NULL,'2026-10-08 15:12:00','2026-10-19 10:45:00'),
('LD-2597','金华众诚汽车服务','武斌','189****3355','客户转介绍','A','won','浙江','金华','汽修连锁',
 '新开店，先配基础洗车套餐',@admin,@x01,NULL,NULL,'2026-10-20 09:48:00','2026-11-03 11:20:00'),
('LD-2596','宁波甬安汽修厂','席磊','150****7781','电话外呼','B','won','浙江','宁波','二类汽修厂',
 '密封件试样通过后下首单',@admin,@e09,NULL,NULL,'2026-10-28 14:06:00','2026-11-05 10:15:00'),

/* ---- B. 在跟：覆盖六个阶段 ---- */
('LD-2612','杭州速洁汽车美容','周航','135****6612','官网询盘','A','pending','浙江','杭州','二类汽修厂',
 '官网表单留资，还没派给销售',@ops,NULL,NULL,NULL,'2026-11-11 09:20:00','2026-11-11 09:20:00'),
('LD-2611','苏州车享家连锁','吴敏','138****4471','1688 询盘','B','pending','江苏','苏州','汽修连锁',
 '1688 店铺咨询，等运营分配',@ops,NULL,NULL,NULL,'2026-11-11 08:40:00','2026-11-11 08:40:00'),
('LD-2610','无锡靓车会所','顾磊','137****5520','客户转介绍','A','pending','江苏','无锡','二类汽修厂',
 '老客介绍，48 小时内要首触',@admin,@x01,NULL,NULL,'2026-11-10 16:05:00','2026-11-10 16:05:00'),
('LD-2609','宁波车洁仕','徐蕾','139****7734','汽配展','B','pending','浙江','宁波','二类汽修厂',
 '展会名单，待首次电话',@admin,@e08,NULL,NULL,'2026-11-10 14:30:00','2026-11-10 14:30:00'),
('LD-2608','上海美车堂','董越','136****2280','汽配城拜访','B','contacted','上海','闵行','汽修连锁',
 '已通电话，约了下周上门',@admin,@x02,NULL,NULL,'2026-11-09 15:12:00','2026-11-09 18:00:00'),
('LD-2607','合肥车管家','蒋文','158****9981','电话外呼','C','contacted','安徽','合肥','汽配经销商',
 '报了箱价，等对方核库存',@admin,@e09,NULL,NULL,'2026-11-08 10:24:00','2026-11-08 15:30:00'),
('LD-2606','南京车之友','邵鹏','189****3325','官网询盘','A','quoted','江苏','南京','汽修连锁',
 '已发洗车毛巾与海绵报价单，附克重检测',@admin,@x01,NULL,NULL,'2026-11-07 11:36:00','2026-11-08 09:15:00'),
('LD-2613','常州车丽坊','陆晨','133****8802','汽配展','A','negotiating','江苏','常州','二类汽修厂',
 '谈判中，卡在首单起订量与账期',@admin,@x02,NULL,NULL,'2026-11-06 14:18:00','2026-11-10 10:40:00'),
('LD-2614','嘉兴洗车人家','何俊','186****4410','1688 询盘','B','negotiating','浙江','嘉兴','汽修连锁',
 '三家店一起谈年框，等老板拍价',@admin,@e08,NULL,NULL,'2026-11-05 09:52:00','2026-11-09 16:20:00'),
('LD-2615','湖州车洁美','沈涛','150****2277','汽配城拜访','C','invalid','浙江','湖州','二类汽修厂',
 '已转竞品供货，标无效',@admin,@e09,NULL,NULL,'2026-11-04 16:40:00','2026-11-06 11:00:00'),
('LD-2616','绍兴快洗站','王凯','137****9080','电话外呼','C','invalid','浙江','绍兴','二类汽修厂',
 '空号 / 非决策人，标无效',@admin,@x02,NULL,NULL,'2026-11-03 09:15:00','2026-11-05 14:30:00'),

/* ---- C. 线索池：超时未跟进、离职回收等 ---- */
('LD-2590','台州宏运汽配商行','夏铭','137****2214','官网询盘','B','pending','浙江','台州','汽配经销商',
 NULL,@admin,NULL,'2026-11-12 09:20:00','超 7 天未跟进','2026-11-05 09:20:00','2026-11-05 09:20:00'),
('LD-2588','东莞寮步汽车养护中心','潘宇','139****8890','汽配展','B','pending','广东','东莞','汽修连锁',
 NULL,@admin,NULL,'2026-11-09 10:10:00','员工离职回收','2026-11-04 16:10:00','2026-11-04 16:10:00'),
('LD-2585','青岛恒达汽修设备','骆琳','135****4432','客户转介绍','B','pending','山东','青岛','汽配经销商',
 NULL,@admin,NULL,'2026-11-08 11:35:00','线索重复清理','2026-11-03 11:35:00','2026-11-03 11:35:00'),
('LD-2581','成都鑫源汽配城商户','倪昊','186****9901','电话外呼','B','pending','四川','成都','汽配经销商',
 NULL,@admin,NULL,'2026-11-10 15:48:00','超 30 天未跟进','2026-11-02 15:48:00','2026-11-02 15:48:00'),
('LD-2577','厦门路达汽车快修','钟启','188****3302','官网询盘','B','pending','福建','厦门','二类汽修厂',
 NULL,@admin,NULL,'2026-11-06 10:05:00','客户主动退回','2026-11-01 10:05:00','2026-11-01 10:05:00'),
('LD-2574','济南泉城汽修连锁','范黎','133****5567','1688 询盘','B','pending','山东','济南','汽修连锁',
 NULL,@admin,NULL,'2026-11-08 14:26:00','超 7 天未跟进','2026-10-31 14:26:00','2026-10-31 14:26:00')
ON DUPLICATE KEY UPDATE
  company          = VALUES(company),
  contact          = VALUES(contact),
  phone            = VALUES(phone),
  source           = VALUES(source),
  level            = VALUES(level),
  status           = VALUES(status),
  province         = VALUES(province),
  city             = VALUES(city),
  industry         = VALUES(industry),
  note             = VALUES(note),
  owner_id         = VALUES(owner_id),
  pool_entered_at  = VALUES(pool_entered_at),
  pool_reason      = VALUES(pool_reason),
  created_at       = VALUES(created_at),
  stage_entered_at = VALUES(stage_entered_at);

/* ============================================================================
   2. 客户 —— 一条已成交线索转一个客户（source_lead_id 唯一）
   ============================================================================ */

INSERT INTO crm_customers (source_lead_id, name, industry, level, owner_id, created_by, created_at)
SELECT l.id, x.name, x.industry, x.level, x.owner_id, @admin, x.created_at
FROM (
  SELECT 'LD-2605' AS lead_no, '杭州驰远汽车服务连锁' AS name, '汽修连锁'   AS industry, '战略客户' AS level, @x02 AS owner_id, '2026-10-28 15:20:00' AS created_at
  UNION ALL SELECT 'LD-2604','上海嘉定安驰 4S 店','4S 店','A 类',@e08,'2026-10-24 11:10:00'
  UNION ALL SELECT 'LD-2603','无锡运通物流车队','车队物流','A 类',@x02,'2026-09-18 10:00:00'
  UNION ALL SELECT 'LD-2602','苏州车之翼汽车用品','汽配经销商','B 类',@x01,'2026-10-11 16:40:00'
  UNION ALL SELECT 'LD-2601','南京依维柯配件部','主机厂配套','战略客户',@x01,'2026-11-02 09:30:00'
  UNION ALL SELECT 'LD-2600','常州瑞虎汽车维修中心','二类汽修厂','B 类',@e08,'2026-10-23 15:05:00'
  UNION ALL SELECT 'LD-2599','合肥皖通汽配贸易','汽配经销商','C 类',@e09,'2026-09-01 14:20:00'
  UNION ALL SELECT 'LD-2598','嘉兴南方汽修','二类汽修厂','B 类',@x02,'2026-10-19 10:45:00'
  UNION ALL SELECT 'LD-2597','金华众诚汽车服务','汽修连锁','C 类',@x01,'2026-11-03 11:20:00'
  UNION ALL SELECT 'LD-2596','宁波甬安汽修厂','二类汽修厂','A 类',@e09,'2026-11-05 10:15:00'
) x
JOIN crm_leads l ON l.lead_no = x.lead_no
ON DUPLICATE KEY UPDATE
  name       = VALUES(name),
  industry   = VALUES(industry),
  level      = VALUES(level),
  owner_id   = VALUES(owner_id),
  created_at = VALUES(created_at);

/* ============================================================================
   3. 客户联系人（表里只有 姓名 / 电话，职务与邮箱前端暂未建模）
   ============================================================================ */

INSERT INTO crm_customer_contacts (customer_id, name, phone)
SELECT c.id, x.contact, x.phone
FROM (
  SELECT '杭州驰远汽车服务连锁' AS customer, '沈立'   AS contact, '138****6621' AS phone
  UNION ALL SELECT '南京依维柯配件部','关鹏','186****5510'
  UNION ALL SELECT '上海嘉定安驰 4S 店','高彤','139****3382'
  UNION ALL SELECT '宁波甬安汽修厂','席磊','150****7781'
  UNION ALL SELECT '苏州车之翼汽车用品','闫雪','135****2208'
  UNION ALL SELECT '无锡运通物流车队','柳志强','137****7719'
  UNION ALL SELECT '常州瑞虎汽车维修中心','钟慧','133****9044'
  UNION ALL SELECT '合肥皖通汽配贸易','傅晨','158****1188'
  UNION ALL SELECT '嘉兴南方汽修','陆瑶','188****6620'
  UNION ALL SELECT '金华众诚汽车服务','武斌','189****3355'
) x
JOIN crm_customers c ON c.name = x.customer
WHERE NOT EXISTS (
  SELECT 1 FROM crm_customer_contacts k WHERE k.customer_id = c.id AND k.name = x.contact
);

/* ============================================================================
   4. 产品主数据
   ----------------------------------------------------------------------------
   价格口径与后端 ProductService 一致：base_price / dealer_price / cost_price
   都存「最小单位价」，报价单位（箱）价 = 最小单位价 × 该单位 factor。
   例如 P001 箱价 640 ÷ 200 = 3.2 元/条。
   ============================================================================ */

/* 4.1 品类 */
INSERT INTO crm_product_categories (name, icon, description, status, sort)
VALUES
  ('洗车毛巾','layers','超细纤维、珊瑚绒、PVA 等擦车布类','active',10),
  ('清洁工具','grid','轮毂刷、轮胎刷、细节刷与海绵','active',20),
  ('清洁剂','sparkle','洗车液、轮毂清洗剂、内饰清洁剂','active',30),
  ('抛光耗材','shield','抛光盘、还原盘、砂纸与背绒耗材','active',40),
  ('包装耗材','box','气泡膜、缠绕膜、纸箱等出货辅料','disabled',50)
ON DUPLICATE KEY UPDATE icon = VALUES(icon), description = VALUES(description), status = VALUES(status), sort = VALUES(sort);

/* 4.2 品类属性模板（整组覆盖，避免残留旧字段） */
DELETE a FROM crm_product_category_attrs a
JOIN crm_product_categories c ON c.id = a.category_id
WHERE c.name IN ('洗车毛巾','清洁工具','清洁剂','抛光耗材','包装耗材');

INSERT INTO crm_product_category_attrs (category_id, attr_key, label, type, unit, options_json, sort)
SELECT c.id, x.attr_key, x.label, x.type, x.unit, x.options_json, x.sort
FROM (
  /* 洗车毛巾 */
  SELECT '洗车毛巾' AS category, 'size'     AS attr_key, '尺寸'     AS label, 'text'   AS type, 'cm'    AS unit, NULL AS options_json, 0 AS sort
  UNION ALL SELECT '洗车毛巾','weight','克重','number','g/m²',NULL,1
  UNION ALL SELECT '洗车毛巾','material','材质','select',NULL,'["超细纤维","珊瑚绒","PVA","鹿皮巾"]',2
  UNION ALL SELECT '洗车毛巾','color','颜色','text',NULL,NULL,3
  UNION ALL SELECT '洗车毛巾','edge','包边工艺','select',NULL,'["双线锁边","缎面","无包边"]',4
  /* 清洁工具 */
  UNION ALL SELECT '清洁工具','bristle','刷毛材质','select',NULL,'["PP 硬毛","尼龙软毛","猪鬃","海绵"]',0
  UNION ALL SELECT '清洁工具','head','刷头尺寸','text','cm',NULL,1
  UNION ALL SELECT '清洁工具','handle','手柄','select',NULL,'["短柄","长柄可伸缩","弧形","无柄"]',2
  UNION ALL SELECT '清洁工具','hardness','硬度','select',NULL,'["软","中","硬"]',3
  /* 清洁剂 */
  UNION ALL SELECT '清洁剂','volume','容量','number','ml',NULL,0
  UNION ALL SELECT '清洁剂','ph','PH 值','text',NULL,NULL,1
  UNION ALL SELECT '清洁剂','ratio','稀释比例','text',NULL,NULL,2
  UNION ALL SELECT '清洁剂','concentrated','是否浓缩','select',NULL,'["浓缩液","即用型"]',3
  /* 抛光耗材 */
  UNION ALL SELECT '抛光耗材','diameter','直径','text','寸',NULL,0
  UNION ALL SELECT '抛光耗材','grit','目数 / 切削力','text',NULL,NULL,1
  UNION ALL SELECT '抛光耗材','backing','背绒','select',NULL,'["背绒","背胶","无背"]',2
  UNION ALL SELECT '抛光耗材','type','类型','select',NULL,'["切削盘","还原盘","收尾盘","水砂纸"]',3
  /* 包装耗材 */
  UNION ALL SELECT '包装耗材','spec','规格','text',NULL,NULL,0
  UNION ALL SELECT '包装耗材','thickness','厚度','text','μm',NULL,1
  UNION ALL SELECT '包装耗材','material','材质','select',NULL,'["PE","PVC","瓦楞纸"]',2
) x
JOIN crm_product_categories c ON c.name = x.category;

/* 4.3 产品 */
INSERT INTO crm_products
  (code, name, category_id, brand, specs_json, sale_unit, base_price, dealer_price, cost_price,
   moq, production_days, produce_mode, customizable, stock_status, status, remark, updated_at)
SELECT x.code, x.name, c.id, x.brand, CAST(x.specs AS JSON), x.sale_unit, x.base_price, x.dealer_price, x.cost_price,
       x.moq, x.production_days, x.mode, x.customizable, x.stock, x.status, x.remark, x.updated_at
FROM (
  SELECT 'BC-TW4040-300' AS code,'超细纤维洗车毛巾 40×40 300g' AS name,'洗车毛巾' AS category,'北辰' AS brand,
         '{"size":"40×40","weight":"300","material":"超细纤维","color":"蓝色","edge":"双线锁边"}' AS specs,
         '箱' AS sale_unit, 3.20000000 AS base_price, 2.80000000 AS dealer_price, 2.10000000 AS cost_price,
         5 AS moq, 7 AS production_days,'self' AS mode, 1 AS customizable,'enough' AS stock,'on' AS status,
         '双线锁边不掉毛，机洗 200 次以上；洗车店最常备的基础款' AS remark,'2026-11-08 10:00:00' AS updated_at
  UNION ALL SELECT 'BC-TW60160-400','珊瑚绒擦车巾 60×160 400g','洗车毛巾','北辰',
         '{"size":"60×160","weight":"400","material":"珊瑚绒","color":"深灰","edge":"缎面"}',
         '箱',9.80000000,8.60000000,6.45000000,3,10,'self',1,'low','on','大尺寸擦干巾，吸水快，适合美容工位收水','2026-11-06 10:00:00'
  UNION ALL SELECT 'BC-PVA4332','PVA 吸水巾 43×32','洗车毛巾','北辰',
         '{"size":"43×32","weight":"—","material":"PVA","color":"浅蓝","edge":"无包边"}',
         '箱',7.60000000,6.80000000,5.10000000,5,12,'outsource',0,'made_to_order','on','鹿皮巾替代款，不留水痕，玻璃与漆面收水用','2026-10-29 10:00:00'
  UNION ALL SELECT 'BC-LP4060','真皮鹿皮巾 40×60','洗车毛巾','安洁',
         '{"size":"40×60","weight":"—","material":"鹿皮巾","color":"米黄","edge":"无包边"}',
         '箱',25.00000000,22.40000000,17.60000000,2,15,'outsource',0,'low','on','高端店收水用，单价高、走量小','2026-09-18 10:00:00'
  UNION ALL SELECT 'BC-BR-LH01','长柄轮毂刷 硬毛','清洁工具','北辰',
         '{"bristle":"PP 硬毛","head":"22×6","handle":"长柄可伸缩","hardness":"硬"}',
         '箱',9.00000000,8.00000000,5.60000000,5,8,'self',1,'enough','on','可伸缩至 60cm，深轮毂与内衬刷洗','2026-11-02 10:00:00'
  UNION ALL SELECT 'BC-BR-TR02','弧形轮胎刷 中硬毛','清洁工具','北辰',
         '{"bristle":"PP 硬毛","head":"18×5","handle":"弧形","hardness":"中"}',
         '箱',8.00000000,7.16666667,5.00000000,5,8,'self',1,'enough','on','弧形贴合胎面，洗胎圈与胎侧','2026-11-02 10:00:00'
  UNION ALL SELECT 'BC-BR-SET5','细节刷 5 件套','清洁工具','北辰',
         '{"bristle":"尼龙软毛","head":"混装","handle":"短柄","hardness":"软"}',
         '箱',10.50000000,9.50000000,6.45000000,5,10,'self',1,'low','on','空调出风口、缝隙、车标清洁，美容工位标配','2026-10-21 10:00:00'
  UNION ALL SELECT 'BC-SP-8ZI','洗车海绵 8 字大孔','清洁工具','北辰',
         '{"bristle":"海绵","head":"20×10×6","handle":"无柄","hardness":"软"}',
         '箱',2.60000000,2.30000000,1.58000000,10,6,'self',0,'enough','on','大孔易起泡，不伤漆面，洗车液配套出货','2026-10-30 10:00:00'
  UNION ALL SELECT 'BC-CL-FOAM1L','泡沫洗车液 1L 浓缩','清洁剂','安洁',
         '{"volume":"1000","ph":"7.5","ratio":"1:100","concentrated":"浓缩液"}',
         '箱',28.00000000,25.00000000,17.00000000,10,5,'outsource',1,'enough','on','中性配方，1:100 稀释，高泡易冲','2026-11-10 10:00:00'
  UNION ALL SELECT 'BC-CL-WHEEL500','轮毂清洗剂 500ml','清洁剂','安洁',
         '{"volume":"500","ph":"4.0","ratio":"原液","concentrated":"即用型"}',
         '箱',19.00000000,17.08333333,12.00000000,5,5,'outsource',1,'low','on','弱酸性去铁粉，喷后 30 秒见紫色反应','2026-11-04 10:00:00'
  UNION ALL SELECT 'BC-PL-5IN','抛光还原盘 5 寸','抛光耗材','北辰',
         '{"diameter":"5","grit":"细","backing":"背绒","type":"还原盘"}',
         '箱',7.50000000,6.60000000,4.30000000,10,9,'outsource',0,'enough','on','收尾还原用，配 DA 机 5 寸托盘','2026-10-15 10:00:00'
  UNION ALL SELECT 'BC-PK-BUB50','气泡膜 50cm×100m','包装耗材','北辰',
         '{"spec":"50cm×100m","thickness":"50","material":"PE"}',
         '箱',45.00000000,41.25000000,30.00000000,4,3,'outsource',0,'enough','off','仅内部出货使用，不对外销售','2026-08-12 10:00:00'
) x
JOIN crm_product_categories c ON c.name = x.category
ON DUPLICATE KEY UPDATE
  name            = VALUES(name),
  category_id     = VALUES(category_id),
  brand           = VALUES(brand),
  specs_json      = VALUES(specs_json),
  sale_unit       = VALUES(sale_unit),
  base_price      = VALUES(base_price),
  dealer_price    = VALUES(dealer_price),
  cost_price      = VALUES(cost_price),
  moq             = VALUES(moq),
  production_days = VALUES(production_days),
  produce_mode    = VALUES(produce_mode),
  customizable    = VALUES(customizable),
  stock_status    = VALUES(stock_status),
  status          = VALUES(status),
  remark          = VALUES(remark);

/* 4.4 三级单位换算：条 → 包 → 箱 */
DROP TEMPORARY TABLE IF EXISTS tmp_product_units;
CREATE TEMPORARY TABLE tmp_product_units (code VARCHAR(64), unit_name VARCHAR(16), factor INT, PRIMARY KEY (code, unit_name));

INSERT INTO tmp_product_units VALUES
  ('BC-TW4040-300','条',1),('BC-TW4040-300','包',10),('BC-TW4040-300','箱',200),
  ('BC-TW60160-400','条',1),('BC-TW60160-400','包',5),('BC-TW60160-400','箱',100),
  ('BC-PVA4332','条',1),('BC-PVA4332','包',10),('BC-PVA4332','箱',100),
  ('BC-LP4060','条',1),('BC-LP4060','包',5),('BC-LP4060','箱',50),
  ('BC-BR-LH01','把',1),('BC-BR-LH01','箱',60),
  ('BC-BR-TR02','把',1),('BC-BR-TR02','箱',60),
  ('BC-BR-SET5','套',1),('BC-BR-SET5','箱',40),
  ('BC-SP-8ZI','个',1),('BC-SP-8ZI','包',10),('BC-SP-8ZI','箱',100),
  ('BC-CL-FOAM1L','瓶',1),('BC-CL-FOAM1L','箱',12),
  ('BC-CL-WHEEL500','瓶',1),('BC-CL-WHEEL500','箱',24),
  ('BC-PL-5IN','片',1),('BC-PL-5IN','包',10),('BC-PL-5IN','箱',50),
  ('BC-PK-BUB50','卷',1),('BC-PK-BUB50','箱',4);

DELETE u FROM crm_product_units u
JOIN crm_products p ON p.id = u.product_id
JOIN tmp_product_units t ON t.code = p.code;

INSERT INTO crm_product_units (product_id, unit_name, factor, is_sale)
SELECT p.id, t.unit_name, t.factor, t.unit_name = p.sale_unit
FROM tmp_product_units t JOIN crm_products p ON p.code = t.code;

/* 4.5 阶梯价：同样存最小单位价 */
DROP TEMPORARY TABLE IF EXISTS tmp_product_tiers;
CREATE TEMPORARY TABLE tmp_product_tiers (code VARCHAR(64), min_qty INT, unit_price DECIMAL(20,8));

INSERT INTO tmp_product_tiers VALUES
  ('BC-TW4040-300',5,3.10000000),('BC-TW4040-300',20,2.95000000),('BC-TW4040-300',50,2.80000000),
  ('BC-TW60160-400',3,9.50000000),('BC-TW60160-400',10,9.00000000),
  ('BC-PVA4332',5,7.40000000),
  ('BC-BR-LH01',5,8.66666667),('BC-BR-LH01',20,8.16666667),
  ('BC-BR-TR02',10,7.66666667),
  ('BC-BR-SET5',5,10.00000000),
  ('BC-SP-8ZI',10,2.45000000),
  ('BC-CL-FOAM1L',10,26.66666667),('BC-CL-FOAM1L',50,24.66666667),
  ('BC-CL-WHEEL500',5,18.33333333),
  ('BC-PL-5IN',10,7.20000000);

DELETE t FROM crm_product_tiers t JOIN crm_products p ON p.id = t.product_id
WHERE p.code IN (SELECT code FROM tmp_product_units);

INSERT INTO crm_product_tiers (product_id, min_qty, unit_price)
SELECT p.id, t.min_qty, t.unit_price
FROM tmp_product_tiers t JOIN crm_products p ON p.code = t.code;

/* 4.6 套装（bundle_price 是整套的成交价，单位「元」，不再按件换算） */
INSERT INTO crm_product_bundles (code, name, bundle_price, status, remark)
VALUES
  ('BC-KIT-OPEN','新店开业洗车套餐',1880.00,'on','洗车工位起步配置，含毛巾、海绵与轮毂刷'),
  ('BC-KIT-POLISH','美容工位抛光套装',2580.00,'on','抛光 + 收水 + 洗车液，新上美容项目的门店常配'),
  ('BC-KIT-4S','4S 交付礼包',2180.00,'off','按台交付时随车赠送，已由新店套餐替代')
ON DUPLICATE KEY UPDATE
  name = VALUES(name), bundle_price = VALUES(bundle_price), status = VALUES(status), remark = VALUES(remark);

DELETE i FROM crm_product_bundle_items i JOIN crm_product_bundles b ON b.id = i.bundle_id
WHERE b.code IN ('BC-KIT-OPEN','BC-KIT-POLISH','BC-KIT-4S');

INSERT INTO crm_product_bundle_items (bundle_id, product_id, qty, unit_name)
SELECT b.id, p.id, x.qty, x.unit
FROM (
  SELECT 'BC-KIT-OPEN'   AS bundle, 'BC-TW4040-300' AS code, 2 AS qty, '箱' AS unit
  UNION ALL SELECT 'BC-KIT-OPEN','BC-SP-8ZI',1,'箱'
  UNION ALL SELECT 'BC-KIT-OPEN','BC-BR-LH01',1,'箱'
  UNION ALL SELECT 'BC-KIT-POLISH','BC-PL-5IN',2,'箱'
  UNION ALL SELECT 'BC-KIT-POLISH','BC-TW60160-400',1,'箱'
  UNION ALL SELECT 'BC-KIT-POLISH','BC-CL-FOAM1L',1,'箱'
  UNION ALL SELECT 'BC-KIT-4S','BC-TW4040-300',1,'箱'
  UNION ALL SELECT 'BC-KIT-4S','BC-BR-SET5',1,'箱'
  UNION ALL SELECT 'BC-KIT-4S','BC-LP4060',1,'箱'
) x
JOIN crm_product_bundles b ON b.code = x.bundle
JOIN crm_products p ON p.code = x.code;

/* 4.7 客户协议价（discount 是乘数，0.88 = 标准价打 88 折） */
INSERT INTO crm_customer_prices (customer_id, discount, product_ids, updated_by, updated_at)
SELECT c.id, x.discount,
       (SELECT JSON_ARRAYAGG(p.id) FROM (
          SELECT id FROM crm_products ORDER BY id LIMIT 999
        ) p),
       c.owner_id, x.updated_at
FROM (
  SELECT '杭州驰远汽车服务连锁' AS customer, 0.880 AS discount, '2026-10-28 16:00:00' AS updated_at
  UNION ALL SELECT '南京依维柯配件部',0.920,'2026-11-02 10:00:00'
  UNION ALL SELECT '宁波甬安汽修厂',0.960,'2026-10-11 15:00:00'
) x
JOIN crm_customers c ON c.name = x.customer
ON DUPLICATE KEY UPDATE
  discount = VALUES(discount), product_ids = VALUES(product_ids), updated_by = VALUES(updated_by), updated_at = VALUES(updated_at);

/* ============================================================================
   5. 渠道市场投入 —— 来源 ROI 的分母
   ----------------------------------------------------------------------------
   只有「全公司范围 + 按月起始」时才参与计算（见 AnalyticsService.sources），
   渠道名必须与 crm_leads.source 完全一致，否则对不上号。
   ============================================================================ */

INSERT INTO crm_channel_costs (channel, period_month, amount, remark)
VALUES
  ('官网询盘','2026-01',4000,'SEO 与落地页投放'),('官网询盘','2026-02',4000,'SEO 与落地页投放'),
  ('官网询盘','2026-03',4000,'SEO 与落地页投放'),('官网询盘','2026-04',4000,'SEO 与落地页投放'),
  ('官网询盘','2026-05',4000,'SEO 与落地页投放'),('官网询盘','2026-06',4000,'SEO 与落地页投放'),
  ('官网询盘','2026-07',4000,'SEO 与落地页投放'),('官网询盘','2026-08',4000,'SEO 与落地页投放'),
  ('官网询盘','2026-09',4000,'SEO 与落地页投放'),('官网询盘','2026-10',4000,'SEO 与落地页投放'),
  ('官网询盘','2026-11',4000,'SEO 与落地页投放'),

  ('1688 询盘','2026-01',9000,'店铺推广费与客服人力'),('1688 询盘','2026-02',9000,'店铺推广费与客服人力'),
  ('1688 询盘','2026-03',9000,'店铺推广费与客服人力'),('1688 询盘','2026-04',9000,'店铺推广费与客服人力'),
  ('1688 询盘','2026-05',9000,'店铺推广费与客服人力'),('1688 询盘','2026-06',9000,'店铺推广费与客服人力'),
  ('1688 询盘','2026-07',9000,'店铺推广费与客服人力'),('1688 询盘','2026-08',9000,'店铺推广费与客服人力'),
  ('1688 询盘','2026-09',9000,'店铺推广费与客服人力'),('1688 询盘','2026-10',9000,'店铺推广费与客服人力'),
  ('1688 询盘','2026-11',9000,'店铺推广费与客服人力'),

  ('汽配城拜访','2026-01',12000,'跑店差旅与样品寄送'),('汽配城拜访','2026-02',12000,'跑店差旅与样品寄送'),
  ('汽配城拜访','2026-03',12000,'跑店差旅与样品寄送'),('汽配城拜访','2026-04',12000,'跑店差旅与样品寄送'),
  ('汽配城拜访','2026-05',12000,'跑店差旅与样品寄送'),('汽配城拜访','2026-06',12000,'跑店差旅与样品寄送'),
  ('汽配城拜访','2026-07',12000,'跑店差旅与样品寄送'),('汽配城拜访','2026-08',12000,'跑店差旅与样品寄送'),
  ('汽配城拜访','2026-09',12000,'跑店差旅与样品寄送'),('汽配城拜访','2026-10',12000,'跑店差旅与样品寄送'),
  ('汽配城拜访','2026-11',12000,'跑店差旅与样品寄送'),

  ('客户转介绍','2026-01',1000,'老客返点与答谢'),('客户转介绍','2026-02',1000,'老客返点与答谢'),
  ('客户转介绍','2026-03',1000,'老客返点与答谢'),('客户转介绍','2026-04',1000,'老客返点与答谢'),
  ('客户转介绍','2026-05',1000,'老客返点与答谢'),('客户转介绍','2026-06',1000,'老客返点与答谢'),
  ('客户转介绍','2026-07',1000,'老客返点与答谢'),('客户转介绍','2026-08',1000,'老客返点与答谢'),
  ('客户转介绍','2026-09',1000,'老客返点与答谢'),('客户转介绍','2026-10',1000,'老客返点与答谢'),
  ('客户转介绍','2026-11',1000,'老客返点与答谢'),

  ('电话外呼','2026-01',6000,'外呼系统与名单采购'),('电话外呼','2026-02',6000,'外呼系统与名单采购'),
  ('电话外呼','2026-03',6000,'外呼系统与名单采购'),('电话外呼','2026-04',6000,'外呼系统与名单采购'),
  ('电话外呼','2026-05',6000,'外呼系统与名单采购'),('电话外呼','2026-06',6000,'外呼系统与名单采购'),
  ('电话外呼','2026-07',6000,'外呼系统与名单采购'),('电话外呼','2026-08',6000,'外呼系统与名单采购'),
  ('电话外呼','2026-09',6000,'外呼系统与名单采购'),('电话外呼','2026-10',6000,'外呼系统与名单采购'),
  ('电话外呼','2026-11',6000,'外呼系统与名单采购'),

  ('汽配展','2026-04',160000,'上海国际汽配展：展位、搭建与物料'),
  ('汽配展','2026-09',126000,'广州汽配展：展位与差旅')
ON DUPLICATE KEY UPDATE amount = VALUES(amount), remark = VALUES(remark);

COMMIT;

/* ---------------------------------------------------------------- 自检 */
SELECT '线索' AS 表, COUNT(*) AS 行数 FROM crm_leads
UNION ALL SELECT '线索-已成交', COUNT(*) FROM crm_leads WHERE status = 'won'
UNION ALL SELECT '线索-池内', COUNT(*) FROM crm_leads WHERE pool_entered_at IS NOT NULL
UNION ALL SELECT '客户', COUNT(*) FROM crm_customers
UNION ALL SELECT '联系人', COUNT(*) FROM crm_customer_contacts
UNION ALL SELECT '品类', COUNT(*) FROM crm_product_categories
UNION ALL SELECT '产品', COUNT(*) FROM crm_products
UNION ALL SELECT '产品单位', COUNT(*) FROM crm_product_units
UNION ALL SELECT '阶梯价', COUNT(*) FROM crm_product_tiers
UNION ALL SELECT '套装', COUNT(*) FROM crm_product_bundles
UNION ALL SELECT '套装明细', COUNT(*) FROM crm_product_bundle_items
UNION ALL SELECT '协议价', COUNT(*) FROM crm_customer_prices
UNION ALL SELECT '渠道费用', COUNT(*) FROM crm_channel_costs;
