#!/bin/bash
# ============================================================
# 02 — Create Roles & Default Schema
# ============================================================
# Creates reusable roles for application access patterns.
# Customize these for your specific projects.
# ============================================================

set -e

echo ">>> Creating roles and default schema..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL

    -- Read-only role (for analytics, dashboards, etc.)
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_readonly') THEN
            CREATE ROLE app_readonly;
        END IF;
    END
    \$\$;

    -- Read-write role (for application backends)
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_readwrite') THEN
            CREATE ROLE app_readwrite;
        END IF;
    END
    \$\$;

    -- Grant permissions
    GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO app_readonly;
    GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO app_readwrite;

    -- Schema-level permissions
    GRANT USAGE ON SCHEMA public TO app_readonly;
    GRANT USAGE, CREATE ON SCHEMA public TO app_readwrite;

    -- Default privileges for future tables
    ALTER DEFAULT PRIVILEGES IN SCHEMA public
        GRANT SELECT ON TABLES TO app_readonly;

    ALTER DEFAULT PRIVILEGES IN SCHEMA public
        GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_readwrite;

    ALTER DEFAULT PRIVILEGES IN SCHEMA public
        GRANT USAGE, SELECT ON SEQUENCES TO app_readwrite;

EOSQL

echo ">>> Roles and schema created successfully."
