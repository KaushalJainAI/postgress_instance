# ============================================================
# General-Purpose PostgreSQL Container for EC2
# ============================================================
# Built on the official PostgreSQL 16 Alpine image for
# a minimal footprint. Optimized for Amazon Linux 2023 on
# c7i-flex.large (2 vCPU Intel Xeon, 4 GB RAM, x86_64).
# ============================================================

# Explicitly target x86_64 (amd64) to match c7i-flex Intel architecture
FROM --platform=linux/amd64 postgres:16-alpine

LABEL maintainer="your-email@example.com"
LABEL description="General-purpose PostgreSQL server for EC2 (c7i-flex.large)"
LABEL version="1.1"

# ---- Install useful utilities ----
# NOTE: aws-cli is NOT available in Alpine apk repos.
# Install via pip if you need S3 backups, or use the host's AWS CLI instead.
RUN apk add --no-cache \
    curl \
    bash \
    py3-pip \
    tzdata && \
    pip3 install --no-cache-dir --break-system-packages awscli

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
