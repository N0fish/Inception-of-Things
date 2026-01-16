#!/bin/bash
set -e

echo "=========================================="
echo "Installing K3s Server on $(hostname)"
echo "=========================================="

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a  # Ignore needrestart exit codes

apt-get update -qq
apt-get install -y curl || true  # Ignore potential non-zero exit codes

INTERFACE=$(ip -4 route ls | grep "192.168.56.0/24" | grep -Po '(?<=dev )(\S+)' || echo "")
echo "Detected network interface: $INTERFACE"

if [ -n "$INTERFACE" ]; then
  FLANNEL_IFACE="--flannel-iface=$INTERFACE"
else
  FLANNEL_IFACE=""
  echo "No specific interface detected, K3s will auto-detect"
fi

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=192.168.56.110 \
  --write-kubeconfig-mode=644 \
  $FLANNEL_IFACE" sh -

# Wait for k3s to start
for i in {1..60}; do
  if systemctl is-active --quiet k3s; then
    echo "K3s is running!"
    break
  fi
  echo "Attempt $i/60..."
  sleep 5
done

mkdir -p /vagrant/confs
chmod 755 /vagrant/confs

cp /var/lib/rancher/k3s/server/node-token /vagrant/confs/node-token
chmod 644 /vagrant/confs/node-token

cp /etc/rancher/k3s/k3s.yaml /vagrant/confs/k3s.yaml
sed -i "s/127.0.0.1/192.168.56.110/g" /vagrant/confs/k3s.yaml
chmod 644 /vagrant/confs/k3s.yaml

echo "=========================================="
echo "K3s Server installed successfully!"
echo "=========================================="
echo "Waiting for nodes to appear..."

for i in {1..30}; do
  if kubectl get nodes | grep -q "urosbyS"; then
    echo "Node registered!"
    break
  fi
  sleep 2
done

kubectl get nodes
