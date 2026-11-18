<template>
  <div class="page">
    <PageHead title="联系人" desc="维护客户方的关键决策人与对接人，标记主联系人便于快速触达">
      <button class="btn" type="button" @click="toast('已导出联系人（演示）')">
        <AppIcon name="download" :size="14" />导出
      </button>
      <button v-can="'contact.edit'" class="btn btn-primary" type="button" @click="toast('新建联系人表单开发中')">
        <AppIcon name="plus" :size="14" />新建联系人
      </button>
    </PageHead>

    <div class="card">
      <div class="toolbar">
        <div class="search">
          <AppIcon name="search" :size="15" />
          <input v-model="keyword" class="input" type="text" placeholder="搜索姓名 / 手机号 / 所属客户" />
        </div>
        <select v-model="customer" class="select">
          <option value="">全部客户</option>
          <option v-for="c in customerOptions" :key="c">{{ c }}</option>
        </select>
        <select v-model="owner" class="select">
          <option value="">全部负责人</option>
          <option v-for="o in owners" :key="o">{{ o }}</option>
        </select>
        <div class="spacer" />
        <label class="check">
          <input v-model="onlyPrimary" type="checkbox" />
          <span>只看主联系人</span>
        </label>
      </div>

      <AppTable :columns="columns" :rows="filtered" :page-size="8">
        <template #cell-name="{ row }">
          <div class="row-tight">
            <UserAvatar :name="row.name" />
            <div>
              <div class="cell-main">
                {{ row.name }}
                <span v-if="row.primary" class="primary-mark">
                  <AppIcon name="star" :size="11" />主联系人
                </span>
              </div>
              <div class="cell-sub">{{ row.title }}</div>
            </div>
          </div>
        </template>
        <template #cell-phone="{ row }">
          <span class="mono-num">{{ row.phone }}</span>
        </template>
        <template #cell-email="{ row }">
          <a class="mail" :href="`mailto:${row.email}`">{{ row.email }}</a>
        </template>
        <template #cell-owner="{ row }">
          <span class="row-tight">
            <UserAvatar :name="row.owner" size="sm" />
            <span>{{ row.owner }}</span>
          </span>
        </template>
        <template #cell-ops="{ row }">
          <div class="row-tight ops">
            <button v-can="'contact.edit'" class="btn-text" type="button" @click="toast(`编辑联系人「${row.name}」`)">编辑</button>
            <button v-can="'contact.edit'" class="btn-text danger" type="button" @click="toast(`已移除联系人「${row.name}」`)">删除</button>
          </div>
        </template>
      </AppTable>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import PageHead from '@/components/PageHead.vue'
import AppIcon from '@/components/AppIcon.vue'
import AppTable from '@/components/AppTable.vue'
import UserAvatar from '@/components/UserAvatar.vue'
import { customerApi } from '@/api/customers'
import { toast } from '@/composables/useToast'

const keyword = ref('')
const customer = ref('')
const owner = ref('')
const onlyPrimary = ref(false)

const contacts = ref([])
const owners = computed(() => [...new Set(contacts.value.map((c) => c.owner))])
onMounted(async () => {
  try {
    contacts.value = (await customerApi.contacts()).map((row) => ({ ...row, primary: true }))
  } catch (e) {
    toast(e.message, 'error')
  }
})
const customerOptions = computed(() => [...new Set(contacts.value.map((c) => c.customer))])

const columns = [
  { key: 'name', label: '联系人' },
  { key: 'customer', label: '所属客户' },
  { key: 'phone', label: '手机号', width: '128px' },
  { key: 'email', label: '邮箱' },
  { key: 'owner', label: '负责人', width: '110px' },
  { key: 'ops', label: '操作', align: 'right', width: '110px' }
]

const filtered = computed(() =>
  contacts.value.filter((c) => {
    if (customer.value && c.customer !== customer.value) return false
    if (owner.value && c.owner !== owner.value) return false
    if (onlyPrimary.value && !c.primary) return false
    if (keyword.value) {
      const k = keyword.value.trim()
      if (![c.name, c.phone, c.customer, c.email].join(' ').includes(k)) return false
    }
    return true
  })
)
</script>

<style scoped>
.primary-mark {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  margin-left: 6px;
  padding: 1px 5px;
  border-radius: 4px;
  background: #fdf3e7;
  color: #b54708;
  font-size: 10.5px;
  font-weight: 500;
  vertical-align: 1px;
}
.mail {
  color: var(--text);
  font-size: 13px;
}
.mail:hover {
  color: var(--brand);
}
.check {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 12.5px;
  color: var(--muted);
  cursor: pointer;
  user-select: none;
  white-space: nowrap;
}
.check input {
  accent-color: var(--brand);
}
.ops {
  justify-content: flex-end;
}
</style>

