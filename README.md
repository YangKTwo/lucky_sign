# 今日幸运签 · Lucky Sign

小圈子每日幸运签 + 任务打卡 + 实时社区聊天。

## 结构

- `backend/` — Spring Boot 3 + MySQL + WebSocket
- `mobile/` — Flutter（Android / iOS / Web）
- `deploy/` — 服务器启动脚本（配合 GitHub Actions）

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

模拟器访问本机后端：`http://10.0.2.2:8080`（见 `mobile/lib/config.dart`）。当前默认连云端。

## 自动部署（GitHub Actions → ECS）

推送到 `main` 且改动了 `backend/**`（或手动 Run workflow）时，会自动构建 JAR、上传到服务器并重启。

推送到 `main` 且改动了 `mobile/**` 时，会自动打安卓 APK 并放到下载目录。

**安装包地址（覆盖安装）：** http://119.23.45.226:8080/downloads/lucky-sign.apk

页面：http://119.23.45.226:8080/downloads/index.html

### 1. GitHub Secrets

仓库 → Settings → Secrets and variables → Actions，新增：

| Secret | 示例 |
|--------|------|
| `DEPLOY_HOST` | `119.23.45.226` |
| `DEPLOY_USER` | `admin` |
| `DEPLOY_SSH_KEY` | 部署用私钥全文（含 `BEGIN`/`END`） |
| `DEPLOY_PORT` | 可选，默认 `22` |

### 2. 服务器一次性准备

```bash
# 将本机生成的部署公钥写入 admin 的 authorized_keys
mkdir -p ~/.ssh
chmod 700 ~/.ssh
# echo "ssh-ed25519 AAAA... deploy@github" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

mkdir -p /www/wwwroot/lucky-api/uploads

cat >/www/wwwroot/lucky-api/run.env <<'EOF'
MYSQL_USER=root
MYSQL_PASSWORD=123456
EOF
chmod 600 /www/wwwroot/lucky-api/run.env
```

`run.env` 只放在服务器，不要提交到 Git。

### 3. 手动触发

GitHub → Actions → **Deploy backend** 或 **Publish APK** → Run workflow。

工作流：

- 后端：[`.github/workflows/deploy-backend.yml`](.github/workflows/deploy-backend.yml)
- APK：[`.github/workflows/deploy-apk.yml`](.github/workflows/deploy-apk.yml)
- 重启脚本：[`deploy/start-backend.sh`](deploy/start-backend.sh)

## 说明

- 邮件默认关闭（`app.mail.enabled=false`），仅打日志
- 本地敏感配置可建 `backend/src/main/resources/application-local.yml`（已加入 .gitignore）
