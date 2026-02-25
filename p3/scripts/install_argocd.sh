#!/bin/bash

set -e

echo "==> Installing ArgoCD..."

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo "==> Applying ArgoCD manifests..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml

echo "==> Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=600s

echo "==> Configuring ArgoCD for HTTP access..."
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}'

echo "==> Restarting ArgoCD server..."
kubectl rollout restart deployment/argocd-server -n argocd
kubectl rollout status deployment/argocd-server -n argocd --timeout=180s

echo "==> Retrieving ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "==> ArgoCD installed successfully!"
echo ""
echo "====================================="
echo "ArgoCD Access Information"
echo "====================================="
echo "URL: http://localhost:9090"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
echo "====================================="
echo ""
echo "Save this password! You can also retrieve it later with:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""

echo "==> Setting up port forwarding for ArgoCD..."
echo "You can access ArgoCD at: http://localhost:8080"
echo ""
echo "To forward ports manually, run:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
