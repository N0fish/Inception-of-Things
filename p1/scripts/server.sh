#!/bin/bash
set -e

echo "=========================================="
echo "Installing K3s Server on $(hostname)"
echo "=========================================="

# Update system
apt-get update -qq
apt-get install -y curl net-tools

# Install K3s server
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=192.168.56.110 \
  --bind-address=192.168.56.110 \
  --advertise-address=192.168.56.110 \
  --tls-san=192.168.56.110 \
  --write-kubeconfig-mode=644 \
  --cluster-init" sh -

# Wait for K3s to start
echo "Waiting for K3s to start..."
for i in {1..60}; do
  if systemctl is-active --quiet k3s; then
    echo "✓ K3s service is active!"
    break
  fi
  sleep 2
done

# Wait for node to be ready
echo "Waiting for node to be ready..."
for i in {1..30}; do
  if kubectl get nodes 2>/dev/null | grep -q "Ready"; then
    echo "✓ Node is Ready!"
    break
  fi
  sleep 2
done

# Create directory for shared files
echo "Creating directory for token..."
mkdir -p /vagrant/confs

# Copy token to shared directory
sudo cp /var/lib/rancher/k3s/server/node-token /vagrant/confs/node-token
sudo chmod 644 /vagrant/confs/node-token

# Copy kubeconfig
sudo cp /etc/rancher/k3s/k3s.yaml /vagrant/confs/k3s.yaml
sudo sed -i "s/127.0.0.1/192.168.56.110/g" /vagrant/confs/k3s.yaml
sudo chmod 644 /vagrant/confs/k3s.yaml

# IMPORTANT: With rsync, we need to make files accessible to vagrant user
# for them to be synced back to host
sudo chown -R vagrant:vagrant /vagrant/confs/

# Create a simple HTTP server to serve the token as backup method
echo "Starting HTTP server to share token..."
TOKEN=$(cat /vagrant/confs/node-token)
cat > /tmp/serve_token.sh << EOF
#!/bin/bash
while true; do
  echo -e "HTTP/1.1 200 OK\\nContent-Type: text/plain\\n\\n$TOKEN" | nc -l -p 8888 -q 1
done
EOF
chmod +x /tmp/serve_token.sh
nohup /tmp/serve_token.sh > /dev/null 2>&1 &

echo ""
echo "=========================================="
echo "K3s Server installation complete!"
echo "Token saved to: /vagrant/confs/node-token"
echo "Token also available via HTTP: http://192.168.56.110:8888"
echo "=========================================="

# Show cluster status
kubectl get nodes -o wide