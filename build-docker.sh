#!/usr/bin/env bash
# Wrapper script to run the ISO build inside a reproducible Docker environment.
set -euo pipefail

WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if docker commands can be run, otherwise prepend sudo
DOCKER_CMD="docker"
if ! docker info &>/dev/null; then
    echo "[!] Docker permission denied. Trying with sudo..."
    DOCKER_CMD="sudo docker"
fi

echo "[+] Building Docker builder image..."
$DOCKER_CMD build -t ubuntu-iso-builder "$WORKSPACE"

echo "[+] Running ISO builder inside container..."
$DOCKER_CMD run --rm \
  --device /dev/kvm \
  -v "$WORKSPACE":"/home/shane/TheMasterISO" \
  ubuntu-iso-builder
