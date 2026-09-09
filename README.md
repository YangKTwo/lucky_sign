# 今日幸运签 · Lucky Sign

小圈子每日幸运签 + 任务打卡 + 实时社区聊天。

## 结构

- `backend/` — Spring Boot 3 + MySQL + WebSocket
- `mobile/` — Flutter（Android / iOS / Web）

## 快速启动

### 后端

```powershell
cd backend
# MySQL 需已创建库 lucky_sign；默认账号 root / 1234，可用环境变量覆盖
# $env:MYSQL_PASSWORD="你的密码"
mvn spring-boot:run
```

默认管理员：`admin@luckysign.local` / `admin123`

### 客户端

```powershell
cd mobile
flutter pub get
flutter run -d emulator-5554
# 或 flutter run -d chrome
```

模拟器访问本机后端：`http://10.0.2.2:8080`（见 `mobile/lib/config.dart`）。

## 说明

- 邮件默认关闭（`app.mail.enabled=false`），仅打日志
- 本地敏感配置可建 `backend/src/main/resources/application-local.yml`（已加入 .gitignore）
