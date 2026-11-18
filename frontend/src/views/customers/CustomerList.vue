<template>
  <div class="page">
    <PageHead title="客户列表" desc="门店、经销商与主机厂客户的档案与累计下单，点客户名进入 360 视图；「已成交」按订单与合同判定，不看人工标记">
      <button class="btn" type="button" @click="toast('已导出客户列表（演示）')">
        <AppIcon name="download" :size="14" />导出
      </button>
      <button v-can="'customer.create'" class="btn btn-primary" type="button" @click="openCreate">
        <AppIcon name="plus" :size="14" />新建客户
      </button>
    </PageHead>

    <div class="card">
      <div class="tabs">
        <button
          v-for="tab in tabs"
          :key="tab.value"
          class="tab"
          :class="{ active: status === tab.value }"
          type="button"
          @click="status = tab.value"
        >
          {{ tab.label }}<span class="tab-count">{{ tab.count }}</span>
        </button>
      </div>

      <div class="toolbar">
        <div class="search">
          <AppIcon name="search" :size="15" />
          <input v-model="keyword" class="input" type="text" placeholder="客户名称 / 编号 / 联系人姓名手机号" />
        </div>
        <select v-model="industry" class="select">
          <option value="">全部客户类型</option>
          <option v-for="i in industries" :key="i">{{ i }}</option>
        </select>
        <select v-model="level" class="select">
          <option value="">全部等级</option>
          <option>战略客户</option>
          <option>A 类</option>
          <option>B 类</option>
          <option>C 类</option>
        </select>
        <select v-model="owner" class="select">
          <option value="">全部负责人</option>
          <option v-for="o in owners" :key="o">{{ o }}</option>
        </select>
        <div class="spacer" />
        <span v-if="!ordersReady" class="faint sum">订单数据无权限，金额与状态暂时无法统计</span>
        <span v-else class="faint sum">
          累计下单 ¥{{ totalAmount.toLocaleString() }} · 已成交 {{ dealCount }} 家
        </span>
      </div>

      <AppTable :columns="columns" :rows="filtered" :page-size="8">
        <template #cell-name="{ row }">
          <div class="cust">
            <span class="cust-logo" :style="{ background: logoBg(row.name) }">{{ row.name.slice(0, 1) }}</span>
            <div>
              <button class="cell-main link" type="button" @click="goDetail(row)">{{ row.name }}</button>
              <div class="cell-sub">
                {{ row.code || `ID ${row.id}` }}
                <template v-if="row.createdAt"> · 建档 {{ row.createdAt }}</template>
              </div>
            </div>
          </div>
        </template>
        <template #cell-industry="{ row }">
          <span class="nowrap">{{ row.industry }}</span>
        </template>
        <template #cell-amount="{ row }">
          <div>
            <div class="num">{{ ordersReady ? `¥${row.amount.toLocaleString()}` : '—' }}</div>
            <div class="cell-sub">
              {{ row.orders ? `${row.orders} 单` : '未成交' }}
              <span v-if="row.overdue" class="overdue">· 逾期 ¥{{ wan(row.overdue) }} 万</span>
              <span v-else-if="row.receivable" class="faint">· 应收 ¥{{ wan(row.receivable) }} 万</span>
            </div>
          </div>
        </template>
        <template #cell-level="{ row }">
          <span class="tag" :class="levelTone(row.level)">{{ row.level }}</span>
        </template>
        <template #cell-owner="{ row }">
          <span class="row-tight">
            <UserAvatar :name="row.owner" size="sm" />
            <span>{{ row.owner }}</span>
          </span>
        </template>
        <template #cell-contacts="{ row }">
          <span class="num">{{ row.contacts }}</span>
        </template>
        <template #cell-status="{ row }">
          <span class="tag" :class="statusTone[row.status]">{{ row.status }}</span>
        </template>
        <template #cell-ops="{ row }">
          <div class="row-tight ops">
            <button class="btn-text" type="button" @click="goDetail(row)">详情</button>
            <button class="btn-text" type="button" @click="toast(`为「${row.name}」新增跟进记录`)">
              跟进
            </button>
            <!-- 客户归属变更 = 离职交接 / 区域调整，销售不能自己转 -->
            <button
              v-can="'lead.transfer'"
              class="btn-text"
              type="button"
              title="把客户改派给其他人（销售离职交接、区域调整）"
              @click="openTransfer(row)"
            >
              转负责人
            </button>
          </div>
        </template>
      </AppTable>
    </div>

    <!-- 转移客户负责人：与线索转移是同一个管理动作，权限点也统一用 lead.transfer -->
    <ModalDialog
      v-model="transferOpen"
      title="转移客户负责人"
      desc="联系人、跟进记录与合同全部保留，只把门店负责人换成另一个人；原负责人转为只读可见"
      ok-text="确认转交"
      @confirm="submitTransfer"
    >
      <div v-if="transferRow" class="tr-box">
        <div class="tr-line">
          <span class="tr-label">客户</span>
          <strong>{{ transferRow.name }}</strong>
          <span class="faint">{{ transferRow.id }} · {{ transferRow.level }} · {{ transferRow.industry }}</span>
        </div>
        <div class="tr-flow">
          <div class="tr-who">
            <span class="tr-label">当前负责人</span>
            <div class="tr-who-body">
              <UserAvatar :name="transferRow.owner" size="sm" />
              <strong>{{ transferRow.owner }}</strong>
              <span class="faint">在跟 {{ transferRow.contacts }} 位联系人</span>
            </div>
          </div>
          <span class="tr-arrow"><AppIcon name="arrow-right" :size="15" /></span>
          <div class="tr-who to">
            <span class="tr-label">转给</span>
            <div class="tr-who-body">
              <UserAvatar v-if="target" :name="target.name" size="sm" />
              <span v-else class="tr-ph"><AppIcon name="user" :size="12" /></span>
              <strong :class="{ pending: !target }">{{ target?.name || '待选择' }}</strong>
            </div>
          </div>
        </div>
        <div class="field">
          <label class="label">接收人<span class="req">*</span></label>
          <AssigneePicker
            v-model="transferForm.owner"
            :employees="transferEmployees"
            :departments="deptOptions"
            :loading="employeeStore.loading && !assignableEmployees.length"
            :error="employeeStore.error"
            default-dept="销售部"
            hide-foot
            placeholder="搜索姓名 / 工号"
            @retry="loadEmployees"
          />
        </div>
        <div class="field">
          <label class="label">转交原因</label>
          <select v-model="transferForm.reason" class="select">
            <option v-for="r in TRANSFER_REASONS" :key="r">{{ r }}</option>
          </select>
        </div>
      </div>
    </ModalDialog>

    <!-- ==================== 新建客户 ====================
         只收「人填的」字段：编号、状态、累计金额都是系统生成的，建档时不可能有。
         负责人默认自己，主管可以在建档时直接指定（省掉「先建再转」那一步）。 -->
    <ModalDialog
      v-model="createOpen"
      title="新建客户"
      desc="客户编号由系统生成，初始状态「跟进中」；成交与否由订单和合同自动判定"
      ok-text="创建客户"
      :loading="creating"
      @confirm="submitCreate"
    >
      <div class="edit-sec">
        <div class="edit-sec-title">基础资料</div>
        <div class="form-grid">
          <div class="field">
            <label class="label">客户名称<span class="req">*</span></label>
            <input
              v-model="createForm.name"
              class="input"
              type="text"
              maxlength="200"
              placeholder="工商全称，合同和发票都用它"
              @input="checkCreateDupes"
            />
          </div>
          <div class="field">
            <label class="label">客户等级</label>
            <select v-model="createForm.level" class="select">
              <option v-for="l in LEVELS" :key="l">{{ l }}</option>
            </select>
          </div>
          <div class="field">
            <label class="label">客户类型</label>
            <input
              v-model="createForm.industry"
              class="input"
              type="text"
              list="cust-industries"
              placeholder="4S 店 / 连锁汽修 / 物流车队"
            />
            <datalist id="cust-industries">
              <option v-for="i in industries" :key="i" :value="i" />
            </datalist>
          </div>
          <div class="field">
            <label class="label">区域</label>
            <input v-model="createForm.region" class="input" type="text" placeholder="浙江 · 杭州" />
          </div>
          <div class="field">
            <label class="label">联系电话</label>
            <input
              v-model="createForm.phone"
              class="input"
              type="text"
              maxlength="20"
              placeholder="手机号或座机"
              @blur="checkCreateDupes"
            />
          </div>
          <div class="field">
            <label class="label">线索来源</label>
            <select v-model="createForm.source" class="select">
              <option v-for="s in SOURCES" :key="s">{{ s }}</option>
            </select>
          </div>
        </div>
        <div class="field">
          <label class="label">注册地址</label>
          <input v-model="createForm.address" class="input" type="text" maxlength="255" placeholder="选填，签合同与发货会用到" />
        </div>
        <div v-if="createDupes.length" class="warn-line">
          <AppIcon name="flag" :size="12" />
          <span>
            库里已有：{{ createDupes.map((d) => `${d.name}（${d.owner || '无主'}）`).join('、') }}，
            确认不是重复建档？
          </span>
        </div>
      </div>

      <div class="edit-sec">
        <div class="edit-sec-title">
          主联系人
          <span class="tag tiny tag-gray">选填</span>
        </div>
        <div class="form-grid three">
          <div class="field">
            <label class="label">姓名</label>
            <input v-model="createForm.contactName" class="input" type="text" maxlength="100" placeholder="对接人" />
          </div>
          <div class="field">
            <label class="label">职务</label>
            <input v-model="createForm.contactTitle" class="input" type="text" maxlength="64" placeholder="采购经理 / 店长" />
          </div>
          <div class="field">
            <label class="label">手机</label>
            <input
              v-model="createForm.contactPhone"
              class="input"
              type="text"
              maxlength="20"
              placeholder="11 位手机号"
              @blur="checkCreateDupes"
            />
          </div>
        </div>
        <p class="field-note">
          填了联系人，才能在客户列表里按「联系人姓名 / 手机号」搜到这家；不填也能建档，但只能靠公司名找
        </p>
      </div>

      <div class="edit-sec">
        <div class="edit-sec-title">
          商务条件
          <span class="tag tiny" :class="canCredit ? 'tag-info' : 'tag-gray'">
            {{ canCredit ? '可设置' : '只读' }}
          </span>
        </div>
        <div v-if="canCredit" class="form-grid">
          <div class="field">
            <label class="label">账期（天）</label>
            <input v-model.number="createForm.paymentTerm" class="input" type="number" min="0" max="180" />
          </div>
          <div class="field">
            <label class="label">信用额度（元）</label>
            <input v-model.number="createForm.creditLimit" class="input" type="number" min="0" step="1000" />
          </div>
        </div>
        <div v-else class="readonly-grid two">
          <div><span>账期</span><b>现款（0 天）</b></div>
          <div><span>信用额度</span><b>¥0 · 不可赊销</b></div>
        </div>
        <p v-if="canCredit" class="field-note">
          账期 0 = 现款；额度决定能赊多少，可用额度 = 授信 − 已用。拿不准就先留 0，谈成再调
        </p>
        <p v-else class="field-note">
          新客户默认现款、无信用额度；需要赊销请让主管设置账期与额度，否则下单只能全款
        </p>
        <div v-if="canCredit && Number(createForm.creditLimit) > 0" class="warn-line">
          <AppIcon name="flag" :size="12" />
          <span>
            给一家还没下过单的客户授信 ¥{{ Number(createForm.creditLimit || 0).toLocaleString() }}，
            等于允许他先货后款，请确认已核实资质
          </span>
        </div>
      </div>

      <div class="edit-sec">
        <div class="edit-sec-title">归属与状态</div>
        <!-- 销售只能建到自己名下；主管 / 运营可以在建档时直接指派，省掉「先建再转」 -->
        <div v-if="canAssignOwner" class="field">
          <label class="label">负责人</label>
          <select v-model="createForm.owner" class="select">
            <option :value="null">默认归我自己（{{ session.user?.name || '当前登录人' }}）</option>
            <option v-for="e in salesOptions" :key="e.rawId" :value="String(e.rawId)">
              {{ e.name }} · {{ e.dept }}
            </option>
          </select>
          <p class="field-note">
            建档交给谁，后续跟进、业绩就记在谁头上；建完再改要走「转负责人」，会留痕
          </p>
        </div>
        <div class="readonly-grid" :class="{ three: canAssignOwner }">
          <div v-if="!canAssignOwner"><span>负责人</span><b>{{ session.user?.name || '本人' }}</b></div>
          <div><span>初始状态</span><b>跟进中</b></div>
          <div><span>建档时间</span><b>{{ TODAY }}</b></div>
          <div><span>客户编号</span><b>保存后生成</b></div>
        </div>
      </div>

      <div v-if="createAttempted && createIssues.length" class="warn-line">
        <AppIcon name="flag" :size="12" />
        <span>{{ createIssues[0] }}</span>
      </div>
    </ModalDialog>
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import UserAvatar from '@/components/UserAvatar.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import AssigneePicker from '@/components/AssigneePicker.vue'
import { nameColor } from '@/utils/avatar'
import { employeeStore, loadEmployees, assignableEmployees } from '@/store/employees'
import { flattenDepartments } from '@/store/departments'
import { withAssigneeLoad } from '@/composables/useAssigneeLoad'
import { toast } from '@/composables/useToast'
import { customerApi } from '@/api/customers'
import { can } from '@/store/permissions'
import { session } from '@/store/session'
import { todayStr } from '@/utils/date'
import { STATUS_TONE } from '@/utils/customer'

const router = useRouter()
const route = useRoute()

function goDetail(row) {
  router.push(`/customers/${row.id}`)
}

/* 转交会改负责人，必须是响应式的副本，直接改 mock 的常量不会触发重渲染 */
const rows = ref([])
/* 客户名 → 联系人数组，用于「按联系人姓名/手机号搜客户」 */
const contactMap = ref({})
/* 三个交易接口都可能因为权限被拒，拒了就显示「—」，不能显示 0 骗人 */
const ordersReady = true
async function loadCustomers() {
  const [list, contacts] = await Promise.all([customerApi.list(), customerApi.contacts().catch(() => [])])
  const map = {}
  for (const contact of contacts) (map[contact.customer] ||= []).push(contact)
  contactMap.value = map
  rows.value = list.map((row) => ({
    ...row, level: /类$|客户$/.test(row.level) ? row.level : row.level + ' 类',
    lastFollow: row.lastFollowAt?.slice(0, 10) || '—'
  }))
}

const status = ref('')
const keyword = ref('')
const industry = ref('')
const level = ref('')
const owner = ref('')

const owners = computed(() => [...new Set(rows.value.map((c) => c.owner))])
const industries = computed(() => [...new Set(rows.value.map((c) => c.industry))])

const statusTone = STATUS_TONE

function levelTone(l) {
  return l === '战略客户' ? 'tag-brand' : l === 'A 类' ? 'tag-info' : 'tag-gray'
}

/* 客户 logo 底色按客户名取，不再借演示同事的颜色 */
function logoBg(name) {
  return nameColor(name)
}

const columns = [
  { key: 'name', label: '客户名称' },
  { key: 'industry', label: '客户类型', width: '112px' },
  { key: 'level', label: '客户等级', width: '96px' },
  { key: 'owner', label: '负责人', width: '108px' },
  { key: 'contacts', label: '联系人', width: '68px' },
  { key: 'amount', label: '累计下单', width: '152px' },
  { key: 'lastFollow', label: '最近下单', width: '108px' },
  { key: 'status', label: '状态', width: '96px' },
  { key: 'ops', label: '操作', align: 'right', width: '150px' }
]

/* 「已成交」不是一个状态，是「有成交事实」：合作中 + 待回款 + 流失风险都算成交过。
   成交客户不另开菜单，也不丢客户池，就在这个 tab 里看。 */
const tabs = computed(() => [
  { label: '全部客户', value: '', count: rows.value.length },
  { label: '已成交', value: '已成交', count: rows.value.filter((c) => c.hasDeal).length },
  { label: '跟进中', value: '跟进中', count: rows.value.filter((c) => c.status === '跟进中').length },
  { label: '待回款', value: '待回款', count: rows.value.filter((c) => c.status === '待回款').length },
  { label: '流失风险', value: '流失风险', count: rows.value.filter((c) => c.status === '流失风险').length }
])

const filtered = computed(() =>
  rows.value.filter((c) => {
    if (status.value === '已成交') {
      if (!c.hasDeal) return false
    } else if (status.value && c.status !== status.value) return false
    if (industry.value && c.industry !== industry.value) return false
    if (level.value && c.level !== level.value) return false
    if (owner.value && c.owner !== owner.value) return false
    if (keyword.value) {
      const k = keyword.value.trim()
      const hitCustomer = `${c.name}${c.id}`.includes(k)
      /* 联系人离开客户没有意义，所以搜到的是客户，不是一条孤立的联系人 */
      const hitContact = (contactMap.value[c.name] || []).some((x) =>
        `${x.name}${x.phone}`.includes(k)
      )
      if (!hitCustomer && !hitContact) return false
    }
    return true
  })
)

const totalAmount = computed(() => filtered.value.reduce((s, c) => s + c.amount, 0))
const dealCount = computed(() => filtered.value.filter((c) => c.hasDeal).length)
const wan = (v) => (Number(v || 0) / 10000).toFixed(1)

/* ============================================================
 * 转移客户负责人
 * ------------------------------------------------------------
 * 业务上这是离职交接：销售走了，他名下的门店要交给同事。
 * 一线销售没有这个权限（lead.transfer 只发给运营 / 主管 / 总监），
 * 否则两个销售之间互相甩客户，台账就乱了。
 *
 * 接口：POST /api/customers/transfer { ids, ownerId, reason }
 * 后端还没有，先在前端演示生效，toast 里会写明。
 * ============================================================ */
const TRANSFER_REASONS = ['销售离职交接', '区域调整', '客户主动要求更换', '同事协作分摊', '其他']

const transferOpen = ref(false)
const transferRow = ref(null)
const transferForm = reactive({ owner: null, reason: TRANSFER_REASONS[0] })

const deptOptions = computed(() => flattenDepartments())
/* 接收人候选：只给销售岗（顾问 / 经理 / 运营），且排除当前负责人——转给自己没有意义。
   客户交接的对象一定是接手的销售，不会交给超管或财务 */
const transferEmployees = computed(() =>
  withAssigneeLoad(
    assignableEmployees.value.filter(
      (e) => String(e.rawId) !== String(transferRow.value?.ownerId) && (e.role || '').includes('销售')
    ),
    {}
  )
)
const target = computed(
  () => assignableEmployees.value.find((e) => String(e.rawId) === String(transferForm.owner)) || null
)

function openTransfer(row) {
  transferRow.value = row
  transferForm.owner = null
  transferForm.reason = TRANSFER_REASONS[0]
  transferOpen.value = true
  if (!assignableEmployees.value.length) loadEmployees()
}

async function submitTransfer() {
  if (!target.value) {
    toast('请先选择接收人')
    return
  }
  try {
    await customerApi.transfer({
      ids: [transferRow.value.id],
      ownerId: target.value.rawId,
      reason: transferForm.reason
    })
    transferOpen.value = false
    toast(`「${transferRow.value.name}」已转给 ${target.value.name}`)
    await loadCustomers()
  } catch (e) {
    toast(e.message, 'error')
  }
}
/* ============================================================
 * 新建客户
 * ------------------------------------------------------------
 * 建档只要三件事：这家公司叫啥、归谁、能不能赊销。
 * 编号 / 状态 / 累计金额全部由系统生成，表单一律不给填——
 * 能填就等于能编，账就不作数了。
 *
 * 接口：POST /api/customers（后端未实现，当前 405）
 * 失败时不插假行、不关弹窗，明确告知「客户没有保存」。
 * ============================================================ */
const LEVELS = ['战略客户', 'A 类', 'B 类', 'C 类']
const SOURCES = ['官网询盘', '官网表单', '1688 询盘', '汽配展', '汽配城拜访', '电话外呼', '客户转介绍', '其他']
const TODAY = todayStr()

const createOpen = ref(false)
const creating = ref(false)
const createAttempted = ref(false)
const createDupes = ref([])

const createForm = reactive({
  name: '',
  level: 'C 类',
  industry: '',
  region: '',
  phone: '',
  source: '官网询盘',
  address: '',
  contactName: '',
  contactTitle: '',
  contactPhone: '',
  paymentTerm: 0,
  creditLimit: 0,
  owner: null
})

/* 账期与额度决定能不能赊销：只有持 customer.credit 的人能设 */
const canCredit = computed(() => can('customer.credit'))
/* 能不能替别人建档。销售只能建到自己名下，否则等于把客户塞给同事还不让对方知道 */
const canAssignOwner = computed(() => can('lead.transfer'))

/* 待选负责人：只给销售岗。交给财务或超管没有意义，他们不跟单 */
const salesOptions = computed(() =>
  assignableEmployees.value.filter((e) => (e.role || '').includes('销售'))
)

function openCreate() {
  Object.assign(createForm, {
    name: '',
    level: 'C 类',
    industry: '',
    region: '',
    phone: '',
    source: SOURCES[0],
    address: '',
    contactName: '',
    contactTitle: '',
    contactPhone: '',
    paymentTerm: 0,
    creditLimit: 0,
    owner: null
  })
  createDupes.value = []
  createAttempted.value = false
  createOpen.value = true
  if (canAssignOwner.value && !assignableEmployees.value.length) loadEmployees()
}

/* 查重：同名 / 同号都提示，但不硬拦（同名不同主体在汽配行业很常见） */
let dupeTimer = null
function checkCreateDupes() {
  clearTimeout(dupeTimer)
  const name = createForm.name.trim()
  const phone = (createForm.phone || createForm.contactPhone || '').trim()
  if (name.length < 2 && phone.replace(/\D/g, '').length < 7) {
    createDupes.value = []
    return
  }
  dupeTimer = setTimeout(async () => {
    try {
      const res = await customerApi.checkDuplicate({ name, phone })
      createDupes.value = res?.duplicates || []
    } catch {
      createDupes.value = []
    }
  }, 400)
}

const createIssues = computed(() => {
  const issues = []
  const name = createForm.name.trim()
  if (!name) issues.push('客户名称不能为空')
  else if (name.length < 2) issues.push('客户名称至少 2 个字')
  if (createForm.phone && !/^[\d\-+() ]{6,20}$/.test(createForm.phone.trim())) {
    issues.push('联系电话格式不对，只填数字、区号和短横线')
  }
  const cn = createForm.contactName.trim()
  const cp = createForm.contactPhone.trim()
  if (cn && !cp) issues.push('填了联系人姓名就要填手机号，否则这条联系人没用')
  if (cp && !cn) issues.push('填了联系人手机号就要填姓名')
  if (cp && !/^1[3-9]\d{9}$/.test(cp)) issues.push('联系人手机号要 11 位，且以 1 开头')
  if (canCredit.value) {
    const t = Number(createForm.paymentTerm)
    const c = Number(createForm.creditLimit)
    if (!Number.isFinite(t) || t < 0 || t > 180) issues.push('账期要在 0–180 天之间')
    if (!Number.isFinite(c) || c < 0) issues.push('信用额度不能为负数')
  }
  return issues
})

async function submitCreate() {
  if (creating.value) return
  createAttempted.value = true
  if (createIssues.value.length) {
    toast(createIssues.value[0], 'error')
    return
  }

  const body = {
    name: createForm.name.trim(),
    level: createForm.level,
    industry: createForm.industry.trim(),
    region: createForm.region.trim(),
    phone: createForm.phone.trim(),
    source: createForm.source,
    address: createForm.address.trim()
  }
  if (createForm.contactName.trim()) {
    body.contacts = [{
      name: createForm.contactName.trim(),
      title: createForm.contactTitle.trim(),
      phone: createForm.contactPhone.trim(),
      isPrimary: true
    }]
  }
  if (canCredit.value) {
    body.paymentTerm = Number(createForm.paymentTerm) || 0
    body.creditLimit = Number(createForm.creditLimit) || 0
  }
  /* 只有能指派的人传 ownerId；其他人后端一律落当前登录人 */
  if (canAssignOwner.value && createForm.owner) body.ownerId = createForm.owner

  creating.value = true
  try {
    const res = await customerApi.create(body)
    createOpen.value = false
    await loadCustomers()
    toast(`已建档：${body.name}`)
    /* 建完直接进详情页，接着补联系人、写跟进；没有 id 就留在列表 */
    if (res?.id) router.push(`/customers/${res.id}`)
  } catch (error) {
    /* 405 = 后端还没实现：弹窗不关、列表不插假行，用户不会以为建成功了 */
    toast(error.message, 'error')
  } finally {
    creating.value = false
  }
}

/* 从全局搜索跳过来时只留这一条：其它筛选一并清掉，
   否则命中的那条会被某个 tab 藏起来，看着像「搜到了又没搜到」 */
function applyQueryKeyword(v) {
  keyword.value = v ? String(v) : ''
  if (!v) return
  status.value = ''
  industry.value = ''
  level.value = ''
  owner.value = ''
}
applyQueryKeyword(route.query.keyword)
watch(() => route.query.keyword, applyQueryKeyword)

onMounted(() => {
  loadCustomers().catch((e) => toast(e.message, 'error'))
  if (!assignableEmployees.value.length) loadEmployees()
})
</script>

<style scoped>
.cust {
  display: flex;
  align-items: center;
  gap: 10px;
}
.cust-logo {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  color: #fff;
  font-size: 13px;
  font-weight: 600;
  flex-shrink: 0;
  opacity: 0.92;
}
.tab-count {
  display: inline-block;
  margin-left: 5px;
  padding: 0 5px;
  height: 17px;
  line-height: 17px;
  border-radius: 4px;
  background: #f2f4f7;
  color: var(--muted);
  font-size: 11px;
  font-variant-numeric: tabular-nums;
}
.tab.active .tab-count {
  background: var(--brand-soft);
  color: var(--brand);
}
.ops {
  justify-content: flex-end;
}
.link {
  padding: 0;
  border: none;
  background: transparent;
  color: var(--ink);
  font-weight: 550;
  text-align: left;
  cursor: pointer;
}
.link:hover {
  color: var(--brand);
}
.overdue {
  color: var(--danger);
  font-variant-numeric: tabular-nums;
}
.nowrap {
  white-space: nowrap;
}
.sum {
  font-size: 12px;
  font-variant-numeric: tabular-nums;
}

/* 转移弹窗 */
.tr-box {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.tr-line {
  display: flex;
  align-items: baseline;
  gap: 8px;
  padding: 11px 13px;
  border-radius: 10px;
  background: #f7f9fc;
  border: 1px solid var(--line-soft);
  font-size: 13px;
}
.tr-line strong {
  font-size: 14px;
}
.tr-label {
  font-size: 11px;
  color: var(--muted);
}
.tr-flow {
  display: grid;
  grid-template-columns: 1fr 26px 1fr;
  align-items: center;
  gap: 6px;
}
.tr-who {
  border: 1px solid var(--line);
  border-radius: 10px;
  padding: 9px 11px;
  min-width: 0;
}
.tr-who.to {
  border-color: var(--brand-line);
  background: var(--brand-soft);
}
.tr-who-body {
  display: flex;
  align-items: center;
  gap: 7px;
  margin-top: 5px;
  font-size: 13px;
  min-width: 0;
}
.tr-who-body strong {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tr-who-body .faint {
  font-size: 11px;
  margin-left: auto;
  white-space: nowrap;
}
.tr-ph {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  border: 1px dashed var(--line);
  display: grid;
  place-items: center;
  color: var(--muted);
  flex-shrink: 0;
}
.pending {
  color: var(--muted);
  font-weight: 500;
}
.tr-arrow {
  display: grid;
  place-items: center;
  color: var(--muted);
}
.tr-note {
  margin: 0;
  font-size: 12px;
  line-height: 1.6;
  color: var(--muted);
}
</style>

