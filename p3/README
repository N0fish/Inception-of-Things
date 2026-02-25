# Part 3: K3d and ArgoCD

K3d cluster with ArgoCD for GitOps deployment from GitHub.

## Setup

### Prerequisites
Runs on host machine (Ubuntu 22.04 LTS). Dependencies installed via `setup_host.sh`.

### Installation

```bash
make all-in-one    # Installs Docker, kubectl, K3d, creates cluster, installs ArgoCD
```

**If Docker was just installed, log out and log back in.**

### Deploy Application

**Before deploying:**
1. Create public GitHub repository (name must include your login)
2. Add `confs/app/deployment.yaml` to your repo
3. Update `repoURL` in `confs/application.yaml` with your repo URL

```bash
make app           # Deploy application via ArgoCD
make test          # Run automated tests
```

## Access

### ArgoCD UI
```bash
make port-forward      # Terminal 1
make argocd-password   # Get password
# Open: http://localhost:9090
```

### Application
```bash
# With port-forward running:
curl http://localhost:9091
```

## Version Update Test

1. Edit image in your GitHub repo: `v1` → `v2`
2. Commit and push
3. ArgoCD syncs automatically
4. Test: `curl http://localhost:9091` (returns v2)

## Commands

```bash
make all-in-one      # Setup everything
make app             # Deploy application
make test            # Run tests
make port-forward    # Port forward services
make argocd-password # Get ArgoCD password
make status          # Check status
make destroy         # Clean up
```

## Tests

Verifies: cluster, nodes, namespaces, ArgoCD, application deployment, response.
