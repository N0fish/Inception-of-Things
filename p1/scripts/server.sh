#!/bin/bash

set -e

echo "=========================================="
echo "Installing K3s Server on $(hostname)"
echo "=========================================="

# Обновление системы
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq > /dev/null 2>&1
apt-get install -y curl > /dev/null 2>&1

# Найти правильный сетевой интерфейс для 192.168.56.110
INTERFACE=$(ip -4 route ls | grep "192.168.56.0/24" | grep -Po '(?<=dev )(\S+)')
echo "Detected network interface: $INTERFACE"

# Если интерфейс найден, использовать его
if [ -n "$INTERFACE" ]; then
  FLANNEL_IFACE="--flannel-iface=$INTERFACE"
else
  FLANNEL_IFACE=""
  echo "No specific interface detected, K3s will auto-detect"
fi

# Установка K3s
echo "Installing K3s server..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=192.168.56.110 \
  --write-kubeconfig-mode=644 \
  $FLANNEL_IFACE" sh -

# Ждем запуска
echo "Waiting for K3s to start..."
for i in {1..60}; do
  if systemctl is-active --quiet k3s; then
    echo "K3s is running!"
    break
  fi
  echo "Attempt $i/60..."
  sleep 5
done

# Ждем kubectl
echo "Waiting for kubectl..."
for i in {1..30}; do
  if kubectl get nodes > /dev/null 2>&1; then
    echo "kubectl is ready!"
    break
  fi
  sleep 2
done

# Создать директорию
mkdir -p /vagrant/confs
chmod 777 /vagrant/confs

# Копировать токен
echo "Copying node token..."
cp /var/lib/rancher/k3s/server/node-token /vagrant/confs/node-token

# Копировать kubeconfig
echo "Copying kubeconfig..."
cp /etc/rancher/k3s/k3s.yaml /vagrant/confs/k3s.yaml
sed -i "s/127.0.0.1/192.168.56.110/g" /vagrant/confs/k3s.yaml

echo "=========================================="
echo "K3s Server installed successfully!"
echo "=========================================="

# Показать ноды
kubectl get nodes

echo ""
echo "Files created:"
ls -la /vagrant/confs/
