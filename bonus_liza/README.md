# BONUS: K3d, ArgoCD and GitLab

K3d cluster with ArgoCD for GitOps deployment using a **local GitLab instance**.

## What's Different from Part 3?

This bonus implementation includes everything from Part 3, plus:
- **Local GitLab instance** running in the cluster (in `gitlab` namespace)
- ArgoCD configured to use the **local GitLab repository** instead of GitHub
- Automated GitLab project creation and configuration
- Complete CI/CD workflow with local infrastructure

## Setup

### Prerequisites
Runs on host machine (Ubuntu 22.04 LTS).

**IMPORTANT:** Run the setup script first to install Helm:
```bash
./setup_host.sh
```

If Docker or other tools were just installed, **log out and log back in** before proceeding.

### Installation

The complete setup installs:
1. K3d cluster
2. ArgoCD (in `argocd` namespace)
3. GitLab CE (in `gitlab` namespace)
4. GitLab project with deployment files
5. Application (in `dev` namespace)

```bash
make all-in-one    # Complete setup (takes 10-15 minutes)
```

**Note:** GitLab installation takes 5-10 minutes as it deploys multiple components.

## Manual Step-by-Step Installation

If you prefer to run each step separately:

```bash
make cluster          # Create K3d cluster
make argocd           # Install ArgoCD
make gitlab           # Install GitLab (5-10 minutes)
make gitlab-config    # Configure GitLab repository
make app              # Deploy application via ArgoCD
make port-forward     # Start port forwarding
```

## Access

### Get Credentials
```bash
make argocd-password   # Get ArgoCD password
make gitlab-password   # Get GitLab password
```

### Services

After running `make port-forward`:

| Service | URL | Username | Password |
|---------|-----|----------|----------|
| ArgoCD | http://localhost:9090 | admin | `make argocd-password` |
| GitLab | http://localhost:8181 | root | `make gitlab-password` |
| Application | http://localhost:9091 | - | - |

### Test Application
```bash
curl http://localhost:9091
# Expected: {"status":"ok", "message": "v1"}
```

## Version Update Test (Using Local GitLab)

This demonstrates the complete CI/CD workflow with local GitLab:

### Method 1: Via GitLab UI

1. Port-forward GitLab: `make port-forward`
2. Open: http://localhost:8181
3. Login with root credentials
4. Navigate to: `root/iot-playground` project
5. Edit `deployment.yaml`: change `image: wil42/playground:v1` → `v2`
6. Commit changes
7. ArgoCD auto-syncs (watch in ArgoCD UI)
8. Test: `curl http://localhost:9091` (returns v2)

### Method 2: Via kubectl (Direct Update)

```bash
# Get GitLab toolbox pod
TOOLBOX=$(kubectl get pods -n gitlab -l app=toolbox -o name)

# Update file in GitLab repository
kubectl exec -n gitlab $TOOLBOX -- gitlab-rails runner "
  project = Project.find_by_full_path('root/iot-playground')
  user = User.find_by_username('root')

  file = project.repository.blob_at('main', 'deployment.yaml')
  new_content = file.data.gsub('playground:v1', 'playground:v2')

  Files::UpdateService.new(
    project, user,
    start_branch: 'main',
    branch_name: 'main',
    commit_message: 'Update to v2',
    file_path: 'deployment.yaml',
    file_content: new_content
  ).execute
"

# Wait for ArgoCD to sync
sleep 15

# Test
curl http://localhost:9091
```

## Architecture

```
┌─────────────────────────────────────────┐
│          K3d Cluster                     │
│                                          │
│  ┌──────────┐  ┌──────────┐  ┌────────┐ │
│  │          │  │          │  │        │ │
│  │  ArgoCD  │←─┤  GitLab  │  │  App   │ │
│  │          │  │          │  │  (dev) │ │
│  │ (argocd) │  │ (gitlab) │  │        │ │
│  └──────────┘  └──────────┘  └────────┘ │
│                     ↑                    │
└─────────────────────┼────────────────────┘
                      │
                GitLab CI/CD
              (local repository)
```

## Commands

```bash
make all-in-one        # Complete setup
make cluster           # Create K3d cluster
make argocd            # Install ArgoCD
make gitlab            # Install GitLab
make gitlab-config     # Configure GitLab repo
make app               # Deploy application
make test              # Run automated tests
make port-forward      # Port forward services
make stop-port-forward # Stop port forwarding
make argocd-password   # Get ArgoCD credentials
make gitlab-password   # Get GitLab credentials
make status            # Show cluster status
make destroy           # Delete cluster
```

## Testing

Run comprehensive tests:
```bash
make test
```

Tests verify:
- ✓ K3d cluster exists
- ✓ Nodes are ready
- ✓ Required namespaces (argocd, gitlab, dev)
- ✓ ArgoCD is running
- ✓ GitLab is running
- ✓ Application deployed
- ✓ Application responding
- ✓ GitLab repository credentials configured

## Namespaces

| Namespace | Purpose |
|-----------|---------|
| `argocd` | ArgoCD controllers and UI |
| `gitlab` | GitLab CE instance |
| `dev` | Application deployment |

## Troubleshooting

### Check GitLab Status
First, always check the installation status:
```bash
make gitlab-status
```

### GitLab Migration Job Failed
This is the most critical issue. If migrations fail, webservice and sidekiq won't start.

**Check migrations:**
```bash
kubectl get jobs -n gitlab
kubectl logs -l app=migrations -n gitlab
```

**Common causes:**
- Insufficient resources (need 4+ CPU, 8GB+ RAM)
- Database initialization timeout
- PostgreSQL version mismatch

**Solution:**
```bash
make destroy           # Clean slate
make cluster          # Recreate cluster
make gitlab           # Try again
```

### Pods in CrashLoopBackOff
Usually caused by waiting for migrations to complete.

**Check dependencies:**
```bash
kubectl logs -l app=webservice -n gitlab -c dependencies
```

Wait for migrations job to complete, then pods will automatically recover.

### GitLab taking too long
GitLab Helm chart is resource-intensive. Monitor progress:
```bash
watch kubectl get pods -n gitlab
```

You can continue once webservice and toolbox are Running/Ready.

### ArgoCD can't connect to GitLab
Verify repository credentials:
```bash
kubectl get secret gitlab-repo-creds -n argocd
kubectl describe secret gitlab-repo-creds -n argocd
```

### Application not syncing
Check ArgoCD application status:
```bash
kubectl describe application wil-playground-app -n argocd
```

Force manual sync:
```bash
kubectl patch application wil-playground-app -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"main"}}}'
```

## Resource Requirements

Minimum recommended:
- CPU: 4 cores
- RAM: 8GB
- Disk: 20GB

## Notes

- **GitLab version:** Helm chart 8.8.0 (stable for local development)
- **Why this version?** Chart 9.x has breaking changes and requires PostgreSQL 16+
- GitLab installation uses minimal configuration for local development
- Registry, Pages, and GitLab Runner are disabled to reduce resource usage
- This setup demonstrates the complete GitOps workflow entirely locally
- All data is ephemeral - destroyed with `make destroy`

## GitLab Installation Details

### What Gets Installed

The GitLab Helm chart (v8.8.0) installs these components in the `gitlab` namespace:

| Component | Purpose | Replicas |
|-----------|---------|----------|
| PostgreSQL | Database | 2 |
| Redis | Cache | 2 |
| Gitaly | Git repository storage | 1 |
| Webservice | GitLab web UI & API | 1 |
| Sidekiq | Background jobs | 1 |
| Toolbox | Admin operations | 1 |
| Migrations | Database setup (job) | 1 |

### Installation Timeline

Typical installation sequence:
1. **0-2 min**: PostgreSQL and Redis starting
2. **2-5 min**: Migrations job running (critical!)
3. **5-10 min**: Webservice and other components starting
4. **10-15 min**: All pods fully ready

**Use `make gitlab-status` to monitor progress!**
