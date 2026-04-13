#!/bin/bash
# ============================================================
# PostgreSQL Backup Script
# ============================================================
# Creates a compressed backup of the database using parallel
# directory-format dumps for faster backup and restore.
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
BACKUP_PATH="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
# Number of parallel dump jobs (match to CPU cores, 2 is safe default)
PARALLEL_JOBS="${BACKUP_PARALLEL_JOBS:-2}"

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting parallel backup of database: ${DB_NAME} (${PARALLEL_JOBS} jobs)..."

# --- Create parallel compressed backup (directory format) ---
docker compose exec -T db pg_dump \
    -U "${POSTGRES_USER:-admin}" \
    -d "${DB_NAME}" \
    --format=directory \
    --jobs="${PARALLEL_JOBS}" \
    --compress=6 \
    --no-owner \
    --no-privileges \
    -f "/backups/${DB_NAME}_${TIMESTAMP}"

BACKUP_SIZE=$(du -sh "${BACKUP_PATH}" 2>/dev/null | cut -f1 || echo "unknown")
echo "[$(date)] Backup created: ${BACKUP_PATH} (${BACKUP_SIZE})"

# --- Cleanup old backups ---
echo "[$(date)] Cleaning up backups older than ${RETENTION_DAYS} days..."
find "${BACKUP_DIR}" -maxdepth 1 -name "${DB_NAME}_*" -mtime +${RETENTION_DAYS} -exec rm -rf {} + 2>/dev/null || true

REMAINING=$(ls -1d ${BACKUP_DIR}/${DB_NAME}_* 2>/dev/null | wc -l)
echo "[$(date)] Backup complete. ${REMAINING} backup(s) retained."

