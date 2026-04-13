# ============================================================
# General-Purpose PostgreSQL Container for EC2
# ============================================================
# Built on the official PostgreSQL 16 Alpine image for
# a minimal footprint. Includes common extensions and
# utilities pre-installed.
# ============================================================

FROM postgres:16-alpine

LABEL maintainer="your-email@example.com"
LABEL description="General-purpose PostgreSQL server for EC2 deployment"
LABEL version="1.0"

# ---- Install useful extensions & utilities ----
RUN apk add --no-cache \
    # For health checks and scripting
    curl \
    bash \
    # For backups to S3 (optional)
    aws-cli \
    # For timezone support
    tzdata

# ---- Copy custom PostgreSQL configuration ----
COPY config/postgresql.conf /etc/postgresql/postgresql.conf
COPY config/pg_hba.conf /etc/postgresql/pg_hba.conf

# ---- Copy initialization scripts ----
# Scripts in /docker-entrypoint-initdb.d/ run automatically
# on first container start (in alphabetical order).
COPY init-scripts/ /docker-entrypoint-initdb.d/

# ---- Make init scripts executable ----
RUN chmod +x /docker-entrypoint-initdb.d/*.sh 2>/dev/null || true

# ---- Set custom config as the active configuration ----
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf", "-c", "hba_file=/etc/postgresql/pg_hba.conf"]

# ---- Expose PostgreSQL port ----
EXPOSE 5432

# ---- Health check ----
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD pg_isready -U ${POSTGRES_USER:-postgres} -d ${POSTGRES_DB:-postgres} || exit 1
