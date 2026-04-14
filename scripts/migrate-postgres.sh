#!/bin/bash
# ============================================================
# PostgreSQL Migration Script (Remote -> Docker EC2)
# ============================================================
# This script pulls an exact copy of a remote database (like 
# AWS RDS) and restores it directly into your new Docker
# container.
#
# Run this from your EC2 Terminal!
# ============================================================

set -e

SOURCE_URI="postgresql://old_user:old_pass@old-rds-host.amazonaws.com:5432/old_db_name"
TARGET_CONTAINER="postgres-server"
TARGET_USER="admin"
TARGET_DB="app_db"
DUMP_FILE="migration_dump.sql"

echo ">>> 1. Extracting data from source database..."
# Extracts structure and data cleanly
docker exec -i $TARGET_CONTAINER pg_dump --dbname="$SOURCE_URI" --clean --if-exists --no-owner --no-privileges > $DUMP_FILE

echo ">>> 2. Injecting data into new Docker database ($TARGET_DB)..."
# Restores data into the local docker DB
cat $DUMP_FILE | docker exec -i $TARGET_CONTAINER psql -U $TARGET_USER -d $TARGET_DB

echo ">>> 3. Cleaning up temporary file..."
rm $DUMP_FILE

echo "============================================"
echo "  ✅ Migration Complete!"
echo "============================================"
