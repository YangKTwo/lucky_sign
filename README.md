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

**调试模式**自动使用 `http://localhost:8080`（模拟器用 `http://10.0.2.2:8080`）。

**Release 构建**必须通过 `--dart-define` 注入 API 地址：

```bash
# Release APK 必须提供 https/wss 地址
flutter build apk --release \
  --dart-define=API_BASE=https://your-domain.example \
  --dart-define=WS_BASE=wss://your-domain.example/ws

# Web 版同源部署时可省略（自动从页面 origin 推导）
flutter build web --release --base-href=/app/
```

> ⚠️ **Release 构建不提供默认值**：如果缺少 `API_BASE` 或 `WS_BASE`，应用启动时会抛出 `StateError`。
> 这是刻意设计——避免发布包意外连接到错误的后端。

## 自动部署（GitHub Actions → ECS）

推送到 `main` 且改动了 `backend/**`（或手动 Run workflow）时，会自动构建 JAR、上传到服务器并重启。

推送到 `main` 且改动了 `mobile/**` 时，会自动：

1. **安卓 APK**
   - **CI 验证**：检查 `PUBLIC_API_BASE` / `PUBLIC_WS_BASE` 或从 `DEPLOY_HOST` 派生，必须 https/wss
   - 验证失败时 **exit 1，不上传任何文件**，不覆盖 `lucky-sign-latest.apk`
   - 构建时注入 `--dart-define=API_BASE=...` 和 `--dart-define=WS_BASE=...`
   - 文件名带版本：`lucky-sign-<version>-<build>.apk`（build 取 GitHub run number）
   - `downloads/latest.txt` — APK 链接一行文本，方便复制
   - `downloads/latest.json` / `index.html` 下载页
   - Actions Summary 也会打印链接
   - 另有别名 `lucky-sign-latest.apk`；历史版本包保留

2. **网页版（给 iPhone / 浏览器）**
   - 构建产物同步到服务器 `webapp/`，对外地址：`https://<主机>/app/`（需要 TLS 证书）
   - API/WS 地址从页面 origin 自动推导（同源部署）
   - `downloads/web-latest.txt` — 网页链接一行文本
   - 与 APK **同一后端、同一账号数据**
   - Safari 可「分享 → 添加到主屏幕」

也可在 Actions 里手动跑 **Publish APK** / **Publish Web**。


### 1. GitHub Secrets & Variables

仓库 → Settings → Secrets and variables → Actions

#### Secrets（敏感信息，不可公开）

| Secret | 说明 |
|--------|------|
| `DEPLOY_HOST` | 服务器公网 IP 或域名 |
| `DEPLOY_USER` | SSH 用户名 |
| `DEPLOY_SSH_KEY` | 部署用私钥全文（含 `BEGIN`/`END`） |
| `DEPLOY_PORT` | 可选，默认 `22` |

> ⚠️ **不要把 JWT_SECRET、数据库密码、OSS 密钥等放入 `--dart-define`**——这些会编译进 APK/Web 产物，可被逆向提取。

#### Variables（公开配置，用于 APK 构建）

| Variable | 说明 |
|----------|------|
| `PUBLIC_API_BASE` | 可选。APK 内置的 API 地址，如 `https://api.example.com`。未设置时从 `DEPLOY_HOST` 派生 |
| `PUBLIC_WS_BASE` | 可选。APK 内置的 WebSocket 地址，如 `wss://api.example.com/ws`。未设置时从 `DEPLOY_HOST` 派生 |

**CI 会验证：**
- `PUBLIC_API_BASE` 或 `DEPLOY_HOST` 至少有一个必须设置
- API 地址必须以 `https://` 开头（release 禁止 http）
- WS 地址必须以 `wss://` 开头（release 禁止 ws）
- 验证失败时 CI 会 exit 1，**不会上传或覆盖 latest APK**

### 2. 服务器一次性准备

> **⚠️ 生产部署必须设置 `run.env`**
>
> 后端启动脚本会读取 `/www/wwwroot/lucky-api/run.env`。
> 如果缺少必需变量，启动会失败并报错。

**必需变量（缺一不可）：**
| 变量 | 要求 | 说明 |
|------|------|------|
| `MYSQL_PASSWORD` | 非空 | MySQL 密码 |
| `JWT_SECRET` | **≥32 字符** | 用于签发 JWT token；必须是安全随机字符串 |
| `CORS_ORIGINS` | **HTTPS 域名** | 生产环境必须设置，如 `https://119-23-45-226.sslip.io` |
| `CORS_PRODUCTION` | `true` | 启用 CORS 严格模式，缺失 CORS_ORIGINS 时 fail-fast |

**生成安全 JWT_SECRET 示例：**
```bash
# Linux/macOS
openssl rand -base64 48
# 或
head -c 48 /dev/urandom | base64
```

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

# ---- 生产 CORS（必需！）----
# 设置前端域名，如 https://119-23-45-226.sslip.io
# 多个域名用逗号分隔；不允许 * 通配符
CORS_ORIGINS=https://your-domain.example
CORS_PRODUCTION=true

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
| CORS | 服务器 `run.env` | `CORS_ORIGINS` + `CORS_PRODUCTION=true`（生产必须显式设置 HTTPS 域名，不允许通配符） |

社区里发送带 `@助手` 的消息即可触发回复（需 `AI_ENABLED=true` 且填了 Key）。

### 3. 手动触发

GitHub → Actions → **Deploy backend** / **Publish APK** / **Publish Web** → Run workflow。

工作流：

- 后端：[`.github/workflows/deploy-backend.yml`](.github/workflows/deploy-backend.yml)
- APK：[`.github/workflows/deploy-apk.yml`](.github/workflows/deploy-apk.yml)
- Web：[`.github/workflows/deploy-web.yml`](.github/workflows/deploy-web.yml)
- 重启脚本：[`deploy/start-backend.sh`](deploy/start-backend.sh)
- Nginx 反向代理（生产 HTTP）：[`deploy/nginx-lucky-api.conf`](deploy/nginx-lucky-api.conf)
- Nginx 反向代理（TLS 示例）：[`deploy/nginx-example.conf`](deploy/nginx-example.conf)

## WebSocket (WSS) 排查

后端 STOMP 端点注册在 `/ws`（精确路径，非 `/ws/`）。

### 快速探测

```bash
# 本地后端测试
./deploy/wss-probe.sh http://127.0.0.1:8080

# 生产环境测试（通过 nginx）
./deploy/wss-probe.sh https://your-domain.example
```

成功时返回 **HTTP 101 Switching Protocols**。

### 常见问题

| 现象 | 可能原因 | 排查 |
|------|----------|------|
| HTTP 404 | Security 配置未放行 `/ws` | 确保 `requestMatchers("/ws", "/ws/**").permitAll()` |
| HTTP 403 | CSRF 拦截 | 确保 CSRF 忽略 `/ws` 和 `/ws/**` |
| HTTP 429 | 被限流 | 确保 RateLimitFilter 豁免 `/ws` 路径 |
| `NoResourceFoundException: No static resource ws` | Spring 把 `/ws` 当静态资源处理 | 检查 WebSocketConfig 是否正确注册端点 |
| 通过 nginx 返回 502/504 | nginx 未正确代理 Upgrade | 检查 nginx `location = /ws` 和 `Connection $connection_upgrade` |

### 后端检查清单

1. **SecurityConfig**：`requestMatchers("/ws", "/ws/**").permitAll()` + CSRF 忽略
2. **RateLimitFilter**：豁免 `/ws` 和 `/ws/**`
3. **GlobalExceptionHandler**：不要把 WS 握手异常转为通用 JSON 错误
4. **WebSocketConfig**：`registry.addEndpoint("/ws")`

### Nginx 检查清单（运维操作）

> ⚠️ nginx 配置由运维管理，开发者仅需确保后端正确。

需要在 `http{}` 块添加 map 指令（Baota 面板需手动编辑 nginx.conf）：

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}
```

然后配置 location（注意 `= /ws` 精确匹配）：

```nginx
location = /ws {
    proxy_pass http://127.0.0.1:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    # ... 其他 headers
}
```

## 说明

- 邮件默认关闭（`app.mail.enabled=false`），仅打日志
- 本地敏感配置可建 `backend/src/main/resources/application-local.yml`（已加入 .gitignore）
- 公开仓库中请勿写入真实数据库口令、JWT、云密钥或管理员密码
