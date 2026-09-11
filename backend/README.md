# 今日幸运签 · 后端

## 环境
- JDK 17
- Maven 3.9+
- MySQL 8（库名 `lucky_sign`）

## 启动
```bash
cd backend
export MYSQL_USER=root
export MYSQL_PASSWORD='你的密码'
export JWT_SECRET='至少32位随机串'
export ADMIN_PASSWORD='首次启动管理员密码'
mvn spring-boot:run
```

口令一律用环境变量或本地 `application-local.yml`（已 gitignore），不要写进仓库。

## 默认管理员
- 邮箱：`admin@luckysign.local`
- 密码：由 `ADMIN_PASSWORD` 决定（仅首次 seed 时生效）

## 主要接口
- `POST /api/auth/register` `{nickname,email,password}`
- `POST /api/auth/login`
- `GET /api/user/profile`
- `GET /api/checkin/today`
- `POST /api/checkin/complete` multipart: text?, image?
- `GET /api/chat/messages`
- `POST /api/chat/messages` `{content}`
- `GET /api/rank`
- `POST /api/admin/users/{id}/unlock`
- WebSocket：`ws://localhost:8080/ws`，订阅 `/topic/chat`，发送 `/app/chat.send`

## 邮件
默认 `app.mail.enabled=false`，只写日志到控制台与 `email_logs` 表。
