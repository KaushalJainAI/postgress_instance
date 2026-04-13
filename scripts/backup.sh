#!/bin/bash
# ============================================================
# PostgreSQL Backup Script
# ============================================================
# Creates a compressed backup of the database.
# Can be run manually or via cron.
#
# Usage:
#   ./scripts/backup.sh                  # Backup default DB
#   ./scripts/backup.sh my_other_db      # Backup specific DB
#
# Crontab example (daily at 2 AM):
#   0 2 * * * cd /path/to/project && ./scripts/backup.sh >> logs/backup.log 2>&1
# ============================================================

set -euo pipefail

# Load environment
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

DB_NAME="${1:-${POSTGRES_DB:-app_db}}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="./backups"
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting backup of database: ${DB_NAME}..."

# --- Create compressed backup ---
docker compose exec -T db pg_dump \
    -U "${POSTGRES_USER:-admin}" \
    -d "${DB_NAME}" \
    --format=plain \
    --no-owner \
    --no-privileges \
    | gzip > "${BACKUP_FILE}"

BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
echo "[$(date)] Backup created: ${BACKUP_FILE} (${BACKUP_SIZE})"

# --- Cleanup old backups ---
echo "[$(date)] Cleaning up backups older than ${RETENTION_DAYS} days..."
find "${BACKUP_DIR}" -name "*.sql.gz" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true

REMAINING=$(ls -1 ${BACKUP_DIR}/*.sql.gz 2>/dev/null | wc -l)
echo "[$(date)] Backup complete. ${REMAINING} backup(s) retained."
