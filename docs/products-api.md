# 产品管理 · 后端对接说明

前端已完成（`src/views/products/` + `src/api/products.js` + `database/crm-product-perms.sql`），
页面目前跑在本地演示数据上，接口按本文契约预留。后端照此实现后，把视图里的本地数组换成
`productApi.*` 即可，参数与返回结构不用改。

---

## 一、业务定位

工贸一体的**汽车美容耗材**（毛巾、刷子、海绵、清洁剂、抛光耗材），标准品，不是按车型适配的零部件。

三条决定了建模方式：

1. **按箱卖、按条比价**：一个 SKU 有三级单位「条 → 包 → 箱」，价格必须能双向换算；
2. **规格由品类决定**：毛巾看克重／尺寸，刷子看刷毛／柄型，清洁剂看容量／稀释比；
3. **自产为主**：产品要带生产方式、起订量、生产周期、是否可贴牌，销售谈单时要看得到。

---

## 二、数据模型

```sql
-- 品类与属性模板
CREATE TABLE crm_product_categories (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  name         VARCHAR(100) NOT NULL UNIQUE,
  icon         VARCHAR(32)  DEFAULT 'box',
  description  VARCHAR(255) DEFAULT '',
  status       ENUM('active','disabled') DEFAULT 'active',
  sort         INT DEFAULT 0,
  created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE crm_product_category_attrs (
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
CREATE TABLE crm_products (
  id              BIGINT PRIMARY KEY AUTO_INCREMENT,
  code            VARCHAR(64) NOT NULL UNIQUE,      -- 物料编码
  name            VARCHAR(200) NOT NULL,
  category_id     BIGINT NOT NULL,
  brand           VARCHAR(64) DEFAULT '',
  specs_json      JSON NULL,                        -- { size: '40×40', weight: '300' }
  sale_unit       VARCHAR(16) NOT NULL,             -- 报价单位：箱
  base_price      DECIMAL(12,2) NOT NULL,           -- 最小单位价（元/条）
  dealer_price    DECIMAL(12,2) DEFAULT NULL,       -- 最小单位价
  cost_price      DECIMAL(12,2) DEFAULT NULL,       -- 最小单位成本价
  moq             INT DEFAULT 1,                    -- 起订量，按 sale_unit
  production_days INT DEFAULT 0,
  produce_mode    ENUM('self','outsource') DEFAULT 'self',
  customizable    TINYINT(1) DEFAULT 0,             -- 支持贴牌
  stock_status    ENUM('enough','low','made_to_order') DEFAULT 'enough',
  status          ENUM('on','off') DEFAULT 'on',
  remark          VARCHAR(500) DEFAULT '',
  created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_category (category_id),
  KEY idx_status (status)
);

-- 单位换算（一个产品 2~3 行）
CREATE TABLE crm_product_units (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  product_id BIGINT NOT NULL,
  unit_name  VARCHAR(16) NOT NULL,     -- 条 / 包 / 箱
  factor     INT NOT NULL,             -- 1 个该单位 = 多少个最小单位
  is_sale    TINYINT(1) DEFAULT 0,     -- 是否报价单位
  UNIQUE KEY uk_product_unit (product_id, unit_name)
);

-- 阶梯价（按 sale_unit 的数量）
CREATE TABLE crm_product_tiers (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  product_id BIGINT NOT NULL,
  min_qty    INT NOT NULL,
  unit_price DECIMAL(12,2) NOT NULL,   -- 最小单位价
  KEY idx_product (product_id)
);

-- 套装
CREATE TABLE crm_product_bundles (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  code         VARCHAR(64) NOT NULL UNIQUE,
  name         VARCHAR(200) NOT NULL,
  bundle_price DECIMAL(12,2) NOT NULL,
  status       ENUM('on','off') DEFAULT 'on',
  remark       VARCHAR(500) DEFAULT ''
);
CREATE TABLE crm_product_bundle_items (
  bundle_id  BIGINT NOT NULL,
  product_id BIGINT NOT NULL,
  qty        INT NOT NULL,
  unit_name  VARCHAR(16) NOT NULL,
  PRIMARY KEY (bundle_id, product_id, unit_name)
);

-- 客户协议价
CREATE TABLE crm_customer_prices (
  customer_id BIGINT NOT NULL,
  discount    DECIMAL(4,3) NOT NULL,   -- 0.880 = 8.8 折
  product_ids JSON NULL,               -- 为空表示全品类
  updated_by  BIGINT NOT NULL,
  updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (customer_id)
);
```

**为什么 base_price 存最小单位价**：整箱数量是可改的（200 条/箱 改 100 条/箱），
如果存箱价，改装箱数后单条价格就漂了；存最小单位价，改装箱数只影响展示。

---

## 三、接口清单

对照 `src/api/products.js`，全部以 `/api` 为前缀。

### 产品

| 方法 | 路径 | 说明 | 状态码 |
|---|---|---|---|
| GET | `/products` | 列表，参数 `keyword / categoryId / brand / status / mode / page / pageSize` | 200 |
| GET | `/products/{id}` | 详情（含 units、tiers） | 200 / 404 |
| POST | `/products` | 新建 | 201 / 400 / 409 |
| PUT | `/products/{id}` | 全量更新 | 204 / 400 / 404 / 409 |
| PATCH | `/products/{id}/status` | 上下架 `{ status: 'on' \| 'off' }` | 204 |
| PATCH | `/products/{id}/stock` | 改可发量 `{ stock: 'enough' \| 'low' \| 'made_to_order' }` | 204 |
| DELETE | `/products/{id}` | 删除；被合同引用时拒绝 | 204 / 409 |
| POST | `/products/import` | multipart 上传 | 200 |
| GET | `/products/export` | 导出国标 CSV（返回文件流） | 200 |

列表响应：

```json
{
  "rows": [
    {
      "id": 1, "code": "BC-TW4040-300", "name": "超细纤维洗车毛巾 40×40 300g",
      "categoryId": 1, "brand": "北辰",
      "specs": { "size": "40×40", "weight": "300", "material": "超细纤维" },
      "units": [{ "name": "条", "factor": 1 }, { "name": "包", "factor": 10 }, { "name": "箱", "factor": 200 }],
      "saleUnit": "箱",
      "prices": { "standard": 640, "dealer": 560, "cost": 420 },
      "tiers": [{ "min": 5, "price": 620 }, { "min": 20, "price": 590 }],
      "moq": 5, "productionDays": 7, "mode": "自产", "customizable": true,
      "stock": "充足", "status": "在售", "remark": "", "updatedAt": "2026-11-08"
    }
  ],
  "total": 12, "page": 1, "pageSize": 20
}
```

`prices` 是**销售单位价**（元/箱），后端在返回时把 `base_price × factor(sale_unit)` 算好，
前端直接展示；`tiers[].price` 同样按销售单位返回。

### 品类

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/product-categories` | 含 `attrs` 模板与 `productCount` |
| POST | `/product-categories` | 新建 |
| PUT | `/product-categories/{id}` | 更新，`attrs` **整包覆盖** |
| DELETE | `/product-categories/{id}` | 有产品 / 历史单据引用时 409 |

`attrs` 覆盖策略：按 `attr_key` 对比——已存在的更新，缺失的删除（但不删产品里的值），
新增的插入。不要级联删除 `crm_products.specs_json` 里的历史键，否则改模板会丢数据。

### 价格

| 方法 | 路径 | 说明 | 权限 |
|---|---|---|---|
| GET | `/products/prices` | 价格总览，含成本与毛利率 | `product.view`，成本字段需 `product.cost` |
| PUT | `/products/{id}/prices` | 改标准价 / 经销价 / 成本价 / 阶梯价 | `product.price` |
| POST | `/products/prices/batch` | 批量调价 `{ ids, kind, mode: 'amount'\|'percent', value }` | `product.price` |
| GET | `/customer-prices` | 客户协议价列表 | `product.view` |
| PUT | `/customer-prices/{customerId}` | 保存折扣与覆盖产品 | `product.price` |

**没有 `product.cost` 权限时，后端必须把 `cost` 字段置空再返回**，不能靠前端隐藏。

### 套装

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/product-bundles` | 列表，含 items |
| POST | `/product-bundles` | 新建 |
| PUT | `/product-bundles/{id}` | 更新 |
| PATCH | `/product-bundles/{id}/status` | 上下架 |

---

## 四、权限

已执行 `database/crm-product-perms.sql`，库里新增三个码：

| 权限码 | 含义 | 默认给了谁 |
|---|---|---|
| `product.view` | 查看产品 | 全员（销售、财务、市场、技术） |
| `product.edit` | 新建 / 编辑 / 上下架 / 品类模板 | 销售运营、产品技术、超管 |
| `product.price` | 调价 | 销售运营、销售经理、运营总监、超管 |
| `product.cost` | 看成本价与毛利率 | 财务、超管 |
| `product.import` | Excel 导入导出 | 销售运营、超管 |

后端每个写接口都要按上表校验；**超管建议直接跳过校验**（库里虽已补全，但新加权限点还会漏）。

---

## 五、必须实现的业务校验

1. **编码唯一**：`code` 重复返回 409，前端已有提示文案。
2. **整箱数量 > 0**、**标准价 > 0**，否则 400。
3. **删除保护**：产品被合同明细、套装子件引用时返回 409；品类下有产品时 409。
   前端把「停用」作为常规下线手段，删除只给误建的数据用。
4. **价格快照**：合同 / 订单明细必须存 `unit_price` 与 `unit_name` 的快照。
   之后改价不影响已签单据——这是耗材生意最容易扯皮的地方。
5. **取价顺序**：客户协议价 → 阶梯价（按数量命中的最高档）→ 经销价 → 标准价。
   后端提供 `GET /products/{id}/effective-price?customerId=&qty=` 会更省事。
6. **套装不单独记库存**：下单时按子件扣减，套装自身只有上下架状态。
7. **导入**：按 `code` 匹配，存在则更新、不存在则新建；任一行校验失败时整批回滚，
   返回 `{ created, updated, failed, errors: [{ row, message }] }`。

---

## 六、前端已做完、后端接入时要改的地方

只改一处：`src/views/products/ProductList.vue` / `Categories.vue` / `Pricing.vue` / `Bundles.vue`
里用 `ref([...mock])` 初始化数据的那几行，换成 `await productApi.list()` 等。
其余（筛选、分页、弹窗、校验、CSV 导出）都不用动。

导入按钮目前只校验"选了文件"，上传逻辑等 `POST /api/products/import` 就绪后再接。

---

## 七、上线顺序建议

1. 建表 + 权限码（§二、§四）；
2. `GET /products` 与 `GET /product-categories`（先把列表跑通，页面即可切真实数据）；
3. 产品增改 + 上下架；
4. 价格接口（含成本字段的权限裁剪）；
5. 品类属性模板覆盖；
6. 套装；
7. 导入导出。

旧链接 `/orders/products` 前端已重定向到 `/products`，后端不需要保留兼容接口。
