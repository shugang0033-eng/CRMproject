<template>
  <div class="page">
    <div class="deny card">
      <span class="deny-ico"><AppIcon name="lock" :size="24" /></span>

      <h2>当前角色没有这个页面的访问权限</h2>
      <p class="deny-desc">
        <template v-if="fromPath">你尝试访问 <code>{{ fromPath }}</code>，</template>
        当前登录身份是 <b>{{ roleName }}</b>。如需开通，请联系管理员在「角色管理」中调整该角色的功能权限。
      </p>

      <div class="deny-meta">
        <div class="dm-item">
          <span>登录账号</span>
          <b>{{ user?.name || '—' }} · {{ user?.account || '—' }}</b>
        </div>
        <div class="dm-item">
          <span>所属角色</span>
          <b>{{ roleName }}</b>
        </div>
        <div class="dm-item">
          <span>可用权限</span>
          <b>{{ grantedList().length }} / {{ totalPerms }} 项</b>
        </div>
      </div>

      <div class="deny-modules">
        <span class="dm-label">你可以访问：</span>
        <template v-if="modules.length">
          <button v-for="m in modules" :key="m.path" class="btn btn-sm" type="button" @click="go(m.path)">
            {{ m.label }}
          </button>
        </template>
        <span v-else class="faint">该角色还没有任何页面权限</span>
      </div>

      <div class="deny-actions">
        <button class="btn" type="button" @click="switchAccount">切换演示账号</button>
        <button class="btn btn-primary" type="button" @click="go(landing)">回到我可访问的首页</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppIcon from '@/components/AppIcon.vue'
import { session, logout } from '@/store/session'
import { currentRole, grantedList, firstAllowedPath, can, filterNav } from '@/store/permissions'
import { ALL_PERMISSIONS } from '@/config/permissions'
import { navItems } from '@/config/nav'

const route = useRoute()
const router = useRouter()

const user = computed(() => session.user)
const roleName = computed(() => currentRole.value?.name || user.value?.role || '未知角色')
const fromPath = computed(() => (typeof route.query.from === 'string' ? route.query.from : ''))
const totalPerms = ALL_PERMISSIONS.length
const landing = computed(() => firstAllowedPath())

/** 列出该角色真正能进的页面，给用户一条出路 */
const modules = computed(() =>
  filterNav(navItems)
    .flatMap((item) => (item.children ? item.children : [{ label: item.label, path: item.path, perm: item.perm }]))
    .filter((item) => can(item.perm))
)

function go(path) {
  router.replace(path)
}

async function switchAccount() {
  await logout()
  router.replace('/login')
}
</script>

<style scoped>
.deny {
  max-width: 620px;
  margin: 60px auto;
  padding: 40px 40px 32px;
  text-align: center;
}

.deny-ico {
  width: 56px;
  height: 56px;
  border-radius: 16px;
  display: grid;
  place-items: center;
  margin: 0 auto 20px;
  background: linear-gradient(150deg, #fdf3f1, #fbe7e3);
  border: 1px solid #f6d6d0;
  color: #c0503f;
}

.deny h2 {
  font-size: 18px;
  font-weight: 600;
  color: var(--ink);
  letter-spacing: 0.2px;
}

.deny-desc {
  margin: 10px auto 0;
  max-width: 460px;
  font-size: 13px;
  line-height: 1.85;
  color: var(--muted);
}
.deny-desc code {
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 12px;
  padding: 1px 5px;
  border-radius: 4px;
  background: #f2f4f7;
  color: var(--text);
}
.deny-desc b {
  color: var(--ink);
  font-weight: 600;
}

.deny-meta {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1px;
  margin: 24px 0 20px;
  border: 1px solid var(--line);
  border-radius: var(--radius-sm);
  overflow: hidden;
  background: var(--line-soft);
}
.dm-item {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 12px 8px;
  background: #fcfcfd;
}
.dm-item span {
  font-size: 11.5px;
  color: var(--faint);
}
.dm-item b {
  font-size: 12.8px;
  color: var(--ink);
  font-weight: 550;
}

.deny-modules {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 14px;
  border: 1px dashed var(--line);
  border-radius: var(--radius-sm);
  background: #fafbfc;
}
.dm-label {
  font-size: 12px;
  color: var(--faint);
}
.faint {
  font-size: 12px;
  color: var(--faint);
}

.deny-actions {
  display: flex;
  justify-content: center;
  gap: 10px;
  margin-top: 26px;
}

@media (max-width: 720px) {
  .deny {
    margin: 24px 0;
    padding: 28px 20px 24px;
  }
  .deny-meta {
    grid-template-columns: 1fr;
  }
}
</style>

