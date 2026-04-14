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

# --- Step 1: Build for linux/amd64 ---
echo ">>> Building image for linux/amd64..."
docker build --platform linux/amd64 -t "${FULL_IMAGE}" .

# Also tag as latest if a version tag was provided
if [ "${TAG}" != "latest" ]; then
    echo ">>> Also tagging as latest..."
    docker tag "${FULL_IMAGE}" "${DOCKER_HUB_USER}/${IMAGE_NAME}:latest"
fi

echo ""
echo ">>> Build complete. Image size:"
docker images "${DOCKER_HUB_USER}/${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# --- Step 2: Push to Docker Hub ---
echo ""
echo ">>> Pushing to Docker Hub..."
docker push "${FULL_IMAGE}"

if [ "${TAG}" != "latest" ]; then
    docker push "${DOCKER_HUB_USER}/${IMAGE_NAME}:latest"
fi

echo ""
echo "============================================"
echo "  ✅ Push Complete!"
echo "============================================"
echo ""
echo "  Image available at:"
echo "  https://hub.docker.com/r/${DOCKER_HUB_USER}/${IMAGE_NAME}"
echo ""
echo "  Pull on EC2 with:"
echo "  docker pull ${FULL_IMAGE}"
echo ""
