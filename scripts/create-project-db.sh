#!/bin/bash
# ============================================================
# Create a New Project Database
# ============================================================
# Quickly spin up a new database for a project with proper
# roles and permissions already applied.
#
# Usage:
#   ./scripts/create-project-db.sh my_project_name
#   ./scripts/create-project-db.sh my_project_name my_app_user my_password
# ============================================================

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <database_name> [app_user] [app_password]"
    exit 1
fi

# Load environment
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

DB_NAME="$1"
APP_USER="${2:-${DB_NAME}_user}"
APP_PASSWORD="${3:-$(openssl rand -base64 24)}"

echo "============================================"
echo "  Creating project database"
echo "============================================"
echo "  Database:  ${DB_NAME}"
echo "  User:      ${APP_USER}"
echo "============================================"

docker compose exec -T db psql \
    -U "${POSTGRES_USER:-admin}" \
    -d postgres <<-EOSQL

    -- Create the database
    CREATE DATABASE ${DB_NAME} OWNER ${POSTGRES_USER:-admin};

    -- Create the application user
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${APP_USER}') THEN
            CREATE ROLE ${APP_USER} WITH LOGIN PASSWORD '${APP_PASSWORD}';
        END IF;
    END
    \$\$;

    -- Grant permissions
    GRANT CONNECT ON DATABASE ${DB_NAME} TO ${APP_USER};
    GRANT app_readwrite TO ${APP_USER};

EOSQL

# Install extensions on the new database
docker compose exec -T db psql \
    -U "${POSTGRES_USER:-admin}" \
    -d "${DB_NAME}" <<-EOSQL

    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";
    CREATE EXTENSION IF NOT EXISTS "pg_trgm";

EOSQL

echo ""
echo "============================================"
echo "  Database created successfully!"
echo "============================================"
echo ""
echo "  Connection string:"
echo "  postgresql://${APP_USER}:${APP_PASSWORD}@<EC2_PUBLIC_IP>:${POSTGRES_PORT:-5432}/${DB_NAME}"
echo ""
echo "  Save these credentials securely!"
echo "============================================"
