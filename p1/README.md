# Part 1: Two-node K3s cluster with Vagrant + libvirt

Two virtual machines provisioned by Vagrant (libvirt/QEMU provider) forming a minimal Kubernetes cluster — one K3s server and one K3s agent.

| VM | Hostname | IP | Role |
|---|---|---|---|
| Server | `urosbyS` | `192.168.56.110` | K3s control plane |
| Worker | `urosbySW` | `192.168.56.111` | K3s agent |

## Prerequisites

Ubuntu 22.04 LTS host. Run once from the project root:

```bash
./setup_host.sh     # installs libvirt, QEMU, Vagrant, vagrant-libvirt, kubectl
```

**Log out and back in** after setup (libvirt/kvm group changes require a fresh session).

## Usage

```bash
make up            # Start both VMs (server first, then worker)
make ssh-server    # SSH into the server
make ssh-worker    # SSH into the worker
make check         # Show hostname, IP, and kubectl get nodes from inside the VMs
make test          # Run evaluation tests
make halt          # Stop both VMs (preserves disk state)
make destroy       # Destroy both VMs
make re            # Destroy + rebuild from scratch
```

## Fix 9p shared folder permissions

If provisioning fails because the VM can't read `/vagrant`:

```bash
make acl           # Grants the qemu user access to the shared folder
make re            # Then reprovision
```

## Tests

`make test` runs [TESTING.sh](TESTING.sh) and verifies:

- Both VMs are running with correct hostnames and IPs
- K3s server service (`k3s`) is active on `urosbyS`
- K3s agent service (`k3s-agent`) is active on `urosbySW`
- Both nodes appear in `kubectl get nodes` with status `Ready`

## Key files

| File | Purpose |
|---|---|
| [Vagrantfile](Vagrantfile) | VM definitions — reads config from `confs/config.yaml` |
| [confs/config.yaml](confs/config.yaml) | Login prefix, box, IPs, CPU/RAM, script paths |
| [scripts/server.sh](scripts/server.sh) | Installs K3s server, writes join token + kubeconfig to `/vagrant/confs/` |
| [scripts/worker.sh](scripts/worker.sh) | Waits for token, waits for API on port 6443, joins cluster as agent |
| [TESTING.sh](TESTING.sh) | Full evaluation test suite (called by `make test`) |
