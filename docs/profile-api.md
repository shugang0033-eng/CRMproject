# 个人中心接口契约（前端已就绪，后端待实现）

前端页面：`src/views/settings/Profile.vue`
前端请求层：`src/api/profile.js`
前端状态层：`src/store/profile.js`

页面已按下面的契约写死调用方式，后端照此实现即可直接联通，**前端不需要再改**。
在接口实现之前，页面会自动降级为本地模式并在顶部提示，不会白屏、不会报错弹窗。

---

## 0. 通用约定

- 所有接口都基于当前 `HttpSession`（与已有的 `/api/auth/*` 一致），**不传 userId**，从 session 里取 `employeeId`。
- 未登录统一返回 `401`。
- 成功但无响应体返回 `204`。
- 错误体沿用 Spring 默认结构：`{ timestamp, status, error, path }`。
- 前端只按状态码判断，中文文案在前端映射（`src/api/http.js`）。

---

## 1. 读取个人资料

```
GET /api/profile
```

响应 `200`：

```json
{
  "id": 11,
  "account": "admin",
  "employeeNo": "Ecd732967dd1f11f1",
  "name": "超级管理员",
  "dept": "华东销售组",
  "deptId": 5,
  "role": "超级管理员",
  "roleCode": "super_admin",
  "phone": "13800000000",
  "email": "admin@beichen.com",
  "avatar": "data:image/jpeg;base64,...",
  "hireDate": "2021-03-01",
  "status": "active",
  "lastLoginAt": "2026-11-11T09:52:00",
  "lastLoginIp": "127.0.0.1",
  "passwordUpdatedAt": "2026-11-10T18:20:00",
  "mustChangePassword": false
}
```

字段说明：

| 字段 | 说明 |
| --- | --- |
| `account` | 登录账号，同 `crm_employees.username` |
| `role` / `roleCode` | 取该员工当前角色（`crm_employee_roles` → `crm_roles`），与 `/api/auth/login` 返回口径一致 |
| `avatar` | 可以直接返回 dataURL，也可以返回 URL 字符串，前端两种都能显示 |
| `mustChangePassword` | 新建账号、管理员重置密码后置 `true`，前端会显示「正在使用初始密码」黄色提醒；改了密码后置 `false` |
| `passwordUpdatedAt` | 最近一次改密时间，可空 |
| `lastLoginAt` / `lastLoginIp` | 上次登录信息，可空（前端在为空时退回本地记录） |

---

## 2. 保存基本信息

```
PUT /api/profile
Content-Type: application/json

{ "name": "张三", "phone": "13800000000", "email": "zhangsan@beichen.com" }
```

- 成功 `204`。
- 校验失败 `400`（前端已有格式校验，后端仍需兜底）。
- **只允许改这三个字段**，`employeeNo`、`departmentId`、角色、状态由员工管理模块维护。

建议的校验：`name` 1–20 字，`phone` 可空或 11 位手机号，`email` 可空或合法邮箱。

---

## 3. 上传头像

```
POST /api/profile/avatar
Content-Type: application/json

{ "dataUrl": "data:image/jpeg;base64,/9j/4AAQSkZJRg..." }
```

- 前端已把图片**居中裁剪成 240×240 的正方形并压缩为 JPEG**，单张约 20–40KB，无恶意大文件风险。
- 成功返回 `200`：

```json
{ "avatar": "data:image/jpeg;base64,..." }
```

`avatar` 可以是原样回传的 dataURL，也可以是后端落盘/传对象存储后的 http URL。前端拿到后直接替换显示。

- 建议用 `MEDIUMTEXT` 存 dataURL，或 `VARCHAR(500)` 存 URL。

---

## 4. 修改密码

```
POST /api/profile/password
Content-Type: application/json

{ "oldPassword": "123456", "newPassword": "Beichen@2026" }
```

- 成功 `204`。
- 旧密码不正确 → `400`（前端会把 400 翻译成「当前密码不正确，请重新输入」）。
- 未登录 → `401`。
- 新密码规则（前端已拦，后端仍要校验）：至少 8 位，且同时包含字母和数字，且不能与旧密码相同。

实现要点：

- 现有 `crm_employees.password_hash` 是 `varchar(128)`，建议用 BCrypt（`BCryptPasswordEncoder`），68 位左右刚好放得下。
- 新用户默认密码 `123456`，创建员工时写入 `password_hash`，并把 `must_change_password` 置 `true`。
- 改密成功后把 `must_change_password` 置 `false`、更新 `password_updated_at`。
- 可以选择改密后调用 `session.invalidate()` 强制重登；若这样做，请返回 `204` 后前端会提示「下次登录请使用新密码」，用户手动退出即可，**不要返回 401**（前端会当作未登录直接跳登录页）。

---

## 5. 最近登录记录

```
GET /api/profile/logins
```

响应 `200`（按时间倒序，最多 10 条）：

```json
[
  {
    "id": 1024,
    "device": "Chrome 122 · Windows 11",
    "ip": "127.0.0.1",
    "location": "杭州",
    "at": "2026-11-11T09:52:00",
    "current": true
  }
]
```

- `current` 表示是不是当前这条会话。
- 没有记录时返回空数组即可，前端会显示空态。
- 若不想做这张表，直接返回 `[]`，页面仍然正常（会显示「登录记录接口待实现」）。

---

## 6. 数据库建议（新建，不影响已有表）

```sql
ALTER TABLE crm_employees
  ADD COLUMN avatar MEDIUMTEXT NULL COMMENT '头像 dataURL 或 URL',
  ADD COLUMN must_change_password TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN password_updated_at DATETIME NULL,
  ADD COLUMN last_login_at DATETIME NULL,
  ADD COLUMN last_login_ip VARCHAR(64) NULL;

CREATE TABLE IF NOT EXISTS crm_login_logs (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  employee_id BIGINT UNSIGNED NOT NULL,
  device VARCHAR(120) NULL,
  ip VARCHAR(64) NULL,
  location VARCHAR(64) NULL,
  logged_in_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_employee_time (employee_id, logged_in_at)
);
```

> 注意：`crm_employees` 现在没有头像相关列，`password_hash` 已存在，可直接用。

---

## 7. 前端已有的行为（后端不需要额外配合）

- 页面入口：左侧菜单「设置 › 个人中心」，以及左下角头像菜单、右上角用户面板，**所有角色都能进**，不走功能权限点。
- 头像上传后**立即本地回显**（同时已调上传接口），刷新后从 `GET /api/profile` 或本地缓存取。
- 接口 404 / 405 / 连不上时，页面顶部显示提示条，表单改为本地保存，不阻塞使用。
- 前端保存基本信息后，员工管理页的姓名/手机/邮箱在下次刷新时才会同步（因为改的是同一张表）。

---

## 8. 自测命令

```bash
# 登录拿 cookie
curl -c /tmp/c.txt -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"123456"}' \
  http://localhost:8080/api/auth/login

# 读资料
curl -b /tmp/c.txt http://localhost:8080/api/profile

# 改基本信息
curl -b /tmp/c.txt -X PUT -H "Content-Type: application/json" \
  -d '{"name":"超级管理员","phone":"13800000000","email":"admin@beichen.com"}' \
  http://localhost:8080/api/profile

# 改密码
curl -b /tmp/c.txt -X POST -H "Content-Type: application/json" \
  -d '{"oldPassword":"123456","newPassword":"Beichen@2026"}' \
  http://localhost:8080/api/profile/password
```
