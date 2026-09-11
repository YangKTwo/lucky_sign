#!/usr/bin/env bash
# ============================================================================
# Lucky Sign 后端启动脚本
# ============================================================================
# 必须在服务器上创建 /www/wwwroot/lucky-api/run.env 并设置以下变量：
#
#   MYSQL_PASSWORD=<数据库密码>      # 必需，不能为空
#   JWT_SECRET=<安全随机字符串>      # 必需，至少 32 字符
#
# 可选变量：
#   MYSQL_USER        默认 root
#   MYSQL_URL         默认 jdbc:mysql://127.0.0.1:3306/lucky_sign?...
#   SERVER_ADDRESS    默认 127.0.0.1（通过反向代理访问）
#   SERVER_PORT       默认 8080
#   ADMIN_PASSWORD    首次启动管理员密码
#
# 生成 JWT_SECRET：openssl rand -base64 48
#
# k2 #6: 支持分离的迁移/启动模式
#   ./start-backend.sh                    # 默认：启动应用（Flyway 自动运行）
#   ./start-backend.sh --migrate-only     # 仅运行 Flyway 迁移，然后退出
#   ./start-backend.sh --check-flyway     # 检查迁移状态，失败则退出
#
# 退出码：
#   0 - 成功
#   1 - 配置错误
#   2 - 迁移失败
#   3 - 启动失败 / 缺少工具
#   4 - 健康检查超时
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="/www/wwwroot/lucky-api"
JAR_NAME="lucky-sign-0.0.1-SNAPSHOT.jar"
JAR_PATH="${APP_DIR}/${JAR_NAME}"
LOG_PATH="${APP_DIR}/lucky-sign.log"
ENV_FILE="${APP_DIR}/run.env"
PID_MATCH="lucky-sign-0.0.1-SNAPSHOT.jar"

# Parse mode from arguments
MODE="start"  # Default: just start (Flyway runs automatically via Spring Boot)
while [[ $# -gt 0 ]]; do
  case $1 in
    --migrate-only)
      MODE="migrate-only"
      shift
      ;;
    --check-flyway)
      MODE="check-flyway"
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--migrate-only|--check-flyway]" >&2
      exit 1
      ;;
  esac
done

MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
MYSQL_URL="${MYSQL_URL:-jdbc:mysql://127.0.0.1:3306/lucky_sign?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai}"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
fi

# ============================================================================
# Validation
# ============================================================================

validate_db_config() {
  if [[ -z "${MYSQL_PASSWORD}" ]]; then
    echo "ERROR: MYSQL_PASSWORD is empty. Set it in ${ENV_FILE}" >&2
    exit 1
  fi
}

validate_full_config() {
  validate_db_config

  JWT_SECRET="${JWT_SECRET:-}"
  if [[ -z "${JWT_SECRET}" ]]; then
    echo "ERROR: JWT_SECRET is required. Set a secure random string (≥32 chars) in ${ENV_FILE}" >&2
    exit 1
  fi
  if [[ ${#JWT_SECRET} -lt 32 ]]; then
    echo "ERROR: JWT_SECRET must be at least 32 characters (current: ${#JWT_SECRET})" >&2
    exit 1
  fi

  if [[ ! -f "${JAR_PATH}" ]]; then
    echo "ERROR: JAR not found: ${JAR_PATH}" >&2
    exit 1
  fi
}

# ============================================================================
# Flyway Functions (k2 #6, k4 fix)
# ============================================================================

# Extract DB connection info from JDBC URL
parse_jdbc_url() {
  local url="$1"
  DB_HOST=$(echo "${url}" | sed -n 's|.*://\([^:/]*\).*|\1|p')
  DB_PORT=$(echo "${url}" | sed -n 's|.*:\([0-9]*\)/.*|\1|p')
  DB_NAME=$(echo "${url}" | sed -n 's|.*/\([^?]*\).*|\1|p')
  
  DB_HOST="${DB_HOST:-127.0.0.1}"
  DB_PORT="${DB_PORT:-3306}"
  DB_NAME="${DB_NAME:-lucky_sign}"
}

# k4 fix: --check-flyway fails closed on DB connection errors
check_flyway_status() {
  echo "Checking Flyway migration status..."
  parse_jdbc_url "${MYSQL_URL}"
  
  local result
  if ! result=$(mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
    -N -e "SELECT COUNT(*) FROM flyway_schema_history WHERE success = 0;" "${DB_NAME}" 2>&1); then
    echo "ERROR: Failed to connect to database or query flyway_schema_history" >&2
    echo "${result}" >&2
    exit 2
  fi
  
  local failed_count="${result}"
  
  if [[ "${failed_count}" -gt 0 ]]; then
    echo "ERROR: Found ${failed_count} failed migration(s) in flyway_schema_history" >&2
    echo "See deploy/flyway-repair-notes.md for repair instructions" >&2
    mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
      -e "SELECT version, description, success, installed_on FROM flyway_schema_history WHERE success = 0;" "${DB_NAME}" 2>/dev/null || true
    exit 2
  fi
  
  echo "Flyway status OK - no failed migrations"
  mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
    -e "SELECT version, description, success FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 5;" "${DB_NAME}" 2>/dev/null || true
}

# k4 fix: --migrate-only uses REAL Flyway only, no fake checksums
run_migration_only() {
  echo "=== Flyway Migration (migrate-only mode) ==="
  
  # Option 1: Use standalone migrate.sh (preferred)
  if [[ -x "${SCRIPT_DIR}/migrate.sh" ]]; then
    echo "Using standalone migrate.sh..."
    exec "${SCRIPT_DIR}/migrate.sh" migrate
    # exec replaces this process, so we never reach here
  fi
  
  # Option 2: Use Maven flyway:migrate (requires backend source)
  local BACKEND_DIR=""
  for dir in "${SCRIPT_DIR}/../backend" "/opt/backend"; do
    if [[ -d "${dir}" && -f "${dir}/pom.xml" && -f "${dir}/src/main/resources/db/migration/V1__initial_schema.sql" ]]; then
      BACKEND_DIR="$(cd "${dir}" && pwd)"
      break
    fi
  done
  
  if [[ -n "${BACKEND_DIR}" ]]; then
    echo "Found backend source at ${BACKEND_DIR}"
    echo "Using Maven flyway:migrate..."
    
    # Check Maven is available
    if ! command -v mvn &> /dev/null; then
      echo "ERROR: Maven not found, and migrate.sh not available." >&2
      echo "Install Maven or ensure migrate.sh is in deploy directory." >&2
      exit 3
    fi
    
    cd "${BACKEND_DIR}"
    if ! mvn flyway:migrate \
      -Dflyway.url="${MYSQL_URL}" \
      -Dflyway.user="${MYSQL_USER}" \
      -Dflyway.password="${MYSQL_PASSWORD}" \
      -Dflyway.baselineOnMigrate=true \
      -Dflyway.baselineVersion=0 \
      -Dflyway.locations="filesystem:src/main/resources/db/migration"; then
      
      echo "ERROR: Maven flyway:migrate failed" >&2
      exit 2
    fi
    
    echo "Migration completed successfully"
    exit 0
  fi
  
  # No valid migration path available - fail closed
  echo "ERROR: Cannot run migrations - no valid Flyway tooling available." >&2
  echo "" >&2
  echo "Required (one of):" >&2
  echo "  1. deploy/migrate.sh + FlywayRunner.java (production)" >&2
  echo "  2. Backend source + Maven (development)" >&2
  echo "" >&2
  echo "DO NOT use raw mysql client to apply migrations." >&2
  echo "That creates incompatible flyway_schema_history entries." >&2
  echo "" >&2
  echo "See deploy/flyway-repair-notes.md for setup instructions." >&2
  exit 3
}

# ============================================================================
# App Startup Functions
# ============================================================================

start_app() {
  mkdir -p "${APP_DIR}/uploads" "${APP_DIR}/downloads" "${APP_DIR}/webapp"
  
  if pgrep -f "${PID_MATCH}" >/dev/null 2>&1; then
    echo "Stopping existing process..."
    pkill -f "${PID_MATCH}" || true
    sleep 2
  fi
  
  # Production: bind to 127.0.0.1 (TLS proxy forwards from public 443)
  SERVER_ADDRESS="${SERVER_ADDRESS:-127.0.0.1}"
  SERVER_PORT="${SERVER_PORT:-8080}"
  
  cd "${APP_DIR}"
  nohup java -jar "${JAR_PATH}" \
    --server.address="${SERVER_ADDRESS}" \
    --server.port="${SERVER_PORT}" \
    --spring.datasource.url="${MYSQL_URL}" \
    --spring.datasource.username="${MYSQL_USER}" \
    --spring.datasource.password="${MYSQL_PASSWORD}" \
    --app.upload.dir="${APP_DIR}/uploads" \
    --app.download.dir="${APP_DIR}/downloads" \
    --app.web.dir="${APP_DIR}/webapp" \
    > "${LOG_PATH}" 2>&1 &
  
  echo "Started PID $!"
}

health_check() {
  echo "Waiting for readiness..."
  
  ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
  local ok=0
  for _ in $(seq 1 30); do
    if [[ -n "${ADMIN_PASSWORD}" ]]; then
      code="$(curl -s -o /dev/null -w "%{http_code}" -m 3 \
        -X POST "http://127.0.0.1:8080/api/auth/login" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"admin@luckysign.local\",\"password\":\"${ADMIN_PASSWORD}\"}" || true)"
      if [[ "${code}" == "200" ]]; then
        ok=1
        break
      fi
    else
      code="$(curl -s -o /dev/null -w "%{http_code}" -m 3 \
        "http://127.0.0.1:8080/api/user/profile" || true)"
      if [[ "${code}" == "401" || "${code}" == "403" || "${code}" == "200" ]]; then
        ok=1
        break
      fi
    fi
    if ! pgrep -f "${PID_MATCH}" >/dev/null 2>&1; then
      echo "ERROR: process exited early. Last log lines:" >&2
      tail -n 40 "${LOG_PATH}" >&2 || true
      exit 3
    fi
    sleep 2
  done
  
  if [[ "${ok}" -ne 1 ]]; then
    echo "ERROR: health check timed out. Last log lines:" >&2
    tail -n 60 "${LOG_PATH}" >&2 || true
    exit 4
  fi
  
  echo "Backend is up on ${SERVER_ADDRESS}:${SERVER_PORT}"
  ss -lntp 2>/dev/null | grep "${SERVER_PORT}" || true
}

# ============================================================================
# Main
# ============================================================================

echo "=== Lucky Sign Deploy Script ==="
echo "Mode: ${MODE}"
echo ""

case "${MODE}" in
  check-flyway)
    validate_db_config
    check_flyway_status
    ;;
  
  migrate-only)
    validate_db_config
    run_migration_only
    # run_migration_only calls exit, so we never reach here
    ;;
  
  start)
    validate_full_config
    start_app
    health_check
    ;;
  
  *)
    echo "ERROR: Unknown mode: ${MODE}" >&2
    exit 1
    ;;
esac
