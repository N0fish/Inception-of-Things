#!/usr/bin/env bash
set -euo pipefail

SERVER_IP="192.168.56.110"
CONFS_DIR="/vagrant/confs"

echo "[server] Installing dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y curl net-tools netcat-openbsd

echo "[server] Installing k3s (server)..."
curl -sfL https://get.k3s.io | sh -s - server \
  --node-ip "${SERVER_IP}" \
  --advertise-address "${SERVER_IP}" \
  --tls-san "${SERVER_IP}" \
  --write-kubeconfig-mode 644 \
  --disable traefik

echo "[server] Waiting for k3s..."
until kubectl get nodes >/dev/null 2>&1; do
  sleep 1
done

echo "[server] Preparing token + kubeconfig (read as root, write to /vagrant as vagrant)..."

TOKEN_TMP="/tmp/node-token"
KCFG_TMP="/tmp/k3s.yaml"

# Read root-owned files into /tmp (root can do this)
cp /var/lib/rancher/k3s/server/node-token "${TOKEN_TMP}"
cp /etc/rancher/k3s/k3s.yaml "${KCFG_TMP}"
sed -i "s/127.0.0.1/${SERVER_IP}/g" "${KCFG_TMP}"

# Make temp files readable (this is local FS, chmod works)
chmod 644 "${TOKEN_TMP}" "${KCFG_TMP}"

# All /vagrant operations as vagrant (root may be blocked on 9p)
sudo -u vagrant mkdir -p "${CONFS_DIR}"
sudo -u vagrant rm -f "${CONFS_DIR}/node-token" "${CONFS_DIR}/k3s.yaml"
sudo -u vagrant cp "${TOKEN_TMP}" "${CONFS_DIR}/node-token"
sudo -u vagrant cp "${KCFG_TMP}" "${CONFS_DIR}/k3s.yaml"

echo "[server] Done."
