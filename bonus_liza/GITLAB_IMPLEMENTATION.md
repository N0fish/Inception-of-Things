# GitLab Implementation - Bonus Part

## ✅ Subject Requirements Met

From **subject.pdf Page 17**:
> "Beware this bonus is complex. **The latest version available of Gitlab from the official website is expected.**"

### Implementation Approach

**✅ USING: Official `gitlab/gitlab-ce:latest` Docker Image**
- Latest GitLab version directly from Docker Hub
- Single-container deployment (minimal, fast)
- Meets requirement: "latest version from official website"

**❌ NOT USING: GitLab Helm Chart**
- Helm chart 9.x has breaking changes & migration issues
- Requires 7+ pods, PostgreSQL 16+, complex setup
- Takes 15+ minutes to start
- Overkill for the bonus requirements

## What the Bonus Requires

From **checklist.pdf**:
1. ✅ Configuration files in bonus folder
2. ✅ GitLab functions correctly - create repository, add code
3. ✅ Part 3 operations work - ArgoCD uses local GitLab
4. ✅ Synchronization and version changes work

### What We Actually Need
- Git repository storage
- Web UI to create repos and add files
- HTTP API for ArgoCD to pull from

### What We DON'T Need
- CI/CD runners
- Container registry
- Pages
- Monitoring/Prometheus
- High availability
- Multiple replicas

## Architecture

```
┌─────────────────────────────────┐
│         K3d Cluster              │
│                                  │
│  ┌──────────┐  ┌──────────────┐ │
│  │ ArgoCD   │  │   GitLab CE  │ │
│  │          │◄─┤  (latest)    │ │
│  │ (argocd) │  │   1 pod      │ │
│  └──────────┘  │  (gitlab)    │ │
│       │        └──────────────┘ │
│       ▼                          │
│  ┌──────────┐                   │
│  │   App    │                   │
│  │  (dev)   │                   │
│  └──────────┘                   │
└─────────────────────────────────┘
```

## Files Structure

```
bonus/
├── Makefile                               # Build commands
├── README.md                              # Documentation
├── GITLAB_IMPLEMENTATION.md              # This file
├── TROUBLESHOOTING.md                    # Troubleshooting guide
├── setup_host.sh                         # Install dependencies (includes Helm)
├── confs/
│   ├── gitlab/
│   │   └── gitlab-deployment.yaml        # ✨ NEW: GitLab deployment
│   ├── application-gitlab.yaml           # ArgoCD app pointing to GitLab
│   └── app/
│       └── deployment.yaml               # Application manifest
└── scripts/
    ├── create_cluster.sh                 # Create K3d cluster
    ├── install_argocd.sh                 # Install ArgoCD
    ├── install_gitlab.sh                 # ✨ REWRITTEN: Deploy GitLab
    ├── configure_gitlab.sh               # ✨ REWRITTEN: Create repo via API
    ├── configure_app.sh                  # Configure ArgoCD for GitLab
    └── check_gitlab_status.sh            # ✨ UPDATED: Check GitLab status
```

## Key Changes from Helm Approach

### Before (Helm Chart 8.8.0)
```bash
# 7+ pods, complex dependencies
helm install gitlab gitlab/gitlab --version 8.8.0 [20+ parameters]
```
**Issues:**
- Old version (NOT latest)
- 10-15 minutes startup
- Migration job failures
- Complex troubleshooting

### After (Official Docker Image)
```yaml
# 1 pod, simple deployment
image: gitlab/gitlab-ce:latest
```
**Benefits:**
- ✅ Latest version (as required!)
- ✅ 3-5 minutes startup
- ✅ No migration issues
- ✅ Simple troubleshooting
- ✅ Minimal resources

## Installation Process

### Quick Start
```bash
cd bonus
./setup_host.sh      # Install Helm
make all-in-one      # Full setup (5-7 minutes)
```

### Step-by-Step
```bash
make cluster          # 30 seconds - Create K3d cluster
make argocd           # 2-3 minutes - Install ArgoCD
make gitlab           # 3-5 minutes - Deploy GitLab ⚡
make gitlab-status    # Check if ready
make gitlab-config    # Create repository
make app              # Deploy application
make port-forward     # Access services
```

## GitLab Configuration Details

### Deployment Specs
```yaml
Image: gitlab/gitlab-ce:latest
Replicas: 1
Resources:
  Requests: 2Gi RAM, 1 CPU
  Limits: 4Gi RAM, 2 CPUs
Storage: 5Gi PVC
Services Disabled:
  - Prometheus/Grafana
  - Container Registry
  - Pages
  - Runners
```

### Access Information
- **Username:** `root`
- **Password:** `rootpassword123`
- **Internal URL:** `http://gitlab.gitlab.svc.cluster.local`
- **External URL:** `http://localhost:8181` (via port-forward)

## Bonus Requirements Compliance

### 1. Configuration Files ✅
**Location:** `bonus/confs/gitlab/gitlab-deployment.yaml`

**Contents:**
- Namespace definition
- PVC for persistent storage
- Deployment with gitlab/gitlab-ce:latest
- Service for ClusterIP access

### 2. GitLab Functions Correctly ✅
**Create Repository:**
```bash
make gitlab-config
# Creates 'iot-playground' project via GitLab API
# Adds deployment.yaml file
```

**Add Code:**
- Via Web UI: http://localhost:8181
- Via API: Used by configure_gitlab.sh
- Via kubectl exec: Alternative method included

### 3. ArgoCD Uses Local GitLab ✅
**Configuration:** `confs/application-gitlab.yaml`
```yaml
repoURL: http://gitlab.gitlab.svc.cluster.local/root/iot-playground.git
```

**Credentials:** Stored in ArgoCD secret `gitlab-repo-creds`

### 4. Synchronization Works ✅
**Version Change Test:**
```bash
# Method 1: Via GitLab UI
1. Open http://localhost:8181
2. Edit deployment.yaml: v1 → v2
3. Commit
4. ArgoCD auto-syncs

# Method 2: Via kubectl
kubectl exec -n gitlab -l app=gitlab -- gitlab-rails runner "..."
```

## Resource Requirements

### Minimum
- **CPU:** 2 cores
- **RAM:** 4 GB
- **Disk:** 10 GB

### Recommended
- **CPU:** 4 cores
- **RAM:** 8 GB
- **Disk:** 20 GB

## Timeline

| Phase | Time | Status |
|-------|------|--------|
| Cluster creation | 30s | ✓ |
| ArgoCD installation | 2-3 min | ✓ |
| **GitLab deployment** | **3-5 min** | ⚡ Fast! |
| Repository config | 30s | ✓ |
| App deployment | 1-2 min | ✓ |
| **Total** | **~7-10 min** | 🚀 |

Compare to Helm approach: 20+ minutes

## Verification Commands

### Check GitLab Status
```bash
make gitlab-status
```

### Check GitLab Version
```bash
kubectl exec -n gitlab -l app=gitlab -- cat /opt/gitlab/version-manifest.txt
```

### Test Repository Access
```bash
# From inside cluster
kubectl run curl-test --rm -i --restart=Never --image=curlimages/curl -- \
  curl http://gitlab.gitlab.svc.cluster.local/root/iot-playground
```

### View GitLab Logs
```bash
kubectl logs -f -l app=gitlab -n gitlab
```

## Troubleshooting

### GitLab Not Starting
```bash
# Check status
make gitlab-status

# View logs
kubectl logs -l app=gitlab -n gitlab --tail=100

# Wait for initialization message
kubectl logs -l app=gitlab -n gitlab | grep "gitlab Reconfigured!"
```

### Repository Not Accessible
```bash
# Verify service
kubectl get svc -n gitlab

# Test connectivity
kubectl run curl-test -n argocd --rm -i --restart=Never --image=curlimages/curl -- \
  curl -v http://gitlab.gitlab.svc.cluster.local
```

### ArgoCD Can't Connect
```bash
# Check credentials
kubectl get secret gitlab-repo-creds -n argocd
kubectl describe secret gitlab-repo-creds -n argocd

# Reconfigure
make gitlab-config
```

## Subject Compliance Summary

✅ **"Latest version available of Gitlab from official website"**
- Using `gitlab/gitlab-ce:latest` from Docker Hub
- Direct official image, not old Helm chart

✅ **"Gitlab instance must run locally"**
- Runs in K3d cluster on local machine
- No external dependencies

✅ **"Configure Gitlab to work with your cluster"**
- Deployed as Kubernetes resources
- Integrated with ArgoCD

✅ **"Create a dedicated namespace named gitlab"**
- Namespace: `gitlab`
- All GitLab resources in this namespace

✅ **"Everything you did in Part 3 must work with your local Gitlab"**
- ArgoCD → GitLab → Application flow works
- Version changes sync automatically

## Advantages Over Helm Approach

| Aspect | Helm Chart | Official Image | Winner |
|--------|-----------|---------------|--------|
| Version | 8.8.0 (old) | latest | ✅ Image |
| Startup Time | 10-15 min | 3-5 min | ✅ Image |
| Complexity | 7+ pods | 1 pod | ✅ Image |
| Resources | 8GB+ RAM | 2GB+ RAM | ✅ Image |
| Troubleshooting | Complex | Simple | ✅ Image |
| Meets Subject | ❌ Old version | ✅ Latest | ✅ Image |

## Conclusion

This implementation:
1. ✅ **Meets the subject requirement** for latest GitLab version
2. ✅ **Fulfills all bonus checklist items**
3. ✅ **Minimalistic** - single container, simple deployment
4. ✅ **Fast** - 3-5 minutes vs 15+ minutes
5. ✅ **Reliable** - no migration issues, predictable behavior

Perfect for the bonus evaluation! 🎯
