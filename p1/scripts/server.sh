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

echo "[server] Writing token and kubeconfig into ${CONFS_DIR}..."
# DO NOT chmod/chown on /vagrant with 9p (can fail). Just create and write.
mkdir -p "${CONFS_DIR}" || true

cat /var/lib/rancher/k3s/server/node-token > "${CONFS_DIR}/node-token"

cp /etc/rancher/k3s/k3s.yaml "${CONFS_DIR}/k3s.yaml"
sed -i "s/127.0.0.1/${SERVER_IP}/g" "${CONFS_DIR}/k3s.yaml"

echo "[server] Installing nginx ingress..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

echo "[server] Starting token HTTP endpoint on :8888 (fallback)..."
nohup sh -c "while true; do nc -l -p 8888 -q 1 < '${CONFS_DIR}/node-token'; done" \
  >/var/log/k3s-token-http.log 2>&1 &

echo "[server] Done."

