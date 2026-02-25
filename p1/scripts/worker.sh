#!/usr/bin/env bash
set -euo pipefail

SERVER_IP="192.168.56.110"
WORKER_IP="192.168.56.111"
CONFS_DIR="/vagrant/confs"
TOKEN_FILE="${CONFS_DIR}/node-token"

echo "[worker] Installing dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y curl net-tools netcat-openbsd

echo "[worker] Reading token from ${TOKEN_FILE} as user vagrant..."

# Root may be blocked on 9p (/vagrant) with libvirt; vagrant user can access it.
TOKEN=""
for i in $(seq 1 600); do
  if sudo -u vagrant test -s "${TOKEN_FILE}"; then
    TOKEN="$(sudo -u vagrant cat "${TOKEN_FILE}")"
    break
  fi

  if (( i % 10 == 0 )); then
    echo "[worker] still waiting for token... (${i}s)"
  fi
  sleep 1
done

if [[ -z "${TOKEN}" ]]; then
  echo "[worker] ERROR: Token not found or empty after waiting."
  echo "[worker] Debug (as vagrant):"
  sudo -u vagrant ls -la "${CONFS_DIR}" || true
  exit 1
fi

echo "[worker] Got token (length: ${#TOKEN}). Waiting for server API ${SERVER_IP}:6443..."
for i in $(seq 1 300); do
  if nc -z "${SERVER_IP}" 6443 >/dev/null 2>&1; then
    echo "[worker] Server API is reachable."
    break
  fi
  if (( i % 10 == 0 )); then
    echo "[worker] still waiting for API... (${i}s)"
  fi
  sleep 1
done

echo "[worker] Installing k3s (agent)..."
export K3S_URL="https://${SERVER_IP}:6443"
export K3S_TOKEN="${TOKEN}"

curl -sfL https://get.k3s.io | sh -s - agent --node-ip "${WORKER_IP}"

echo "[worker] Done."
