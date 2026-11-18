<template>
  <div class="auth">
    <!-- ==================== 左侧品牌区 ==================== -->
    <section class="brand-side">
      <div class="brand-glow" />
      <svg class="orbit" viewBox="0 0 640 640" fill="none" aria-hidden="true">
        <circle cx="320" cy="320" r="120" stroke="rgba(255,255,255,.14)" stroke-dasharray="2 6" />
        <circle cx="320" cy="320" r="190" stroke="rgba(255,255,255,.10)" />
        <circle cx="320" cy="320" r="262" stroke="rgba(255,255,255,.07)" stroke-dasharray="1 7" />
        <circle cx="320" cy="320" r="3.5" fill="rgba(255,255,255,.55)" />
        <circle cx="510" cy="320" r="4" fill="#7fb3e8" />
        <circle cx="130" cy="320" r="2.5" fill="rgba(255,255,255,.45)" />
        <circle cx="320" cy="130" r="2.5" fill="rgba(255,255,255,.35)" />
        <circle cx="425" cy="215" r="2" fill="rgba(255,255,255,.5)" />
        <path d="M320 320 L510 320" stroke="rgba(255,255,255,.16)" />
        <path d="M320 320 L425 215" stroke="rgba(255,255,255,.12)" />
      </svg>

      <header class="brand-logo">
        <span class="logo-mark">
          <svg viewBox="0 0 24 24" width="20" height="20" fill="none" aria-hidden="true">
            <path
              d="M12 2.6 14.1 9l6.6 2.1-6.6 2.1L12 19.6 9.9 13.2 3.3 11.1 9.9 9z"
              fill="#fff"
              fill-opacity=".95"
            />
            <circle cx="18.6" cy="5.4" r="1.5" fill="#9fc6f0" />
          </svg>
        </span>
        <div class="logo-text">
          <strong>北辰装配科技</strong>
          <em>BEICHEN&nbsp;&nbsp;ASSEMBLY&nbsp;&nbsp;TECH</em>
        </div>
      </header>

      <div class="brand-main">
        <div class="eyebrow">
          <span class="eyebrow-dot" />
          汽车配件耗材 · 销售协同平台
        </div>
        <h1 class="headline">
          让每一家门店，<br />
          都按时补货。
        </h1>
        <p class="subline">
          紧固件、密封件、线束辅料、化学品类——规格、包装、起订量统一口径。
          从汽配展询盘到月结回款，一条链路跑完，谁该补货了一目了然。
        </p>

        <ul class="features">
          <li v-for="f in features" :key="f.title">
            <span class="f-icon">
              <AppIcon :name="f.icon" :size="16" />
            </span>
            <div>
              <strong>{{ f.title }}</strong>
              <span>{{ f.desc }}</span>
            </div>
          </li>
        </ul>
      </div>

      <footer class="brand-foot">
        <div class="foot-stats">
          <div><b>1,260</b><span>在供耗材 SKU</span></div>
          <i />
          <div><b>480+</b><span>合作门店与经销商</span></div>
          <i />
          <div><b>24h</b><span>询盘响应时效</span></div>
        </div>
        <p class="copyright">© 2026 北辰装配科技有限公司 · 浙ICP备 2026001234 号</p>
      </footer>

      <!-- 悬浮数据卡，增加产品感 -->
      <div class="float-card">
        <div class="fc-head">
          <span>本月耗材出货额</span>
          <span class="fc-live"><i />实时</span>
        </div>
        <div class="fc-value">¥1,286,400</div>
        <div class="fc-bar"><i /></div>
        <div class="fc-foot">
          <span>目标 ¥1,600,000</span>
          <span class="fc-up">+12.4%</span>
        </div>
      </div>
    </section>

    <!-- ==================== 右侧登录区 ==================== -->
    <section class="form-side">
      <div class="form-wrap">
        <div class="mobile-brand">
          <span class="logo-mark small">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" aria-hidden="true">
              <path
                d="M12 2.6 14.1 9l6.6 2.1-6.6 2.1L12 19.6 9.9 13.2 3.3 11.1 9.9 9z"
                fill="#fff"
              />
            </svg>
          </span>
          <strong>北辰装配科技</strong>
        </div>

        <h2 class="form-title">欢迎回来</h2>
        <p class="form-sub">登录后继续今天的跑店、报价与回款</p>

        <form class="form" @submit.prevent="submit">
          <div class="field">
            <label class="label" for="account">账号</label>
            <div class="input-icon">
              <AppIcon name="user" :size="16" />
              <input
                id="account"
                v-model.trim="form.account"
                class="input"
                :class="{ error: errors.account }"
                type="text"
                placeholder="请输入手机号或工号"
                autocomplete="username"
                @input="errors.account = ''"
              />
            </div>
            <span v-if="errors.account" class="err-msg">{{ errors.account }}</span>
          </div>

          <div class="field">
            <label class="label" for="password">密码</label>
            <div class="input-icon">
              <AppIcon name="lock" :size="16" />
              <input
                id="password"
                v-model="form.password"
                class="input"
                :class="{ error: errors.password }"
                :type="showPwd ? 'text' : 'password'"
                placeholder="请输入登录密码"
                autocomplete="current-password"
                @input="errors.password = ''"
              />
              <button type="button" class="pwd-eye" @click="showPwd = !showPwd">
                <AppIcon :name="showPwd ? 'eye' : 'key'" :size="15" />
              </button>
            </div>
            <span v-if="errors.password" class="err-msg">{{ errors.password }}</span>
          </div>

          <div class="form-row">
            <label class="check">
              <input v-model="remember" type="checkbox" />
              <span>记住账号</span>
            </label>
            <button type="button" class="btn-text">忘记密码？</button>
          </div>

          <p v-if="serverError" class="form-alert">{{ serverError }}</p>

          <button class="btn btn-primary submit" type="submit" :disabled="loading">
            <span v-if="!loading">登录</span>
            <span v-else class="loading">
              <i class="spinner" />正在登录
            </span>
          </button>
        </form>

        <p class="form-foot">
          登录即表示同意
          <button type="button" class="btn-text">《服务协议》</button>
          与
          <button type="button" class="btn-text">《隐私政策》</button>
        </p>
      </div>
    </section>
  </div>
</template>

<script setup>
import { reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppIcon from '@/components/AppIcon.vue'
import { login } from '@/store/session'
import { resetProfile, touchLastLogin } from '@/store/profile'
import { canVisit, firstAllowedPath } from '@/store/permissions'

const router = useRouter()
const route = useRoute()

const features = [
  { icon: 'target', title: '询盘到回款一条链路', desc: '汽配展询盘、门店档案、供货协议、月结回款全打通' },
  { icon: 'box', title: '耗材 SKU 有统一口径', desc: '规格、材质、包装与起订量沉淀在目录里，报价不再翻表格' },
  { icon: 'users', title: '渠道分工与权限', desc: '渠道、配套、仓储、财务按岗位分配可见范围与审批权' }
]

const form = reactive({ account: localStorage.getItem('crm-remembered-account') || '', password: '' })
const errors = reactive({ account: '', password: '' })
const showPwd = ref(false)
const remember = ref(true)
const loading = ref(false)
const serverError = ref('')

async function submit() {
  serverError.value = ''
  errors.account = form.account ? '' : '请输入账号'
  errors.password = form.password ? '' : '请输入密码'
  if (errors.account || errors.password) return

  loading.value = true
  try {
    await login({ username: form.account, password: form.password })
    if (remember.value) localStorage.setItem('crm-remembered-account', form.account)
    else localStorage.removeItem('crm-remembered-account')
    touchLastLogin()
    resetProfile()
    // 目标地址若当前角色无权访问，落到他有权限的第一个页面
    const wanted = typeof route.query.redirect === 'string' ? route.query.redirect : ''
    const target = wanted && canVisit(wanted) ? wanted : firstAllowedPath()
    router.replace(target)
  } catch (e) {
    serverError.value = e.status === 401 ? '账号或密码错误，或账号已停用' : e.message || '登录失败，请稍后重试'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.auth {
  display: grid;
  grid-template-columns: minmax(0, 1.32fr) minmax(420px, 1fr);
  min-height: 100vh;
  background: #fff;
}

/* ==================== 左侧 ==================== */
.brand-side {
  position: relative;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 44px 56px 36px;
  color: #fff;
  background:
    radial-gradient(120% 90% at 88% 6%, rgba(43, 108, 176, 0.42) 0%, rgba(20, 36, 59, 0) 58%),
    radial-gradient(90% 70% at 6% 96%, rgba(21, 60, 100, 0.55) 0%, rgba(14, 27, 46, 0) 62%),
    linear-gradient(157deg, #16283f 0%, #0e1b2e 52%, #0b1523 100%);
}

.brand-side::after {
  content: '';
  position: absolute;
  inset: 0;
  background-image: linear-gradient(rgba(255, 255, 255, 0.028) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255, 255, 255, 0.028) 1px, transparent 1px);
  background-size: 64px 64px;
  mask-image: radial-gradient(80% 70% at 30% 40%, #000 20%, transparent 78%);
  pointer-events: none;
}

.brand-glow {
  position: absolute;
  width: 520px;
  height: 520px;
  right: -190px;
  top: 12%;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(84, 148, 214, 0.26), transparent 66%);
  filter: blur(10px);
  pointer-events: none;
}

.orbit {
  position: absolute;
  width: 620px;
  height: 620px;
  right: -180px;
  bottom: -180px;
  opacity: 0.9;
  pointer-events: none;
}

.brand-logo {
  position: relative;
  display: flex;
  align-items: center;
  gap: 12px;
  z-index: 2;
}

.logo-mark {
  width: 38px;
  height: 38px;
  border-radius: 11px;
  display: grid;
  place-items: center;
  background: linear-gradient(150deg, #3d7fc4, #1d4f85);
  box-shadow: 0 6px 18px rgba(20, 60, 100, 0.55), inset 0 1px 0 rgba(255, 255, 255, 0.24);
}

.logo-mark.small {
  width: 28px;
  height: 28px;
  border-radius: 8px;
}

.logo-text {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.logo-text strong {
  font-size: 16.5px;
  font-weight: 600;
  letter-spacing: 0.6px;
}
.logo-text em {
  font-style: normal;
  font-size: 9px;
  letter-spacing: 1.6px;
  color: rgba(255, 255, 255, 0.42);
}

.brand-main {
  position: relative;
  z-index: 2;
  max-width: 470px;
  padding: 30px 0;
}

.eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  height: 26px;
  padding: 0 11px;
  border-radius: 99px;
  border: 1px solid rgba(255, 255, 255, 0.14);
  background: rgba(255, 255, 255, 0.05);
  font-size: 11.5px;
  letter-spacing: 0.4px;
  color: rgba(255, 255, 255, 0.72);
  backdrop-filter: blur(4px);
}

.eyebrow-dot {
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: #6fbf9a;
  box-shadow: 0 0 0 3px rgba(111, 191, 154, 0.16);
}

.headline {
  margin: 22px 0 16px;
  font-size: clamp(30px, 2.6vw, 40px);
  line-height: 1.34;
  font-weight: 600;
  letter-spacing: 0.5px;
  color: #fff;
  text-shadow: 0 2px 24px rgba(0, 0, 0, 0.18);
}

.subline {
  font-size: 13.8px;
  line-height: 1.9;
  color: rgba(255, 255, 255, 0.6);
  max-width: 396px;
}

.features {
  list-style: none;
  margin: 34px 0 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.features li {
  display: flex;
  align-items: flex-start;
  gap: 12px;
}

.f-icon {
  width: 32px;
  height: 32px;
  border-radius: 9px;
  display: grid;
  place-items: center;
  background: rgba(255, 255, 255, 0.07);
  border: 1px solid rgba(255, 255, 255, 0.1);
  color: #a8c9ea;
  flex-shrink: 0;
}

.features strong {
  display: block;
  font-size: 13.5px;
  font-weight: 550;
  color: rgba(255, 255, 255, 0.92);
  letter-spacing: 0.2px;
}

.features span:last-child {
  display: block;
  margin-top: 2px;
  font-size: 12.2px;
  color: rgba(255, 255, 255, 0.45);
}

.brand-foot {
  position: relative;
  z-index: 2;
}

.foot-stats {
  display: flex;
  align-items: center;
  gap: 22px;
}

.foot-stats div {
  display: flex;
  flex-direction: column;
  gap: 1px;
}
.foot-stats b {
  font-size: 17px;
  font-weight: 600;
  letter-spacing: 0.4px;
  font-variant-numeric: tabular-nums;
}
.foot-stats span {
  font-size: 11px;
  color: rgba(255, 255, 255, 0.4);
}
.foot-stats i {
  width: 1px;
  height: 26px;
  background: rgba(255, 255, 255, 0.12);
}

.copyright {
  margin-top: 18px;
  font-size: 11px;
  color: rgba(255, 255, 255, 0.28);
}

.float-card {
  position: absolute;
  right: 52px;
  bottom: 104px;
  width: 214px;
  padding: 16px 16px 14px;
  border-radius: 14px;
  background: linear-gradient(160deg, rgba(255, 255, 255, 0.13), rgba(255, 255, 255, 0.05));
  border: 1px solid rgba(255, 255, 255, 0.14);
  backdrop-filter: blur(14px);
  box-shadow: 0 22px 48px rgba(4, 12, 22, 0.45);
  z-index: 3;
  animation: floaty 7s ease-in-out infinite;
}

@keyframes floaty {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-7px); }
}

@keyframes floaty {
  0%, 100% { transform: translateY(-42%); }
  50% { transform: translateY(-47%); }
}

.fc-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 11.5px;
  color: rgba(255, 255, 255, 0.6);
}
.fc-live {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 10.5px;
  color: #7fd6b0;
}
.fc-live i {
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: #7fd6b0;
  animation: pulse 2s infinite;
}
@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.28; }
}
.fc-value {
  margin: 8px 0 12px;
  font-size: 21px;
  font-weight: 600;
  letter-spacing: 0.4px;
  font-variant-numeric: tabular-nums;
}
.fc-bar {
  height: 4px;
  border-radius: 99px;
  background: rgba(255, 255, 255, 0.12);
  overflow: hidden;
}
.fc-bar i {
  display: block;
  width: 80%;
  height: 100%;
  border-radius: 99px;
  background: linear-gradient(90deg, #5a9bda, #9fc6f0);
}
.fc-foot {
  margin-top: 9px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 10.5px;
  color: rgba(255, 255, 255, 0.42);
}
.fc-up {
  color: #e8a2a2;
  font-weight: 600;
}

/* ==================== 右侧 ==================== */
.form-side {
  display: grid;
  place-items: center;
  padding: 48px 40px;
  background: #fff;
}

.form-wrap {
  width: 100%;
  max-width: 344px;
}

.mobile-brand {
  display: none;
  align-items: center;
  gap: 9px;
  margin-bottom: 26px;
  color: var(--ink);
  font-size: 15px;
  letter-spacing: 0.4px;
}

.form-title {
  font-size: 25px;
  font-weight: 650;
  color: var(--ink);
  letter-spacing: 0.4px;
}

.form-sub {
  margin-top: 8px;
  font-size: 13.5px;
  color: var(--muted);
}

.form {
  margin-top: 30px;
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.input-icon {
  position: relative;
  display: flex;
  align-items: center;
}
.input-icon > svg {
  position: absolute;
  left: 12px;
  color: var(--faint);
  pointer-events: none;
}
.input-icon .input {
  height: 44px;
  padding-left: 37px;
  border-radius: 9px;
  background: #fcfcfd;
  font-size: 14px;
}
.input-icon .input:focus {
  background: #fff;
}

.pwd-eye {
  position: absolute;
  right: 6px;
  width: 30px;
  height: 30px;
  display: grid;
  place-items: center;
  border: none;
  background: transparent;
  color: var(--faint);
  border-radius: 6px;
  cursor: pointer;
}
.pwd-eye:hover {
  background: #f2f4f7;
  color: var(--text);
}

.form-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: -4px;
}

.check {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  font-size: 13px;
  color: var(--muted);
  cursor: pointer;
  user-select: none;
}
.check input {
  width: 14px;
  height: 14px;
  accent-color: var(--brand);
  cursor: pointer;
}

.form-alert {
  padding: 9px 12px;
  border-radius: 8px;
  background: var(--danger-bg);
  color: var(--danger);
  font-size: 12.5px;
  border: 1px solid #f6d2ce;
}

.submit {
  height: 44px;
  font-size: 14px;
  font-weight: 550;
  letter-spacing: 1px;
  border-radius: 9px;
  margin-top: 2px;
}

.loading {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  font-size: 13.5px;
}

.spinner {
  width: 13px;
  height: 13px;
  border-radius: 50%;
  border: 2px solid rgba(255, 255, 255, 0.35);
  border-top-color: #fff;
  animation: spin 0.7s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.demo {
  margin-top: 20px;
  padding: 12px;
  border: 1px dashed var(--line);
  border-radius: 10px;
  background: #fafbfc;
}

.demo-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 10px;
}
.demo-head strong {
  font-size: 12px;
  font-weight: 600;
  color: var(--text);
  flex-shrink: 0;
}
.demo-head span {
  font-size: 10.5px;
  color: var(--faint);
  text-align: right;
  line-height: 1.5;
}

.demo-tip {
  margin-top: 9px;
  font-size: 10.5px;
  line-height: 1.6;
  color: var(--faint);
  text-align: center;
}

.demo-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 6px;
}

.demo-chip {
  display: flex;
  flex-direction: column;
  gap: 1px;
  padding: 6px 9px;
  border: 1px solid var(--line);
  border-radius: 7px;
  background: #fff;
  cursor: pointer;
  text-align: left;
  transition: all 0.15s;
}
.demo-chip:hover {
  border-color: #c8d4e2;
  background: #f8fbff;
}
.demo-chip.on {
  border-color: var(--brand);
  background: var(--brand-soft);
  box-shadow: 0 0 0 2px rgba(43, 108, 176, 0.08);
}
.dc-role {
  font-size: 12px;
  font-weight: 550;
  color: var(--ink);
  line-height: 1.4;
}
.demo-chip.on .dc-role {
  color: var(--brand);
}
.dc-acc {
  font-size: 10.5px;
  color: #9aa3b0;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  letter-spacing: 0.2px;
}
.demo-chip.on .dc-acc {
  color: #6f93bb;
}

.form-foot {
  margin-top: 26px;
  font-size: 11.5px;
  color: var(--faint);
  text-align: center;
  line-height: 1.8;
}
.form-foot .btn-text {
  font-size: 11.5px;
  color: var(--muted);
}
.form-foot .btn-text:hover {
  color: var(--brand);
}

/* ==================== 响应式 ==================== */
@media (max-width: 1180px) {
  .brand-side { padding: 40px 44px 32px; }
  .float-card { display: none; }
  .orbit { opacity: 0.5; }
}

@media (max-width: 900px) {
  .auth { grid-template-columns: 1fr; }
  .brand-side { display: none; }
  .form-side { padding: 40px 24px; }
  .mobile-brand { display: flex; }
}
</style>

