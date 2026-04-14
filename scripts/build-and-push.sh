#!/bin/bash
# ============================================================
# Build & Push PostgreSQL Image to Docker Hub
# ============================================================
# Run this from your LOCAL machine (Windows/Mac/Linux) to
# build the image and push it to Docker Hub.
#
# Prerequisites:
#   - Docker Desktop running
#   - Logged in: docker login
#
# Usage:
#   bash scripts/build-and-push.sh
#   bash scripts/build-and-push.sh v2    # optional tag
# ============================================================

set -euo pipefail

# --- Configuration ---
DOCKER_HUB_USER="kaushaljainai"
IMAGE_NAME="postgres-ec2"
TAG="${1:-latest}"
FULL_IMAGE="${DOCKER_HUB_USER}/${IMAGE_NAME}:${TAG}"

echo "============================================"
echo "  Building & Pushing PostgreSQL Image"
echo "============================================"
echo "  Image: ${FULL_IMAGE}"
echo "  Platform: linux/amd64 (for EC2)"
echo "============================================"
echo ""

# --- Step 1 & 2: Build with Buildx and Push ---
echo ">>> Building and pushing image for linux/amd64..."
# Ensure buildx builder exists and is used
docker buildx create --name mybuilder --use 2>/dev/null || docker buildx use mybuilder

if [ "${TAG}" != "latest" ]; then
    docker buildx build --platform linux/amd64 --push -t "${FULL_IMAGE}" -t "${DOCKER_HUB_USER}/${IMAGE_NAME}:latest" .
else
    docker buildx build --platform linux/amd64 --push -t "${FULL_IMAGE}" .
fi

echo ""
echo "============================================"
echo "  ✅ Build & Push Complete!"
echo "============================================"
echo ""
echo "  Image available at:"
echo "  https://hub.docker.com/r/${DOCKER_HUB_USER}/${IMAGE_NAME}"
echo ""
echo "  Pull on EC2 with:"
echo "  docker-compose -f docker-compose.hub.yml pull"
echo ""
