#!/usr/bin/env bash
set -euo pipefail

SERVER_IP="192.168.56.110"
WORKER_IP="192.168.56.111"
CONFS_DIR="/vagrant/confs"
OWNER="${SUDO_USER:-vagrant}"

echo "[worker] Installing dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y curl net-tools openssh-client

TOKEN=""

echo "[worker] Method 1: read token from shared folder (with retries)..."
# Server may still be provisioning; retry up to ~60s
for i in $(seq 1 30); do
  if [[ -f "${CONFS_DIR}/node-token" ]] && [[ -s "${CONFS_DIR}/node-token" ]]; then
    TOKEN="$(cat "${CONFS_DIR}/node-token")"
    break
  fi
  sleep 2
done

if [[ -z "${TOKEN}" ]]; then
  echo "[worker] ERROR: Could not obtain K3S token (shared folder / HTTP / SSH all failed)."
  exit 1
fi

echo "[worker] Installing k3s (agent)..."
export K3S_URL="https://${SERVER_IP}:6443"
export K3S_TOKEN="${TOKEN}"

curl -sfL https://get.k3s.io | sh -s - agent --node-ip "${WORKER_IP}"

echo "[worker] Done."

