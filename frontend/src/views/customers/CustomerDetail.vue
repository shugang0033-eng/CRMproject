<template>
  <div class="page">
    <!-- 顶部布局已经有一层「客户 › 客户详情」面包屑，这里只留返回入口 -->
    <div class="crumbs">
      <button class="btn-text back" type="button" @click="router.push('/customers')">
        <AppIcon name="chevron-left" :size="14" />返回客户列表
      </button>
      <span v-if="isLocal" class="local-hint">
        <AppIcon name="flag" :size="11" />演示数据（接口未就绪）
      </span>
    </div>

    <!-- ==================== 档案条 ==================== -->
    <section v-if="detail" class="card hero">
      <div class="hero-top">
        <div class="logo">{{ p.name.slice(0, 1) }}</div>
        <div class="hero-id">
          <div class="name-row">
            <h2>{{ p.name }}</h2>
            <span class="tag" :class="levelTone(p.level)">{{ p.level }}</span>
            <span class="tag" :class="m.tier.tone">{{ m.tier.label }}</span>
          </div>
          <div class="hero-sub">
            {{ p.id }} · {{ p.industry }} · {{ p.region }} · 建档 {{ p.createdAt }}
          </div>
          <div v-if="p.tags.length" class="hero-tags">
            <span v-for="t in p.tags" :key="t" class="chip">{{ t }}</span>
          </div>
        </div>
        <div class="hero-actions">
          <button v-can="'followup.create'" class="btn btn-primary" type="button" @click="openFollow">
            <AppIcon name="plus" :size="14" />写跟进
          </button>
          <button v-can="'customer.edit'" class="btn" type="button" @click="openEdit">
            <AppIcon name="edit" :size="14" />编辑
          </button>
          <button class="btn" type="button" @click="moreOpen = !moreOpen">
            <AppIcon name="more" :size="14" />更多
          </button>
          <div v-if="moreOpen" class="more-menu">
            <button type="button" @click="toast('客户资料下载已发起（演示）')">
              <AppIcon name="download" :size="13" />导出客户资料
            </button>
            <button v-can="'customer.merge'" type="button" @click="openMerge">
              <AppIcon name="layers" :size="13" />合并重复客户
            </button>
            <button v-can="'customer.public.claim'" type="button" @click="releaseOpen = true">
              <AppIcon name="logout" :size="13" />退回客户池
            </button>
          </div>
        </div>
      </div>

      <!-- 谈单时最常被问到的五个数，直接摊在头上，不用翻 tab -->
      <div class="facts">
        <div class="fact">
          <span class="fk">客户经理</span>
          <div class="fv">
            <strong>{{ p.owner }}</strong>
            <span class="tag tiny" :class="statusTone[status]">{{ status }}</span>
          </div>
        </div>
        <div class="fact">
          <span class="fk">协议折扣</span>
          <div class="fv">
            <strong>{{ p.discount < 1 ? (p.discount * 10).toFixed(1) + ' 折' : '标准价' }}</strong>
            <span class="faint fs">{{ p.discountScope }}</span>
          </div>
        </div>
        <div class="fact">
          <span class="fk">账期</span>
          <div class="fv">
            <strong>{{ p.term ? p.term + ' 天' : '现款' }}</strong>
            <span class="faint fs">月结</span>
          </div>
        </div>
        <div class="fact">
          <span class="fk">可用额度</span>
          <div class="fv">
            <strong :class="{ neg: m.creditRemain <= 0 }">¥{{ wan(m.creditRemain) }} 万</strong>
            <span class="faint fs">共 {{ wan(p.credit.limit) }} 万</span>
          </div>
        </div>
        <div class="fact">
          <span class="fk">应收余额</span>
          <div class="fv">
            <strong :class="{ neg: m.overdue > 0 }">¥{{ wan(m.receivable) }} 万</strong>
            <span v-if="m.overdue" class="tag tag-danger tiny">逾期 {{ wan(m.overdue) }} 万</span>
            <span v-else class="faint fs">未逾期</span>
          </div>
        </div>
      </div>
    </section>

    <!-- ==================== 四个指标 ==================== -->
    <div v-if="detail" class="grid-4 metrics">
      <StatTile label="累计下单额" :value="m.total" money icon="chart" :hint="`近 90 天 ¥${wan(m.net90)} 万`" />
      <StatTile label="订单数" :value="m.orders" unit="单" icon="receipt" :hint="`平均 ¥${wan(m.avgOrder)} 万 / 单`" />
      <StatTile
        label="平均复购周期"
        :value="m.cycle || '—'"
        unit="天"
        icon="refresh"
        :tone="m.cycle && m.cycle <= 35 ? 'success' : 'warning'"
        :hint="m.lastOrder ? `最近下单 ${m.lastOrder}` : '还没有首单'"
      />
      <StatTile
        label="应收余额"
        :value="m.receivable"
        money
        icon="wallet"
        :tone="m.overdue ? 'danger' : m.receivable ? 'warning' : 'success'"
        :hint="m.overdue ? `其中逾期 ¥${wan(m.overdue)} 万` : '账期内，无逾期'"
      />
    </div>

    <!-- ==================== 业务 tab ==================== -->
    <div v-if="detail" class="card main">
      <div class="tabs">
        <button
          v-for="t in tabs"
          :key="t.value"
          class="tab"
          :class="{ active: tab === t.value }"
          type="button"
          @click="tab = t.value"
        >
          {{ t.label }}<span v-if="t.count != null" class="tab-count">{{ t.count }}</span>
        </button>
      </div>

      <!-- ---------------- 概览 ---------------- -->
      <div v-show="tab === 'overview'" class="pane">
        <div class="two-col">
          <div class="stack">
            <section class="sub-card">
              <div class="sub-head">
                <span>近 6 个月采购</span>
                <span class="faint fs">合计 ¥{{ wan(sixMonth) }} 万 · 下单口径</span>
              </div>
              <div class="bars">
                <div v-for="b in monthly" :key="b.month" class="bar-col">
                  <span class="bar-val">{{ b.amount ? wan(b.amount, 1) : '—' }}</span>
                  <div class="bar-track">
                    <div class="bar" :style="{ height: barH(b.amount) }" />
                  </div>
                  <span class="bar-lab">{{ b.month }} 月</span>
                </div>
              </div>
            </section>

            <section class="sub-card">
              <div class="sub-head"><span>客户画像</span></div>
              <p class="note">{{ p.note || '暂无备注' }}</p>
              <div class="kv">
                <div><span class="fk">联系电话</span><b class="mono-num">{{ p.phone }}</b></div>
                <div><span class="fk">注册地址</span><b>{{ p.address }}</b></div>
                <div><span class="fk">线索来源</span><b>{{ p.source }}</b></div>
                <div><span class="fk">最近下单</span><b>{{ m.lastOrder || '暂无' }}</b></div>
              </div>
            </section>
          </div>

          <div class="stack">
            <section class="sub-card">
              <div class="sub-head">
                <span>需要处理</span>
                <span class="faint fs">{{ todoList.length }} 项</span>
              </div>
              <div v-if="todoList.length" class="todos">
                <div v-for="(t, i) in todoList" :key="i" class="todo" :class="t.tone">
                  <span class="todo-dot" />
                  <div>
                    <div class="todo-title">{{ t.title }}</div>
                    <div class="todo-desc">{{ t.desc }}</div>
                  </div>
                </div>
              </div>
              <div v-else class="all-good">
                <AppIcon name="check-circle" :size="15" />档案完整，暂无待处理事项
              </div>
            </section>

            <section class="sub-card">
              <div class="sub-head">
                <span>决策链</span>
                <button class="btn-text fs" type="button" @click="tab = 'contacts'">全部 {{ contacts.length }} 人</button>
              </div>
              <div class="chain">
                <div v-for="c in contacts.slice(0, 3)" :key="c.name" class="chain-item">
                  <UserAvatar :name="c.name" size="sm" />
                  <div class="chain-body">
                    <div class="chain-name">{{ c.name }}<span class="tag tiny" :class="c.roleTone">{{ c.roleLabel }}</span></div>
                    <div class="faint fs">{{ c.title }} · 最近联系 {{ c.lastContact }}</div>
                  </div>
                  <span class="mono-num faint fs">{{ c.phone }}</span>
                </div>
              </div>
            </section>

            <section class="sub-card">
              <div class="sub-head">
                <span>最近动态</span>
                <button class="btn-text fs" type="button" @click="tab = 'timeline'">全部</button>
              </div>
              <div class="mini-list">
                <div v-for="(t, i) in (detail.timeline || []).slice(0, 3)" :key="i" class="mini-row">
                  <span class="mini-at">{{ t.at.slice(5, 10) }}</span>
                  <span class="mini-title">{{ t.title }}</span>
                  <span class="tag tiny" :class="`tag-${t.tone === 'brand' ? 'brand' : t.tone}`">
                    {{ kindLabel[t.kind] }}
                  </span>
                </div>
              </div>
            </section>
          </div>
        </div>
      </div>

      <!-- ---------------- 联系人 ---------------- -->
      <div v-show="tab === 'contacts'" class="pane">
        <div class="chain-cards">
          <div v-for="r in roleGroups" :key="r.role" class="role-card">
            <div class="role-head">
              <span class="tag" :class="r.tone">{{ r.label }}</span>
              <span class="faint fs">{{ r.people.length }} 人</span>
            </div>
            <div v-if="r.people.length" class="role-people">
              <div v-for="c in r.people" :key="c.name" class="role-person">
                <UserAvatar :name="c.name" size="sm" />
                <div>
                  <div class="chain-name">
                    {{ c.name }}
                    <span v-if="c.primary" class="primary-mark"><AppIcon name="star" :size="10" />主联系人</span>
                  </div>
                  <div class="faint fs">{{ c.title }}</div>
                </div>
              </div>
            </div>
            <div v-else class="role-empty">尚未录入</div>
          </div>
        </div>

        <AppTable :columns="contactColumns" :rows="contacts" row-key="name" :show-pager="false" compact>
          <template #cell-name="{ row }">
            <div class="row-tight">
              <UserAvatar :name="row.name" />
              <div>
                <div class="cell-main">
                  {{ row.name }}
                  <span v-if="row.primary" class="primary-mark"><AppIcon name="star" :size="10" />主联系人</span>
                </div>
                <div class="cell-sub">{{ row.title }}</div>
              </div>
            </div>
          </template>
          <template #cell-phone="{ row }">
            <span class="mono-num">{{ row.phone }}</span>
          </template>
          <template #cell-email="{ row }">
            <span class="faint">{{ row.email || '—' }}</span>
          </template>
          <template #cell-role="{ row }">
            <span class="tag" :class="row.roleTone">{{ row.roleLabel }}</span>
          </template>
          <template #cell-ops="{ row }">
            <div class="row-tight ops">
              <button v-can="'contact.edit'" class="btn-text" type="button" @click="toast(`编辑联系人「${row.name}」`)">
                编辑
              </button>
              <button
                v-can="'contact.edit'"
                class="btn-text"
                type="button"
                :disabled="row.primary"
                @click="setPrimary(row)"
              >
                {{ row.primary ? '已是主联系人' : '设为主联系人' }}
              </button>
            </div>
          </template>
        </AppTable>
      </div>

      <!-- ---------------- 跟进动态 ---------------- -->
      <div v-show="tab === 'timeline'" class="pane">
        <div class="tl-bar">
          <div class="seg">
            <button
              v-for="f in kinds"
              :key="f.value"
              type="button"
              :class="{ on: kind === f.value }"
              @click="kind = f.value"
            >
              {{ f.label }}
            </button>
          </div>
          <div class="spacer" />
          <button v-can="'followup.create'" class="btn btn-sm btn-primary" type="button" @click="openFollow">
            <AppIcon name="plus" :size="13" />写跟进
          </button>
        </div>

        <div class="timeline">
          <article v-for="(item, i) in timeline" :key="i" class="tl-item">
            <div class="tl-date">
              <b>{{ item.at.slice(5, 10).replace('-', '/') }}</b>
              <span>{{ item.at.slice(11) }}</span>
            </div>
            <div class="tl-axis"><i :class="item.tone" /></div>
            <div class="tl-card">
              <div class="tl-head">
                <span class="row-tight">
                  <span class="type-ico" :class="`tone-${item.tone}`">
                    <AppIcon :name="kindIcon[item.kind]" :size="14" />
                  </span>
                  <strong>{{ item.title }}</strong>
                </span>
                <span class="tag tiny" :class="`tag-${item.tone === 'brand' ? 'brand' : item.tone}`">
                  {{ kindLabel[item.kind] }}
                </span>
              </div>
              <p class="tl-content">{{ item.desc }}</p>
              <div class="tl-foot">
                <span class="faint">{{ item.meta }}</span>
              </div>
            </div>
          </article>

          <div v-if="!timeline.length" class="empty">
            <div class="empty-icon"><AppIcon name="inbox" :size="20" /></div>
            <span>还没有跟进记录，写一条开始吧</span>
          </div>
        </div>
      </div>

      <!-- ---------------- 合同与回款 ---------------- -->
      <div v-show="tab === 'orders'" class="pane">
        <div class="sub-card">
          <div class="sub-head">
            <span>合同</span>
            <span class="faint fs">共 {{ contractRows.length }} 份 · 框架金额 ¥{{ wan(contractAmount) }} 万</span>
          </div>
          <AppTable :columns="contractColumns" :rows="contractRows" :show-pager="false" compact>
            <template #cell-amount="{ row }">
              <span class="num">¥{{ row.amount.toLocaleString() }}</span>
            </template>
            <template #cell-paid="{ row }">
              <div v-if="row.paid == null" class="faint fs" title="回款没有按合同核销，多份合同时无法拆分">
                按客户汇总
              </div>
              <div v-else class="paid">
                <div class="paid-track"><div class="paid-fill" :style="{ width: row.paid + '%' }" /></div>
                <span class="mono-num fs">{{ row.paid }}%</span>
              </div>
            </template>
            <template #cell-status="{ row }">
              <span class="tag" :class="contractTone[row.status]">{{ row.status }}</span>
            </template>
          </AppTable>
        </div>

        <div class="sub-card">
          <div class="sub-head">
            <span>回款</span>
            <span class="faint fs" :class="{ neg: m.overdue > 0 }">
              应收余额 ¥{{ wan(m.receivable) }} 万{{ m.overdue ? ` · 逾期 ¥${wan(m.overdue)} 万` : '' }}
            </span>
          </div>
          <AppTable :columns="paymentColumns" :rows="paymentRows" :show-pager="false" compact>
            <template #cell-amount="{ row }">
              <span class="num">¥{{ row.amount.toLocaleString() }}</span>
            </template>
            <template #cell-status="{ row }">
              <span class="tag" :class="paymentTone[row.status]">{{ row.status }}</span>
            </template>
          </AppTable>
          <p v-if="!paymentRows.length" class="empty-line">
            还没有回款记录；应收 ¥{{ wan(m.receivable) }} 万按合同账期跟进
          </p>
        </div>
      </div>

      <!-- ---------------- 附件 ---------------- -->
      <div v-show="tab === 'files'" class="pane">
        <div class="files">
          <div v-for="f in detail.attach" :key="f.name" class="file" :class="{ warn: !f.ok }">
            <div class="file-ico"><AppIcon name="file" :size="16" /></div>
            <div class="file-body">
              <div class="file-name">{{ f.name }}</div>
              <div class="faint fs">{{ f.type }} · {{ f.size }} · {{ f.at }}</div>
            </div>
            <span v-if="!f.ok" class="tag tag-warning tiny">待补齐</span>
            <button class="btn-text fs" type="button" @click="toast(`下载「${f.name}」（演示）`)">下载</button>
          </div>
          <button v-can="'customer.edit'" class="file add" type="button" @click="toast('上传附件功能开发中')">
            <AppIcon name="upload" :size="15" />
            <span>上传资质 / 协议</span>
          </button>
        </div>
      </div>
    </div>

    <div v-else class="card loading-card">
      <div class="empty">
        <div class="empty-icon"><AppIcon name="inbox" :size="20" /></div>
        <span>{{ loadError || '正在加载客户档案…' }}</span>
      </div>
    </div>

    <!-- ==================== 写跟进 ==================== -->
    <ModalDialog v-model="followOpen" title="写跟进" desc="记录会同时进入客户动态与团队跟进看板" ok-text="保存" @confirm="submitFollow">
      <div class="form-grid">
        <div class="field">
          <label class="label">跟进方式<span class="req">*</span></label>
          <select v-model="followForm.type" class="select">
            <option v-for="t in followTypes" :key="t">{{ t }}</option>
          </select>
        </div>
        <div class="field">
          <label class="label">本次结果</label>
          <select v-model="followForm.result" class="select">
            <option v-for="r in followResults" :key="r">{{ r }}</option>
          </select>
        </div>
      </div>
      <div class="field">
        <label class="label">跟进内容<span class="req">*</span></label>
        <textarea v-model="followForm.content" class="input area" rows="4" placeholder="聊了什么、客户什么态度、下一步做什么" />
      </div>
      <div class="field">
        <label class="label">下次跟进</label>
        <input v-model="followForm.next" class="input" type="date" />
      </div>
    </ModalDialog>

    <!-- ==================== 合并客户 ==================== -->
    <ModalDialog
      v-model="mergeOpen"
      title="合并重复客户"
      desc="把当前档案合并到主客户，联系人与跟进记录全部迁过去，当前档案作废"
      ok-text="确认合并"
      @confirm="submitMerge"
    >
      <div class="field">
        <label class="label">合并到<span class="req">*</span></label>
        <select v-model="mergeTarget" class="select">
          <option :value="null">请选择主客户</option>
          <option v-for="c in mergeOptions" :key="c.id" :value="c.id">{{ c.name }}（{{ c.id }}）</option>
        </select>
      </div>
      <p class="hint-line">
        <AppIcon name="shield" :size="12" />
        有未结清合同的客户不能合并，需要先把回款结掉。
      </p>
    </ModalDialog>

    <!-- ==================== 退回客户池 ==================== -->
    <ModalDialog
      v-model="releaseOpen"
      title="退回客户池"
      desc="客户会进入公共池，其他人可以领取；历史跟进与合同保留"
      ok-text="确认退回"
      @confirm="release"
    >
      <div class="field">
        <label class="label">退回原因</label>
        <select v-model="releaseReason" class="select">
          <option v-for="r in releaseReasons" :key="r">{{ r }}</option>
        </select>
      </div>
      <p class="hint-line">
        <AppIcon name="flag" :size="12" />
        退回后 {{ p.name }} 的原负责人会变成只读，30 天内不能重新领取。
      </p>
    </ModalDialog>
    <!-- ==================== 编辑客户档案 ==================== -->
    <ModalDialog
      v-model="editOpen"
      title="编辑客户档案"
      desc="只改档案字段；状态、累计下单、最近下单由交易记录自动算，不允许手改"
      ok-text="保存"
      :loading="saving"
      @confirm="submitEdit"
    >
      <div class="edit-sec">
        <div class="edit-sec-title">基础资料</div>
        <div class="form-grid">
          <div class="field">
            <label class="label">客户名称<span class="req">*</span></label>
            <input v-model="editForm.name" class="input" type="text" maxlength="200" @input="checkDupes" />
          </div>
          <div class="field">
            <label class="label">客户等级</label>
            <select v-model="editForm.level" class="select">
              <option v-for="l in LEVELS" :key="l">{{ l }}</option>
            </select>
          </div>
          <div class="field">
            <label class="label">客户类型</label>
            <input v-model="editForm.industry" class="input" type="text" placeholder="4S 店 / 连锁汽修 / 物流车队" />
          </div>
          <div class="field">
            <label class="label">区域</label>
            <input v-model="editForm.region" class="input" type="text" placeholder="浙江 · 杭州" />
          </div>
          <div class="field">
            <label class="label">联系电话</label>
            <input
              v-model="editForm.phone"
              class="input"
              type="text"
              :placeholder="phoneMasked ? '原号码已脱敏，不改请留空' : '手机号或座机'"
            />
          </div>
          <div class="field">
            <label class="label">线索来源</label>
            <input v-model="editForm.source" class="input" type="text" />
          </div>
        </div>
        <div class="field">
          <label class="label">注册地址</label>
          <input v-model="editForm.address" class="input" type="text" />
        </div>
        <div class="field">
          <label class="label">客户画像备注</label>
          <textarea
            v-model="editForm.note"
            class="input area"
            rows="3"
            maxlength="500"
            placeholder="决策链、比价习惯、竞品情况"
          />
        </div>
        <div v-if="dupes.length" class="warn-line">
          <AppIcon name="flag" :size="12" />
          <span>已有相似客户：{{ dupes.map((d) => d.name).join('、') }}，确认不是重复建档？</span>
        </div>
      </div>

      <div class="edit-sec">
        <div class="edit-sec-title">
          商务条件
          <span class="tag tiny" :class="canCredit ? 'tag-info' : 'tag-gray'">
            {{ canCredit ? '可编辑' : '只读' }}
          </span>
        </div>
        <div v-if="canCredit" class="form-grid">
          <div class="field">
            <label class="label">账期（天）</label>
            <input v-model.number="editForm.paymentTerm" class="input" type="number" min="0" max="180" />
          </div>
          <div class="field">
            <label class="label">信用额度（元）</label>
            <input v-model.number="editForm.creditLimit" class="input" type="number" min="0" step="1000" />
          </div>
        </div>
        <div v-else class="readonly-grid two">
          <div><span>账期</span><b>{{ editForm.paymentTerm ? editForm.paymentTerm + ' 天' : '现款' }}</b></div>
          <div><span>信用额度</span><b>¥{{ Number(editForm.creditLimit || 0).toLocaleString() }}</b></div>
        </div>
        <p v-if="canCredit" class="field-note">
          可用额度 = 授信 − 已用（当前已用 ¥{{ Number(p.credit?.used || 0).toLocaleString() }}）
        </p>
        <p v-else class="field-note">
          账期与额度直接决定能不能赊销下单，只有销售主管 / 运营总监能改，需要调整请联系上级
        </p>
        <div v-if="creditUp" class="warn-line">
          <AppIcon name="flag" :size="12" />
          <span>
            额度从 ¥{{ Number(editBase.creditLimit || 0).toLocaleString() }} 上调到
            ¥{{ Number(editForm.creditLimit || 0).toLocaleString() }}，上调等于放宽赊销上限，请确认
          </span>
        </div>
      </div>

      <div class="edit-sec">
        <div class="edit-sec-title">系统字段（只读）</div>
        <div class="readonly-grid">
          <div><span>负责人</span><b>{{ p.owner }}</b></div>
          <div><span>当前状态</span><b>{{ status }}</b></div>
          <div><span>累计下单</span><b>¥{{ wan(m.total) }} 万</b></div>
          <div><span>建档时间</span><b>{{ p.createdAt }}</b></div>
        </div>
      </div>
    </ModalDialog>
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppIcon from '@/components/AppIcon.vue'
import UserAvatar from '@/components/UserAvatar.vue'
import AppTable from '@/components/AppTable.vue'
import ModalDialog from '@/components/ModalDialog.vue'
import StatTile from '@/components/analytics/StatTile.vue'
import { toast } from '@/composables/useToast'
import { customerApi } from '@/api/customers'
import { can } from '@/store/permissions'
import { aggregateCustomer, resolveStatus, tierOf, monthlyOf, STATUS_TONE as statusTone } from '@/utils/customer'

const route = useRoute()
const router = useRouter()

const detail = ref(null)
const isLocal = ref(false)
const loadError = ref('')
const allCustomers = ref([])


/* 后端 /customers/{id} 的 metrics 目前是写死的 0，合同与回款也返回空数组。
   在接口补齐之前，这三份明细由前端按 customerId 拉真实数据自己汇总，
   保证页面数字和数据库一致（口径见 utils/customer.js）。 */
const trade = ref({ orders: [], contracts: [], receipts: [] })
/* 没有 payment.view 时 /receipts 403，应收返回 null 显示「—」，不能当成 0 */

async function load() {
  loadError.value = ''
  const id = route.params.id
  try {
    detail.value = await customerApi.detail(id)
  } catch (error) {
    detail.value = null
    loadError.value = error.message
    return
  }

  trade.value = { contracts: detail.value.contracts, receipts: detail.value.payments }

  allCustomers.value = await customerApi.list().catch(() => [])
}

onMounted(load)

const p = computed(() => detail.value?.profile || { name: '', tags: [], credit: { limit: 0, used: 0 } })
const contacts = computed(() => detail.value?.contacts || [])

const status = computed(() => p.value.status)
const monthly = computed(() => detail.value?.monthly || [])
const m = computed(() => {
  const metrics = detail.value?.metrics || {}
  return { ...metrics, tier: tierOf(metrics) }
})

function wan(v, dec = 1) {
  const n = Number(v || 0) / 10000
  return dec ? n.toFixed(dec) : Math.round(n).toLocaleString()
}

function levelTone(l) {
  return l === '战略客户' ? 'tag-brand' : l === 'A 类' ? 'tag-info' : 'tag-gray'
}

/* ---------------- tab ---------------- */
const tab = ref('overview')
const tabs = computed(() => [
  { label: '概览', value: 'overview' },
  { label: '联系人', value: 'contacts', count: contacts.value.length },
  { label: '跟进动态', value: 'timeline', count: detail.value?.timeline.length || 0 },
  { label: '合同与回款', value: 'orders', count: contractRows.value.length + paymentRows.value.length },
  { label: '附件', value: 'files', count: detail.value?.attach.length || 0 }
])

/* ---------------- 概览 ---------------- */
const sixMonth = computed(() => monthly.value.reduce((s, b) => s + b.amount, 0))

const maxMonth = computed(() => Math.max(1, ...monthly.value.map((b) => b.amount)))
function barH(v) {
  return `${Math.max(v ? 4 : 2, Math.round((v / maxMonth.value) * 100))}%`
}

/** 待处理事项由数据推出来，不写死文案：逾期、合同待审批、附件缺失、长期未跟进 */
const todoList = computed(() => {
  const list = []
  if (m.value.overdue > 0) {
    list.push({ title: `回款逾期 ¥${wan(m.value.overdue)} 万`, desc: '已超过合同约定账期，需财务协同催收', tone: 'danger' })
  } else if (m.value.receivable > 0) {
    list.push({
      title: `¥${wan(m.value.receivable)} 万待收`,
      desc: `已签收未回款，账期 ${p.value.term || 0} 天`,
      tone: 'info'
    })
  }
  const pending = trade.value.contracts.filter((c) => c.status === '待审批')
  if (pending.length) {
    list.push({ title: `${pending.length} 份合同待审批`, desc: pending.map((c) => c.id).join('、'), tone: 'warning' })
  }
  const missing = (detail.value?.attach || []).filter((f) => !f.ok)
  if (missing.length) {
    list.push({ title: `${missing.length} 份资质待补齐`, desc: missing.map((f) => f.name).join('、'), tone: 'info' })
  }
  if (!m.value.orders) {
    list.push({ title: '还没有首单', desc: '客户已建档但零成交，优先安排上门拜访', tone: 'warning' })
  } else if (m.value.cycle > 45) {
    list.push({ title: `复购周期 ${m.value.cycle} 天，偏长`, desc: '高于 45 天均值，确认是需求变少还是被竞品分流', tone: 'info' })
  }
  return list
})

/* ---------------- 联系人 ---------------- */
const contactColumns = [
  { key: 'name', label: '联系人' },
  { key: 'role', label: '角色', width: '92px' },
  { key: 'phone', label: '手机号', width: '128px' },
  { key: 'email', label: '邮箱' },
  { key: 'lastContact', label: '最近联系', width: '112px' },
  { key: 'ops', label: '操作', align: 'right', width: '186px' }
]

const roleGroups = computed(() =>
  [
    { role: 'decision', label: '决策人', tone: 'tag-brand' },
    { role: 'user', label: '使用人', tone: 'tag-info' },
    { role: 'payer', label: '付款人', tone: 'tag-warning' }
  ].map((r) => ({ ...r, people: contacts.value.filter((c) => c.role === r.role) }))
)

async function setPrimary(row) {
  try {
    await customerApi.updateContact(p.value.id, row.id, { primary: true })
    await load()
  } catch (error) { toast(error.message, 'error') }
}

/* ---------------- 跟进动态 ---------------- */
const kind = ref('')
const kinds = [
  { label: '全部', value: '' },
  { label: '跟进', value: 'follow' },
  { label: '合同', value: 'contract' },
  { label: '回款', value: 'payment' }
]
const kindIcon = { follow: 'phone', contract: 'file', payment: 'wallet' }
const kindLabel = { follow: '跟进', contract: '合同', payment: '回款' }

const timeline = computed(() => {
  const list = detail.value?.timeline || []
  return kind.value ? list.filter((t) => t.kind === kind.value) : list
})

/* ---------------- 写跟进 ---------------- */
const followOpen = ref(false)
const followTypes = ['电话', '微信', '客户拜访', '线上会议', '邮件']
const followResults = ['推进', '待反馈', '待回款', '暂缓']
const followForm = reactive({ type: '电话', result: '推进', content: '', next: '' })

function openFollow() {
  followForm.type = '电话'
  followForm.result = '推进'
  followForm.content = ''
  followForm.next = ''
  followOpen.value = true
}

async function submitFollow() {
  if (!followForm.content.trim()) return toast('请填写跟进内容')
  try {
    await customerApi.addFollowUp(p.value.id, { ...followForm, next: followForm.next || null })
    followOpen.value = false
    await load()
    toast('跟进已记录')
  } catch (error) { toast(error.message, 'error') }
}

/* ---------------- 合并客户 ---------------- */
const moreOpen = ref(false)
const mergeOpen = ref(false)
const mergeTarget = ref(null)
const mergeOptions = computed(() => allCustomers.value.filter((c) => String(c.id) !== String(p.value.id)))

function openMerge() {
  moreOpen.value = false
  mergeTarget.value = null
  mergeOpen.value = true
}

async function submitMerge() {
  if (!mergeTarget.value) return toast('请选择主档案')
  try {
    await customerApi.merge({ fromId: p.value.id, toId: mergeTarget.value })
    mergeOpen.value = false
    router.push('/customers/' + mergeTarget.value)
  } catch (error) { toast(error.message, 'error') }
}

/* ---------------- 退回客户池 ---------------- */
const releaseOpen = ref(false)
const releaseReasons = ['长期未跟进', '客户主动要求更换', '员工离职交接', '价格不匹配', '其他']
const releaseReason = ref(releaseReasons[0])

async function release() {
  try {
    await customerApi.transfer({ ids: [p.value.id], ownerId: null, reason: releaseReason.value })
    releaseOpen.value = false
    toast('已退回客户池')
    router.push('/customers/public')
  } catch (error) { toast(error.message, 'error') }
}

/* ---------------- 编辑客户档案 ---------------- */
/* 只改「人填的」字段。状态、累计签约、最近下单、已用额度都是交易事实推出来的，
   放进来编辑等于让人改账；负责人走「转负责人」，独立权限 + 留痕。 */
const editOpen = ref(false)
const saving = ref(false)
const dupes = ref([])
const phoneMasked = ref(false)

const LEVELS = ['战略客户', 'A 类', 'B 类', 'C 类']

const editForm = reactive({
  name: '',
  industry: '',
  level: 'C 类',
  region: '',
  phone: '',
  address: '',
  source: '',
  note: '',
  paymentTerm: 0,
  creditLimit: 0
})
let editBase = {}

/* 账期和信用额度是商务条件：销售能改 = 自己给自己提额度再下超限单，等于绕过审批 */
const canCredit = computed(() => can('customer.credit'))
const creditUp = computed(
  () => canCredit.value && Number(editForm.creditLimit) > Number(editBase.creditLimit || 0)
)

function openEdit() {
  const d = p.value
  const rawPhone = String(d.phone || '')
  phoneMasked.value = rawPhone.includes('*')
  Object.assign(editForm, {
    name: d.name || '',
    industry: d.industry || '',
    level: LEVELS.includes(d.level) ? d.level : 'C 类',
    region: d.region && d.region !== '—' ? d.region : '',
    phone: phoneMasked.value ? '' : rawPhone,
    address: d.address && d.address !== '—' ? d.address : '',
    source: d.source && d.source !== '—' ? d.source : '',
    note: d.note || '',
    paymentTerm: Number(d.term || 0),
    creditLimit: Number(d.credit?.limit || 0)
  })
  editBase = { ...editForm }
  dupes.value = []
  editOpen.value = true
}

/* 改名时查重，避免改出两个「郑州恒大」。接口已实现：POST /customers/duplicates/check */
let dupeTimer = null
function checkDupes() {
  clearTimeout(dupeTimer)
  const name = editForm.name.trim()
  if (name.length < 2 || name === editBase.name) {
    dupes.value = []
    return
  }
  dupeTimer = setTimeout(async () => {
    try {
      const res = await customerApi.checkDuplicate({ name, phone: '' })
      dupes.value = (res?.duplicates || []).filter((x) => String(x.id) !== String(p.value.id))
    } catch {
      dupes.value = []
    }
  }, 400)
}

const changedKeys = computed(() =>
  Object.keys(editBase).filter((k) => {
    const a = editBase[k]
    const b = editForm[k]
    return typeof a === 'number' ? Number(a) !== Number(b) : String(a ?? '') !== String(b ?? '')
  })
)

async function submitEdit() {
  if (saving.value) return
  const name = editForm.name.trim()
  if (!name) return toast('客户名称不能为空')
  if (name.length > 200) return toast('客户名称不能超过 200 字')
  if (!changedKeys.value.length) {
    editOpen.value = false
    return toast('没有改动')
  }

  /* PATCH 是「传了才改」，所以只提交真正变了的字段：
     整表回填会把库里的 NULL 冲成空串，还会在 changes 表里记一堆假变更 */
  const text = (k) => String(editForm[k] ?? '').trim()
  const body = {}
  for (const k of changedKeys.value) {
    if (k === 'phone') {
      /* 详情接口返回的电话是脱敏的（138****1188），没重填就不写回去，否则会把星号存进库 */
      if (!phoneMasked.value) body.phone = text('phone')
    } else if (k === 'paymentTerm' || k === 'creditLimit') {
      if (canCredit.value) body[k] = Number(editForm[k]) || 0
    } else {
      body[k] = text(k)
    }
  }
  if (!Object.keys(body).length) {
    editOpen.value = false
    return toast('没有改动')
  }

  saving.value = true
  try {
    const res = await customerApi.update(p.value.id, body)
    /* 后端会跳过「值没变」的字段，以它返回的 changed 为准 */
    const n = Array.isArray(res?.changed) ? res.changed.length : Object.keys(body).length
    editOpen.value = false
    await load()
    toast(n ? `已保存 ${n} 项变更` : '没有改动')
  } catch (error) {
    toast(error.message, 'error')
  } finally {
    saving.value = false
  }
}

/* ---------------- 表格列 ---------------- */
/* 合同是框架协议（年框额度），和「累计下单额」不是一回事，两个数分开显示 */
const contractAmount = computed(() =>
  trade.value.contracts
    .filter((c) => c.status !== '已终止')
    .reduce((s, c) => s + Number(c.amount || 0), 0)
)

const contractRows = computed(() =>
  trade.value.contracts.map((c) => ({
    id: c.code || `HT-${c.id}`,
    name: c.name,
    amount: Number(c.amount || 0),
    signDate: c.sign_date || c.date || '—',
    /* 回款没有按合同核销，只有一份合同时比例才可信，多份就交给后端 */
    paid: c.paid ?? null,
    status: c.status
  }))
)

const paymentRows = computed(() =>
  trade.value.receipts.map((r) => ({
    id: r.code || `SK-${r.id}`,
    amount: Number(r.amount || 0),
    method: r.method || '—',
    paidDate: r.pay_date || r.date || '—',
    status: r.status || '待核销'
  }))
)

const contractColumns = [
  { key: 'id', label: '合同编号', width: '142px' },
  { key: 'name', label: '合同名称' },
  { key: 'amount', label: '签约额', width: '130px', align: 'right' },
  { key: 'signDate', label: '签署日期', width: '108px' },
  { key: 'paid', label: '回款进度', width: '128px' },
  { key: 'status', label: '状态', width: '92px', align: 'center' }
]
const contractTone = { 执行中: 'tag-brand', 待审批: 'tag-warning', 已完成: 'tag-success', 已终止: 'tag-gray' }

const paymentColumns = [
  { key: 'id', label: '回款单号', width: '142px' },
  { key: 'amount', label: '金额', width: '124px', align: 'right' },
  { key: 'method', label: '结算方式', width: '120px' },
  { key: 'paidDate', label: '到账日期', width: '112px' },
  { key: 'status', label: '核销状态', width: '100px', align: 'center' }
]
const paymentTone = { 已核销: 'tag-success', 已回款: 'tag-success', 部分核销: 'tag-warning', 待核销: 'tag-warning' }
</script>

<style scoped>
/* ---------- 面包屑 ---------- */
.crumbs {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 12px;
  font-size: 12.5px;
  color: var(--faint);
}
.back {
  display: inline-flex;
  align-items: center;
  gap: 2px;
  color: var(--muted);
}
.back:hover {
  color: var(--brand);
}
.sep {
  color: var(--line);
}
.cur {
  color: var(--ink);
  font-weight: 550;
}
.local-hint {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  margin-left: 4px;
  padding: 1px 6px;
  border-radius: 4px;
  background: var(--warning-bg);
  color: var(--warning);
  font-size: 10.5px;
}

/* ---------- 档案条 ---------- */
.hero {
  padding: 18px 20px 0;
}
.hero-top {
  display: flex;
  align-items: flex-start;
  gap: 14px;
  padding-bottom: 16px;
}
.logo {
  width: 46px;
  height: 46px;
  border-radius: 12px;
  display: grid;
  place-items: center;
  background: var(--brand-600);
  color: #fff;
  font-size: 19px;
  font-weight: 600;
  flex-shrink: 0;
}
.hero-id {
  min-width: 0;
  flex: 1;
}
.name-row {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}
.name-row h2 {
  font-size: 19px;
  font-weight: 650;
  color: var(--ink);
  letter-spacing: -0.2px;
}
.hero-sub {
  margin-top: 4px;
  font-size: 12.5px;
  color: var(--muted);
}
.hero-tags {
  display: flex;
  gap: 6px;
  margin-top: 8px;
  flex-wrap: wrap;
}
.chip {
  padding: 1px 7px;
  border-radius: 4px;
  background: #f2f4f7;
  color: var(--muted);
  font-size: 11px;
}
.hero-actions {
  position: relative;
  display: flex;
  gap: 8px;
  flex-shrink: 0;
}
.more-menu {
  position: absolute;
  top: 38px;
  right: 0;
  z-index: 30;
  width: 168px;
  padding: 5px;
  background: #fff;
  border: 1px solid var(--line);
  border-radius: 9px;
  box-shadow: var(--shadow-md);
  display: flex;
  flex-direction: column;
}
.more-menu button {
  display: flex;
  align-items: center;
  gap: 7px;
  height: 32px;
  padding: 0 9px;
  border: none;
  background: transparent;
  border-radius: 6px;
  font-size: 12.5px;
  color: var(--text);
  text-align: left;
  cursor: pointer;
}
.more-menu button:hover {
  background: #f5f7fa;
  color: var(--ink);
}

.facts {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  border-top: 1px solid var(--line-soft);
}
.fact {
  padding: 12px 14px 14px;
  border-right: 1px solid var(--line-soft);
  min-width: 0;
}
.fact:last-child {
  border-right: none;
}
.fk {
  font-size: 11.5px;
  color: var(--faint);
}
.fv {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 5px;
  min-width: 0;
}
.fv strong {
  font-size: 14px;
  font-weight: 600;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}
.fs {
  font-size: 11.5px;
}
.tiny {
  font-size: 10.5px;
  padding: 1px 5px;
}

.metrics {
  margin: 16px 0;
}

/* ---------- tab ---------- */
.main {
  padding-bottom: 4px;
}
.pane {
  padding: 16px 20px 18px;
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

.two-col {
  display: grid;
  grid-template-columns: minmax(0, 1.5fr) minmax(0, 1fr);
  gap: 16px;
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 14px;
  min-width: 0;
}
.sub-card {
  border: 1px solid var(--line-soft);
  border-radius: 10px;
  padding: 14px 16px;
}
.sub-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 12px;
  font-size: 13px;
  font-weight: 600;
  color: var(--ink);
}

/* ---------- 迷你柱图 ---------- */
.bars {
  display: flex;
  align-items: flex-end;
  gap: 12px;
  height: 132px;
}
.bar-col {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 5px;
  height: 100%;
  min-width: 0;
}
.bar-val {
  font-size: 11px;
  color: var(--muted);
  font-variant-numeric: tabular-nums;
}
.bar-track {
  flex: 1;
  width: 100%;
  display: flex;
  align-items: flex-end;
  justify-content: center;
}
.bar {
  width: 60%;
  max-width: 38px;
  border-radius: 4px 4px 2px 2px;
  background: linear-gradient(180deg, #4b86c6, #2b6cb0);
  transition: height 0.3s;
}
.bar-lab {
  font-size: 11px;
  color: var(--faint);
}

/* ---------- 画像 ---------- */
.note {
  font-size: 12.5px;
  line-height: 1.7;
  color: #4a5568;
  padding: 9px 11px;
  border-radius: 8px;
  background: #f7f9fc;
  margin-bottom: 12px;
}
.kv {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px 16px;
}
.kv > div {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.kv b {
  font-size: 12.5px;
  font-weight: 500;
  color: var(--text);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* ---------- 待处理 ---------- */
.todos {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.todo {
  display: flex;
  gap: 9px;
  padding: 9px 11px;
  border-radius: 8px;
  background: #f9fafb;
  border-left: 2px solid var(--line);
}
.todo.danger {
  background: #fef6f5;
  border-left-color: var(--danger);
}
.todo.warning {
  background: #fdf9f4;
  border-left-color: var(--warning);
}
.todo.info {
  background: #f5f8ff;
  border-left-color: var(--info);
}
.todo-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  margin-top: 6px;
  flex-shrink: 0;
  background: currentColor;
}
.todo.danger .todo-dot { color: var(--danger); }
.todo.warning .todo-dot { color: var(--warning); }
.todo.info .todo-dot { color: var(--info); }
.todo-title {
  font-size: 12.5px;
  font-weight: 550;
  color: var(--ink);
}
.todo-desc {
  margin-top: 1px;
  font-size: 11.5px;
  color: var(--muted);
  line-height: 1.55;
}
.all-good {
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 12px;
  border-radius: 8px;
  background: var(--success-bg);
  color: var(--success);
  font-size: 12.5px;
}

/* ---------- 决策链 ---------- */
.chain {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.chain-item {
  display: flex;
  align-items: center;
  gap: 9px;
  min-width: 0;
}
.chain-body {
  flex: 1;
  min-width: 0;
}
.chain-name {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12.5px;
  color: var(--ink);
  font-weight: 550;
}
.chain-cards {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
  margin-bottom: 16px;
}
.role-card {
  border: 1px solid var(--line-soft);
  border-radius: 10px;
  padding: 12px 13px;
}
.role-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 9px;
}
.role-people {
  display: flex;
  flex-direction: column;
  gap: 9px;
}
.role-person {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}
.role-empty {
  font-size: 12px;
  color: var(--faint);
  padding: 6px 0;
}
.primary-mark {
  display: inline-flex;
  align-items: center;
  gap: 2px;
  padding: 1px 5px;
  border-radius: 4px;
  background: #fdf3e7;
  color: #b54708;
  font-size: 10px;
  font-weight: 500;
}
.mini-list {
  display: flex;
  flex-direction: column;
  gap: 9px;
}
.mini-row {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}
.mini-at {
  font-size: 11px;
  color: var(--faint);
  font-variant-numeric: tabular-nums;
  flex-shrink: 0;
}
.mini-title {
  flex: 1;
  min-width: 0;
  font-size: 12px;
  color: var(--text);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ops {
  justify-content: flex-end;
}
.ops .btn-text:disabled {
  color: var(--faint);
  cursor: default;
}

/* ---------- 时间线 ---------- */
.tl-bar {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 4px;
}
.tl-bar .spacer {
  flex: 1;
}
.seg {
  display: flex;
  padding: 2px;
  background: #f2f4f7;
  border-radius: 7px;
}
.seg button {
  height: 27px;
  padding: 0 13px;
  border: none;
  background: transparent;
  border-radius: 5px;
  font-size: 12.5px;
  color: var(--muted);
  cursor: pointer;
}
.seg button.on {
  background: #fff;
  color: var(--ink);
  font-weight: 550;
  box-shadow: var(--shadow-xs);
}
.timeline {
  padding: 4px 0 0;
}
.tl-item {
  display: grid;
  grid-template-columns: 62px 22px 1fr;
  padding-top: 14px;
}
.tl-date {
  display: flex;
  flex-direction: column;
  padding-top: 9px;
  padding-right: 4px;
  text-align: right;
}
.tl-date b {
  font-size: 12.5px;
  color: var(--text);
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}
.tl-date span {
  font-size: 10.5px;
  color: var(--faint);
  font-variant-numeric: tabular-nums;
}
.tl-axis {
  position: relative;
  display: flex;
  justify-content: center;
}
.tl-axis::before {
  content: '';
  position: absolute;
  top: 14px;
  bottom: -16px;
  width: 1px;
  background: #dde3ea;
}
.tl-item:last-of-type .tl-axis::before {
  display: none;
}
.tl-axis i {
  width: 9px;
  height: 9px;
  margin-top: 13px;
  border-radius: 50%;
  background: #fff;
  border: 2px solid #c6d4e3;
  z-index: 1;
}
.tl-axis i.success { border-color: #7fbfa8; }
.tl-axis i.warning { border-color: #e0b183; }
.tl-axis i.danger { border-color: #e29e96; }
.tl-axis i.brand { border-color: #93b4d8; }
.tl-card {
  margin-left: 8px;
  padding: 12px 14px;
  border: 1px solid var(--line);
  border-radius: 10px;
  background: #fff;
}
.tl-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.tl-head strong {
  font-size: 13px;
  color: var(--ink);
  font-weight: 600;
}
.type-ico {
  width: 25px;
  height: 25px;
  border-radius: 7px;
  display: grid;
  place-items: center;
  margin-right: 2px;
  flex-shrink: 0;
}
.tone-info { background: var(--info-bg); color: var(--info); }
.tone-brand { background: var(--brand-soft); color: var(--brand); }
.tone-warning { background: var(--warning-bg); color: var(--warning); }
.tone-success { background: var(--success-bg); color: var(--success); }
.tone-danger { background: var(--danger-bg); color: var(--danger); }
.tone-gray { background: #f2f4f7; color: var(--muted); }
.tl-content {
  margin: 8px 0 9px;
  font-size: 12.5px;
  line-height: 1.7;
  color: #4a5568;
}
.tl-foot {
  padding-top: 8px;
  border-top: 1px dashed var(--line-soft);
  font-size: 11.5px;
}

/* ---------- 合同回款 ---------- */
.paid {
  display: flex;
  align-items: center;
  gap: 7px;
}
.paid-track {
  flex: 1;
  height: 6px;
  border-radius: 3px;
  background: #e4e7ec;
  overflow: hidden;
  min-width: 42px;
}
.paid-fill {
  height: 100%;
  border-radius: 3px;
  background: var(--brand);
}
.num {
  font-variant-numeric: tabular-nums;
  color: var(--ink);
}

/* ---------- 附件 ---------- */
.files {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}
.file {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 11px 13px;
  border: 1px solid var(--line-soft);
  border-radius: 9px;
  min-width: 0;
}
.file.warn {
  border-color: #f3dcc4;
  background: #fefbf7;
}
.file-ico {
  width: 30px;
  height: 30px;
  border-radius: 7px;
  display: grid;
  place-items: center;
  background: var(--brand-soft);
  color: var(--brand);
  flex-shrink: 0;
}
.file-body {
  flex: 1;
  min-width: 0;
}
.file-name {
  font-size: 12.5px;
  color: var(--ink);
  font-weight: 500;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.file.add {
  justify-content: center;
  gap: 6px;
  border-style: dashed;
  color: var(--muted);
  font-size: 12.5px;
  background: transparent;
  cursor: pointer;
}
.file.add:hover {
  border-color: var(--brand-line);
  color: var(--brand);
}

/* ---------- 表单 ---------- */
.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}
.area {
  height: auto;
  padding: 9px 11px;
  line-height: 1.65;
  resize: vertical;
  font-family: inherit;
}
.hint-line {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  margin-top: 4px;
  padding: 9px 11px;
  border-radius: 8px;
  background: #f7f9fc;
  font-size: 11.5px;
  line-height: 1.6;
  color: var(--muted);
}
.loading-card {
  padding: 40px 0;
}

@media (max-width: 1280px) {
  .facts {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
  .fact:nth-child(3) {
    border-right: none;
  }
}
@media (max-width: 1100px) {
  .two-col {
    grid-template-columns: 1fr;
  }
  .chain-cards {
    grid-template-columns: 1fr;
  }
  .files {
    grid-template-columns: 1fr;
  }
  .metrics {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

/* ---------- 编辑客户档案 ---------- */
.empty-line {
  margin: 10px 0 0;
  font-size: 12px;
  color: var(--faint);
}
</style>


