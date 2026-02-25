#!/bin/bash

set -e

echo "==> Configuring ArgoCD application..."

kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f confs/application.yaml

echo "==> Waiting for application to sync..."
sleep 10

kubectl wait --for=condition=Ready pods -l app=wil-playground -n dev --timeout=120s 2>/dev/null || echo "Waiting for pods to be ready..."

echo ""
echo "==> Application Status:"
kubectl get applications -n argocd

echo ""
echo "==> Pods:"
kubectl get pods -n dev

echo ""
echo "==> Services:"
kubectl get svc -n dev
