#!/bin/bash
# ============================================================
# PostgreSQL Restore Script
# ============================================================
# Restores a database from a compressed backup file.
#
# Usage:
#   ./scripts/restore.sh backups/app_db_20260413_020000.sql.gz
#   ./scripts/restore.sh backups/app_db_20260413_020000.sql.gz my_other_db
# ============================================================

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <backup_file.sql.gz> [database_name]"
    echo ""
    echo "Available backups:"
    ls -lh backups/*.sql.gz 2>/dev/null || echo "  No backups found."
    exit 1
fi

# Load environment
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

BACKUP_FILE="$1"
DB_NAME="${2:-${POSTGRES_DB:-app_db}}"

if [ ! -f "${BACKUP_FILE}" ]; then
    echo "ERROR: Backup file not found: ${BACKUP_FILE}"
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

echo "[$(date)] Starting restore of ${DB_NAME} from ${BACKUP_FILE}..."

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

# --- Restore from backup ---
gunzip -c "${BACKUP_FILE}" | docker compose exec -T db psql \
    -U "${POSTGRES_USER:-admin}" \
    -d "${DB_NAME}" \
    --quiet

echo "[$(date)] Restore complete."
