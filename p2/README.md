# Part 2: K3s with 3 apps + Traefik Ingress routing

Single virtual machine running K3s with three web applications, routed to by hostname via Traefik Ingress.

| VM | Hostname | IP |
|---|---|---|
| Server | `urosbyS` | `192.168.56.110` |

| Host header | Routed to |
|---|---|
| `app1.com` | App 1 |
| `app2.com` | App 2 |
| *(anything else)* | App 3 (default catch-all) |

## Prerequisites

Ubuntu 22.04 LTS host. Run once from the project root:

```bash
./setup_host.sh     # installs libvirt, QEMU, Vagrant, vagrant-libvirt, kubectl
```

**Log out and back in** after setup if libvirt groups were just assigned.

## Usage

```bash
make up              # Start VM (also updates /etc/hosts automatically)
make ssh             # SSH into the VM
make check           # Show nodes, pods, ingress rules, and services
make test            # Run evaluation tests
make halt            # Stop VM (preserves disk state)
make destroy         # Destroy VM
make re              # Destroy + rebuild from scratch
make update-hosts    # Re-add app hostnames to /etc/hosts (if needed)
```

## /etc/hosts

`make up` calls `make update-hosts` automatically, which adds:

```
192.168.56.110 app1.com app2.com app3.com    # IOT_P2_APPS
```

After this, `curl -H "Host: app1.com" http://192.168.56.110/` (or just `curl http://app1.com/`) routes to App 1.

## Tests

`make test` runs [test.sh](test.sh) and verifies:

- VM is running, SSH works, IP address is correct
- K3s service is active, node is Ready
- All three Deployments exist (`app1`, `app2`, `app3`)
- Ingress object exists in the default namespace
- `/etc/hosts` has the correct marker entry
- HTTP 200 response from `app1.com`, `app2.com`, and `app3.com`

## Key files

| File | Purpose |
|---|---|
| [Vagrantfile](Vagrantfile) | Single VM definition |
| [scripts/setup.sh](scripts/setup.sh) | Installs K3s, waits for Traefik, deploys all manifests |
| [confs/app1.yaml](confs/app1.yaml) | Deployment + Service + ConfigMap for App 1 |
| [confs/app2.yaml](confs/app2.yaml) | Deployment + Service + ConfigMap for App 2 |
| [confs/app3.yaml](confs/app3.yaml) | Deployment + Service + ConfigMap for App 3 |
| [confs/ingress.yaml](confs/ingress.yaml) | Ingress rules: app1.com → app1, app2.com → app2, default → app3 |
| [test.sh](test.sh) | Full evaluation test suite (called by `make test`) |
