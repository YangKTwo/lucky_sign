#!/usr/bin/env bash
# ============================================================================
# Lucky Sign Standalone Migration Script
# ============================================================================
# Runs Flyway migrations using REAL Flyway API — no fake checksums.
# Works in production where backend/ source directory is not available.
#
# IMPORTANT: This script uses real Flyway with proper checksums.
# DO NOT use raw mysql client to apply migrations — that creates
# incompatible flyway_schema_history entries that will break validation.
#
# Usage:
#   ./migrate.sh                    # Run migrations
#   ./migrate.sh info               # Show migration status
#   ./migrate.sh validate           # Validate migrations
#   ./migrate.sh repair             # Repair schema history (caution!)
#
# Required environment (from run.env or exported):
#   MYSQL_PASSWORD
#   MYSQL_USER (default: root)
#   MYSQL_URL (default: jdbc:mysql://127.0.0.1:3306/lucky_sign?...)
#
# Required tooling:
#   - Java 17+ (JDK for compilation, or JRE with pre-compiled FlywayRunner)
#   - Flyway libraries (extracted from app JAR)
#
# Exit codes:
#   0 - Success
#   1 - Configuration error
#   2 - Migration/validation failed
#   3 - Missing required tooling (Java/Flyway)
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="/www/wwwroot/lucky-api"
JAR_PATH="${APP_DIR}/lucky-sign-0.0.1-SNAPSHOT.jar"
MIGRATE_DIR="${APP_DIR}/flyway-migrations"
FLYWAY_LOG="${APP_DIR}/flyway-migrate.log"
ENV_FILE="${APP_DIR}/run.env"

# Parse arguments
COMMAND="migrate"
if [[ $# -gt 0 ]]; then
  case $1 in
    migrate|info|validate|repair)
      COMMAND="$1"
      ;;
    --help|-h)
      echo "Usage: $0 [migrate|info|validate|repair]"
      echo ""
      echo "Commands:"
      echo "  migrate   Run pending migrations (default)"
      echo "  info      Show migration status"
      echo "  validate  Validate applied migrations"
      echo "  repair    Repair schema history (use with caution)"
      exit 0
      ;;
    *)
      echo "ERROR: Unknown command: $1" >&2
      echo "Usage: $0 [migrate|info|validate|repair]" >&2
      exit 1
      ;;
  esac
fi

# Load environment
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
MYSQL_URL="${MYSQL_URL:-jdbc:mysql://127.0.0.1:3306/lucky_sign?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai}"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
fi

if [[ -z "${MYSQL_PASSWORD}" ]]; then
  echo "ERROR: MYSQL_PASSWORD is empty. Set it in ${ENV_FILE}" >&2
  exit 1
fi

# ============================================================================
# Check required tooling
# ============================================================================

check_java() {
  if ! command -v java &> /dev/null; then
    echo "ERROR: Java not found. Install JDK 17+ or JRE." >&2
    echo "On Ubuntu: sudo apt install openjdk-17-jre-headless" >&2
    exit 3
  fi
  
  local java_version
  java_version=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | cut -d'.' -f1)
  if [[ "${java_version}" -lt 17 ]]; then
    echo "ERROR: Java 17+ required, found version ${java_version}" >&2
    exit 3
  fi
}

check_jar() {
  if [[ ! -f "${JAR_PATH}" ]]; then
    echo "ERROR: Application JAR not found: ${JAR_PATH}" >&2
    echo "Deploy the JAR first before running migrations." >&2
    exit 1
  fi
}

# ============================================================================
# Setup Flyway environment
# ============================================================================

setup_flyway_env() {
  echo "Setting up Flyway environment..."
  
  rm -rf "${MIGRATE_DIR}"
  mkdir -p "${MIGRATE_DIR}/lib"
  
  # Extract migration SQL files from JAR
  echo "Extracting migrations from JAR..."
  if ! unzip -q -j "${JAR_PATH}" "BOOT-INF/classes/db/migration/*.sql" -d "${MIGRATE_DIR}" 2>/dev/null; then
    unzip -q -j "${JAR_PATH}" "db/migration/*.sql" -d "${MIGRATE_DIR}" 2>/dev/null || {
      echo "ERROR: Could not extract migrations from JAR" >&2
      exit 1
    }
  fi
  
  local sql_count
  sql_count=$(ls -1 "${MIGRATE_DIR}"/*.sql 2>/dev/null | wc -l)
  if [[ "${sql_count}" -eq 0 ]]; then
    echo "ERROR: No migration SQL files found in JAR" >&2
    exit 1
  fi
  echo "Found ${sql_count} migration files"
  
  # Extract Flyway libraries from JAR
  echo "Extracting Flyway libraries..."
  unzip -q -j "${JAR_PATH}" "BOOT-INF/lib/flyway-core-*.jar" -d "${MIGRATE_DIR}/lib" 2>/dev/null || true
  unzip -q -j "${JAR_PATH}" "BOOT-INF/lib/flyway-mysql-*.jar" -d "${MIGRATE_DIR}/lib" 2>/dev/null || true
  unzip -q -j "${JAR_PATH}" "BOOT-INF/lib/mysql-connector-*.jar" -d "${MIGRATE_DIR}/lib" 2>/dev/null || true
  unzip -q -j "${JAR_PATH}" "BOOT-INF/lib/slf4j-api-*.jar" -d "${MIGRATE_DIR}/lib" 2>/dev/null || true
  
  # Check if we have the required libraries
  if ! ls "${MIGRATE_DIR}/lib"/flyway-core-*.jar &>/dev/null; then
    echo "ERROR: Could not extract flyway-core from JAR" >&2
    echo "Ensure the application JAR contains Flyway dependencies." >&2
    exit 3
  fi
  
  if ! ls "${MIGRATE_DIR}/lib"/mysql-connector-*.jar &>/dev/null; then
    echo "ERROR: Could not extract MySQL connector from JAR" >&2
    exit 3
  fi
  
  echo "Flyway libraries extracted successfully"
}

# ============================================================================
# Build classpath
# ============================================================================

build_classpath() {
  local cp=""
  for jar in "${MIGRATE_DIR}/lib"/*.jar; do
    [[ -f "$jar" ]] && cp="${cp}:${jar}"
  done
  echo "${cp#:}"  # Remove leading colon
}

# ============================================================================
# Compile or use pre-compiled FlywayRunner
# ============================================================================

prepare_runner() {
  local runner_class="${MIGRATE_DIR}/FlywayRunner.class"
  local runner_source="${SCRIPT_DIR}/FlywayRunner.java"
  
  # Check for pre-compiled runner (shipped with deploy artifacts)
  if [[ -f "${SCRIPT_DIR}/FlywayRunner.class" ]]; then
    cp "${SCRIPT_DIR}/FlywayRunner.class" "${MIGRATE_DIR}/"
    echo "Using pre-compiled FlywayRunner"
    return 0
  fi
  
  # Need to compile
  if [[ ! -f "${runner_source}" ]]; then
    echo "ERROR: FlywayRunner.java not found at ${runner_source}" >&2
    echo "Ensure FlywayRunner.java is in the deploy directory." >&2
    exit 3
  fi
  
  # Check for javac
  if ! command -v javac &> /dev/null; then
    echo "ERROR: javac (Java compiler) not found." >&2
    echo "Either:" >&2
    echo "  1. Install JDK: sudo apt install openjdk-17-jdk-headless" >&2
    echo "  2. Ship pre-compiled FlywayRunner.class with deploy artifacts" >&2
    exit 3
  fi
  
  echo "Compiling FlywayRunner..."
  local cp
  cp=$(build_classpath)
  
  if ! javac -cp "${cp}" -d "${MIGRATE_DIR}" "${runner_source}" 2>&1; then
    echo "ERROR: Failed to compile FlywayRunner" >&2
    exit 3
  fi
  
  echo "FlywayRunner compiled successfully"
}

# ============================================================================
# Run Flyway command
# ============================================================================

run_flyway() {
  local command="$1"
  
  echo "=== Flyway ${command} ==="
  echo "URL: ${MYSQL_URL}"
  echo "User: ${MYSQL_USER}"
  echo "Migrations: ${MIGRATE_DIR}"
  echo "Log: ${FLYWAY_LOG}"
  echo ""
  
  local cp
  cp=$(build_classpath)
  
  cd "${MIGRATE_DIR}"
  
  # Run FlywayRunner with real Flyway API
  # Config aligns with Spring Boot: baselineOnMigrate=true, baselineVersion=0
  if ! java -cp ".:${cp}" FlywayRunner \
    "${command}" \
    "${MYSQL_URL}" \
    "${MYSQL_USER}" \
    "${MYSQL_PASSWORD}" \
    "filesystem:${MIGRATE_DIR}" \
    2>&1 | tee "${FLYWAY_LOG}"; then
    
    echo "" >&2
    echo "ERROR: Flyway ${command} failed" >&2
    echo "See ${FLYWAY_LOG} for details" >&2
    exit 2
  fi
  
  echo ""
  echo "Flyway ${command} completed successfully"
}

# ============================================================================
# Main
# ============================================================================

echo "=== Lucky Sign Migration Script ==="
echo "Command: ${COMMAND}"
echo ""

check_java
check_jar
setup_flyway_env
prepare_runner
run_flyway "${COMMAND}"
