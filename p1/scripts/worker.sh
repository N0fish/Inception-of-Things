#!/bin/bash
set -e

echo "=========================================="
echo "Installing K3s Agent on $(hostname)"
echo "=========================================="

# Update system
apt-get update -qq
apt-get install -y curl net-tools

# Wait for server to be ready
echo "Waiting for server to be ready..."
for i in {1..120}; do
  if curl -k -s https://192.168.56.110:6443 > /dev/null 2>&1; then
    echo "✓ Server API is reachable!"
    break
  fi
  sleep 2
done

# Try multiple methods to get token
echo "Trying to get K3s token..."
TOKEN=""

# Method 1: Check shared folder (rsync from host)
if [ -f "/vagrant/confs/node-token" ]; then
  TOKEN=$(cat /vagrant/confs/node-token | tr -d '\n\r')
  echo "✓ Got token from shared folder"
fi

# Method 2: Try HTTP server on server
if [ -z "$TOKEN" ] || [ ${#TOKEN} -lt 10 ]; then
  echo "Trying HTTP server on server..."
  for i in {1..10}; do
    TOKEN=$(curl -s http://192.168.56.110:8888 2>/dev/null || curl -s http://192.168.56.110:8888/token 2>/dev/null)
    if [ -n "$TOKEN" ] && [ ${#TOKEN} -gt 10 ]; then
      echo "✓ Got token via HTTP"
      break
    fi
    sleep 2
  done
fi

# Method 3: Try SSH (if keys are set up)
if [ -z "$TOKEN" ] || [ ${#TOKEN} -lt 10 ]; then
  echo "Trying SSH to get token..."
  # Check if we have SSH access
  if [ -f "/home/vagrant/.ssh/id_rsa" ] || ssh -o PasswordAuthentication=no -o ConnectTimeout=5 vagrant@192.168.56.110 "echo test" 2>/dev/null; then
    for i in {1..5}; do
      TOKEN=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 vagrant@192.168.56.110 \
        "sudo cat /var/lib/rancher/k3s/server/node-token 2>/dev/null" 2>/dev/null)
      if [ -n "$TOKEN" ] && [ ${#TOKEN} -gt 10 ]; then
        echo "✓ Got token via SSH"
        break
      fi
      sleep 2
    done
  fi
fi

# Final fallback: If still no token, show error
if [ -z "$TOKEN" ] || [ ${#TOKEN} -lt 10 ]; then
  echo "ERROR: Could not get K3s token!"
  echo ""
  echo "Possible solutions:"
  echo "1. Check if server VM is running: vagrant status"
  echo "2. Get token manually from server: vagrant ssh urosbyS -c 'sudo cat /var/lib/rancher/k3s/server/node-token'"
  echo "3. Copy token to worker: echo 'TOKEN' > /home/vagrant/k3s-token"
  exit 1
fi

K3S_URL="https://192.168.56.110:6443"

echo "Token length: ${#TOKEN} characters"

# Install K3s agent
echo "Installing K3s agent..."
curl -sfL https://get.k3s.io | K3S_URL="$K3S_URL" \
  K3S_TOKEN="$TOKEN" \
  INSTALL_K3S_EXEC="--node-ip=192.168.56.111" sh -

# Wait for agent to start
echo "Waiting for K3s agent to start..."
for i in {1..60}; do
  if systemctl is-active --quiet k3s-agent; then
    echo "✓ K3s agent service is active!"
    break
  fi
  sleep 2
done

echo "=========================================="
echo "K3s Agent installation complete!"
echo "=========================================="

# Give time for node registration
sleep 10
echo "Check cluster status from server: kubectl get nodes"