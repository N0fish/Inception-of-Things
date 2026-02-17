#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-iot-bonus}"
ARGO_NS="argocd"
GITLAB_NS="gitlab"

VALUES_FILE="bonus/confs/gitlab-values.yaml"

log() { echo "[bootstrap] $*"; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

for c in docker kubectl k3d helm; do
  if ! need_cmd "$c"; then
    echo "[bootstrap] Missing dependency: $c"
    echo "[bootstrap] Run: sudo bonus/scripts/install-tools.sh"
    exit 1
  fi
done

log "Creating k3d cluster '${CLUSTER_NAME}' (if not exists)..."
if k3d cluster list | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"; then
  log "Cluster already exists."
else
  # Expose port 8888 -> k3d loadbalancer:80 (handy for your app from p3)
  k3d cluster create "${CLUSTER_NAME}" --agents 1 --port "8888:80@loadbalancer"
fi

log "Creating namespaces..."
kubectl create namespace "${ARGO_NS}" 2>/dev/null || true
kubectl create namespace "${GITLAB_NS}" 2>/dev/null || true

# -------------------------
# Argo CD
# -------------------------
log "Installing Argo CD into ${ARGO_NS}..."
kubectl apply --server-side -n "${ARGO_NS}" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yam

log "Waiting for argocd-server deployment..."
kubectl -n "${ARGO_NS}" wait --for=condition=available deploy/argocd-server --timeout=300s

# -------------------------
# GitLab (official chart)
# -------------------------
if [[ ! -f "${VALUES_FILE}" ]]; then
  echo "[bootstrap] Missing ${VALUES_FILE}"
  exit 1
fi

log "Adding GitLab helm repo..."
helm repo add gitlab https://charts.gitlab.io >/dev/null 2>&1 || true
helm repo update >/dev/null

log "Installing GitLab into ${GITLAB_NS} (this can take several minutes)..."
helm upgrade --install gitlab gitlab/gitlab \
  -n "${GITLAB_NS}" \
  -f "${VALUES_FILE}"

log "Waiting for GitLab webservice deployment..."
# Depending on chart version, deployment names can vary slightly.
# We'll wait for *any* webservice deployment to become available.
WEB_DEPLOY="$(kubectl -n "${GITLAB_NS}" get deploy -o name | grep -E 'webservice' | head -n 1 || true)"
if [[ -z "${WEB_DEPLOY}" ]]; then
  log "Could not find webservice deployment yet. Showing deployments:"
  kubectl -n "${GITLAB_NS}" get deploy || true
  log "Waiting up to 10 minutes for deployments to appear..."
  for i in $(seq 1 600); do
    WEB_DEPLOY="$(kubectl -n "${GITLAB_NS}" get deploy -o name | grep -E 'webservice' | head -n 1 || true)"
    [[ -n "${WEB_DEPLOY}" ]] && break
    sleep 1
  done
fi

if [[ -z "${WEB_DEPLOY}" ]]; then
  echo "[bootstrap] ERROR: GitLab webservice deployment never appeared."
  kubectl -n "${GITLAB_NS}" get all || true
  exit 1
fi

kubectl -n "${GITLAB_NS}" wait --for=condition=available "${WEB_DEPLOY}" --timeout=900s

log "Done."
echo ""
echo "================= ACCESS ================="
echo "GitLab is installed in namespace: ${GITLAB_NS}"
echo ""
echo "Get the initial root password:"
echo "  kubectl -n ${GITLAB_NS} get secret gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' | base64 -d; echo"
echo ""
echo "Port-forward GitLab web UI to localhost:8080 (run in a separate terminal):"
echo "  kubectl -n ${GITLAB_NS} port-forward svc/gitlab-webservice-default 8080:8181"
echo ""
echo "Then open:"
echo "  http://localhost:8080"
echo ""
echo "Argo CD UI (optional):"
echo "  kubectl -n ${ARGO_NS} port-forward svc/argocd-server 8081:80"
echo "  http://localhost:8081"
echo "=========================================="
