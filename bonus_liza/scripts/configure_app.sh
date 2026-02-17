#!/bin/bash

set -e

echo "==> Configuring ArgoCD application with GitLab..."

# Create dev namespace
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

# Configure ArgoCD to connect to GitLab
echo "==> Adding GitLab repository to ArgoCD..."

GITLAB_URL="http://gitlab.gitlab.svc.cluster.local/root/iot-playground.git"
# Note: Token will be dynamically set during gitlab-config step
GITLAB_TOKEN="${GITLAB_TOKEN:-iot-argocd-access-token}"

# Create a secret for GitLab credentials
kubectl create secret generic gitlab-repo-creds \
  --namespace argocd \
  --from-literal=username=root \
  --from-literal=password=$GITLAB_TOKEN \
  --dry-run=client -o yaml | kubectl apply -f -

# Label the secret so ArgoCD recognizes it as repository credentials
kubectl label secret gitlab-repo-creds \
  --namespace argocd \
  argocd.argoproj.io/secret-type=repository \
  --overwrite

# Add repository credentials annotation
kubectl annotate secret gitlab-repo-creds \
  --namespace argocd \
  managed-by=argocd.argoproj.io \
  --overwrite

# Patch the secret to add repository URL
kubectl patch secret gitlab-repo-creds -n argocd --type merge -p "{\"stringData\":{\"url\":\"$GITLAB_URL\",\"username\":\"root\",\"password\":\"$GITLAB_TOKEN\"}}"

echo "==> Repository credentials configured"

# Apply the ArgoCD application pointing to GitLab
echo "==> Applying ArgoCD application configuration..."
kubectl apply -f confs/application-gitlab.yaml

echo "==> Waiting for application to sync..."
sleep 15

# Wait for pods
echo "==> Waiting for application pods to be ready..."
kubectl wait --for=condition=Ready pods -l app=wil-playground -n dev --timeout=180s 2>/dev/null || echo "Pods may still be starting..."

echo ""
echo "==> Application Status:"
kubectl get applications -n argocd

echo ""
echo "==> Pods:"
kubectl get pods -n dev

echo ""
echo "==> Services:"
kubectl get svc -n dev

echo ""
echo "==> ArgoCD Application Details:"
kubectl describe application wil-playground-app -n argocd | grep -A 10 "^Status:" || echo "Application syncing..."

echo ""
echo "✓ Application configured to use local GitLab repository"
echo ""
