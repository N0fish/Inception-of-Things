# Inception-of-Things

A progressive exploration of Kubernetes deployment approaches — from bare virtual machines managed by Vagrant, through a container-based cluster, to a fully automated GitOps pipeline backed by a self-hosted Git server.

Each part introduces a new layer of tooling and a new concept, building on the previous one. The parts are independent: you can run any of them without having completed the others.

---

## Host setup

All parts run on an **Ubuntu 22.04 LTS** host machine. The script [setup_host.sh](setup_host.sh) at the project root installs every tool required across all parts in one go: libvirt, QEMU, Vagrant, the vagrant-libvirt plugin, Docker, K3d, kubectl, Helm, and make. Individual parts also have their own setup scripts (`p1/setup-host.sh`, `p3/setup_host.sh`, `bonus/setup_host.sh`) for isolated use, but the root script is the recommended single entrypoint.

---

## Part 1 — Two VMs, one cluster

**→ [p1/](p1/) · [README](p1/README.md)**

### What it does

Part 1 creates a two-node Kubernetes cluster using **virtual machines**. Each VM is defined in [p1/Vagrantfile](p1/Vagrantfile) and provisioned automatically by Vagrant using the **libvirt** provider, which drives QEMU/KVM on the host.

There are two machines:

- **`urosbyS`** (`192.168.56.110`) acts as the **K3s server** — the Kubernetes control plane. Its provisioning script ([p1/scripts/server.sh](p1/scripts/server.sh)) installs K3s in server mode, then writes the cluster join token and the kubeconfig file into the shared `/vagrant/confs/` directory so the worker can read them.

- **`urosbySW`** (`192.168.56.111`) acts as the **K3s agent** (worker node). Its provisioning script ([p1/scripts/worker.sh](p1/scripts/worker.sh)) waits for the token file to appear in the shared folder, then waits for the server's API port (6443) to become reachable, and finally installs K3s in agent mode using the token and server URL. This sequencing ensures the worker never tries to join before the server is ready.

### Key concepts

**Vagrant** is a tool for defining and managing virtual machines via a declarative `Vagrantfile`. Here it uses the **vagrant-libvirt** plugin to talk to `libvirtd` (the Linux virtualisation daemon), which in turn runs the VMs through QEMU/KVM.

**K3s** is a lightweight, production-grade Kubernetes distribution. It runs as a single binary — `k3s server` on the control plane and `k3s agent` on each worker node. The two nodes communicate over the private network (`192.168.56.x`) that Vagrant creates.

VM names, IPs, resource sizes, and script paths are all driven from [p1/confs/config.yaml](p1/confs/config.yaml), which the Vagrantfile reads at startup. This makes the setup data-driven rather than hard-coded.

---

## Part 2 — One VM, three apps, hostname-based routing

**→ [p2/](p2/) · [README](p2/README.md)**

### What it does

Part 2 uses a **single VM** (`urosbyS`, `192.168.56.110`) running K3s. On top of the cluster, it deploys three web applications and a **Traefik Ingress** that routes HTTP requests to the correct app based on the `Host` header of the request.

- `app1.com` → App 1
- `app2.com` → App 2
- any other hostname → App 3 (the default catch-all)

The VM is defined in [p2/Vagrantfile](p2/Vagrantfile). Its provisioning script, [p2/scripts/setup.sh](p2/scripts/setup.sh), installs K3s (which includes **Traefik** as the built-in ingress controller), waits for Traefik to be fully ready and its port 80 to be reachable, then applies all the Kubernetes manifests from the `confs/` folder.

### Key concepts

Each application is defined by a **Kubernetes manifest** ([app1.yaml](p2/confs/app1.yaml), [app2.yaml](p2/confs/app2.yaml), [app3.yaml](p2/confs/app3.yaml)) containing three resources:
- a **Deployment** (describes the pod: which container image to run, how many replicas),
- a **Service** (gives the pod a stable internal name and port),
- a **ConfigMap** (holds the HTML content served by the nginx container).

The routing rules are in [p2/confs/ingress.yaml](p2/confs/ingress.yaml). This is a Kubernetes **Ingress** object — a set of rules that tells Traefik which Service to forward traffic to, depending on the `Host` header it receives. App 3 has no host rule, making it the default backend for any request that doesn't match `app1.com` or `app2.com`.

For the host machine to resolve `app1.com` etc., the Makefile automatically adds a line to `/etc/hosts` mapping those three hostnames to the VM's IP.

---

## Part 3 — K3d cluster + ArgoCD + GitOps from GitHub

**→ [p3/](p3/) · [README](p3/README.md)**

### What it does

Part 3 moves away from virtual machines entirely. The Kubernetes cluster runs **inside Docker containers** on the host, using **K3d** — a tool that wraps K3s nodes in Docker containers so you get a full cluster without needing to spin up VMs. The cluster is created by [p3/scripts/create_cluster.sh](p3/scripts/create_cluster.sh).

On top of this cluster, **ArgoCD** is installed ([p3/scripts/install_argocd.sh](p3/scripts/install_argocd.sh)). ArgoCD is a **GitOps controller** — it continuously watches a Git repository and ensures that whatever Kubernetes manifests are in that repository are exactly what's deployed in the cluster. If the repository changes, ArgoCD reconciles the cluster to match.

The application manifest that ArgoCD watches is [p3/confs/app/deployment.yaml](p3/confs/app/deployment.yaml). The ArgoCD Application object that points to the GitHub repository is defined in [p3/confs/application.yaml](p3/confs/application.yaml). When a new image version is pushed to GitHub (e.g. changing `v1` to `v2` in `deployment.yaml`), ArgoCD detects the diff and rolls out the new version automatically.

### Key concepts

**K3d** creates a Kubernetes cluster as Docker containers on the host, so no VMs or extra hardware are needed. The cluster exists entirely within Docker's network.

**ArgoCD** operates on the *GitOps* principle: the Git repository is the single source of truth for the desired state of the cluster. ArgoCD polls the repo and applies any changes — no manual `kubectl apply` needed after the initial setup.

---

## Bonus — K3d cluster + ArgoCD + local GitLab

**→ [bonus/](bonus/) · [README](bonus/README.md)**

### What it does

The bonus part extends Part 3 by replacing GitHub with a **self-hosted GitLab** instance running inside the same K3d cluster. This makes the entire pipeline self-contained — no external services required.

GitLab is installed via its official **Helm chart** ([bonus/scripts/install_gitlab.sh](bonus/scripts/install_gitlab.sh)). After GitLab is up, a script ([bonus/scripts/configure_gitlab.sh](bonus/scripts/configure_gitlab.sh)) creates a repository inside GitLab, generates an access token, and pushes the application's deployment manifest to it. Then another script ([bonus/scripts/configure_argocd.sh](bonus/scripts/configure_argocd.sh)) adds GitLab as a private repository source in ArgoCD and deploys the Application object pointing to it.

From that point on, the flow is identical to Part 3: editing `deployment.yaml` in the local GitLab repository (via the UI or API) triggers ArgoCD to roll out the new version in the `dev` namespace.

### Key concepts

**Helm** is the Kubernetes package manager. It installs complex applications (like GitLab, which consists of dozens of pods and services) from a single parameterised chart, rather than requiring you to write all the individual manifests by hand.

Everything runs inside the single K3d cluster: the GitLab server, ArgoCD, and the deployed application all live as pods in different namespaces (`gitlab`, `argocd`, `dev`). Port-forwarding from the host exposes each service on `localhost` for browser and API access.
