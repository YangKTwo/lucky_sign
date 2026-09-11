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
#   3 - 启动失败
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

# k4 fix: --migrate-only works without backend source, truly exits
run_migration_only() {
  echo "=== Flyway Migration (migrate-only mode) ==="
  
  # Use standalone migrate.sh if available (preferred for production)
  if [[ -x "${SCRIPT_DIR}/migrate.sh" ]]; then
    echo "Using standalone migrate.sh..."
    exec "${SCRIPT_DIR}/migrate.sh"
    # exec replaces this process, so we never reach here
  fi
  
  # Fallback: if migrate.sh not available, check if we have backend source
  local BACKEND_DIR=""
  for dir in "${APP_DIR}/../backend" "/opt/backend" "${SCRIPT_DIR}/../backend"; do
    if [[ -d "${dir}" && -f "${dir}/pom.xml" ]]; then
      BACKEND_DIR="$(cd "${dir}" && pwd)"
      break
    fi
  done
  
  if [[ -n "${BACKEND_DIR}" && -f "${BACKEND_DIR}/src/main/resources/db/migration/V1__initial_schema.sql" ]]; then
    echo "Found backend source at ${BACKEND_DIR}"
    echo "Using Maven flyway:migrate..."
    
    cd "${BACKEND_DIR}"
    mvn flyway:migrate \
      -Dflyway.url="${MYSQL_URL}" \
      -Dflyway.user="${MYSQL_USER}" \
      -Dflyway.password="${MYSQL_PASSWORD}" \
      -Dflyway.locations="filesystem:src/main/resources/db/migration"
    
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
      echo "ERROR: Migration failed with exit code ${exit_code}" >&2
      exit 2
    fi
    
    echo "Migration completed successfully"
    exit 0
  fi
  
  # Last resort: extract from JAR and run via MySQL client
  echo "No backend source found. Extracting migrations from JAR..."
  
  if [[ ! -f "${JAR_PATH}" ]]; then
    echo "ERROR: JAR not found: ${JAR_PATH}" >&2
    echo "Deploy the JAR first, or ensure backend source is available." >&2
    exit 1
  fi
  
  local MIGRATE_DIR="${APP_DIR}/flyway-migrations"
  rm -rf "${MIGRATE_DIR}"
  mkdir -p "${MIGRATE_DIR}"
  
  # Extract SQL files
  if ! unzip -q -j "${JAR_PATH}" "BOOT-INF/classes/db/migration/*.sql" -d "${MIGRATE_DIR}" 2>/dev/null; then
    unzip -q -j "${JAR_PATH}" "db/migration/*.sql" -d "${MIGRATE_DIR}" 2>/dev/null || {
      echo "ERROR: Could not extract migrations from JAR" >&2
      exit 1
    }
  fi
  
  echo "Extracted migrations to ${MIGRATE_DIR}:"
  ls -la "${MIGRATE_DIR}"/*.sql
  
  # Run via MySQL client
  parse_jdbc_url "${MYSQL_URL}"
  
  # Get current version
  local current_version
  current_version=$(mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
    -N -e "SELECT COALESCE(MAX(version), '0') FROM flyway_schema_history WHERE success = 1;" "${DB_NAME}" 2>/dev/null || echo "0")
  
  echo "Current migration version: ${current_version}"
  
  local FLYWAY_LOG="${APP_DIR}/flyway-migrate.log"
  : > "${FLYWAY_LOG}"
  
  for sql_file in "${MIGRATE_DIR}"/V*.sql; do
    [[ -f "${sql_file}" ]] || continue
    
    local filename=$(basename "${sql_file}")
    local version=$(echo "${filename}" | sed -n 's/^V\([0-9]*\)__.*/\1/p')
    
    if [[ "${version}" -le "${current_version}" ]]; then
      echo "Skipping ${filename} (already applied)"
      continue
    fi
    
    echo "Applying ${filename}..."
    if ! mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
      "${DB_NAME}" < "${sql_file}" >> "${FLYWAY_LOG}" 2>&1; then
      echo "ERROR: Failed to apply ${filename}" >&2
      echo "See ${FLYWAY_LOG} for details" >&2
      tail -n 30 "${FLYWAY_LOG}" >&2
      
      # Record failure in flyway_schema_history
      local description=$(echo "${filename}" | sed 's/^V[0-9]*__//; s/\.sql$//' | tr '_' ' ')
      mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
        -e "INSERT INTO flyway_schema_history (installed_rank, version, description, type, script, checksum, installed_by, execution_time, success) 
            SELECT COALESCE(MAX(installed_rank), 0) + 1, '${version}', '${description}', 'SQL', '${filename}', 0, '${MYSQL_USER}', 0, 0 
            FROM flyway_schema_history;" "${DB_NAME}" 2>/dev/null || true
      exit 2
    fi
    
    # Record success
    local description=$(echo "${filename}" | sed 's/^V[0-9]*__//; s/\.sql$//' | tr '_' ' ')
    mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
      -e "INSERT INTO flyway_schema_history (installed_rank, version, description, type, script, checksum, installed_by, execution_time, success) 
          SELECT COALESCE(MAX(installed_rank), 0) + 1, '${version}', '${description}', 'SQL', '${filename}', 0, '${MYSQL_USER}', 0, 1 
          FROM flyway_schema_history;" "${DB_NAME}" 2>/dev/null || {
      # Create table if needed
      mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DB_NAME}" << 'TABLESQL'
CREATE TABLE IF NOT EXISTS flyway_schema_history (
  installed_rank INT NOT NULL,
  version VARCHAR(50),
  description VARCHAR(200) NOT NULL,
  type VARCHAR(20) NOT NULL,
  script VARCHAR(1000) NOT NULL,
  checksum INT,
  installed_by VARCHAR(100) NOT NULL,
  installed_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  execution_time INT NOT NULL,
  success TINYINT(1) NOT NULL,
  PRIMARY KEY (installed_rank)
);
TABLESQL
      mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
        -e "INSERT INTO flyway_schema_history (installed_rank, version, description, type, script, checksum, installed_by, execution_time, success) 
            VALUES (1, '${version}', '${description}', 'SQL', '${filename}', 0, '${MYSQL_USER}', 0, 1);" "${DB_NAME}"
    }
    
    echo "Applied ${filename} successfully"
  done
  
  echo ""
  echo "Migration completed successfully"
  echo "Process exiting (migrate-only mode)"
  exit 0
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
