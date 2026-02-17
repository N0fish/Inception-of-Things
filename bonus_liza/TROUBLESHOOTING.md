# Bonus Part - Quick Troubleshooting Guide

## Quick Status Check

```bash
make gitlab-status    # Detailed GitLab health check
make status           # Overall cluster status
```

## Common Issues & Solutions

### 1. Migrations Job Failed ❌

**Symptoms:**
- Webservice pods in `Init:CrashLoopBackOff`
- Sidekiq pods in `Init:CrashLoopBackOff`
- Migrations job shows `Failed` or `Error`

**Check:**
```bash
kubectl get jobs -n gitlab
kubectl logs -l app=migrations -n gitlab --tail=100
```

**Solution:**
```bash
# Clean slate approach
make destroy
make cluster
make argocd
make gitlab

# OR if you want to retry migrations only
kubectl delete job -l app=migrations -n gitlab
helm upgrade gitlab gitlab/gitlab --namespace gitlab --reuse-values
```

### 2. GitLab Pods Not Starting ⏳

**Symptoms:**
- Pods stuck in `Pending` or `ContainerCreating`
- Pods in `CrashLoopBackOff`

**Check order of startup:**
1. PostgreSQL (must be Running first)
2. Redis (must be Running second)
3. Migrations (job must Complete)
4. Then: Webservice, Sidekiq, Toolbox, Gitaly

**Check specific pod:**
```bash
kubectl describe pod <pod-name> -n gitlab
kubectl logs <pod-name> -n gitlab
```

**For init containers:**
```bash
kubectl logs <pod-name> -n gitlab -c <init-container-name>
kubectl logs -l app=webservice -n gitlab -c dependencies
```

### 3. Insufficient Resources 💾

**Symptoms:**
- Pods stuck in `Pending`
- Node resource warnings
- Very slow startup

**Check resources:**
```bash
kubectl top nodes
kubectl describe nodes
```

**Minimum requirements:**
- CPU: 4 cores
- RAM: 8GB
- Disk: 20GB free

**Solution:** Upgrade your VM or host machine resources.

### 4. Helm Chart Issues 📦

**Current version:** 8.8.0 (stable)

**Why not 9.x?**
- Requires PostgreSQL 16
- Breaking changes in cert-manager
- Migration issues

**Check installed version:**
```bash
helm list -n gitlab
```

**Reinstall specific version:**
```bash
helm uninstall gitlab -n gitlab
helm install gitlab gitlab/gitlab --version 8.8.0 --namespace gitlab [options]
```

### 5. Port Forward Not Working 🔌

**Symptoms:**
- Can't access GitLab at localhost:8181
- Connection refused

**Check:**
```bash
# See if port-forward is running
ps aux | grep "kubectl port-forward"

# Check if service exists
kubectl get svc -n gitlab
```

**Solution:**
```bash
make stop-port-forward
make port-forward
```

**Manual port forward:**
```bash
kubectl port-forward svc/gitlab-webservice-default -n gitlab 8181:8181
```

### 6. ArgoCD Can't Connect to GitLab 🔗

**Symptoms:**
- Application shows "Unknown" or "Error" status
- "Repository not reachable" error

**Check:**
```bash
# Verify credentials exist
kubectl get secret gitlab-repo-creds -n argocd

# Check ArgoCD application
kubectl describe application wil-playground-app -n argocd

# Check if GitLab service is reachable from ArgoCD
kubectl run curl-test -n argocd --image=curlimages/curl -i --rm --restart=Never -- \
  curl -v http://gitlab-webservice-default.gitlab.svc.cluster.local:8181
```

**Solution:**
```bash
# Reconfigure repository credentials
make gitlab-config
```

### 7. Application Not Deploying 🚫

**Symptoms:**
- App stuck in "Progressing" or "Unknown"
- Pods not created in `dev` namespace

**Check:**
```bash
# ArgoCD application status
kubectl get application -n argocd
kubectl describe application wil-playground-app -n argocd

# Check if namespace exists
kubectl get namespace dev

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

**Solution:**
```bash
# Force sync
kubectl patch application wil-playground-app -n argocd --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'

# OR delete and recreate
kubectl delete application wil-playground-app -n argocd
make app
```

## Diagnostic Commands

### Quick Health Check
```bash
# All namespaces
kubectl get pods --all-namespaces | grep -v Running

# GitLab specific
kubectl get pods -n gitlab
kubectl get jobs -n gitlab
kubectl get svc -n gitlab

# ArgoCD
kubectl get application -n argocd
kubectl get pods -n argocd

# Application
kubectl get pods -n dev
```

### Detailed Logs
```bash
# GitLab migrations (most critical)
kubectl logs -l app=migrations -n gitlab

# GitLab webservice
kubectl logs -l app=webservice -n gitlab -c webservice
kubectl logs -l app=webservice -n gitlab -c dependencies

# ArgoCD application controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Your application
kubectl logs -n dev -l app=wil-playground
```

### Resource Usage
```bash
# Node resources
kubectl top nodes

# Pod resources by namespace
kubectl top pods -n gitlab
kubectl top pods -n argocd
kubectl top pods -n dev
```

## Reset Everything

If all else fails:
```bash
# Nuclear option - start fresh
make destroy
make all-in-one
```

## Getting Help

1. Check this file first
2. Run `make gitlab-status`
3. Check pod logs for specific errors
4. Verify resource requirements are met
5. Consider reducing GitLab components if resources are limited

## Timeline Expectations

**Normal installation:**
- Cluster: 30 seconds
- ArgoCD: 2-3 minutes
- GitLab: 10-15 minutes
- Application: 1-2 minutes

**Total:** ~20 minutes for `make all-in-one`

If it's taking significantly longer, check logs and resources.
