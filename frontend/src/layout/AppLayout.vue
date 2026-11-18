<template>
  <div class="shell">
    <!-- ==================== 侧边导航 ==================== -->
    <aside class="side" :class="{ open: sidebarOpen }">
      <div class="side-brand">
        <span class="logo-mark">
          <svg viewBox="0 0 24 24" width="17" height="17" fill="none" aria-hidden="true">
            <path d="M12 2.6 14.1 9l6.6 2.1-6.6 2.1L12 19.6 9.9 13.2 3.3 11.1 9.9 9z" fill="#fff" />
          </svg>
        </span>
        <div class="brand-txt">
          <strong>北辰装配科技</strong>
          <em>BEICHEN ASSEMBLY</em>
        </div>
        <button class="side-close" type="button" @click="sidebarOpen = false">
          <AppIcon name="close" :size="16" />
        </button>
      </div>

      <nav class="side-nav">
        <template v-for="item in menus" :key="item.label">
          <!-- 单项 -->
          <router-link
            v-if="!item.children"
            :to="item.path"
            class="nav-item"
            :class="{ active: navPath === item.path }"
          >
            <AppIcon :name="item.icon" :size="17" />
            <span>{{ item.label }}</span>
            <i v-if="item.badge === 'todo' && todoCounts.total" class="nav-badge" :class="{ hot: todoCounts.overdue }">
              {{ todoCounts.total > 99 ? '99+' : todoCounts.total }}
            </i>
          </router-link>

          <!-- 分组 -->
          <div v-else class="nav-group">
            <button
              type="button"
              class="nav-item parent"
              :class="{ 'group-active': isGroupActive(item), expanded: openGroups.includes(item.label) }"
              @click="toggleGroup(item.label)"
            >
              <AppIcon :name="item.icon" :size="17" />
              <span>{{ item.label }}</span>
              <AppIcon class="chev" name="chevron-down" :size="13" />
            </button>

            <div class="nav-sub" :class="{ show: openGroups.includes(item.label) }">
              <router-link
                v-for="child in item.children"
                :key="child.path"
                :to="child.path"
                class="nav-child"
                :class="{ active: navPath === child.path }"
              >
                {{ child.label }}
              </router-link>
            </div>
          </div>
        </template>
      </nav>

      <div class="side-foot">
        <div v-if="can('contract.view')" class="goal-card">
          <!-- 目标是可配置项（业绩目标页），没配过就只显示真实签约额，不拿示例值算完成率 -->
          <template v-if="targetConfigured">
            <div class="goal-top">
              <span>{{ targetScope.all ? `${QUARTER.label} 业绩目标` : '本部门业绩目标' }}</span>
              <b>{{ goal.pct }}%</b>
            </div>
            <div class="bar"><i :style="{ width: goal.pct + '%' }" /></div>
            <div class="goal-num">
              <span>签约 ¥{{ goal.achieved }} 万</span>
              <span>/ ¥{{ goal.target }} 万</span>
            </div>
          </template>
          <template v-else>
            <div class="goal-top">
              <span>{{ QUARTER.label }} 已签合同</span>
              <b>¥{{ goal.achieved }} 万</b>
            </div>
            <div class="goal-num single">
              <span>目标还没设，去「业绩目标」填一个</span>
            </div>
          </template>
        </div>

        <button class="side-user" type="button" @click="userMenuOpen = !userMenuOpen">
          <UserAvatar :name="user.name" :src="avatarSrc" />
          <div class="su-txt">
            <strong>{{ user.name }}</strong>
            <span>{{ user.role }}</span>
          </div>
          <AppIcon name="more" :size="15" />
        </button>

        <transition name="fade-up">
          <div v-if="userMenuOpen" class="side-user-pop">
            <button v-if="can('dashboard.view')" type="button" @click="go('/dashboard')">
              <AppIcon name="grid" :size="15" /> 回到工作台
            </button>
            <button type="button" @click="go('/settings/profile')">
              <AppIcon name="user" :size="15" /> 个人中心
            </button>
            <div class="pop-sep" />
            <button type="button" class="danger" @click="signOut">
              <AppIcon name="logout" :size="15" /> 退出登录
            </button>
          </div>
        </transition>
      </div>
    </aside>

    <div v-if="sidebarOpen" class="side-mask" @click="sidebarOpen = false" />

    <!-- ==================== 主区域 ==================== -->
    <div class="main">
      <header class="top">
        <div class="top-left">
          <button class="icon-btn menu-btn" type="button" @click="sidebarOpen = true">
            <AppIcon name="layers" :size="17" />
          </button>
          <div class="crumb">
            <span class="faint">{{ route.meta.group || '概览' }}</span>
            <AppIcon name="chevron-right" :size="12" />
            <span class="cur">{{ route.meta.title }}</span>
          </div>
        </div>

        <div class="top-right">
          <!-- 全局搜索：客户 / 线索 / 合同 / 订单 一起搜，Ctrl K 聚焦 -->
          <div v-if="canSearch" class="search-wrap">
            <label class="top-search" :class="{ on: searchOpen && keyword.trim() }">
              <AppIcon name="search" :size="15" />
              <input
                ref="searchInput"
                v-model="keyword"
                type="text"
                autocomplete="off"
                placeholder="搜索客户、线索、合同…"
                @focus="focusSearch"
                @keydown.down.prevent="moveHit(1)"
                @keydown.up.prevent="moveHit(-1)"
                @keydown.enter.prevent="submitHit"
                @keydown.esc="closeSearch()"
                @blur="onSearchBlur"
              />
              <kbd v-if="!keyword">Ctrl K</kbd>
              <button
                v-else
                class="search-clear"
                type="button"
                tabindex="-1"
                @mousedown.prevent
                @click="clearSearch"
              >
                <AppIcon name="close" :size="11" />
              </button>
            </label>

            <transition name="fade-up">
              <div v-if="searchOpen && keyword.trim()" class="search-panel">
                <div v-if="searchError" class="sp-tip">{{ searchError }}</div>
                <div v-if="searchLoading && !searchHits.total" class="sp-tip">正在检索…</div>
                <div v-else-if="!searchHits.total && !searchError" class="sp-empty">
                  没有匹配「{{ keyword.trim() }}」的客户、线索、合同或订单
                </div>

                <template v-if="searchHits.total">
                  <div class="sp-total">
                    找到 <b>{{ searchHits.total }}</b> 条，按 ↑ ↓ 选择，回车打开
                  </div>
                  <div v-for="g in searchHits.groups" :key="g.key" class="sp-group">
                    <button class="sp-group-head" type="button" @click="goGroup(g)">
                      <AppIcon :name="g.icon" :size="12" />
                      <span>{{ g.label }}</span>
                      <em>{{ g.count }}</em>
                      <span class="sp-more" v-if="g.more">还有 {{ g.more }} 条，进模块找 ›</span>
                    </button>
                    <button
                      v-for="item in g.items"
                      :key="item.key"
                      type="button"
                      class="sp-item"
                      :class="{ active: activeHit === item.key }"
                      @mousedown.prevent
                      @mouseenter="activeHit = item.key"
                      @click="goHit(item)"
                    >
                      <span class="sp-title">{{ item.title }}</span>
                      <span class="sp-sub">{{ item.sub }}</span>
                      <span v-if="item.meta" class="sp-meta">{{ item.meta }}</span>
                    </button>
                  </div>
                </template>
              </div>
            </transition>
          </div>

          <div v-if="creates.length" class="dd">
            <button class="btn btn-primary btn-sm create-btn" type="button" @click="toggle('quick')">
              <AppIcon name="plus" :size="14" />
              新建
            </button>
            <transition name="fade-up">
              <div v-if="open === 'quick'" class="panel quick-panel">
                <div class="panel-title">快捷新建</div>
                <button
                  v-for="q in creates"
                  :key="q.path"
                  class="quick-item"
                  type="button"
                  @click="go(q.path)"
                >
                  <span class="qi-icon"><AppIcon :name="q.icon" :size="15" /></span>
                  <span class="qi-txt">
                    <strong>{{ q.label }}</strong>
                    <em>{{ q.desc }}</em>
                  </span>
                </button>
              </div>
            </transition>
          </div>

          <!-- 铃铛只做「今天必须看」的提醒，完整清单在待办页；
               原来是三条写死的演示通知，点了也进不去对应单据 -->
          <div class="dd">
            <button class="icon-btn" type="button" @click="toggle('notif')">
              <AppIcon name="bell" :size="17" />
              <i v-if="todoCounts.overdue || todoCounts.today" class="dot-badge" />
            </button>
            <transition name="fade-up">
              <div v-if="open === 'notif'" class="panel notif-panel">
                <div class="panel-head">
                  <strong>待办提醒</strong>
                  <span class="faint head-cnt">
                    {{ todoCounts.total }} 项待处理<template v-if="todoCounts.overdue">
                      · {{ todoCounts.overdue }} 项逾期</template>
                  </span>
                </div>
                <button
                  v-for="n in urgentNotices"
                  :key="n.key"
                  class="notif-item"
                  type="button"
                  @click="go(n.path)"
                >
                  <span class="tag" :class="`tag-${n.tone}`">{{ n.kind }}</span>
                  <span class="ni-txt">
                    <strong>{{ n.title }}</strong>
                    <em>{{ n.desc }}</em>
                    <i>{{ n.dueText }} · 到期 {{ n.due }}</i>
                  </span>
                </button>
                <p v-if="!urgentNotices.length" class="notif-empty">
                  {{ todoCounts.total ? '没有逾期或今天到期的事项' : '当前没有待处理事项' }}
                </p>
                <div class="panel-foot">
                  <button class="btn-text" type="button" @click="go('/todos')">查看全部待办</button>
                </div>
              </div>
            </transition>
          </div>

          <div class="dd">
            <button class="user-chip" type="button" @click="toggle('user')">
              <UserAvatar :name="user.name" :src="avatarSrc" size="sm" />
              <span>{{ user.name }}</span>
              <AppIcon name="chevron-down" :size="13" />
            </button>
            <transition name="fade-up">
              <div v-if="open === 'user'" class="panel user-panel">
                <div class="up-head">
                  <UserAvatar :name="user.name" :src="avatarSrc" size="lg" />
                  <div>
                    <strong>{{ user.name }}</strong>
                    <span>{{ user.dept }} · {{ user.role }}</span>
                  </div>
                </div>
                <div class="pop-sep" />
                <button type="button" @click="go('/settings/profile')">
                  <AppIcon name="user" :size="15" /> 个人中心
                </button>
                <button v-if="can('target.view')" type="button" @click="go('/settings/targets')">
                  <AppIcon name="target" :size="15" /> 我的业绩目标
                </button>
                <button v-if="can('role.view')" type="button" @click="go('/settings/roles')">
                  <AppIcon name="shield" :size="15" /> 权限与角色
                </button>
                <div class="pop-sep" />
                <button type="button" class="danger" @click="signOut">
                  <AppIcon name="logout" :size="15" /> 退出登录
                </button>
              </div>
            </transition>
          </div>
        </div>
      </header>

      <main class="content">
        <router-view />
      </main>
    </div>

    <ToastHost />
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppIcon from '@/components/AppIcon.vue'
import UserAvatar from '@/components/UserAvatar.vue'
import ToastHost from '@/components/ToastHost.vue'
import { navItems, quickCreate } from '@/config/nav'
import { session, logout } from '@/store/session'
import { avatarSrc, loadProfile, resetProfile } from '@/store/profile'
import { can, filterNav } from '@/store/permissions'
import { useTodos } from '@/composables/useTodos'
import { QUARTER, currentQuarterSummary, loadTargetBase } from '@/composables/useTargetProgress'
import { targetScope } from '@/store/targets'
import { searchAll, loadSearchBook, searchLoading, searchError } from '@/composables/useGlobalSearch'

/* ==================== 实时待办（侧栏徽标 + 铃铛 + 目标卡共用） ==================== */
const { items: todoItems, counts: todoCounts, refresh: refreshTodos } = useTodos()

/* 铃铛里只放「已经逾期或今天到期」的，最多 4 条；完整清单在待办页 */
const urgentNotices = computed(() =>
  todoItems.value.filter((t) => t.bucket === 'overdue' || t.bucket === 'today').slice(0, 4)
)

/* 侧栏目标卡与「设置 › 业绩目标」同一份计算，但固定看当前自然季度：
   页面里切到 Q1 回看历史时，侧栏不该跟着变 */
const targetSummaryRef = computed(() => currentQuarterSummary.value)

const goal = computed(() => {
  const s = targetSummaryRef.value
  return {
    pct: s.pct == null ? 0 : Math.min(100, s.pct),
    achieved: s.achieved == null ? '—' : (s.achieved / 10000).toFixed(1),
    target: (s.target / 10000).toLocaleString('zh-CN', { maximumFractionDigits: 1 })
  }
})

/* 本季度有没有设过目标：没设就只显示真实签约额，不拿示例目标算完成率 */
const targetConfigured = computed(() => targetSummaryRef.value.configured)

const route = useRoute()
const router = useRouter()

const user = computed(() => session.user || { name: '访客', role: '—', dept: '' })

/* 按当前角色过滤菜单 / 快捷入口；通知改用真实待办，不再读演示通知 */
const menus = computed(() => filterNav(navItems))
const creates = computed(() => quickCreate.filter((q) => can(q.perm)))

const sidebarOpen = ref(false)
const userMenuOpen = ref(false)
const open = ref('')

/* 详情页这类不在菜单里的路由，用 meta.navPath 指回它所属的列表页，
   否则左侧菜单会一个都不亮、分组也收起来 */
const navPath = computed(() => route.meta.navPath || route.path)

const openGroups = ref(
  filterNav(navItems)
    .filter((i) => i.children && i.children.some((c) => c.path === navPath.value))
    .map((i) => i.label)
)

const activeGroup = computed(() => {
  const group = menus.value.find((i) => i.children?.some((c) => c.path === navPath.value))
  return group?.label || ''
})

function isGroupActive(item) {
  return item.children?.some((c) => c.path === navPath.value)
}

function toggleGroup(label) {
  const idx = openGroups.value.indexOf(label)
  if (idx > -1) openGroups.value.splice(idx, 1)
  else openGroups.value.push(label)
}

function toggle(name) {
  open.value = open.value === name ? '' : name
  userMenuOpen.value = false
}

function go(path) {
  open.value = ''
  userMenuOpen.value = false
  sidebarOpen.value = false
  if (route.path !== path) router.push(path)
}

/**
 * 全局搜索
 * ------------------------------------------------------------
 * 原来这里只有 router.push('/customers')，关键词被丢掉，Ctrl K 也只是装饰。
 * 现在：输入即搜（客户/线索/合同/订单），↑↓ 选、回车开、Esc 关。
 * 点结果不是跳模块首页，而是带着 keyword 进对应列表，落地的还是那一条。
 */
const keyword = ref('')
const searchOpen = ref(false)
const activeHit = ref('')
const searchInput = ref(null)

const canSearch = computed(() =>
  ['customer.view', 'lead.view', 'contract.view', 'order.view'].some((p) => can(p))
)

const searchHits = computed(() => searchAll(keyword.value))

/* 键盘上下移动要在所有分组里连续走，所以摊平一份带顺序的命中列表 */
const flatHits = computed(() => searchHits.value.groups.flatMap((g) => g.items))

function focusSearch() {
  searchOpen.value = true
  loadSearchBook({ force: true })
}

watch(keyword, (value) => {
  activeHit.value = ''
  if (value.trim() && document.activeElement === searchInput.value) openSearch()
})

function openSearch() {
  searchOpen.value = true
  if (!searchHits.value.groups.length) loadSearchBook({}).catch(() => {})
  if (!activeHit.value && flatHits.value.length) activeHit.value = flatHits.value[0].key
}

function moveHit(delta) {
  if (!flatHits.value.length) return
  const i = flatHits.value.findIndex((h) => h.key === activeHit.value)
  const next = i < 0 ? 0 : (i + delta + flatHits.value.length) % flatHits.value.length
  activeHit.value = flatHits.value[next].key
}

function goHit(item) {
  if (!item) return
  router.push({ path: item.path, query: { keyword: item.keyword || keyword.value.trim() } })
  keyword.value = ''
  activeHit.value = ''
  searchOpen.value = false
  searchInput.value?.blur()
}

function goGroup(g) {
  router.push({ path: g.path, query: { keyword: keyword.value.trim() } })
  keyword.value = ''
  searchOpen.value = false
  searchInput.value?.blur()
}

function submitHit(event) {
  if (event.isComposing || event.keyCode === 229) return
  openSearch()
  const hit = flatHits.value.find((h) => h.key === activeHit.value) || flatHits.value[0]
  if (hit) goHit(hit)
}

function clearSearch() {
  keyword.value = ''
  activeHit.value = ''
  searchInput.value?.focus()
}

function closeSearch() {
  searchOpen.value = false
  activeHit.value = ''
}

/* 结果要能点：先让 mousedown 走完再收面板，否则点不到 */
function onSearchBlur() {
  setTimeout(() => {
    searchOpen.value = false
  }, 160)
}

/* Ctrl/Cmd + K 聚焦搜索框，这是顶栏一直画着却没人接的快捷键 */
function onHotkey(e) {
  if ((e.ctrlKey || e.metaKey) && String(e.key).toLowerCase() === 'k') {
    e.preventDefault()
    searchInput.value?.focus()
    openSearch()
  }
}

async function signOut() {
  await logout()
  resetProfile()
  router.replace('/login')
}

function onDocClick(e) {
  if (!e.target.closest('.dd')) open.value = ''
  if (!e.target.closest('.side-foot')) userMenuOpen.value = false
}

watch(
  () => route.fullPath,
  () => {
    sidebarOpen.value = false
    open.value = ''
    userMenuOpen.value = false
    // 跳页后搜索面板必须收掉，否则会悬在新页面上遮内容
    searchOpen.value = false
    activeHit.value = ''
    keyword.value = ''
    if (activeGroup.value && !openGroups.value.includes(activeGroup.value)) {
      openGroups.value.push(activeGroup.value)
    }
  }
)

onMounted(() => {
  document.addEventListener('mousedown', onDocClick)
  window.addEventListener('keydown', onHotkey)
  // 头像来自个人资料，进入应用就先取一次，保证侧栏/顶栏一致
  loadProfile()
  // 待办一次聚合，侧栏徽标与铃铛共用；失败不打断页面
  refreshTodos().catch(() => {})
  /* 目标本身只需要 target.view；完成额要不要得到由 loadTargetBase 内部按 contract.view 自己判断，
     不能因为它在这儿整段跳过——市场专员有目标却看不到，会显示成「还没给你设目标」 */
  if (can('target.view')) loadTargetBase().catch(() => {})
})
onBeforeUnmount(() => {
  document.removeEventListener('mousedown', onDocClick)
  window.removeEventListener('keydown', onHotkey)
})
</script>

<style scoped>
.shell {
  display: flex;
  min-height: 100vh;
  background: var(--bg);
}

/* ==================== 侧栏 ==================== */
.side {
  position: sticky;
  top: 0;
  display: flex;
  flex-direction: column;
  width: var(--nav-w);
  height: 100vh;
  flex-shrink: 0;
  background: linear-gradient(180deg, #17293f 0%, #101d2f 62%, #0d1826 100%);
  border-right: 1px solid rgba(255, 255, 255, 0.06);
  z-index: 40;
}

.side-brand {
  display: flex;
  align-items: center;
  gap: 10px;
  height: var(--top-h);
  padding: 0 16px;
  flex-shrink: 0;
}

.logo-mark {
  width: 30px;
  height: 30px;
  border-radius: 9px;
  display: grid;
  place-items: center;
  background: linear-gradient(150deg, #3d7fc4, #1c4c80);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.22), 0 4px 12px rgba(6, 18, 32, 0.4);
  flex-shrink: 0;
}

.brand-txt {
  display: flex;
  flex-direction: column;
  line-height: 1.3;
  overflow: hidden;
}
.brand-txt strong {
  font-size: 14px;
  font-weight: 600;
  color: #fff;
  letter-spacing: 0.4px;
  white-space: nowrap;
}
.brand-txt em {
  font-style: normal;
  font-size: 8.5px;
  letter-spacing: 2px;
  color: rgba(255, 255, 255, 0.34);
}

.side-close {
  display: none;
  margin-left: auto;
  border: none;
  background: transparent;
  color: rgba(255, 255, 255, 0.6);
  cursor: pointer;
  padding: 4px;
}

.side-nav {
  flex: 1;
  overflow-y: auto;
  padding: 10px 0 16px;
}
.side-nav::-webkit-scrollbar {
  width: 4px;
}
.side-nav::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.12);
}

.nav-item {
  display: flex;
  align-items: center;
  gap: 10px;
  width: calc(100% - 20px);
  margin: 1px 10px;
  height: 38px;
  padding: 0 10px;
  border: none;
  border-radius: 8px;
  background: transparent;
  color: rgba(255, 255, 255, 0.66);
  font-size: 13.5px;
  font-weight: 450;
  letter-spacing: 0.2px;
  cursor: pointer;
  text-align: left;
  transition: background 0.15s, color 0.15s;
  text-decoration: none;
}

.nav-item:hover {
  background: rgba(255, 255, 255, 0.06);
  color: #fff;
}

.nav-item.active {
  background: rgba(79, 147, 214, 0.2);
  color: #fff;
  font-weight: 500;
  box-shadow: inset 2px 0 0 #58a0dd;
}

.nav-item.parent {
  justify-content: flex-start;
}

/* 待办条数徽标：有逾期时变红，提醒真的有事 */
.nav-badge {
  margin-left: auto;
  min-width: 18px;
  height: 17px;
  padding: 0 5px;
  border-radius: 9px;
  background: rgba(255, 255, 255, 0.14);
  color: rgba(255, 255, 255, 0.86);
  font-size: 10.5px;
  font-style: normal;
  font-weight: 600;
  line-height: 17px;
  text-align: center;
  font-variant-numeric: tabular-nums;
}
.nav-badge.hot {
  background: #c9403a;
  color: #fff;
}
.nav-item.parent.group-active {
  color: #fff;
}
.nav-item.parent .chev {
  margin-left: auto;
  opacity: 0.5;
  transition: transform 0.2s ease;
}
.nav-item.parent.expanded .chev {
  transform: rotate(180deg);
}

.nav-sub {
  max-height: 0;
  overflow: hidden;
  margin: 0 10px 0 20px;
  transition: max-height 0.24s ease;
}
.nav-sub.show {
  max-height: 280px;
}

.nav-child {
  display: flex;
  align-items: center;
  height: 33px;
  padding: 0 10px 0 18px;
  border-radius: 7px;
  color: rgba(255, 255, 255, 0.52);
  font-size: 13px;
  text-decoration: none;
  position: relative;
  transition: color 0.14s, background 0.14s;
}
.nav-child + .nav-child {
  margin-top: 1px;
}
.nav-child:hover {
  color: rgba(255, 255, 255, 0.9);
  background: rgba(255, 255, 255, 0.05);
}
.nav-child.active {
  color: #fff;
  background: rgba(255, 255, 255, 0.09);
  font-weight: 500;
}
.nav-child.active::before {
  content: '';
  position: absolute;
  left: 6px;
  top: 50%;
  transform: translateY(-50%);
  width: 3px;
  height: 13px;
  border-radius: 2px;
  background: #58a0dd;
}

/* 侧栏底部 */
.side-foot {
  position: relative;
  padding: 12px 12px 14px;
  border-top: 1px solid rgba(255, 255, 255, 0.07);
  flex-shrink: 0;
}

.goal-card {
  padding: 11px 12px;
  border-radius: 9px;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.07);
  margin-bottom: 10px;
}
.goal-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 11.5px;
  color: rgba(255, 255, 255, 0.5);
  margin-bottom: 8px;
}
.goal-top b {
  color: #9fc6f0;
  font-size: 12.5px;
  font-variant-numeric: tabular-nums;
}
.goal-card .bar {
  height: 4px;
  background: rgba(255, 255, 255, 0.1);
}
.goal-card .bar > i {
  background: linear-gradient(90deg, #4b8ac9, #8cbde9);
}
.goal-num {
  display: flex;
  justify-content: space-between;
  margin-top: 6px;
  font-size: 10.5px;
  color: rgba(255, 255, 255, 0.34);
  font-variant-numeric: tabular-nums;
}
.goal-num.single {
  display: block;
  line-height: 1.5;
}

.side-user {
  display: flex;
  align-items: center;
  gap: 9px;
  width: 100%;
  padding: 7px 8px;
  border: none;
  background: transparent;
  border-radius: 8px;
  cursor: pointer;
  color: rgba(255, 255, 255, 0.55);
  text-align: left;
}
.side-user:hover {
  background: rgba(255, 255, 255, 0.06);
}
.su-txt {
  display: flex;
  flex-direction: column;
  line-height: 1.35;
  overflow: hidden;
  flex: 1;
}
.su-txt strong {
  font-size: 12.5px;
  color: #fff;
  font-weight: 550;
}
.su-txt span {
  font-size: 10.5px;
  color: rgba(255, 255, 255, 0.4);
}

.side-user-pop {
  position: absolute;
  left: 12px;
  right: 12px;
  bottom: 62px;
  padding: 5px;
  border-radius: 10px;
  background: #1b2d44;
  border: 1px solid rgba(255, 255, 255, 0.1);
  box-shadow: 0 16px 36px rgba(0, 0, 0, 0.4);
  z-index: 60;
}
.side-user-pop button,
.user-panel button {
  display: flex;
  align-items: center;
  gap: 9px;
  width: 100%;
  padding: 8px 9px;
  border: none;
  background: transparent;
  border-radius: 7px;
  font-size: 12.5px;
  color: rgba(255, 255, 255, 0.75);
  cursor: pointer;
  text-align: left;
}
.side-user-pop button:hover {
  background: rgba(255, 255, 255, 0.08);
  color: #fff;
}
.side-user-pop button.danger {
  color: #f0a29c;
}
.side-user-pop .pop-sep {
  height: 1px;
  margin: 4px 2px;
  background: rgba(255, 255, 255, 0.08);
}

/* ==================== 主区 ==================== */
.main {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
}

.top {
  position: sticky;
  top: 0;
  z-index: 30;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  height: var(--top-h);
  padding: 0 26px;
  background: rgba(255, 255, 255, 0.9);
  backdrop-filter: saturate(180%) blur(12px);
  border-bottom: 1px solid var(--line);
  flex-shrink: 0;
}

.top-left {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
}

.menu-btn {
  display: none;
}

.crumb {
  display: flex;
  align-items: center;
  gap: 7px;
  font-size: 12.5px;
  color: var(--faint);
}
.crumb .cur {
  color: var(--ink);
  font-weight: 550;
  font-size: 13px;
}

.top-right {
  display: flex;
  align-items: center;
  gap: 10px;
}

.top-search {
  position: relative;
  display: flex;
  align-items: center;
  width: 236px;
}
.top-search > svg {
  position: absolute;
  left: 10px;
  color: var(--faint);
  pointer-events: none;
}
.top-search input {
  width: 100%;
  height: 34px;
  padding: 0 42px 0 32px;
  border: 1px solid transparent;
  border-radius: 8px;
  background: #f3f5f8;
  font-size: 12.5px;
  font-family: inherit;
  color: var(--ink);
  outline: none;
  transition: all 0.16s;
}
.top-search input::placeholder {
  color: #a7aeba;
}
.top-search input:focus {
  background: #fff;
  border-color: var(--brand);
  box-shadow: 0 0 0 3px rgba(43, 108, 176, 0.1);
}
.top-search kbd {
  position: absolute;
  right: 8px;
  font-family: inherit;
  font-size: 10px;
  color: #a7aeba;
  background: #fff;
  border: 1px solid var(--line);
  border-radius: 4px;
  padding: 1px 4px;
  line-height: 1.3;
}

/* ==================== 全局搜索结果 ==================== */
.search-wrap {
  position: relative;
}
.search-clear {
  position: absolute;
  right: 6px;
  display: grid;
  place-items: center;
  width: 18px;
  height: 18px;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: #dfe4ea;
  color: #6b7280;
  cursor: pointer;
}
.search-clear:hover {
  background: #cfd6de;
  color: var(--ink);
}
.search-panel {
  position: absolute;
  top: calc(100% + 6px);
  right: 0;
  z-index: 60;
  width: 400px;
  max-height: 430px;
  overflow-y: auto;
  padding: 6px;
  background: #fff;
  border: 1px solid var(--line);
  border-radius: 10px;
  box-shadow: 0 14px 34px rgba(15, 23, 42, 0.14);
}
.sp-total {
  padding: 5px 9px 7px;
  font-size: 11px;
  color: var(--faint);
}
.sp-total b {
  color: var(--ink);
}
.sp-tip,
.sp-empty {
  padding: 16px 10px;
  font-size: 12px;
  color: var(--faint);
  text-align: center;
  line-height: 1.6;
}
.sp-group + .sp-group {
  margin-top: 2px;
  border-top: 1px solid #f1f3f7;
  padding-top: 2px;
}
.sp-group-head {
  display: flex;
  align-items: center;
  gap: 5px;
  width: 100%;
  padding: 6px 9px 4px;
  border: 0;
  background: none;
  font-family: inherit;
  font-size: 11px;
  color: var(--faint);
  text-align: left;
  cursor: pointer;
}
.sp-group-head:hover {
  color: var(--brand);
}
.sp-group-head em {
  font-style: normal;
  font-size: 10.5px;
  color: #8a93a0;
  background: #f3f5f8;
  border-radius: 20px;
  padding: 0 5px;
}
.sp-more {
  margin-left: auto;
  font-size: 10.5px;
  color: #9aa3b0;
}
.sp-item {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 1px 8px;
  width: 100%;
  padding: 6px 9px;
  border: 0;
  border-radius: 7px;
  background: none;
  font-family: inherit;
  text-align: left;
  cursor: pointer;
}
.sp-item.active {
  background: #eef4fb;
}
.sp-title {
  grid-column: 1;
  font-size: 12.5px;
  font-weight: 600;
  color: var(--ink);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.sp-sub {
  grid-column: 1;
  font-size: 11px;
  color: var(--faint);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.sp-meta {
  grid-row: 1 / span 2;
  grid-column: 2;
  align-self: center;
  padding: 2px 6px;
  border-radius: 4px;
  background: #f3f5f8;
  font-size: 10.5px;
  color: #6b7280;
  white-space: nowrap;
}

.icon-btn {
  position: relative;
  width: 34px;
  height: 34px;
  display: grid;
  place-items: center;
  border: 1px solid transparent;
  background: transparent;
  border-radius: 8px;
  color: var(--muted);
  cursor: pointer;
  transition: all 0.15s;
}
.icon-btn:hover {
  background: #f3f5f8;
  color: var(--ink);
}

.dot-badge {
  position: absolute;
  top: 8px;
  right: 8px;
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #d92d20;
  border: 1.5px solid #fff;
}

.create-btn {
  height: 34px;
  padding: 0 12px;
}

.user-chip {
  display: flex;
  align-items: center;
  gap: 7px;
  height: 34px;
  padding: 0 8px 0 5px;
  border: 1px solid transparent;
  background: transparent;
  border-radius: 8px;
  color: var(--text);
  font-size: 12.5px;
  cursor: pointer;
  transition: all 0.15s;
}
.user-chip:hover {
  background: #f3f5f8;
}

/* 下拉面板 */
.dd {
  position: relative;
}

.panel {
  position: absolute;
  right: 0;
  top: calc(100% + 9px);
  width: 268px;
  background: #fff;
  border: 1px solid var(--line);
  border-radius: 12px;
  box-shadow: 0 18px 44px rgba(16, 24, 40, 0.14);
  padding: 6px;
  z-index: 60;
}

.panel-title {
  padding: 7px 9px 6px;
  font-size: 11px;
  letter-spacing: 0.6px;
  color: var(--faint);
  text-transform: uppercase;
}

.panel-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 9px;
  border-bottom: 1px solid var(--line-soft);
  margin-bottom: 4px;
}
.panel-head strong {
  font-size: 13px;
  color: var(--ink);
}

.panel-foot {
  border-top: 1px solid var(--line-soft);
  margin-top: 4px;
  padding: 8px 9px 4px;
  text-align: center;
}

.quick-item,
.notif-item {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  width: 100%;
  padding: 8px 9px;
  border: none;
  background: transparent;
  border-radius: 8px;
  cursor: pointer;
  text-align: left;
}
.quick-item:hover,
.notif-item:hover {
  background: #f6f8fa;
}

.qi-icon {
  width: 28px;
  height: 28px;
  border-radius: 7px;
  display: grid;
  place-items: center;
  background: var(--brand-soft);
  color: var(--brand);
  flex-shrink: 0;
}
.qi-txt,
.ni-txt {
  display: flex;
  flex-direction: column;
  line-height: 1.45;
  min-width: 0;
}
.qi-txt strong,
.ni-txt strong {
  font-size: 12.8px;
  color: var(--ink);
  font-weight: 550;
}
.qi-txt em,
.ni-txt em {
  font-style: normal;
  font-size: 11.5px;
  color: var(--faint);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ni-txt i {
  font-style: normal;
  font-size: 11px;
  color: #b6bdc9;
  margin-top: 2px;
}
.notif-item .tag {
  margin-top: 2px;
  flex-shrink: 0;
}
.notif-panel {
  width: 336px;
}
.head-cnt {
  font-size: 11.5px;
}
.notif-empty {
  padding: 18px 10px;
  text-align: center;
  font-size: 12px;
  color: var(--faint);
}

.user-panel {
  width: 232px;
}
.up-head {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 9px;
}
.up-head div {
  display: flex;
  flex-direction: column;
  line-height: 1.4;
}
.up-head strong {
  font-size: 13px;
  color: var(--ink);
}
.up-head span {
  font-size: 11.5px;
  color: var(--faint);
}
.user-panel button {
  color: var(--text);
  font-size: 12.8px;
}
.user-panel button:hover {
  background: #f6f8fa;
}
.user-panel button.danger {
  color: var(--danger);
}
.pop-sep {
  height: 1px;
  margin: 4px 2px;
  background: var(--line-soft);
}

.content {
  flex: 1;
  min-width: 0;
}

/* 过渡 */
.fade-up-enter-active,
.fade-up-leave-active {
  transition: opacity 0.16s ease, transform 0.16s ease;
}
.fade-up-enter-from,
.fade-up-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}

.page-enter-active,
.page-leave-active {
  transition: opacity 0.18s ease;
}
.page-enter-from,
.page-leave-to {
  opacity: 0;
}

/* ==================== 响应式 ==================== */
@media (max-width: 1080px) {
  .top-search {
    display: none;
  }
}

@media (max-width: 900px) {
  .side {
    position: fixed;
    left: 0;
    top: 0;
    transform: translateX(-100%);
    transition: transform 0.24s cubic-bezier(0.22, 1, 0.36, 1);
    box-shadow: 0 0 40px rgba(0, 0, 0, 0.3);
  }
  .side.open {
    transform: none;
  }
  .side-mask {
    position: fixed;
    inset: 0;
    background: rgba(16, 24, 40, 0.4);
    z-index: 35;
  }
  .menu-btn {
    display: grid;
  }
  .side-close {
    display: grid;
    place-items: center;
  }
  .top {
    padding: 0 14px;
  }
  .user-chip span {
    display: none;
  }
}
</style>

