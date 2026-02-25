# Bonus: K3d + ArgoCD + GitLab

K3d cluster with ArgoCD syncing from a **local GitLab** instance (no GitHub dependency).

## Prerequisites

Ubuntu 22.04 LTS. Run once before anything else:

```bash
./setup_host.sh    # installs Docker, kubectl, k3d, helm
```

If Docker was just installed, log out and back in before continuing.

## Full Setup

```bash
make all-in-one
```

Runs in sequence: cluster → ArgoCD → GitLab → configure GitLab → configure ArgoCD → port-forward.

## Step-by-step (if something fails mid-way)

```bash
make cluster            # create k3d cluster
make argocd             # install ArgoCD
make gitlab             # install GitLab via Helm (~30min on first run, images are large)
make configure-gitlab   # create repo in GitLab, push deployment.yaml
make configure-argocd   # point ArgoCD to local GitLab
make port-forward       # forward ports to localhost
```

## Access

| Service     | URL                      | Credentials              |
|-------------|--------------------------|--------------------------|
| ArgoCD      | http://localhost:9090    | `make argocd-password`   |
| GitLab      | http://localhost:8181    | `make gitlab-password`   |
| Application | http://localhost:9091    | —                        |

## Update application version (v1 → v2)

### Option A — GitLab UI (simplest)

1. Open http://localhost:8181 (run `make port-forward` first if needed)
2. Log in: `make gitlab-password` for credentials
3. Go to **root / iot-playground** → `deployment.yaml` → edit (pencil icon)
4. Change `wil42/playground:v1` to `wil42/playground:v2`
5. Click **Commit changes**
6. ArgoCD syncs automatically within ~3 minutes
7. Verify: `curl http://localhost:9091` — response shows v2

### Option B — API (scriptable)

```bash
TOKEN=$(cat /tmp/gitlab-token)

CONTENT=$(sed 's/playground:v1/playground:v2/' confs/app/deployment.yaml | base64 -w0)

curl -s -X PUT \
  -H "PRIVATE-TOKEN: $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"branch\":\"main\",\"commit_message\":\"v2\",\"encoding\":\"base64\",\"content\":\"$CONTENT\"}" \
  "http://localhost:8181/api/v4/projects/1/repository/files/deployment.yaml"
```

Then watch ArgoCD sync:
```bash
kubectl get pods -n dev -w
# pod will restart with new image
curl http://localhost:9091   # should return v2
```

### Roll back to v1

Same steps — replace `v2` with `v1` in the edit.

## Commands

```bash
make all-in-one        # full setup
make gitlab            # install GitLab only
make configure-gitlab  # create GitLab repo and push deployment
make configure-argocd  # connect ArgoCD to GitLab
make port-forward      # forward all ports
make argocd-password   # get ArgoCD admin password
make gitlab-password   # get GitLab root password
make status            # show all pod status
make destroy           # delete cluster
```
