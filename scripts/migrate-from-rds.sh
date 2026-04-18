#!/bin/bash
# ============================================================
# RDS to EC2 PostgreSQL Migration Script (Same VPC)
# ============================================================
# This script migrates data from an AWS RDS instance to this
# local Dockerized PostgreSQL instance.
#
# Prerequisite: EC2 Security Group must allow outbound to RDS.
# ============================================================

set -e

# --- Configuration ---
if [ -f .env.migration ]; then
    export $(grep -v '^#' .env.migration | xargs)
else
    echo "ERROR: .env.migration not found. Setup RDS credentials first."
    exit 1
fi

# Target (Local Docker)
TARGET_CONTAINER="postgres-server"
TARGET_USER=$(grep POSTGRES_USER .env | cut -d '=' -f2)
TARGET_DB=$(grep POSTGRES_DB .env | cut -d '=' -f2)

DUMP_FILE="rds_migration_dump.sql"

echo "============================================"
echo "  🚀 Starting RDS to EC2 Migration"
echo "============================================"

# Check if target container is running
if ! docker ps | grep -q $TARGET_CONTAINER; then
    echo "ERROR: Target container $TARGET_CONTAINER is not running."
    exit 1
fi

echo ">>> 1. Extracting data from RDS ($SOURCE_HOST)..."
# We run pg_dump inside the container to avoid local dependency issues
docker exec -e PGPASSWORD="$SOURCE_PASS" -i $TARGET_CONTAINER \
    pg_dump -h $SOURCE_HOST -p $SOURCE_PORT -U $SOURCE_USER -d $SOURCE_DB \
    --clean --if-exists --no-owner --no-privileges > $DUMP_FILE

echo ">>> 2. Injecting data into local PostgreSQL ($TARGET_DB)..."
# Restore data into the local docker DB
cat $DUMP_FILE | docker exec -i $TARGET_CONTAINER psql -U $TARGET_USER -d $TARGET_DB

echo ">>> 3. Cleaning up temporary file..."
rm $DUMP_FILE

echo "============================================"
echo "  ✅ Migration Complete!"
echo "============================================"
echo "  Next Steps:"
echo "  - Check your app connection to ngu_db"
echo "  - You can now safely stop the RDS instance to save costs."
echo "============================================"
