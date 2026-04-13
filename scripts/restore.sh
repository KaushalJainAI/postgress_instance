#!/bin/bash
# ============================================================
# PostgreSQL Restore Script
# ============================================================
# Restores a database from a backup (directory or .sql.gz).
# Supports parallel restore for directory-format backups.
#
# Usage:
#   ./scripts/restore.sh backups/app_db_20260413_020000           # Directory format (parallel)
#   ./scripts/restore.sh backups/app_db_20260413_020000.sql.gz    # Legacy gzip format
#   ./scripts/restore.sh backups/app_db_20260413_020000 my_db     # Specify target DB
# ============================================================

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <backup_path> [database_name]"
    echo ""
    echo "Available backups:"
    ls -1d backups/*/ 2>/dev/null | sed 's|/$||' || true
    ls -1 backups/*.sql.gz 2>/dev/null || true
    echo ""
    [ -z "$(ls -A backups/ 2>/dev/null)" ] && echo "  No backups found."
    exit 1
fi

# Load environment
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

BACKUP_PATH="$1"
DB_NAME="${2:-${POSTGRES_DB:-app_db}}"
PARALLEL_JOBS="${BACKUP_PARALLEL_JOBS:-2}"

# Validate backup exists
if [ ! -e "${BACKUP_PATH}" ]; then
    echo "ERROR: Backup not found: ${BACKUP_PATH}"
    exit 1
fi

echo "============================================"
echo "  WARNING: This will DROP and recreate"
echo "  database '${DB_NAME}'!"
echo "============================================"
read -p "Continue? (y/N): " CONFIRM

if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]]; then
    echo "Restore cancelled."
    exit 0
fi

echo "[$(date)] Starting restore of ${DB_NAME} from ${BACKUP_PATH}..."

# --- Drop and recreate database ---
docker compose exec -T db psql \
    -U "${POSTGRES_USER:-admin}" \
    -d postgres \
    -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${DB_NAME}' AND pid <> pg_backend_pid();" \
    2>/dev/null || true

docker compose exec -T db psql \
    -U "${POSTGRES_USER:-admin}" \
    -d postgres \
    -c "DROP DATABASE IF EXISTS ${DB_NAME};"

docker compose exec -T db psql \
    -U "${POSTGRES_USER:-admin}" \
    -d postgres \
    -c "CREATE DATABASE ${DB_NAME} OWNER ${POSTGRES_USER:-admin};"

# --- Restore from backup (auto-detect format) ---
if [ -d "${BACKUP_PATH}" ]; then
    # Directory format — use pg_restore with parallel jobs
    echo "[$(date)] Detected directory-format backup, restoring with ${PARALLEL_JOBS} parallel jobs..."
    docker compose exec -T db pg_restore \
        -U "${POSTGRES_USER:-admin}" \
        -d "${DB_NAME}" \
        --jobs="${PARALLEL_JOBS}" \
        --no-owner \
        --no-privileges \
        "/backups/$(basename ${BACKUP_PATH})"
elif [[ "${BACKUP_PATH}" == *.sql.gz ]]; then
    # Legacy gzip format — pipe through psql
    echo "[$(date)] Detected legacy .sql.gz backup, restoring via psql..."
    gunzip -c "${BACKUP_PATH}" | docker compose exec -T db psql \
        -U "${POSTGRES_USER:-admin}" \
        -d "${DB_NAME}" \
        --quiet
else
    echo "ERROR: Unrecognized backup format: ${BACKUP_PATH}"
    echo "Expected a directory or a .sql.gz file."
    exit 1
fi

echo "[$(date)] Restore complete."

