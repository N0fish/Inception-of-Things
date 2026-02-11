# Inception-of-Things - Part 1

K3s cluster setup with Vagrant and Libvirt

## ⚠️ Got "Permission denied" error?

See [QUICKFIX.md](QUICKFIX.md) - 30 second solution!

```bash
make use-rsync
make clean && make up
```

## 📋 Project Structure

```
p1/
├── Vagrantfile              # Main Vagrant configuration (9p)
├── Vagrantfile-rsync        # Alternative: rsync synced folder
├── Vagrantfile-nfs          # Alternative: NFS synced folder
├── Makefile                 # Command shortcuts
├── setup-host.sh           # Host dependency installer
├── fix-9p-permissions.sh   # Fix 9p permission issues
├── TESTING.sh              # Automated test suite
├── INSTRUCTIONS.md         # Detailed testing guide
├── QUICKFIX.md             # Quick solution for permission errors
├── TROUBLESHOOTING.md      # Comprehensive troubleshooting
├── README.md               # This file
├── confs/
│   ├── config.yaml         # VM configuration
│   ├── node-token          # K3s token (generated)
│   └── k3s.yaml            # Kubeconfig (generated)
└── scripts/
    ├── server.sh           # Server provisioning
    └── worker.sh           # Worker provisioning
```

## 🚀 Quick Start

### 1. Setup (First Time Only)
```bash
chmod +x setup-host.sh
./setup-host.sh
```
**Important:** Log out and log back in after setup!

### 2. Start VMs
```bash
make up
```

### 3. Verify
```bash
make test
```

## 📖 What This Does

This project creates a 2-node Kubernetes cluster using K3s:

- **Server VM (`urosbyS`)**: K3s control plane at 192.168.56.110
- **Worker VM (`urosbySW`)**: K3s agent at 192.168.56.111

Both VMs automatically join the same cluster.

## 🛠️ Common Commands

```bash
make help          # Show all commands
make up            # Start both VMs
make status        # Check VM status
make check         # Quick health check
make test          # Run full test suite
make ssh-server    # SSH into server
make ssh-worker    # SSH into worker
make destroy       # Delete all VMs
make clean         # Clean everything
make re            # Rebuild from scratch
```

## ✅ Testing

### Automated Tests
```bash
make test
```

### Manual Verification
```bash
# Check cluster
vagrant ssh urosbyS -c "kubectl get nodes -o wide"

# Expected: 2 Ready nodes with correct IPs
```

See [INSTRUCTIONS.md](INSTRUCTIONS.md) for detailed testing procedures.

## 📝 Requirements Met

- ✅ 2 VMs with Vagrant
- ✅ Ubuntu 22.04 LTS (latest stable)
- ✅ 1 CPU, 1024MB RAM each
- ✅ SSH access without password
- ✅ Dedicated IPs (192.168.56.110, 192.168.56.111)
- ✅ VM names include login (`urosby`)
- ✅ K3s server mode on first VM
- ✅ K3s agent mode on second VM
- ✅ kubectl installed and working
- ✅ Both nodes in same cluster

## 🔧 Configuration

Main settings in `confs/config.yaml`:
```yaml
login: urosby
box: generic/ubuntu2204
provider: libvirt
resources:
  cpus: 1
  memory: 1024
```

## 🐛 Troubleshooting

### VMs won't start
```bash
sudo systemctl status libvirtd
groups | grep libvirt  # You should be in this group
```

### Worker won't join cluster
```bash
# Re-provision worker
make destroy
make up
```

### Reset everything
```bash
make clean
make up
```

## 📚 Resources

- [K3s Documentation](https://docs.k3s.io/)
- [Vagrant Documentation](https://www.vagrantup.com/docs)
- [Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)

## 📄 License

42 School Project

## 👤 Author

urosby
