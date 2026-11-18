import { customerBook } from '@/composables/useCustomerBook'
import { leadApi } from '@/api/leads'

/**
 * 撞单核对
 * ------------------------------------------------------------
 * 汽配这行同一家集团往往有好几个门店、好几个采购联系人：给销售 A 分线索时，
 * 这家店可能早就是销售 B 名下的客户，或者已经有一条线索在 B 手里跟进。
 * 分下去两个人各谈一遍，客户被问两遍报价，内部先打起来。
 *
 * 所以分配 / 转移前先做一次核对，把三种情况挑出来：
 *   type=customer  已是客户档案（有明确负责人）
 *   type=lead      已有同名线索在别人名下，或同一批里出现两条重复线索
 *   type=pool      同名线索在公海里挂着（还没人要，但值得知道）
 *
 * 原则：只提醒、不阻断。业务上确实会有“同一个集团再开一家店”的情况，
 * 由分配的人自己判断，但必须让他看见。
 *
 * 数据来源：优先 POST /api/leads/conflicts；后端没实现时退回本地核对
 * （客户档案 mock + 当前线索列表），并在返回值里标明 source。
 */

/** 公司名比对前的归一化：去掉空白（含全角空格）与大小写差异 */
export function normalizeCompany(name = '') {
  return String(name || '')
    .replace(/[\s\u3000]/g, '')
    .toLowerCase()
}

/** 手机号 / 座机归一化；带掩码（186****9901）的号码不能用来比对，直接丢弃 */
function phoneKey(phone = '') {
  const s = String(phone || '')
  if (!s || s.includes('*')) return ''
  const digits = s.replace(/\D/g, '')
  return digits.length >= 7 ? digits : ''
}

function customerDetail(c) {
  return [c.level, c.industry].filter(Boolean).join(' · ')
}

function leadDetail(row) {
  return [row.status, row.source].filter(Boolean).join(' · ')
}

/**
 * 本地核对（不依赖后端的兜底）
 * @param {Array} rows     本次要分配 / 转移的线索
 * @param {Object} ctx     { allLeads: 全部线索, customers: 客户档案 }
 */
export function findLocalConflicts(rows = [], { allLeads = [], customers = customerBook.value } = {}) {
  const batchIds = new Set(rows.map((r) => String(r.id)))
  const seen = new Set()
  const out = []

  const push = (item) => {
    const key = `${item.type}:${item.code}:${item.leadId}`
    if (seen.has(key)) return
    seen.add(key)
    out.push(item)
  }

  for (const row of rows) {
    const name = normalizeCompany(row.company)
    const tel = phoneKey(row.phone)
    if (!name && !tel) continue

    /* 1) 已经是客户档案：这条最需要拦一下，客户已经在别人手里跑着 */
    for (const c of customers) {
      const sameName = name && normalizeCompany(c.name) === name
      if (!sameName) continue
      push({
        leadId: row.id,
        leadName: row.company,
        type: 'customer',
        code: c.id,
        name: c.name,
        owner: c.owner || '',
        ownerId: c.ownerId ?? null,
        status: c.status || '',
        detail: customerDetail(c)
      })
    }

    /* 2) 已有线索：包括在别人名下的、以及同一批里的重复线索 */
    for (const l of allLeads) {
      if (String(l.id) === String(row.id)) continue
      const sameName = name && normalizeCompany(l.company || l.name) === name
      const samePhone = tel && phoneKey(l.phone) === tel
      if (!sameName && !samePhone) continue
      const inBatch = batchIds.has(String(l.id))
      const owned = !!(l.owner && l.owner !== '未分配') || !!l.ownerId
      push({
        leadId: row.id,
        leadName: row.company,
        /* 同批重复的线索不叫撞单，叫“重复线索”，单独标一下更准确 */
        type: owned ? 'lead' : inBatch ? 'duplicate' : 'pool',
        code: l.id,
        name: l.company || l.name,
        owner: l.owner || '',
        ownerId: l.ownerId ?? null,
        status: l.statusRaw || l.status || '',
        detail: leadDetail(l)
      })
    }
  }

  return out
}

const TYPE_LABEL = {
  customer: '客户档案',
  lead: '在跟线索',
  pool: '线索池',
  duplicate: '重复线索'
}

export function conflictTypeLabel(type) {
  return TYPE_LABEL[type] || '重复'
}

function normalizeItem(item, row) {
  return {
    leadId: item.leadId ?? row?.id ?? '',
    leadName: item.leadName || row?.company || '',
    type: item.type || 'lead',
    code: item.code || item.id || '',
    name: item.name || row?.company || '',
    owner: item.owner || '',
    ownerId: item.ownerId ?? null,
    status: item.status || '',
    detail: item.detail || ''
  }
}

/**
 * 核对入口：先问后端，后端不可用就用本地数据。
 * 这是“提示型”调用，任何失败都不应该冒错误 toast，只降级。
 */
export async function checkLeadConflicts(rows = [], ctx = {}) {
  if (!rows.length) return { items: [], source: 'local' }
  try {
    const data = await leadApi.conflicts({
      ids: rows.map((r) => r.id),
      ownerId: ctx.ownerId ?? undefined
    })
    const items = Array.isArray(data) ? data : data?.items
    if (!Array.isArray(items)) throw new Error('unexpected payload')
    const customers = findLocalConflicts(rows, { customers: ctx.customers })
    return { items: [...items.map((it) => normalizeItem(it, rows.find((r) => r.id === it.leadId))), ...customers], source: 'api' }
  } catch {
    return { items: findLocalConflicts(rows, ctx), source: 'local' }
  }
}

/**
 * 目标接收人自己的档案 / 线索不算撞单——分回给本来就负责的人，
 * 只是把线索归位，不该弹一堆红字吓人。
 */
export function filterActiveConflicts(items = [], { ownerId, ownerName } = {}) {
  const id = ownerId === null || ownerId === undefined || ownerId === '' ? '' : String(ownerId)
  const name = ownerName || ''
  return items.filter((c) => {
    if (c.ownerId !== null && c.ownerId !== undefined && id && String(c.ownerId) === id) return false
    if (!c.ownerId && name && c.owner === name) return false
    return true
  })
}

