#!/usr/bin/env bash
#
# Testing Script for Inception-of-Things Part 2
#

set -euo pipefail

# Always run from the directory where this script lives
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Config (adjust if you change these)
LOGIN="urosby"
SERVER_NAME="${LOGIN}S"
SERVER_IP="192.168.56.110"
HOSTS_MARKER="IOT_P2_APPS"
HOSTS_LINE="192.168.56.110 app1.com app2.com app3.com"

TOTAL=0
PASS=0
FAIL=0

header() {
  echo ""
  echo -e "${BLUE}=========================================="
  echo -e "$1"
  echo -e "==========================================${NC}"
  echo ""
}

testcase() {
  echo -e "${YELLOW}[TEST]${NC} $1"
  TOTAL=$((TOTAL + 1))
}

ok() {
  echo -e "${GREEN}[PASS]${NC} $1"
  PASS=$((PASS + 1))
}

bad() {
  echo -e "${RED}[FAIL]${NC} $1"
  FAIL=$((FAIL + 1))
}

# Helper to run a command and mark pass/fail
run() {
  local name="$1"
  shift
  testcase "$name"
  if "$@" >/dev/null 2>&1; then
    ok "$name"
    return 0
  else
    bad "$name"
    return 1
  fi
}

header "INCEPTION-OF-THINGS PART 2 - TESTS"

header "1) FILES PRESENT"
run "Vagrantfile exists" test -f ./Vagrantfile
run "setup.sh exists" test -f ./scripts/setup.sh
run "confs folder exists" test -d ./confs
run "app1.yaml exists" test -f ./confs/app1.yaml
run "app2.yaml exists" test -f ./confs/app2.yaml
run "app3.yaml exists" test -f ./confs/app3.yaml
run "ingress.yaml exists" test -f ./confs/ingress.yaml

header "2) VM STATUS"
testcase "VM is running"
if vagrant status | grep -q "running"; then
  ok "VM is running"
else
  bad "VM is not running (run: make up)"
fi

header "3) SERVER CHECKS"
run "SSH works" vagrant ssh "${SERVER_NAME}" -c "exit"

testcase "Server IP on eth1 is ${SERVER_IP}"
IP_ACTUAL="$(vagrant ssh "${SERVER_NAME}" -c "ip -4 a show eth1 | awk '/inet /{print \$2}' | cut -d/ -f1" 2>/dev/null | tr -d '\r')"
if [[ "${IP_ACTUAL}" == "${SERVER_IP}" ]]; then
  ok "Server IP is ${IP_ACTUAL}"
else
  bad "Server IP mismatch. Expected ${SERVER_IP}, got '${IP_ACTUAL}'"
fi

run "k3s service active" vagrant ssh "${SERVER_NAME}" -c "sudo systemctl is-active --quiet k3s"
run "kubectl works" vagrant ssh "${SERVER_NAME}" -c "kubectl get nodes >/dev/null"

testcase "Server node is Ready"
if vagrant ssh "${SERVER_NAME}" -c "kubectl get nodes --no-headers | awk '{print \$2}' | grep -q Ready"; then
  ok "Node is Ready"
else
  bad "Node not Ready"
fi

header "4) K8S OBJECTS (APPS + INGRESS)"
run "Deployments exist (app1/app2/app3)" vagrant ssh "${SERVER_NAME}" -c "kubectl get deploy -n default | awk 'NR>1{print \$1}' | grep -E 'app1|app2|app3' >/dev/null"
run "Ingress exists (default namespace)" vagrant ssh "${SERVER_NAME}" -c "kubectl get ingress -n default >/dev/null"

header "5) HOSTNAME RESOLUTION (HOST MACHINE)"
testcase "/etc/hosts has ${HOSTS_MARKER} entry"
if grep -q "${HOSTS_MARKER}" /etc/hosts 2>/dev/null; then
  ok "/etc/hosts marker found"
else
  bad "/etc/hosts missing marker '${HOSTS_MARKER}' (run: make update-hosts)"
fi

# Use getent (system resolver) to verify hostnames map to expected IP
for h in app1.com app2.com app3.com; do
  testcase "Host resolves ${h} -> ${SERVER_IP}"
  RES="$(getent hosts "${h}" 2>/dev/null | awk '{print $1}' | head -n1 || true)"
  if [[ "${RES}" == "${SERVER_IP}" ]]; then
    ok "${h} resolves correctly"
  else
    bad "${h} resolves to '${RES}' (expected ${SERVER_IP})"
  fi
done

header "6) HTTP CHECKS FROM HOST"
# We don't assume response body strings, just HTTP 200.
for h in app1.com app2.com app3.com; do
  testcase "HTTP 200 for Host: ${h}"
  CODE="$(curl -s -o /dev/null -w "%{http_code}" -H "Host: ${h}" "http://${SERVER_IP}/" || true)"
  if [[ "${CODE}" == "200" ]]; then
    ok "HTTP 200 for ${h}"
  else
    bad "Expected 200 for ${h}, got ${CODE}"
  fi
done

header "RESULTS"
echo "Total:  ${TOTAL}"
echo -e "${GREEN}Pass:   ${PASS}${NC}"
echo -e "${RED}Fail:   ${FAIL}${NC}"
echo ""

if [[ "${FAIL}" -eq 0 ]]; then
  echo -e "${GREEN}✓ All p2 tests passed.${NC}"
  exit 0
else
  echo -e "${RED}✗ Some p2 tests failed.${NC}"
  exit 1
fi
