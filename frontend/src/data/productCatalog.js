/**
 * 产品主数据（演示数据）
 * ------------------------------------------------------------
 * 业务：工贸一体的汽车美容耗材，自产为主，标准品按箱出货。
 *
 * 三条建模约定，后端建表时要照抄：
 *  1. 价格一律以「最小单位」为基准存：这里为了演示直观，prices 写的是
 *     **销售单位（箱）价**，换算由 unitPrice() 完成。后端建议存
 *     `base_price`（分/最小单位）+ `sale_unit`，避免小数误差。
 *  2. 单位是三级换算：条 → 包 → 箱，factor 表示「1 个该单位 = 多少个最小单位」。
 *  3. 品类决定规格字段（attrs），产品只存 key-value，换品类不丢数据。
 */

/* ---------------- 品类与属性模板 ---------------- */
export const productCategories = [
  {
    id: 'C01',
    name: '洗车毛巾',
    icon: 'layers',
    desc: '超细纤维、珊瑚绒、PVA 等擦车布类',
    status: '启用',
    attrs: [
      { key: 'size', label: '尺寸', unit: 'cm', type: 'text', required: true },
      { key: 'weight', label: '克重', unit: 'g/m²', type: 'number', required: true },
      { key: 'material', label: '材质', type: 'select', options: ['超细纤维', '珊瑚绒', 'PVA', '鹿皮巾'] },
      { key: 'color', label: '颜色', type: 'text' },
      { key: 'edge', label: '包边工艺', type: 'select', options: ['双线锁边', '缎面', '无包边'] }
    ]
  },
  {
    id: 'C02',
    name: '清洁工具',
    icon: 'grid',
    desc: '轮毂刷、轮胎刷、细节刷与海绵',
    status: '启用',
    attrs: [
      { key: 'bristle', label: '刷毛材质', type: 'select', options: ['PP 硬毛', '尼龙软毛', '猪鬃', '海绵'] },
      { key: 'head', label: '刷头尺寸', unit: 'cm', type: 'text' },
      { key: 'handle', label: '手柄', type: 'select', options: ['短柄', '长柄可伸缩', '弧形', '无柄'] },
      { key: 'hardness', label: '硬度', type: 'select', options: ['软', '中', '硬'] }
    ]
  },
  {
    id: 'C03',
    name: '清洁剂',
    icon: 'sparkle',
    desc: '洗车液、轮毂清洗剂、内饰清洁剂',
    status: '启用',
    attrs: [
      { key: 'volume', label: '容量', unit: 'ml', type: 'number', required: true },
      { key: 'ph', label: 'PH 值', type: 'text' },
      { key: 'ratio', label: '稀释比例', type: 'text' },
      { key: 'concentrated', label: '是否浓缩', type: 'select', options: ['浓缩液', '即用型'] }
    ]
  },
  {
    id: 'C04',
    name: '抛光耗材',
    icon: 'shield',
    desc: '抛光盘、还原盘、砂纸与背绒耗材',
    status: '启用',
    attrs: [
      { key: 'diameter', label: '直径', unit: '寸', type: 'text' },
      { key: 'grit', label: '目数 / 切削力', type: 'text' },
      { key: 'backing', label: '背绒', type: 'select', options: ['背绒', '背胶', '无背'] },
      { key: 'type', label: '类型', type: 'select', options: ['切削盘', '还原盘', '收尾盘', '水砂纸'] }
    ]
  },
  {
    id: 'C05',
    name: '包装耗材',
    icon: 'box',
    desc: '气泡膜、缠绕膜、纸箱等出货辅料',
    status: '停用',
    attrs: [
      { key: 'spec', label: '规格', type: 'text' },
      { key: 'thickness', label: '厚度', unit: 'μm', type: 'text' },
      { key: 'material', label: '材质', type: 'select', options: ['PE', 'PVC', '瓦楞纸'] }
    ]
  }
]

/* ---------------- 产品 ---------------- */
export const productItems = [
  {
    id: 'P001', code: 'BC-TW4040-300', name: '超细纤维洗车毛巾 40×40 300g', categoryId: 'C01', brand: '北辰',
    specs: { size: '40×40', weight: '300', material: '超细纤维', color: '蓝色', edge: '双线锁边' },
    units: [{ name: '条', factor: 1 }, { name: '包', factor: 10 }, { name: '箱', factor: 200 }],
    saleUnit: '箱',
    prices: { standard: 640, dealer: 560, cost: 420 },
    tiers: [{ min: 5, price: 620 }, { min: 20, price: 590 }, { min: 50, price: 560 }],
    moq: 5, productionDays: 7, mode: '自产', customizable: true,
    stock: '充足', status: '在售', remark: '双线锁边不掉毛，机洗 200 次以上；洗车店最常备的基础款',
    updatedAt: '2026-11-08'
  },
  {
    id: 'P002', code: 'BC-TW60160-400', name: '珊瑚绒擦车巾 60×160 400g', categoryId: 'C01', brand: '北辰',
    specs: { size: '60×160', weight: '400', material: '珊瑚绒', color: '深灰', edge: '缎面' },
    units: [{ name: '条', factor: 1 }, { name: '包', factor: 5 }, { name: '箱', factor: 100 }],
    saleUnit: '箱',
    prices: { standard: 980, dealer: 860, cost: 645 },
    tiers: [{ min: 3, price: 950 }, { min: 10, price: 900 }],
    moq: 3, productionDays: 10, mode: '自产', customizable: true,
    stock: '少量', status: '在售', remark: '大尺寸擦干巾，吸水快，适合美容工位收水',
    updatedAt: '2026-11-06'
  },
  {
    id: 'P003', code: 'BC-PVA4332', name: 'PVA 吸水巾 43×32', categoryId: 'C01', brand: '北辰',
    specs: { size: '43×32', weight: '—', material: 'PVA', color: '浅蓝', edge: '无包边' },
    units: [{ name: '条', factor: 1 }, { name: '包', factor: 10 }, { name: '箱', factor: 100 }],
    saleUnit: '箱',
    prices: { standard: 760, dealer: 680, cost: 510 },
    tiers: [{ min: 5, price: 740 }],
    moq: 5, productionDays: 12, mode: '外采', customizable: false,
    stock: '需排产', status: '在售', remark: '鹿皮巾替代款，不留水痕，玻璃与漆面收水用',
    updatedAt: '2026-10-29'
  },
  {
    id: 'P004', code: 'BC-LP4060', name: '真皮鹿皮巾 40×60', categoryId: 'C01', brand: '安洁',
    specs: { size: '40×60', weight: '—', material: '鹿皮巾', color: '米黄', edge: '无包边' },
    units: [{ name: '条', factor: 1 }, { name: '包', factor: 5 }, { name: '箱', factor: 50 }],
    saleUnit: '箱',
    prices: { standard: 1250, dealer: 1120, cost: 880 },
    tiers: [],
    moq: 2, productionDays: 15, mode: '外采', customizable: false,
    stock: '少量', status: '在售', remark: '高端店收水用，单价高、走量小',
    updatedAt: '2026-09-18'
  },
  {
    id: 'P005', code: 'BC-BR-LH01', name: '长柄轮毂刷 硬毛', categoryId: 'C02', brand: '北辰',
    specs: { bristle: 'PP 硬毛', head: '22×6', handle: '长柄可伸缩', hardness: '硬' },
    units: [{ name: '把', factor: 1 }, { name: '箱', factor: 60 }],
    saleUnit: '箱',
    prices: { standard: 540, dealer: 480, cost: 336 },
    tiers: [{ min: 5, price: 520 }, { min: 20, price: 490 }],
    moq: 5, productionDays: 8, mode: '自产', customizable: true,
    stock: '充足', status: '在售', remark: '可伸缩至 60cm，深轮毂与内衬刷洗',
    updatedAt: '2026-11-02'
  },
  {
    id: 'P006', code: 'BC-BR-TR02', name: '弧形轮胎刷 中硬毛', categoryId: 'C02', brand: '北辰',
    specs: { bristle: 'PP 硬毛', head: '18×5', handle: '弧形', hardness: '中' },
    units: [{ name: '把', factor: 1 }, { name: '箱', factor: 60 }],
    saleUnit: '箱',
    prices: { standard: 480, dealer: 430, cost: 300 },
    tiers: [{ min: 10, price: 460 }],
    moq: 5, productionDays: 8, mode: '自产', customizable: true,
    stock: '充足', status: '在售', remark: '弧形贴合胎面，洗胎圈与胎侧',
    updatedAt: '2026-11-02'
  },
  {
    id: 'P007', code: 'BC-BR-SET5', name: '细节刷 5 件套', categoryId: 'C02', brand: '北辰',
    specs: { bristle: '尼龙软毛', head: '混装', handle: '短柄', hardness: '软' },
    units: [{ name: '套', factor: 1 }, { name: '箱', factor: 40 }],
    saleUnit: '箱',
    prices: { standard: 420, dealer: 380, cost: 258 },
    tiers: [{ min: 5, price: 400 }],
    moq: 5, productionDays: 10, mode: '自产', customizable: true,
    stock: '少量', status: '在售', remark: '空调出风口、缝隙、车标清洁，美容工位标配',
    updatedAt: '2026-10-21'
  },
  {
    id: 'P008', code: 'BC-SP-8ZI', name: '洗车海绵 8 字大孔', categoryId: 'C02', brand: '北辰',
    specs: { bristle: '海绵', head: '20×10×6', handle: '无柄', hardness: '软' },
    units: [{ name: '个', factor: 1 }, { name: '包', factor: 10 }, { name: '箱', factor: 100 }],
    saleUnit: '箱',
    prices: { standard: 260, dealer: 230, cost: 158 },
    tiers: [{ min: 10, price: 245 }],
    moq: 10, productionDays: 6, mode: '自产', customizable: false,
    stock: '充足', status: '在售', remark: '大孔易起泡，不伤漆面，洗车液配套出货',
    updatedAt: '2026-10-30'
  },
  {
    id: 'P009', code: 'BC-CL-FOAM1L', name: '泡沫洗车液 1L 浓缩', categoryId: 'C03', brand: '安洁',
    specs: { volume: '1000', ph: '7.5', ratio: '1:100', concentrated: '浓缩液' },
    units: [{ name: '瓶', factor: 1 }, { name: '箱', factor: 12 }],
    saleUnit: '箱',
    prices: { standard: 336, dealer: 300, cost: 204 },
    tiers: [{ min: 10, price: 320 }, { min: 50, price: 296 }],
    moq: 10, productionDays: 5, mode: '外采', customizable: true,
    stock: '充足', status: '在售', remark: '中性配方，1:100 稀释，高泡易冲',
    updatedAt: '2026-11-10'
  },
  {
    id: 'P010', code: 'BC-CL-WHEEL500', name: '轮毂清洗剂 500ml', categoryId: 'C03', brand: '安洁',
    specs: { volume: '500', ph: '4.0', ratio: '原液', concentrated: '即用型' },
    units: [{ name: '瓶', factor: 1 }, { name: '箱', factor: 24 }],
    saleUnit: '箱',
    prices: { standard: 456, dealer: 410, cost: 288 },
    tiers: [{ min: 5, price: 440 }],
    moq: 5, productionDays: 5, mode: '外采', customizable: true,
    stock: '少量', status: '在售', remark: '弱酸性去铁粉，喷后 30 秒见紫色反应',
    updatedAt: '2026-11-04'
  },
  {
    id: 'P011', code: 'BC-PL-5IN', name: '抛光还原盘 5 寸', categoryId: 'C04', brand: '北辰',
    specs: { diameter: '5', grit: '细', backing: '背绒', type: '还原盘' },
    units: [{ name: '片', factor: 1 }, { name: '包', factor: 10 }, { name: '箱', factor: 50 }],
    saleUnit: '箱',
    prices: { standard: 375, dealer: 330, cost: 215 },
    tiers: [{ min: 10, price: 360 }],
    moq: 10, productionDays: 9, mode: '外采', customizable: false,
    stock: '充足', status: '在售', remark: '收尾还原用，配 DA 机 5 寸托盘',
    updatedAt: '2026-10-15'
  },
  {
    id: 'P012', code: 'BC-PK-BUB50', name: '气泡膜 50cm×100m', categoryId: 'C05', brand: '北辰',
    specs: { spec: '50cm×100m', thickness: '50', material: 'PE' },
    units: [{ name: '卷', factor: 1 }, { name: '箱', factor: 4 }],
    saleUnit: '箱',
    prices: { standard: 180, dealer: 165, cost: 120 },
    tiers: [],
    moq: 4, productionDays: 3, mode: '外采', customizable: false,
    stock: '充足', status: '停售', remark: '仅内部出货使用，不对外销售',
    updatedAt: '2026-08-12'
  }
]

/* ---------------- 套装组合 ---------------- */
export const productBundles = [
  {
    id: 'B001', code: 'BC-KIT-OPEN', name: '新店开业洗车套餐',
    items: [
      { productId: 'P001', qty: 2, unit: '箱' },
      { productId: 'P008', qty: 1, unit: '箱' },
      { productId: 'P005', qty: 1, unit: '箱' }
    ],
    bundlePrice: 1880, status: '在售',
    remark: '洗车工位起步配置，含毛巾、海绵与轮毂刷',
    updatedAt: '2026-11-05'
  },
  {
    id: 'B002', code: 'BC-KIT-POLISH', name: '美容工位抛光套装',
    items: [
      { productId: 'P011', qty: 2, unit: '箱' },
      { productId: 'P002', qty: 1, unit: '箱' },
      { productId: 'P009', qty: 1, unit: '箱' }
    ],
    bundlePrice: 2580, status: '在售',
    remark: '抛光 + 收水 + 洗车液，新上美容项目的门店常配',
    updatedAt: '2026-10-28'
  },
  {
    id: 'B003', code: 'BC-KIT-4S', name: '4S 交付礼包',
    items: [
      { productId: 'P001', qty: 1, unit: '箱' },
      { productId: 'P007', qty: 1, unit: '箱' },
      { productId: 'P004', qty: 1, unit: '箱' }
    ],
    bundlePrice: 2180, status: '停售',
    remark: '按台交付时随车赠送，已由新店套餐替代',
    updatedAt: '2026-07-19'
  }
]

/* ---------------- 客户协议价（演示） ---------------- */
export const customerPrices = [
  { customer: '杭州驰远汽车服务连锁', level: '战略客户', discount: 0.88, products: 24, owner: '林致远', updatedAt: '2026-10-28' },
  { customer: '南京依维柯配件部', level: '年框客户', discount: 0.92, products: 16, owner: '苏晚', updatedAt: '2026-11-02' },
  { customer: '宁波甬安汽修厂', level: '普通客户', discount: 0.96, products: 8, owner: '周予安', updatedAt: '2026-10-11' }
]

/* ---------------- 换算与格式化 ---------------- */

/** 1 个指定单位 = 多少个最小单位 */
export function factorOf(product, unitName) {
  const hit = (product.units || []).find((u) => u.name === unitName)
  return hit ? hit.factor : 1
}

/**
 * 把「销售单位价」折算成任意单位价
 * product.prices 里存的是 saleUnit（箱）价
 */
export function unitPrice(product, unitName, kind = 'standard') {
  const price = product.prices?.[kind]
  if (price == null) return 0
  const base = price / factorOf(product, product.saleUnit)
  return base * factorOf(product, unitName)
}

/** 规格摘要：只取有值的属性，按品类模板顺序拼 */
export function specSummary(product) {
  const cat = productCategories.find((c) => c.id === product.categoryId)
  if (!cat) return '—'
  return cat.attrs
    .map((a) => product.specs?.[a.key])
    .filter((v) => v && v !== '—')
    .join(' / ')
}

/** 单位描述：条 · 10/包 · 200/箱 */
export function unitSummary(product) {
  const levels = [...(product.units || [])].sort((a, b) => a.factor - b.factor)
  return levels.map((u, i) => (i === 0 ? u.name : `${u.factor}/${u.name}`)).join(' · ')
}

/** 金额：整数不带小数，小额保留两位 */
export function money(n) {
  if (n == null || Number.isNaN(n)) return '—'
  return n >= 100 ? n.toLocaleString('zh-CN', { maximumFractionDigits: 0 }) : n.toFixed(2)
}

/** 毛利率 */
export function marginOf(product) {
  const { standard, cost } = product.prices || {}
  if (!standard || cost == null) return null
  return ((standard - cost) / standard) * 100
}

/** 套装单买价（按标准价） */
export function bundleOriginalPrice(bundle) {
  return bundle.items.reduce((sum, it) => {
    const p = productItems.find((x) => x.id === it.productId)
    if (!p) return sum
    return sum + unitPrice(p, it.unit) * it.qty
  }, 0)
}

export const stockTone = { 充足: 'tag-success', 少量: 'tag-warning', 需排产: 'tag-gray' }
export const categoryName = (id) => productCategories.find((c) => c.id === id)?.name || '未分类'
