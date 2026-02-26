#!/usr/bin/env bash
set -euo pipefail

SERVER_IP="192.168.56.110"

echo "=========================================="
echo "Setting up K3s Server"
echo "=========================================="

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

apt-get update -qq
apt-get install -y curl net-tools

echo "Installing K3s..."
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode=644 \
  --node-ip="${SERVER_IP}"

echo "Waiting for K3s API to respond..."
for i in $(seq 1 120); do
  if kubectl get --raw=/readyz >/dev/null 2>&1; then
    echo "K3s API is ready."
    break
  fi
  sleep 1
done

echo "Waiting for node object to appear..."
for i in $(seq 1 120); do
  if kubectl get nodes --no-headers 2>/dev/null | grep -q .; then
    echo "Node object found."
    break
  fi
  sleep 1
done

echo "Waiting for node to be Ready..."
NODE_NAME="$(kubectl get nodes --no-headers 2>/dev/null | awk 'NR==1{print $1}')"
if [[ -z "${NODE_NAME}" ]]; then
  echo "ERROR: Node name still empty. kubectl get nodes:"
  kubectl get nodes -o wide || true
  exit 1
fi
kubectl wait --for=condition=Ready "node/${NODE_NAME}" --timeout=120s

echo "=========================================="
echo "Waiting for Traefik + port 80..."
echo "=========================================="

echo "Waiting for Traefik deployment to appear..."
for i in $(seq 1 120); do
  if kubectl -n kube-system get deploy traefik >/dev/null 2>&1; then
    echo "Traefik deployment found."
    break
  fi
  sleep 1
done

echo "Waiting for Traefik pod to be Ready..."
kubectl -n kube-system wait --for=condition=Ready pod -l app.kubernetes.io/name=traefik --timeout=120s || true

echo "Waiting for port 80 to accept connections on ${SERVER_IP}..."
for i in $(seq 1 180); do
  if curl -s -o /dev/null --connect-timeout 1 "http://${SERVER_IP}/"; then
    echo "Port 80 is reachable."
    break
  fi
  sleep 1
done

echo "=========================================="
echo "Deploying applications..."
echo "=========================================="

apply_manifest() {
  local f="$1"
  if ! sudo -u vagrant test -r "$f"; then
    echo "ERROR: vagrant cannot read $f"
    sudo -u vagrant ls -la /vagrant/confs || true
    exit 1
  fi
  sudo -u vagrant kubectl apply -f "$f"
}

apply_manifest /vagrant/confs/app1.yaml
apply_manifest /vagrant/confs/app2.yaml
apply_manifest /vagrant/confs/app3.yaml
apply_manifest /vagrant/confs/ingress.yaml

echo "Waiting for ingress to exist..."
kubectl -n default get ingress app-ingress >/dev/null 2>&1 || true

echo "Waiting for app services endpoints..."
for svc in app1-service app2-service app3-service; do
  for i in $(seq 1 120); do
    EP="$(kubectl -n default get endpoints "${svc}" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || true)"
    if [[ -n "${EP}" ]]; then
      break
    fi
    sleep 1
  done
done

echo "=========================================="
echo "Setup complete!"
echo "=========================================="
sudo -u vagrant kubectl get nodes -o wide || true
sudo -u vagrant kubectl get pods -A || true
sudo -u vagrant kubectl get ingress -A || true