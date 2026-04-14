#!/bin/bash
# ============================================================
# EC2 Quick Deploy — Pull from Docker Hub & Run
# ============================================================
# Run this on a FRESH EC2 instance (Amazon Linux 2023).
# It installs Docker, pulls the image from Docker Hub,
# and starts everything. No need to clone the repo!
#
# Usage (run as root or with sudo):
#   curl -sSL https://raw.githubusercontent.com/KaushalJainAI/postgres-ec2/main/scripts/ec2-deploy.sh | sudo bash
#   OR
#   sudo bash ec2-deploy.sh
# ============================================================

set -euo pipefail

DOCKER_HUB_USER="kaushaljainai"
IMAGE_NAME="postgres-ec2"
DEPLOY_DIR="/opt/postgres-server"

echo "============================================"
echo "  PostgreSQL EC2 Deployment (Docker Hub)"
echo "============================================"

# --- Step 1: Install Docker ---
echo ">>> Installing Docker..."
dnf update -y
dnf install -y docker git
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# --- Install Docker Compose plugin ---
echo ">>> Installing Docker Compose..."
mkdir -p /usr/local/lib/docker/cli-plugins
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

echo ">>> Docker version: $(docker --version)"
echo ">>> Docker Compose version: $(docker compose version)"

# --- Step 2: Kernel tuning ---
echo ">>> Applying kernel optimizations..."
cat > /etc/sysctl.d/30-postgresql.conf << 'EOF'
vm.swappiness = 1
vm.dirty_ratio = 40
vm.dirty_background_ratio = 10
fs.file-max = 262144
vm.nr_hugepages = 550
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
EOF
sysctl -p /etc/sysctl.d/30-postgresql.conf

# --- Step 3: Create deployment directory ---
echo ">>> Setting up deployment directory at ${DEPLOY_DIR}..."
mkdir -p "${DEPLOY_DIR}/backups"
cd "${DEPLOY_DIR}"

# --- Step 4: Create .env file ---
if [ ! -f .env ]; then
    cat > .env << 'ENVEOF'
# ============================================================
# PostgreSQL Configuration — EDIT THESE VALUES!
# ============================================================

# --- Core Database Settings ---
POSTGRES_USER=admin
POSTGRES_PASSWORD=CHANGE_ME_TO_A_STRONG_PASSWORD
POSTGRES_DB=app_db

# --- Connection Settings ---
POSTGRES_PORT=5432

# --- Resource Limits ---
PG_SHARED_MEMORY=256m
PG_MEMORY_LIMIT=3.5G
PG_MEMORY_RESERVATION=2G

# --- PgBouncer ---
PGBOUNCER_PORT=6432

# --- Backup ---
BACKUP_RETENTION_DAYS=7
BACKUP_PARALLEL_JOBS=2

# --- PgAdmin (Optional) ---
PGADMIN_EMAIL=admin@example.com
PGADMIN_PASSWORD=CHANGE_ME
PGADMIN_PORT=5050

# --- Monitoring (Optional) ---
EXPORTER_PORT=9187
ENVEOF
    echo ""
    echo ">>> ⚠️  IMPORTANT: Edit .env with your credentials!"
    echo ">>>    nano ${DEPLOY_DIR}/.env"
    echo ""
fi

# --- Step 5: Create docker-compose.yml ---
cat > docker-compose.yml << 'COMPOSEEOF'
services:
  db:
    image: kaushaljainai/postgres-ec2:latest
    container_name: postgres-server
    restart: unless-stopped
    env_file: .env
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-admin}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in .env}
      POSTGRES_DB: ${POSTGRES_DB:-app_db}
    ports:
      - "${POSTGRES_PORT:-5432}:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./backups:/backups
    shm_size: ${PG_SHARED_MEMORY:-256m}
    networks:
      - pg-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-admin} -d ${POSTGRES_DB:-app_db}"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
    deploy:
      resources:
        limits:
          memory: ${PG_MEMORY_LIMIT:-3.5G}
        reservations:
          memory: ${PG_MEMORY_RESERVATION:-2G}
    oom_score_adj: -1000

  pgbouncer:
    image: edoburu/pgbouncer:latest
    container_name: pgbouncer
    restart: unless-stopped
    environment:
      DATABASE_URL: "postgresql://${POSTGRES_USER:-admin}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB:-app_db}"
      POOL_MODE: transaction
      MAX_CLIENT_CONN: 500
      DEFAULT_POOL_SIZE: 20
      MIN_POOL_SIZE: 5
      RESERVE_POOL_SIZE: 5
      RESERVE_POOL_TIMEOUT: 3
      SERVER_LIFETIME: 3600
      SERVER_IDLE_TIMEOUT: 600
      SERVER_CONNECT_TIMEOUT: 15
      AUTH_TYPE: scram-sha-256
    ports:
      - "${PGBOUNCER_PORT:-6432}:5432"
    depends_on:
      db:
        condition: service_healthy
    networks:
      - pg-network
    logging:
      driver: "json-file"
      options:
        max-size: "5m"
        max-file: "3"

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: pgadmin
    restart: unless-stopped
    profiles:
      - admin
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_EMAIL:-admin@example.com}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_PASSWORD:?Set PGADMIN_PASSWORD in .env}
      PGADMIN_LISTEN_PORT: 80
    ports:
      - "${PGADMIN_PORT:-5050}:80"
    volumes:
      - pgadmin_data:/var/lib/pgadmin
    depends_on:
      db:
        condition: service_healthy
    networks:
      - pg-network

  postgres-exporter:
    image: prometheuscommunity/postgres-exporter:latest
    container_name: postgres-exporter
    restart: unless-stopped
    profiles:
      - monitoring
    environment:
      DATA_SOURCE_NAME: "postgresql://${POSTGRES_USER:-admin}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB:-app_db}?sslmode=disable"
    ports:
      - "${EXPORTER_PORT:-9187}:9187"
    depends_on:
      db:
        condition: service_healthy
    networks:
      - pg-network

volumes:
  pgdata:
    driver: local
  pgadmin_data:
    driver: local

networks:
  pg-network:
    driver: bridge
COMPOSEEOF

# --- Step 6: Pull the image ---
echo ">>> Pulling PostgreSQL image from Docker Hub..."
docker pull "${DOCKER_HUB_USER}/${IMAGE_NAME}:latest"

echo ""
echo "============================================"
echo "  ✅ Deployment Ready!"
echo "============================================"
echo ""
echo "  Deployment dir: ${DEPLOY_DIR}"
echo ""
echo "  Next steps:"
echo "  1. Edit credentials:  sudo nano ${DEPLOY_DIR}/.env"
echo "  2. Start PostgreSQL:  cd ${DEPLOY_DIR} && sudo docker compose up -d"
echo "  3. Verify:            sudo docker compose ps"
echo ""
echo "  Optional:"
echo "  - PgAdmin:    sudo docker compose --profile admin up -d"
echo "  - Monitoring: sudo docker compose --profile monitoring up -d"
echo ""
echo "  Connect from your app:"
echo "  postgresql://admin:PASSWORD@<EC2-PUBLIC-IP>:5432/app_db"
echo "  (via PgBouncer: port 6432)"
echo ""
