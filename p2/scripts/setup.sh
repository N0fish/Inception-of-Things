#!/bin/bash
set -e

echo "=========================================="
echo "Setting up K3s Server"
echo "=========================================="

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# Install K3s in server mode
echo "Installing K3s..."
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode=644 \
  --node-ip=192.168.56.110

# Wait for K3s to be ready
echo "Waiting for K3s to start..."
sleep 10

# Wait for node to be ready
echo "Waiting for node to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=60s

if [ ! -d /vagrant/confs ]; then
  echo "ERROR: /vagrant/confs not found!"
  echo "Available directories:"
  ls -la /
  exit 1
fi

echo "=========================================="
echo "Deploying applications..."
echo "=========================================="

# Apply all manifests from /vagrant/confs/
kubectl apply -f /vagrant/confs/app1.yaml
kubectl apply -f /vagrant/confs/app2.yaml
kubectl apply -f /vagrant/confs/app3.yaml
kubectl apply -f /vagrant/confs/ingress.yaml

# Wait for deployments to be ready
echo "Waiting for deployments to be ready..."
sleep 30

echo "=========================================="
echo "Setup complete!"
echo "=========================================="

echo "Deployments:"
kubectl get deployments

echo ""
echo "Pods:"
kubectl get pods

echo ""
echo "Services:"
kubectl get services

echo ""
echo "Ingress:"
kubectl get ingress