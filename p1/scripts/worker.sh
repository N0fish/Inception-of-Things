#!/bin/bash

set -e

echo "=========================================="
echo "Installing K3s Agent on $(hostname)"
echo "=========================================="

# Обновление
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq > /dev/null 2>&1
apt-get install -y curl > /dev/null 2>&1

# Найти интерфейс
INTERFACE=$(ip -4 route ls | grep "192.168.56.0/24" | grep -Po '(?<=dev )(\S+)')
echo "Detected network interface: $INTERFACE"

if [ -n "$INTERFACE" ]; then
  FLANNEL_IFACE="--flannel-iface=$INTERFACE"
else
  FLANNEL_IFACE=""
fi

# Ждем токен
echo "Waiting for server token..."
MAX_ATTEMPTS=60
ATTEMPT=0

while [ ! -f /vagrant/confs/node-token ] && [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS..."
  sleep 5
  ATTEMPT=$((ATTEMPT + 1))
done

if [ ! -f /vagrant/confs/node-token ]; then
  echo "ERROR: Could not find node token!"
  exit 1
fi

# Читаем токен
K3S_TOKEN=$(cat /vagrant/confs/node-token)
K3S_URL="https://192.168.56.110:6443"

echo "Token found! Installing K3s agent..."

# Установка agent
curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL \
  K3S_TOKEN=$K3S_TOKEN \
  INSTALL_K3S_EXEC="--node-ip=192.168.56.111 $FLANNEL_IFACE" sh -

echo "Waiting for agent to start..."
sleep 15

echo "=========================================="
echo "K3s Agent installed successfully!"
echo "=========================================="

systemctl status k3s-agent --no-pager || true
