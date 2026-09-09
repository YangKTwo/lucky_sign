# 今日幸运签 · 后端

## 环境
- JDK 17
- Maven 3.9+
- MySQL 8（库名 `lucky_sign`，账号 root，密码见 `application.yml`）

## 启动
```bash
cd backend
mvn spring-boot:run
```

## 默认管理员
- 邮箱：`admin@luckysign.local`
- 密码：`admin123`

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
