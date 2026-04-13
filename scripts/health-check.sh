#!/bin/bash
# ============================================================
# Health Check Script
# ============================================================
# Quick status check of the PostgreSQL container and database.
#
# Usage: ./scripts/health-check.sh
# ============================================================

set -euo pipefail

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

echo "============================================"
echo "  PostgreSQL Health Check"
echo "============================================"
echo ""

# --- Container Status ---
echo "--- Container Status ---"
docker compose ps db --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
echo ""

# --- Database Connectivity ---
echo "--- Database Connectivity ---"
if docker compose exec -T db pg_isready -U "${POSTGRES_USER:-admin}" -d "${POSTGRES_DB:-app_db}" > /dev/null 2>&1; then
    echo "  ✅ PostgreSQL is accepting connections"
else
    echo "  ❌ PostgreSQL is NOT accepting connections"
    exit 1
fi
echo ""

# --- Database Info ---
echo "--- Server Info ---"
docker compose exec -T db psql -U "${POSTGRES_USER:-admin}" -d "${POSTGRES_DB:-app_db}" -t -c \
    "SELECT 'Version: ' || version();"
echo ""

# --- Databases ---
echo "--- Databases ---"
docker compose exec -T db psql -U "${POSTGRES_USER:-admin}" -d postgres -c \
    "SELECT datname AS database, pg_size_pretty(pg_database_size(datname)) AS size FROM pg_database WHERE datistemplate = false ORDER BY pg_database_size(datname) DESC;"
echo ""

# --- Active Connections ---
echo "--- Active Connections ---"
docker compose exec -T db psql -U "${POSTGRES_USER:-admin}" -d "${POSTGRES_DB:-app_db}" -c \
    "SELECT count(*) AS total_connections, count(*) FILTER (WHERE state = 'active') AS active, count(*) FILTER (WHERE state = 'idle') AS idle FROM pg_stat_activity WHERE datname IS NOT NULL;"
echo ""

# --- Disk Usage ---
echo "--- Disk Usage ---"
docker compose exec -T db df -h /var/lib/postgresql/data | tail -1 | awk '{print "  Used: " $3 " / " $2 " (" $5 " full)"}'
echo ""

echo "============================================"
echo "  Health check complete"
echo "============================================"
