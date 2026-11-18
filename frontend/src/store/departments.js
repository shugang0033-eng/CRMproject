import { reactive } from 'vue'
import { departmentApi } from '@/api/departments'

/**
 * 部门数据源（真实后端）
 * 部门树与负责人候选来自 Spring Boot，不再走 localStorage 演示数据。
 */
export const deptStore = reactive({
  tree: [],
  leaders: [],
  loading: false,
  loaded: false,
  error: ''
})

let inflight = null

export async function loadDepartments({ force = false } = {}) {
  if (inflight) return inflight
  if (deptStore.loaded && !force) return deptStore.tree

  deptStore.loading = true
  deptStore.error = ''

  inflight = (async () => {
    try {
      // 负责人候选失败不应让整页挂掉，退化为空列表
      const [tree, leaders] = await Promise.all([
        departmentApi.tree(),
        departmentApi.leaderOptions().catch(() => [])
      ])
      deptStore.tree = Array.isArray(tree) ? tree : []
      deptStore.leaders = Array.isArray(leaders) ? leaders : []
      deptStore.loaded = true
      return deptStore.tree
    } catch (e) {
      deptStore.error = e?.message || '部门数据加载失败'
      deptStore.tree = []
      throw e
    } finally {
      deptStore.loading = false
      inflight = null
    }
  })()

  return inflight
}

/** 展平部门树，附带 depth，便于下拉与统计 */
export function flattenDepartments(nodes = deptStore.tree, depth = 0, out = []) {
  nodes.forEach((n) => {
    out.push({ ...n, depth })
    if (n.children?.length) flattenDepartments(n.children, depth + 1, out)
  })
  return out
}

/** 部门名列表，供员工等下拉框使用 */
export function departmentNames() {
  return flattenDepartments().map((d) => d.name)
}
