#!/bin/bash
# ============================================================
# 01 — Create Extensions
# ============================================================
# This script runs automatically on first database initialization.
# Add any extensions you commonly use across projects.
# ============================================================

set -e

echo ">>> Installing common PostgreSQL extensions..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL

    -- UUID generation (essential for modern apps)
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";

    -- Full-text search utilities
    CREATE EXTENSION IF NOT EXISTS "pg_trgm";
    CREATE EXTENSION IF NOT EXISTS "unaccent";

    -- Case-insensitive text (useful for emails, usernames, etc.)
    CREATE EXTENSION IF NOT EXISTS "citext";

    -- Statistics & monitoring
    CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

    -- Table partitioning helper (if available)
    -- CREATE EXTENSION IF NOT EXISTS "pg_partman";

EOSQL

echo ">>> Extensions installed successfully."
