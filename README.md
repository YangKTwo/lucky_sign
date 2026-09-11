# 今日幸运签 · Lucky Sign

小圈子每日幸运签 + 任务打卡 + 实时社区聊天。

## 结构

- `backend/` — Spring Boot 3 + MySQL + WebSocket
- `mobile/` — **Flutter（Dart）** 客户端：Material + `http` + STOMP，无 Provider/Riverpod/Bloc
- `deploy/` — 服务器启动脚本（配合 GitHub Actions）

## 前端技术栈（简述）

Flutter 3.x / Dart ≥3.3 · StatefulWidget · http + stomp_dart_client · shared_preferences · image_picker · 目标 Android / iOS / Web。详见 [`mobile/README.md`](mobile/README.md)。

## 快速启动

### 后端

```powershell
cd backend
# 先建好 MySQL 库 lucky_sign，并用环境变量提供账号口令（勿把真实口令写进仓库）
# $env:MYSQL_USER="root"
# $env:MYSQL_PASSWORD="你的密码"
# $env:JWT_SECRET="至少32位随机串"
# $env:ADMIN_PASSWORD="首次启动管理员密码"
mvn spring-boot:run
```

默认管理员邮箱：`admin@luckysign.local`（密码以服务器 `ADMIN_PASSWORD` 为准，勿提交到 Git）。

### 客户端

```powershell
cd mobile
flutter pub get
flutter run -d emulator-5554
# 或 flutter run -d chrome
```

模拟器访问本机后端：`http://10.0.2.2:8080`（见 `mobile/lib/config.dart`）。也可用 `--dart-define=API_BASE=...` 覆盖。

## 自动部署（GitHub Actions → ECS）

推送到 `main` 且改动了 `backend/**`（或手动 Run workflow）时，会自动构建 JAR、上传到服务器并重启。

推送到 `main` 且改动了 `mobile/**` 时，会自动打安卓 APK：

- 文件名带版本：`lucky-sign-<version>-<build>.apk`（build 取 GitHub run number）
- 每次构建会在服务器写入：
  - `downloads/latest.txt` — **一行纯文本下载链接，直接复制**
  - `downloads/latest.json` — 含版本、体积、时间
  - `downloads/index.html` — 下载页
- Actions run 的 **Summary** 里也会打印同一链接
- 另有别名 `lucky-sign-latest.apk`（始终指向最新包）；历史版本包会保留在同目录

### 1. GitHub Secrets

仓库 → Settings → Secrets and variables → Actions，新增：

| Secret | 说明 |
|--------|------|
| `DEPLOY_HOST` | 服务器公网 IP 或域名 |
| `DEPLOY_USER` | SSH 用户名 |
| `DEPLOY_SSH_KEY` | 部署用私钥全文（含 `BEGIN`/`END`） |
| `DEPLOY_PORT` | 可选，默认 `22` |

### 2. 服务器一次性准备

```bash
# 将本机生成的部署公钥写入部署用户的 authorized_keys
mkdir -p ~/.ssh
chmod 700 ~/.ssh
# echo "ssh-ed25519 AAAA... deploy@github" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

mkdir -p /www/wwwroot/lucky-api/uploads /www/wwwroot/lucky-api/downloads

cat >/www/wwwroot/lucky-api/run.env <<'EOF'
MYSQL_USER=root
MYSQL_PASSWORD=<your-mysql-password>
JWT_SECRET=<at-least-32-char-random-secret>
ADMIN_PASSWORD=<your-admin-password>

# ---- 阿里云 OSS（图片/头像）----
OSS_ENABLED=true
OSS_ENDPOINT=oss-cn-guangzhou.aliyuncs.com
OSS_ACCESS_KEY_ID=<your-access-key-id>
OSS_ACCESS_KEY_SECRET=<your-access-key-secret>
OSS_BUCKET=<your-bucket>
OSS_DIR_PREFIX=lucky-sign/
# 可选：绑定了 CDN/自定义域名时填写，如 https://img.example.com
# OSS_PUBLIC_BASE_URL=

# ---- 通义千问社区助手 ----
AI_ENABLED=true
AI_API_KEY=<your-dashscope-api-key>
AI_MODEL=qwen-plus
# 可选：
# AI_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
# AI_MENTION=@助手
# CORS_ORIGINS=https://your-web-origin.example
EOF
chmod 600 /www/wwwroot/lucky-api/run.env
```

`run.env` 只放在服务器，**不要提交到 Git**。改完后重启后端（或重新跑 Deploy backend）生效。

### 配置项说明

| 用途 | 填写位置 | 变量 |
|------|----------|------|
| MySQL / JWT / 管理员 | 服务器 `run.env` | `MYSQL_*` / `JWT_SECRET` / `ADMIN_PASSWORD` |
| OSS | 同上，或 `application.yml` 的 `app.oss` | `OSS_ENABLED` / `OSS_ENDPOINT` / `OSS_ACCESS_KEY_ID` / `OSS_ACCESS_KEY_SECRET` / `OSS_BUCKET` |
| 千问 | 同上 `app.ai` | `AI_ENABLED` / `AI_API_KEY` / `AI_MODEL` |

社区里发送带 `@助手` 的消息即可触发回复（需 `AI_ENABLED=true` 且填了 Key）。

### 3. 手动触发

GitHub → Actions → **Deploy backend** 或 **Publish APK** → Run workflow。

工作流：

- 后端：[`.github/workflows/deploy-backend.yml`](.github/workflows/deploy-backend.yml)
- APK：[`.github/workflows/deploy-apk.yml`](.github/workflows/deploy-apk.yml)
- 重启脚本：[`deploy/start-backend.sh`](deploy/start-backend.sh)

## 说明

- 邮件默认关闭（`app.mail.enabled=false`），仅打日志
- 本地敏感配置可建 `backend/src/main/resources/application-local.yml`（已加入 .gitignore）
- 公开仓库中请勿写入真实数据库口令、JWT、云密钥或管理员密码
