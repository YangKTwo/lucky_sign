#!/usr/bin/env bash
# ============================================================================
# Lucky Sign Standalone Migration Script
# ============================================================================
# Runs Flyway migrations WITHOUT starting Spring Boot application.
# Works in production where backend/ source directory is not available.
#
# Usage:
#   ./migrate.sh                    # Run migrations
#   ./migrate.sh --check            # Check for failed migrations only
#   ./migrate.sh --info             # Show migration status
#
# Required environment (from run.env or exported):
#   MYSQL_PASSWORD
#   MYSQL_USER (default: root)
#   MYSQL_URL (default: jdbc:mysql://127.0.0.1:3306/lucky_sign?...)
#
# Exit codes:
#   0 - Success
#   1 - Configuration error
#   2 - Migration failed / failed migrations detected
# ============================================================================
set -euo pipefail

APP_DIR="/www/wwwroot/lucky-api"
JAR_PATH="${APP_DIR}/lucky-sign-0.0.1-SNAPSHOT.jar"
MIGRATE_DIR="${APP_DIR}/flyway-migrations"
FLYWAY_LOG="${APP_DIR}/flyway-migrate.log"
ENV_FILE="${APP_DIR}/run.env"

# Parse arguments
ACTION="migrate"
while [[ $# -gt 0 ]]; do
  case $1 in
    --check)
      ACTION="check"
      shift
      ;;
    --info)
      ACTION="info"
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--check|--info]" >&2
      exit 1
      ;;
  esac
done

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

# Check for failed migrations using direct MySQL query
check_failed_migrations() {
  echo "Checking for failed migrations..."
  parse_jdbc_url "${MYSQL_URL}"
  
  local result
  if ! result=$(mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
    -N -e "SELECT COUNT(*) FROM flyway_schema_history WHERE success = 0;" "${DB_NAME}" 2>&1); then
    echo "ERROR: Failed to query flyway_schema_history" >&2
    echo "${result}" >&2
    exit 2
  fi
  
  local failed_count="${result}"
  
  if [[ "${failed_count}" -gt 0 ]]; then
    echo "ERROR: Found ${failed_count} failed migration(s)" >&2
    echo "See deploy/flyway-repair-notes.md for repair instructions" >&2
    mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
      -e "SELECT version, description, success, installed_on FROM flyway_schema_history WHERE success = 0;" "${DB_NAME}" 2>/dev/null || true
    exit 2
  fi
  
  echo "No failed migrations found"
}

# Show migration info
show_info() {
  echo "Migration status:"
  parse_jdbc_url "${MYSQL_URL}"
  
  mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
    -e "SELECT version, description, type, installed_on, success FROM flyway_schema_history ORDER BY installed_rank;" "${DB_NAME}" 2>/dev/null || {
    echo "No flyway_schema_history table found (fresh database)"
  }
}

# Extract migrations from JAR and run them
run_migrations() {
  echo "=== Flyway Migration (Standalone) ==="
  
  if [[ ! -f "${JAR_PATH}" ]]; then
    echo "ERROR: JAR not found: ${JAR_PATH}" >&2
    exit 1
  fi
  
  # Check for failed migrations first
  parse_jdbc_url "${MYSQL_URL}"
  local failed_check
  if failed_check=$(mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
    -N -e "SELECT COUNT(*) FROM flyway_schema_history WHERE success = 0;" "${DB_NAME}" 2>/dev/null); then
    if [[ "${failed_check}" -gt 0 ]]; then
      echo "ERROR: Cannot migrate - ${failed_check} failed migration(s) exist" >&2
      echo "See deploy/flyway-repair-notes.md for repair instructions" >&2
      exit 2
    fi
  fi
  # If table doesn't exist yet, that's OK - fresh database
  
  # Extract migration SQL files from JAR
  echo "Extracting migrations from JAR..."
  rm -rf "${MIGRATE_DIR}"
  mkdir -p "${MIGRATE_DIR}"
  
  # Use unzip to extract db/migration directory
  if ! unzip -q -j "${JAR_PATH}" "BOOT-INF/classes/db/migration/*.sql" -d "${MIGRATE_DIR}" 2>/dev/null; then
    # Try alternative path for non-Boot JARs
    unzip -q -j "${JAR_PATH}" "db/migration/*.sql" -d "${MIGRATE_DIR}" 2>/dev/null || {
      echo "ERROR: Could not extract migrations from JAR" >&2
      exit 1
    }
  fi
  
  echo "Extracted migrations:"
  ls -la "${MIGRATE_DIR}"/*.sql 2>/dev/null || {
    echo "ERROR: No migration files found" >&2
    exit 1
  }
  
  # Run migrations using Java + Flyway (from JAR classpath)
  # This approach uses Flyway's API without Spring Boot context
  echo "Running Flyway migrate..."
  echo "Log: ${FLYWAY_LOG}"
  
  # Create a minimal Java class to run Flyway
  local RUNNER_CLASS="${MIGRATE_DIR}/FlywayRunner.java"
  cat > "${RUNNER_CLASS}" << 'JAVA_EOF'
import org.flywaydb.core.Flyway;

public class FlywayRunner {
    public static void main(String[] args) {
        if (args.length < 3) {
            System.err.println("Usage: FlywayRunner <url> <user> <password> <locations>");
            System.exit(1);
        }
        
        String url = args[0];
        String user = args[1];
        String password = args[2];
        String locations = args.length > 3 ? args[3] : "filesystem:./";
        
        try {
            Flyway flyway = Flyway.configure()
                .dataSource(url, user, password)
                .locations(locations)
                .load();
            
            flyway.migrate();
            System.out.println("Migration completed successfully");
            System.exit(0);
        } catch (Exception e) {
            System.err.println("Migration failed: " + e.getMessage());
            e.printStackTrace();
            System.exit(2);
        }
    }
}
JAVA_EOF

  # Compile and run the Flyway runner
  # Use the JAR's classpath for Flyway dependencies
  cd "${MIGRATE_DIR}"
  
  # Extract Flyway and MySQL connector from the JAR for classpath
  local LIB_DIR="${MIGRATE_DIR}/lib"
  mkdir -p "${LIB_DIR}"
  
  # For Spring Boot fat JAR, libraries are in BOOT-INF/lib
  unzip -q -j "${JAR_PATH}" "BOOT-INF/lib/flyway-core-*.jar" -d "${LIB_DIR}" 2>/dev/null || true
  unzip -q -j "${JAR_PATH}" "BOOT-INF/lib/flyway-mysql-*.jar" -d "${LIB_DIR}" 2>/dev/null || true
  unzip -q -j "${JAR_PATH}" "BOOT-INF/lib/mysql-connector-*.jar" -d "${LIB_DIR}" 2>/dev/null || true
  
  # Build classpath
  local CP=""
  for jar in "${LIB_DIR}"/*.jar; do
    [[ -f "$jar" ]] && CP="${CP}:${jar}"
  done
  CP="${CP#:}"  # Remove leading colon
  
  if [[ -z "${CP}" ]]; then
    echo "ERROR: Could not extract Flyway libraries from JAR" >&2
    echo "Falling back to direct SQL execution..." >&2
    run_migrations_via_mysql
    return
  fi
  
  # Compile
  if ! javac -cp "${CP}" FlywayRunner.java > "${FLYWAY_LOG}" 2>&1; then
    echo "ERROR: Failed to compile FlywayRunner" >&2
    cat "${FLYWAY_LOG}" >&2
    echo "Falling back to direct SQL execution..." >&2
    run_migrations_via_mysql
    return
  fi
  
  # Run
  if ! java -cp ".:${CP}" FlywayRunner \
    "${MYSQL_URL}" "${MYSQL_USER}" "${MYSQL_PASSWORD}" \
    "filesystem:${MIGRATE_DIR}" >> "${FLYWAY_LOG}" 2>&1; then
    echo "ERROR: Migration failed" >&2
    tail -n 50 "${FLYWAY_LOG}" >&2
    exit 2
  fi
  
  echo "Migration completed successfully"
  
  # Cleanup
  rm -rf "${LIB_DIR}" FlywayRunner.java FlywayRunner.class
}

# Fallback: run migrations directly via MySQL client
# This is simpler but doesn't get Flyway's versioning benefits
run_migrations_via_mysql() {
  echo "Running migrations via MySQL client (fallback)..."
  parse_jdbc_url "${MYSQL_URL}"
  
  # Check current version
  local current_version
  current_version=$(mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
    -N -e "SELECT COALESCE(MAX(version), '0') FROM flyway_schema_history WHERE success = 1;" "${DB_NAME}" 2>/dev/null || echo "0")
  
  echo "Current version: ${current_version}"
  
  # Run each migration file in order
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
      tail -n 30 "${FLYWAY_LOG}" >&2
      exit 2
    fi
    
    # Record in flyway_schema_history (simplified)
    local description=$(echo "${filename}" | sed 's/^V[0-9]*__//; s/\.sql$//' | tr '_' ' ')
    mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
      -e "INSERT INTO flyway_schema_history (installed_rank, version, description, type, script, checksum, installed_by, execution_time, success) 
          SELECT COALESCE(MAX(installed_rank), 0) + 1, '${version}', '${description}', 'SQL', '${filename}', 0, '${MYSQL_USER}', 0, 1 
          FROM flyway_schema_history;" "${DB_NAME}" 2>/dev/null || {
      # Create table if it doesn't exist
      mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
        -e "CREATE TABLE IF NOT EXISTS flyway_schema_history (
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
            );" "${DB_NAME}"
      mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
        -e "INSERT INTO flyway_schema_history (installed_rank, version, description, type, script, checksum, installed_by, execution_time, success) 
            VALUES (1, '${version}', '${description}', 'SQL', '${filename}', 0, '${MYSQL_USER}', 0, 1);" "${DB_NAME}"
    }
  done
  
  echo "Migration completed (MySQL fallback mode)"
}

# Main
case "${ACTION}" in
  check)
    check_failed_migrations
    ;;
  info)
    show_info
    ;;
  migrate)
    run_migrations
    ;;
esac
