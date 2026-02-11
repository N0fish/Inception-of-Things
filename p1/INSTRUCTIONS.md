# Inception-of-Things Part 1 - Testing Instructions

## Overview
This document provides step-by-step instructions for testing your Part 1 setup according to the evaluation checklist.

## Prerequisites

### 1. Initial Host Setup
Before starting, you need to install all required dependencies on your host VM:

```bash
chmod +x setup-host.sh
./setup-host.sh
```

**IMPORTANT:** After running the setup script, you MUST log out and log back in for group changes to take effect.

Verify the setup:
```bash
groups | grep libvirt  # Should show that you're in the libvirt group
vagrant --version      # Should display Vagrant version
kubectl version --client  # Should display kubectl version
```

## Quick Start

### Start the VMs
```bash
make up
```

This will:
1. Start the server VM (`urosbyS`) with K3s in controller mode
2. Start the worker VM (`urosbySW`) with K3s in agent mode
3. Both VMs will join the same cluster

### Run All Tests
```bash
make test
```

This runs the automated test suite that checks all requirements from the evaluation checklist.

## Manual Testing (Following the Checklist)

### Part 1 - Configuration Checks

#### 1. Verify Vagrantfile exists
```bash
ls -la Vagrantfile
```
✓ Should show the Vagrantfile in the p1 folder

#### 2. Check Vagrantfile content
```bash
cat Vagrantfile
```
Verify:
- ✓ Two VMs are defined
- ✓ VM names include login: `urosbyS` and `urosbySW`
- ✓ IP addresses: 192.168.56.110 and 192.168.56.111
- ✓ Latest stable Ubuntu version (generic/ubuntu2204)

#### 3. Check VM names and hostnames
```bash
vagrant status
```
✓ Should show both `urosbyS` and `urosbySW`

### Part 1 - Usage Tests

#### 1. SSH into VMs
```bash
# Server
vagrant ssh urosbyS

# Worker (in another terminal)
vagrant ssh urosbySW
```
✓ Should connect without password

#### 2. Verify hostnames
Inside Server VM:
```bash
hostname
# Expected output: urosbyS
```

Inside Worker VM:
```bash
hostname
# Expected output: urosbySW
```

#### 3. Verify IP addresses

**On Server VM:**
```bash
ip a show eth1
# Should show: 192.168.56.110/24
```

**On Worker VM:**
```bash
ip a show eth1
# Should show: 192.168.56.111/24
```

**Alternative command (from host):**
```bash
vagrant ssh urosbyS -c "ip a show eth1 | grep 'inet '"
vagrant ssh urosbySW -c "ip a show eth1 | grep 'inet '"
```

#### 4. Verify K3s installation

**On Server VM:**
```bash
which k3s
sudo systemctl status k3s
kubectl version
```

**On Worker VM:**
```bash
which k3s
sudo systemctl status k3s-agent
```

#### 5. Verify cluster (MOST IMPORTANT TEST)

**On Server VM:**
```bash
kubectl get nodes -o wide
```

**Expected output:**
```
NAME       STATUS   ROLES                  AGE   VERSION        INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
urosbyS    Ready    control-plane,master   Xm    v1.28.x+k3s1   192.168.56.110   <none>        Ubuntu 22.04.x LTS   x.x.x-xx-generic   containerd://1.7.x
urosbySW   Ready    <none>                 Xm    v1.28.x+k3s1   192.168.56.111   <none>        Ubuntu 22.04.x LTS   x.x.x-xx-generic   containerd://1.7.x
```

✓ Both nodes should be present
✓ Both should have STATUS = Ready
✓ Server should have ROLES = control-plane,master
✓ IPs should match: 192.168.56.110 and 192.168.56.111

#### 6. Check all pods
```bash
kubectl get pods -A
```
✓ All pods should be in Running state

### Additional Verification Commands

#### View cluster info
```bash
kubectl cluster-info
kubectl get all -A
```

#### Check K3s logs
```bash
# Server
sudo journalctl -u k3s -f

# Worker
sudo journalctl -u k3s-agent -f
```

## Makefile Commands Reference

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make setup` | Install all dependencies (run once) |
| `make up` | Start both VMs |
| `make server` | Start only server VM |
| `make worker` | Start only worker VM |
| `make ssh-server` | SSH into server VM |
| `make ssh-worker` | SSH into worker VM |
| `make status` | Show VM status |
| `make check` | Quick cluster health check |
| `make test` | Run full test suite |
| `make destroy` | Destroy all VMs |
| `make clean` | Destroy VMs and clean files |
| `make re` | Rebuild from scratch |
| `make halt` | Stop VMs |
| `make reload` | Reload VMs |
| `make provision` | Re-run provisioning |

## Troubleshooting

### VMs won't start
```bash
# Check libvirt is running
sudo systemctl status libvirtd

# Check your user groups
groups | grep libvirt

# If not in group, log out and log back in
```

### K3s not running
```bash
# On server
vagrant ssh urosbyS -c "sudo systemctl restart k3s"

# On worker
vagrant ssh urosbySW -c "sudo systemctl restart k3s-agent"
```

### Worker not joining cluster
```bash
# Check token file
vagrant ssh urosbyS -c "cat /vagrant/confs/node-token"

# Check worker can reach server
vagrant ssh urosbySW -c "curl -k https://192.168.56.110:6443"

# Re-provision worker
vagrant provision urosbySW
```

### Reset everything
```bash
make clean
make up
```

## Evaluation Day Checklist

1. **Before evaluation:**
   ```bash
   make clean  # Clean state
   make up     # Fresh start
   make test   # Verify everything works
   ```

2. **During evaluation, be ready to:**
   - Explain the Vagrantfile configuration
   - Explain K3s architecture (server/agent)
   - Show `kubectl get nodes -o wide` output
   - SSH into both VMs
   - Show IP addresses with `ip a show eth1`
   - Demonstrate cluster is working

3. **Files to show:**
   - `Vagrantfile` - VM configuration
   - `confs/config.yaml` - Configuration values
   - `scripts/server.sh` - Server provisioning script
   - `scripts/worker.sh` - Worker provisioning script

## Expected Outputs for Evaluation

### 1. VM Status
```bash
$ vagrant status
Current machine states:

urosbyS                   running (libvirt)
urosbySW                  running (libvirt)
```

### 2. Cluster Nodes
```bash
$ vagrant ssh urosbyS -c "kubectl get nodes"
NAME       STATUS   ROLES                  AGE   VERSION
urosbyS    Ready    control-plane,master   10m   v1.28.x+k3s1
urosbySW   Ready    <none>                 8m    v1.28.x+k3s1
```

### 3. All Pods Running
```bash
$ vagrant ssh urosbyS -c "kubectl get pods -A"
NAMESPACE     NAME                      READY   STATUS    RESTARTS   AGE
kube-system   coredns-xxx               1/1     Running   0          10m
kube-system   local-path-provisioner    1/1     Running   0          10m
kube-system   metrics-server-xxx        1/1     Running   0          10m
...
```

## Success Criteria

Your setup is correct if:
- ✓ Both VMs start successfully
- ✓ You can SSH to both without password
- ✓ Hostnames are `urosbyS` and `urosbySW`
- ✓ IPs are correct (192.168.56.110 and 192.168.56.111)
- ✓ K3s is running on both machines
- ✓ `kubectl get nodes` shows 2 Ready nodes
- ✓ Both nodes are in the same cluster
- ✓ All system pods are Running

Good luck with your evaluation! 🚀
