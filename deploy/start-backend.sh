#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/www/wwwroot/lucky-api"
JAR_NAME="lucky-sign-0.0.1-SNAPSHOT.jar"
JAR_PATH="${APP_DIR}/${JAR_NAME}"
LOG_PATH="${APP_DIR}/lucky-sign.log"
ENV_FILE="${APP_DIR}/run.env"
PID_MATCH="lucky-sign-0.0.1-SNAPSHOT.jar"

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

if [[ -z "${MYSQL_PASSWORD}" ]]; then
  echo "ERROR: MYSQL_PASSWORD is empty. Set it in ${ENV_FILE}" >&2
  exit 1
fi

if [[ ! -f "${JAR_PATH}" ]]; then
  echo "ERROR: JAR not found: ${JAR_PATH}" >&2
  exit 1
fi

mkdir -p "${APP_DIR}/uploads" "${APP_DIR}/downloads"

if pgrep -f "${PID_MATCH}" >/dev/null 2>&1; then
  echo "Stopping existing process..."
  pkill -f "${PID_MATCH}" || true
  sleep 2
fi

cd "${APP_DIR}"
nohup java -jar "${JAR_PATH}" \
  --server.address=0.0.0.0 \
  --server.port=8080 \
  --spring.datasource.url="${MYSQL_URL}" \
  --spring.datasource.username="${MYSQL_USER}" \
  --spring.datasource.password="${MYSQL_PASSWORD}" \
  --app.upload.dir="${APP_DIR}/uploads" \
  --app.download.dir="${APP_DIR}/downloads" \
  > "${LOG_PATH}" 2>&1 &

echo "Started PID $!"
echo "Waiting for readiness..."

ok=0
for _ in $(seq 1 30); do
  code="$(curl -s -o /dev/null -w "%{http_code}" -m 3 \
    -X POST "http://127.0.0.1:8080/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@luckysign.local","password":"admin123"}' || true)"
  if [[ "${code}" == "200" ]]; then
    ok=1
    break
  fi
  if ! pgrep -f "${PID_MATCH}" >/dev/null 2>&1; then
    echo "ERROR: process exited early. Last log lines:" >&2
    tail -n 40 "${LOG_PATH}" >&2 || true
    exit 1
  fi
  sleep 2
done

if [[ "${ok}" -ne 1 ]]; then
  echo "ERROR: health check timed out. Last log lines:" >&2
  tail -n 60 "${LOG_PATH}" >&2 || true
  exit 1
fi

echo "Backend is up on 0.0.0.0:8080"
ss -lntp 2>/dev/null | grep 8080 || true
