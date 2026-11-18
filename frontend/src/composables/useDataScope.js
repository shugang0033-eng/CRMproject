import { computed, ref, watch } from 'vue'
import { can } from '@/store/permissions'
import { PERIODS } from '@/data/analytics'
import { analyticsApi } from '@/api/analytics'
import { toast } from '@/composables/useToast'

export function useDataScope(type) {
  const period = ref('year')
  const dept = ref('')
  const owner = ref('')
  const depts = ref([])
  const owners = ref([])
  const report = ref(null)
  const filters = () => ({ period: period.value, deptId: dept.value, ownerId: owner.value })

  analyticsApi.filters().then((data) => {
    depts.value = data.depts
    owners.value = data.owners
  }).catch((error) => toast(error.message, 'error'))

  watch([period, dept, owner], async (_, __, onCleanup) => {
    let current = true
    onCleanup(() => { current = false })
    report.value = null
    try {
      const data = await analyticsApi[type](filters())
      if (current) report.value = data
    } catch (error) {
      if (current) toast(error.message, 'error')
    }
  }, { immediate: true })

  async function exportReport() {
    try {
      const blob = await analyticsApi.exportFile(type, filters())
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.download = type + '.xlsx'
      link.click()
      URL.revokeObjectURL(link.href)
    } catch (error) {
      toast(error.message, 'error')
    }
  }

  const scopeLabel = computed(() => {
    if (can('data.scope.all')) return '全公司数据'
    if (can('data.scope.dept')) return '本部门及下级'
    return '仅本人数据'
  })
  return { period, dept, owner, depts, owners, scopeLabel, periods: PERIODS, report, exportReport }
}
