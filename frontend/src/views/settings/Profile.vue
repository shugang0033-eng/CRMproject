<template>
  <div class="page">
    <PageHead title="个人中心" desc="维护账号资料、登录密码与消息偏好，这里的设置只对你自己生效">
      <button class="btn" type="button" @click="onLogout">
        <AppIcon name="logout" :size="14" />退出登录
      </button>
    </PageHead>

    <!-- 后端接口未就绪时的说明条 -->
    <div v-if="profileState.apiReady === false" class="api-note">
      <span class="an-ico"><AppIcon name="dot" :size="14" /></span>
      <div class="an-txt">
        <strong>个人中心接口尚未接入</strong>
        <p>
          已按契约预留 <code>GET /api/profile</code>、<code>PUT /api/profile</code>、
          <code>POST /api/profile/avatar</code>、<code>POST /api/profile/password</code>、
          <code>GET /api/profile/logins</code>。当前展示本地数据，改动先保存在浏览器，接口就绪后自动切过去。
        </p>
      </div>
    </div>

    <div class="pf-grid">
      <!-- ==================== 左：名片 ==================== -->
      <aside class="pf-side">
        <div class="card pf-card">
          <div class="pf-cover" />
          <div class="pf-body">
            <div class="avatar-wrap">
              <UserAvatar :name="profile.name" :src="avatarSrc" size="xl" />
              <button class="av-edit" type="button" title="更换头像" :disabled="uploading" @click="pickFile">
                <AppIcon :name="uploading ? 'refresh' : 'camera'" :size="13" />
              </button>
              <input
                ref="fileInput"
                class="hidden-file"
                type="file"
                accept="image/png,image/jpeg,image/webp"
                @change="onPickFile"
              />
            </div>

            <h2 class="pf-name">{{ profile.name || '—' }}</h2>
            <p class="pf-sub">{{ roleLine }}</p>

            <div class="pf-tags">
              <span class="tag" :class="profile.status === 'active' ? 'tag-success' : 'tag-gray'">
                {{ profile.status === 'active' ? '在职' : '已停用' }}
              </span>
              <span v-if="usingInitialPassword" class="tag tag-warning">初始密码未修改</span>
            </div>

            <dl class="pf-meta">
              <div>
                <dt>工号</dt>
                <dd>{{ profile.employeeNo || '—' }}</dd>
              </div>
              <div>
                <dt>登录账号</dt>
                <dd>{{ profile.account || '—' }}</dd>
              </div>
              <div>
                <dt>手机</dt>
                <dd>{{ profile.phone || '未填写' }}</dd>
              </div>
              <div>
                <dt>邮箱</dt>
                <dd class="ellipsis">{{ profile.email || '未填写' }}</dd>
              </div>
              <div>
                <dt>入职日期</dt>
                <dd>{{ profile.hireDate || '—' }}</dd>
              </div>
            </dl>

            <button class="btn btn-sm pf-upload" type="button" :disabled="uploading" @click="pickFile">
              <AppIcon name="upload" :size="13" />{{ uploading ? '处理中…' : '上传新头像' }}
            </button>
            <p class="pf-hint">JPG / PNG，建议正方形，不超过 2MB</p>
          </div>
        </div>

        <div class="card sec-card">
          <div class="card-head">
            <div class="card-title"><span class="dot" />账号安全</div>
          </div>
          <div class="sec-body">
            <div class="sec-row">
              <span>密码状态</span>
              <b :class="usingInitialPassword ? 'warn' : 'ok'">
                {{ usingInitialPassword ? '初始密码' : '已修改' }}
              </b>
            </div>
            <div class="sec-row">
              <span>上次修改</span>
              <b>{{ profileState.passwordUpdatedAt ? fmtDate(profileState.passwordUpdatedAt) : '—' }}</b>
            </div>
            <div class="sec-row">
              <span>上次登录</span>
              <b>{{ fmtDate(profile.lastLoginAt) }}</b>
            </div>
            <div v-if="profile.lastLoginIp" class="sec-row">
              <span>登录 IP</span>
              <b>{{ profile.lastLoginIp }}</b>
            </div>
            <p class="sec-tip">
              <AppIcon name="shield" :size="13" />
              定期更换密码，不要与其他系统共用同一套账号密码。
            </p>
          </div>
        </div>
      </aside>

      <!-- ==================== 右：表单区 ==================== -->
      <section class="pf-main">
        <!-- 初始密码提醒 -->
        <div v-if="usingInitialPassword" class="pwd-banner">
          <AppIcon name="lock" :size="16" />
          <div>
            <strong>你正在使用初始密码</strong>
            <p>新账号默认密码为 123456，为了账号安全，请立即在下方修改为自己的密码。</p>
          </div>
        </div>

        <!-- 基本信息 -->
        <div class="card">
          <div class="card-head">
            <div class="card-title"><span class="dot" />基本信息</div>
            <span class="card-sub">工号、部门与角色由管理员维护</span>
          </div>
          <div class="card-body">
            <div class="form-grid">
              <div class="field">
                <label class="label" for="pf-name">姓名 <i class="req">*</i></label>
                <input id="pf-name" v-model.trim="basic.name" class="input" :class="{ error: errs.name }" maxlength="20" />
                <span v-if="errs.name" class="err-msg">{{ errs.name }}</span>
              </div>
              <div class="field">
                <label class="label" for="pf-phone">手机号</label>
                <input
                  id="pf-phone"
                  v-model.trim="basic.phone"
                  class="input"
                  :class="{ error: errs.phone }"
                  maxlength="11"
                  inputmode="numeric"
                  placeholder="用于接收业务提醒"
                />
                <span v-if="errs.phone" class="err-msg">{{ errs.phone }}</span>
              </div>
              <div class="field span-2">
                <label class="label" for="pf-email">邮箱</label>
                <input
                  id="pf-email"
                  v-model.trim="basic.email"
                  class="input"
                  :class="{ error: errs.email }"
                  placeholder="用于接收日报与审批通知"
                />
                <span v-if="errs.email" class="err-msg">{{ errs.email }}</span>
              </div>
              <div class="field">
                <label class="label">工号</label>
                <input class="input" :value="profile.employeeNo || ''" placeholder="由系统生成" readonly />
              </div>
              <div class="field">
                <label class="label">所属部门</label>
                <input class="input" :value="profile.dept || '—'" readonly />
              </div>
              <div class="field">
                <label class="label">角色</label>
                <input class="input" :value="profile.role || '—'" readonly />
              </div>
              <div class="field">
                <label class="label">账号</label>
                <input class="input" :value="profile.account || '—'" readonly />
              </div>
            </div>
            <div class="card-foot">
              <button class="btn" type="button" :disabled="basicSaving" @click="resetBasic">重置</button>
              <button class="btn btn-primary" type="button" :disabled="basicSaving" @click="submitBasic">
                {{ basicSaving ? '保存中…' : '保存修改' }}
              </button>
            </div>
          </div>
        </div>

        <!-- 修改密码 -->
        <div class="card">
          <div class="card-head">
            <div class="card-title"><span class="dot" />修改密码</div>
            <span class="card-sub">修改后下次登录请使用新密码</span>
          </div>
          <div class="card-body">
            <div class="form-grid">
              <div class="field span-2">
                <label class="label" for="pwd-old">当前密码 <i class="req">*</i></label>
                <div class="pwd-wrap">
                  <input
                    id="pwd-old"
                    v-model="pwd.old"
                    class="input"
                    :class="{ error: pwdErrs.old }"
                    :type="visible.old ? 'text' : 'password'"
                    autocomplete="current-password"
                    placeholder="请输入当前使用的密码"
                  />
                  <button class="pwd-eye" type="button" tabindex="-1" @click="visible.old = !visible.old">
                    <AppIcon :name="visible.old ? 'eye-off' : 'eye'" :size="15" />
                  </button>
                </div>
                <span v-if="pwdErrs.old" class="err-msg">{{ pwdErrs.old }}</span>
              </div>
              <div class="field">
                <label class="label" for="pwd-new">新密码 <i class="req">*</i></label>
                <div class="pwd-wrap">
                  <input
                    id="pwd-new"
                    v-model="pwd.next"
                    class="input"
                    :class="{ error: pwdErrs.next }"
                    :type="visible.next ? 'text' : 'password'"
                    autocomplete="new-password"
                    placeholder="至少 8 位，含字母和数字"
                  />
                  <button class="pwd-eye" type="button" tabindex="-1" @click="visible.next = !visible.next">
                    <AppIcon :name="visible.next ? 'eye-off' : 'eye'" :size="15" />
                  </button>
                </div>
                <span v-if="pwdErrs.next" class="err-msg">{{ pwdErrs.next }}</span>
                <div v-if="pwd.next" class="strength">
                  <i v-for="n in 4" :key="n" :class="n <= strength ? levelClass : ''" />
                  <span>{{ strengthText }}</span>
                </div>
              </div>
              <div class="field">
                <label class="label" for="pwd-confirm">确认新密码 <i class="req">*</i></label>
                <div class="pwd-wrap">
                  <input
                    id="pwd-confirm"
                    v-model="pwd.confirm"
                    class="input"
                    :class="{ error: pwdErrs.confirm }"
                    :type="visible.confirm ? 'text' : 'password'"
                    autocomplete="new-password"
                    placeholder="再次输入新密码"
                  />
                  <button class="pwd-eye" type="button" tabindex="-1" @click="visible.confirm = !visible.confirm">
                    <AppIcon :name="visible.confirm ? 'eye-off' : 'eye'" :size="15" />
                  </button>
                </div>
                <span v-if="pwdErrs.confirm" class="err-msg">{{ pwdErrs.confirm }}</span>
              </div>
            </div>

            <ul class="rules">
              <li v-for="r in rules" :key="r.text" :class="{ pass: r.pass }">
                <AppIcon :name="r.pass ? 'check' : 'dot'" :size="13" />{{ r.text }}
              </li>
            </ul>

            <div class="card-foot">
              <button class="btn btn-primary" type="button" :disabled="pwdSaving" @click="submitPassword">
                {{ pwdSaving ? '提交中…' : '确认修改' }}
              </button>
            </div>
          </div>
        </div>

        <!-- 偏好与通知 -->
        <div class="card">
          <div class="card-head">
            <div class="card-title"><span class="dot" />偏好与通知</div>
            <span class="card-sub">仅保存在当前浏览器</span>
          </div>
          <div class="card-body">
            <div class="form-grid">
              <div class="field">
                <label class="label">列表每页条数</label>
                <select v-model.number="prefs.pageSize" class="select">
                  <option :value="10">每页 10 条</option>
                  <option :value="20">每页 20 条</option>
                  <option :value="50">每页 50 条</option>
                </select>
              </div>
              <div class="field">
                <label class="label">日历起始日</label>
                <select v-model="prefs.weekStart" class="select">
                  <option value="周一">周一</option>
                  <option value="周日">周日</option>
                </select>
              </div>
            </div>

            <div class="switch-list">
              <div class="switch-row">
                <div>
                  <strong>站内消息</strong>
                  <span>线索待跟进、合同待审批等提醒</span>
                </div>
                <button class="switch" :class="{ on: prefs.inApp }" type="button" @click="prefs.inApp = !prefs.inApp">
                  <i />
                </button>
              </div>
              <div class="switch-row">
                <div>
                  <strong>邮件通知</strong>
                  <span>每日汇总发送到 {{ profile.email || '未填写邮箱' }}</span>
                </div>
                <button class="switch" :class="{ on: prefs.email }" type="button" @click="prefs.email = !prefs.email">
                  <i />
                </button>
              </div>
              <div class="switch-row">
                <div>
                  <strong>短信提醒</strong>
                  <span>仅在回款逾期等紧急事项时发送</span>
                </div>
                <button class="switch" :class="{ on: prefs.sms }" type="button" @click="prefs.sms = !prefs.sms">
                  <i />
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- 最近登录 -->
        <div class="card">
          <div class="card-head">
            <div class="card-title"><span class="dot" />最近登录</div>
            <button class="btn-text" type="button" @click="reloadLogins">刷新</button>
          </div>
          <div v-if="logins.length" class="table-wrap">
            <table class="table">
              <thead>
                <tr>
                  <th>登录时间</th>
                  <th>设备</th>
                  <th>IP / 地点</th>
                  <th>状态</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in logins" :key="row.id">
                  <td>{{ fmtDate(row.at) }}</td>
                  <td :title="row.device || ''">{{ deviceLabel(row.device) }}</td>
                  <td>{{ row.ip || '—' }}<span v-if="row.location" class="faint"> · {{ row.location }}</span></td>
                  <td>
                    <span class="tag" :class="row.current ? 'tag-success' : 'tag-gray'">
                      {{ row.current ? '当前会话' : '已结束' }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <p v-else class="logins-empty">暂无登录记录。</p>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import UserAvatar from '@/components/UserAvatar.vue'
import { toast } from '@/composables/useToast'
import { logout } from '@/store/session'
import {
  avatarSrc,
  changePassword,
  loadLogins,
  loadProfile,
  profileState,
  resetProfile,
  saveAvatar,
  saveBasic,
  usingInitialPassword
} from '@/store/profile'

const router = useRouter()
const profile = computed(() => profileState.data || {})

/* 后端的 dept 有时直接返回角色名，重复就只显示一次 */
const roleLine = computed(() => {
  const { dept = '', role = '' } = profile.value
  if (dept && role && dept === role) return role
  return [role, dept].filter(Boolean).join(' · ') || '未分配部门'
})

/* ---------------- 基本信息 ---------------- */
const basic = reactive({ name: '', phone: '', email: '' })
const errs = reactive({ name: '', phone: '', email: '' })
const basicSaving = ref(false)

function fillBasic(data) {
  basic.name = data?.name || ''
  basic.phone = data?.phone || ''
  basic.email = data?.email || ''
}

watch(
  () => profileState.data,
  (d) => {
    if (d && !basicSaving.value) fillBasic(d)
  },
  { immediate: true }
)

function resetBasic() {
  fillBasic(profileState.data)
  errs.name = errs.phone = errs.email = ''
}

function validateBasic() {
  errs.name = basic.name ? (basic.name.length > 20 ? '姓名不能超过 20 个字符' : '') : '请填写姓名'
  errs.phone = basic.phone && !/^1[3-9]\d{9}$/.test(basic.phone) ? '请填写 11 位手机号' : ''
  errs.email = basic.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(basic.email) ? '邮箱格式不正确' : ''
  return !errs.name && !errs.phone && !errs.email
}

async function submitBasic() {
  if (!validateBasic()) return
  basicSaving.value = true
  try {
    const { synced } = await saveBasic({
      name: basic.name,
      phone: basic.phone,
      email: basic.email
    })
    toast(synced ? '资料已保存' : '已保存到本地（接口待实现，PUT /api/profile）')
  } catch (err) {
    toast(err.message || '保存失败', 'error')
  } finally {
    basicSaving.value = false
  }
}

/* ---------------- 头像 ---------------- */
const fileInput = ref(null)
const uploading = ref(false)

function pickFile() {
  if (uploading.value) return
  fileInput.value?.click()
}

async function onPickFile(e) {
  const file = e.target.files?.[0]
  e.target.value = ''
  if (!file) return
  if (!/^image\/(png|jpeg|webp)$/.test(file.type)) {
    toast('只支持 JPG / PNG / WEBP 格式的图片', 'error')
    return
  }
  if (file.size > 2 * 1024 * 1024) {
    toast('图片不能超过 2MB', 'error')
    return
  }
  uploading.value = true
  try {
    const dataUrl = await compressImage(file, 240)
    const { synced } = await saveAvatar(dataUrl)
    toast(synced ? '头像已更新' : '头像已更新，暂存本地（接口待实现）')
  } catch (err) {
    toast(err.message || '头像处理失败', 'error')
  } finally {
    uploading.value = false
  }
}

/** 居中裁剪成正方形并压到 240px，避免把原图整张塞进 localStorage / 请求体 */
function compressImage(file, size) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file)
    const img = new Image()
    img.onload = () => {
      const canvas = document.createElement('canvas')
      canvas.width = size
      canvas.height = size
      const ctx = canvas.getContext('2d')
      const side = Math.min(img.width, img.height)
      ctx.drawImage(img, (img.width - side) / 2, (img.height - side) / 2, side, side, 0, 0, size, size)
      URL.revokeObjectURL(url)
      resolve(canvas.toDataURL('image/jpeg', 0.88))
    }
    img.onerror = () => {
      URL.revokeObjectURL(url)
      reject(new Error('图片读取失败，请换一张试试'))
    }
    img.src = url
  })
}

/* ---------------- 修改密码 ---------------- */
const pwd = reactive({ old: '', next: '', confirm: '' })
const pwdErrs = reactive({ old: '', next: '', confirm: '' })
const visible = reactive({ old: false, next: false, confirm: false })
const pwdSaving = ref(false)

const strength = computed(() => {
  const v = pwd.next || ''
  let s = 0
  if (v.length >= 8) s += 1
  if (/[a-zA-Z]/.test(v) && /\d/.test(v)) s += 1
  if (/[^a-zA-Z0-9]/.test(v)) s += 1
  if (v.length >= 12) s += 1
  return v ? s : 0
})

const levelClass = computed(() => ['', 'lv-1', 'lv-2', 'lv-3', 'lv-4'][strength.value])
const strengthText = computed(() => {
  if (!pwd.next) return ''
  return ['太短', '弱', '一般', '较强', '很强'][strength.value]
})

const rules = computed(() => [
  { text: '至少 8 位字符', pass: pwd.next.length >= 8 },
  { text: '同时包含字母和数字', pass: /[a-zA-Z]/.test(pwd.next) && /\d/.test(pwd.next) },
  { text: '不能与当前密码相同', pass: Boolean(pwd.next) && pwd.next !== pwd.old },
  { text: '两次输入一致', pass: Boolean(pwd.confirm) && pwd.next === pwd.confirm }
])

function validatePwd() {
  pwdErrs.old = pwd.old ? '' : '请输入当前密码'
  pwdErrs.next = !pwd.next
    ? '请输入新密码'
    : pwd.next.length < 8
      ? '新密码至少 8 位'
      : pwd.next === pwd.old
        ? '新密码不能与当前密码相同'
        : ''
  pwdErrs.confirm = pwd.confirm === pwd.next ? '' : '两次输入的密码不一致'
  return !pwdErrs.old && !pwdErrs.next && !pwdErrs.confirm
}

async function submitPassword() {
  if (!validatePwd()) return
  pwdSaving.value = true
  try {
    const { synced } = await changePassword({ oldPassword: pwd.old, newPassword: pwd.next })
    if (synced) {
      pwd.old = pwd.next = pwd.confirm = ''
      toast('密码已修改，下次登录请使用新密码')
    } else {
      toast('接口待实现（POST /api/profile/password），密码暂未真正修改', 'error')
    }
  } catch (err) {
    toast(err.message || '密码修改失败', 'error')
  } finally {
    pwdSaving.value = false
  }
}

/* ---------------- 偏好 ---------------- */
const PREFS_KEY = 'crm-prefs'
const prefs = reactive({ pageSize: 10, weekStart: '周一', inApp: true, email: true, sms: false })
try {
  Object.assign(prefs, JSON.parse(localStorage.getItem(PREFS_KEY) || '{}'))
} catch {
  /* 忽略脏数据 */
}
watch(prefs, () => localStorage.setItem(PREFS_KEY, JSON.stringify(prefs)), { deep: true })

/* ---------------- 登录记录 ---------------- */
const logins = ref([])

async function reloadLogins() {
  try {
    const { list } = await loadLogins()
    logins.value = list
  } catch (err) {
    logins.value = []
    toast(err.message || '登录记录加载失败', 'error')
  }
}

/* ---------------- 工具 ---------------- */
function pad(n) {
  return String(n).padStart(2, '0')
}

function fmtDate(iso) {
  if (!iso) return '—'
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}

/* 后端存的是完整 UA，直接铺在表格里会撑两行；这里压成「Chrome 157 · Windows」，
   完整串留在 title 上，鼠标悬停仍可看全 */
function deviceLabel(ua) {
  if (!ua) return '—'
  // curl / Postman 之类的非浏览器客户端，原样保留
  if (!/Mozilla\//i.test(ua)) return ua

  const os = /Windows NT 10/i.test(ua) ? 'Windows'
    : /Windows/i.test(ua) ? 'Windows'
    : /iPhone|iPad/i.test(ua) ? 'iOS'
    : /Android/i.test(ua) ? 'Android'
    : /Mac OS X/i.test(ua) ? 'macOS'
    : /Linux/i.test(ua) ? 'Linux'
    : ''

  let browser = ''
  const edge = ua.match(/Edg(?:e|A|iOS)?\/(\d+)/)
  const chrome = ua.match(/(?:HeadlessChrome|Chrome)\/(\d+)/)
  const firefox = ua.match(/Firefox\/(\d+)/)
  const safari = ua.match(/Version\/(\d+)[.\d]* Safari/)
  if (edge) browser = `Edge ${edge[1]}`
  else if (chrome) browser = `Chrome ${chrome[1]}`
  else if (firefox) browser = `Firefox ${firefox[1]}`
  else if (safari) browser = `Safari ${safari[1]}`
  else browser = '浏览器'

  return [browser, os].filter(Boolean).join(' · ')
}

async function onLogout() {
  await logout()
  resetProfile()
  router.replace('/login')
}

onMounted(async () => {
  await loadProfile(true)
  reloadLogins()
})
</script>

<style scoped>
.pf-grid {
  display: grid;
  grid-template-columns: 296px minmax(0, 1fr);
  gap: 18px;
  align-items: start;
}

@media (max-width: 1080px) {
  .pf-grid {
    grid-template-columns: 1fr;
  }
  .pf-side {
    position: static !important;
  }
}

/* ---------- 接口未就绪提示 ---------- */
.api-note {
  display: flex;
  gap: 10px;
  padding: 12px 16px;
  margin-bottom: 16px;
  border: 1px solid #d8e3f3;
  border-radius: var(--radius-sm);
  background: var(--brand-soft);
}
.an-ico {
  color: var(--brand);
  margin-top: 1px;
}
.an-txt strong {
  font-size: 13px;
  color: var(--brand-700);
}
.an-txt p {
  margin-top: 3px;
  font-size: 12.5px;
  line-height: 1.7;
  color: var(--muted);
}
.an-txt code,
.logins-empty code {
  padding: 1px 5px;
  border-radius: 4px;
  background: rgba(43, 108, 176, 0.1);
  font-size: 12px;
  color: var(--brand-700);
}

/* ---------- 左栏 ---------- */
.pf-side {
  display: flex;
  flex-direction: column;
  gap: 16px;
  position: sticky;
  top: 76px;
}

.pf-card {
  overflow: hidden;
}
.pf-cover {
  height: 72px;
  background: linear-gradient(120deg, var(--brand-900), var(--brand-700) 55%, var(--brand));
}
.pf-body {
  padding: 0 20px 20px;
  text-align: center;
  margin-top: -40px;
}
.avatar-wrap {
  position: relative;
  display: inline-block;
  padding: 4px;
  background: var(--surface);
  border-radius: 50%;
  box-shadow: var(--shadow-sm);
}
.av-edit {
  position: absolute;
  right: 1px;
  bottom: 1px;
  width: 26px;
  height: 26px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  border: 2px solid var(--surface);
  background: var(--brand);
  color: #fff;
  cursor: pointer;
  transition: background 0.16s;
}
.av-edit:hover {
  background: var(--brand-hover);
}
.av-edit[disabled] {
  opacity: 0.6;
  cursor: default;
}
.hidden-file {
  display: none;
}

.pf-name {
  margin-top: 10px;
  font-size: 16.5px;
  font-weight: 650;
  color: var(--ink);
}
.pf-sub {
  margin-top: 4px;
  font-size: 12.5px;
  color: var(--muted);
}
.pf-tags {
  margin-top: 10px;
  display: flex;
  justify-content: center;
  flex-wrap: wrap;
  gap: 6px;
}

.pf-meta {
  margin-top: 16px;
  border-top: 1px solid var(--line-soft);
  padding-top: 12px;
  display: flex;
  flex-direction: column;
  gap: 9px;
}
.pf-meta > div {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  font-size: 12.5px;
}
.pf-meta dt {
  color: var(--faint);
  flex-shrink: 0;
}
.pf-meta dd {
  color: var(--text);
  font-weight: 500;
  text-align: right;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.pf-upload {
  width: 100%;
  margin-top: 16px;
}
.pf-hint {
  margin-top: 7px;
  font-size: 11.5px;
  color: var(--faint);
}

.sec-card .card-head {
  padding-bottom: 10px;
}
.sec-body {
  padding: 0 20px 18px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.sec-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 12.5px;
  color: var(--muted);
}
.sec-row b {
  font-weight: 600;
  color: var(--text);
}
.sec-row b.ok {
  color: var(--success);
}
.sec-row b.warn {
  color: var(--warning);
}
.sec-tip {
  margin-top: 4px;
  display: flex;
  gap: 6px;
  padding-top: 10px;
  border-top: 1px solid var(--line-soft);
  font-size: 12px;
  line-height: 1.6;
  color: var(--faint);
}
.sec-tip svg {
  flex-shrink: 0;
  margin-top: 2px;
}

/* ---------- 右栏 ---------- */
.pf-main {
  display: flex;
  flex-direction: column;
  gap: 16px;
  min-width: 0;
}

.pwd-banner {
  display: flex;
  gap: 10px;
  padding: 12px 16px;
  border: 1px solid #f3ddc3;
  border-radius: var(--radius-sm);
  background: var(--warning-bg);
  color: var(--warning);
}
.pwd-banner strong {
  font-size: 13px;
}
.pwd-banner p {
  margin-top: 3px;
  font-size: 12.5px;
  line-height: 1.6;
  color: #8a5a15;
}
.pwd-banner svg {
  flex-shrink: 0;
  margin-top: 2px;
}

.card-foot {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  margin-top: 18px;
  padding-top: 16px;
  border-top: 1px solid var(--line-soft);
}

.err-msg {
  font-size: 12px;
  color: var(--danger);
}

/* 密码框 */
.pwd-wrap {
  position: relative;
}
.pwd-wrap .input {
  padding-right: 38px;
}
.pwd-eye {
  position: absolute;
  right: 6px;
  top: 50%;
  transform: translateY(-50%);
  width: 28px;
  height: 28px;
  display: grid;
  place-items: center;
  border: none;
  border-radius: var(--radius-xs);
  background: transparent;
  color: var(--faint);
  cursor: pointer;
}
.pwd-eye:hover {
  background: var(--line-soft);
  color: var(--text);
}

/* 强度条 */
.strength {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-top: 2px;
}
.strength i {
  width: 30px;
  height: 4px;
  border-radius: 3px;
  background: var(--line);
  transition: background 0.2s;
}
.strength i.lv-1 {
  background: var(--danger);
}
.strength i.lv-2 {
  background: #e08b3c;
}
.strength i.lv-3 {
  background: var(--brand);
}
.strength i.lv-4 {
  background: var(--success);
}
.strength span {
  margin-left: 4px;
  font-size: 11.5px;
  color: var(--faint);
}

/* 规则清单 */
.rules {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 7px 18px;
  margin-top: 16px;
  padding: 12px 14px;
  border-radius: var(--radius-sm);
  background: #fafbfc;
  border: 1px solid var(--line-soft);
}
.rules li {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12.5px;
  color: var(--faint);
}
.rules li.pass {
  color: var(--success);
}

/* 开关 */
.switch-list {
  margin-top: 18px;
  border-top: 1px solid var(--line-soft);
}
.switch-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 13px 0;
  border-bottom: 1px solid var(--line-soft);
}
.switch-row:last-child {
  border-bottom: none;
  padding-bottom: 2px;
}
.switch-row strong {
  display: block;
  font-size: 13px;
  font-weight: 550;
  color: var(--ink);
}
.switch-row span {
  display: block;
  margin-top: 3px;
  font-size: 12px;
  color: var(--muted);
}
.switch {
  width: 40px;
  height: 22px;
  flex-shrink: 0;
  border: none;
  border-radius: 11px;
  background: #d5dae2;
  cursor: pointer;
  padding: 2px;
  transition: background 0.18s;
}
.switch i {
  display: block;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: #fff;
  box-shadow: 0 1px 2px rgba(16, 24, 40, 0.2);
  transition: transform 0.18s;
}
.switch.on {
  background: var(--brand);
}
.switch.on i {
  transform: translateX(18px);
}

.logins-empty {
  padding: 22px 20px 26px;
  font-size: 12.5px;
  line-height: 1.7;
  color: var(--faint);
}
</style>
