#!/bin/bash
# ============================================================
# EC2 Bootstrap Script
# ============================================================
# Run this script on a fresh EC2 instance (Amazon Linux 2023 or
# Ubuntu 22.04+) to install Docker and bring up PostgreSQL.
#
# Usage:
#   chmod +x scripts/ec2-setup.sh
#   sudo ./scripts/ec2-setup.sh
# ============================================================

set -euo pipefail

echo "============================================"
echo "  PostgreSQL EC2 Setup"
echo "============================================"

# --- Detect OS ---
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "ERROR: Cannot detect OS."
    exit 1
fi

echo ">>> Detected OS: $OS"

# --- Install Docker ---
install_docker_amazon_linux() {
    echo ">>> Installing Docker on Amazon Linux..."
    dnf update -y
    dnf install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user
}

install_docker_ubuntu() {
    echo ">>> Installing Docker on Ubuntu..."
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ubuntu
}

case "$OS" in
    amzn)   install_docker_amazon_linux ;;
    ubuntu) install_docker_ubuntu ;;
    *)
        echo "ERROR: Unsupported OS '$OS'. Install Docker manually."
        exit 1
        ;;
esac

# --- Install Docker Compose plugin (if not bundled) ---
if ! docker compose version &>/dev/null; then
    echo ">>> Installing Docker Compose plugin..."
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

echo ">>> Docker version: $(docker --version)"
echo ">>> Docker Compose version: $(docker compose version)"

# --- Create required directories ---
echo ">>> Creating backup directory..."
mkdir -p backups

# --- Setup .env if not present ---
if [ ! -f .env ]; then
    echo ">>> Creating .env from template..."
    cp .env.example .env
    echo ""
    echo "============================================"
    echo "  IMPORTANT: Edit .env before starting!"
    echo "  nano .env"
    echo "============================================"
else
    echo ">>> .env already exists, skipping."
fi

echo ""
echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo ""
echo "  Next steps:"
echo "  1. Edit .env with your credentials"
echo "  2. Run: docker compose up -d"
echo "  3. Verify: docker compose ps"
echo ""
echo "  Optional:"
echo "  - PgAdmin:    docker compose --profile admin up -d"
echo "  - Monitoring: docker compose --profile monitoring up -d"
echo ""
