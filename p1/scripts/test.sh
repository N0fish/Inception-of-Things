#!/usr/bin/env bash
set -euo pipefail

# This script lives in p1/scripts/.
# We want paths (./Vagrantfile, ./confs/...) relative to p1/.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOGIN="urosby"
SERVER_NAME="${LOGIN}S"
WORKER_NAME="${LOGIN}SW"
SERVER_IP="192.168.56.110"
WORKER_IP="192.168.56.111"

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

print_header() {
    echo ""
    echo -e "${BLUE}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
    echo ""
}

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

run_test() {
    local test_name="$1"
    local command="$2"

    print_test "$test_name"

    if eval "$command" > /dev/null 2>&1; then
        print_pass "$test_name"
        return 0
    else
        print_fail "$test_name"
        return 1
    fi
}

print_header "INCEPTION-OF-THINGS PART 1 - EVALUATION TESTS"

print_header "1. PRELIMINARY CHECKS"

print_test "Check if Vagrantfile exists in p1 folder"
if [ -f "./Vagrantfile" ]; then
    print_pass "Vagrantfile exists"
else
    print_fail "Vagrantfile not found in ${PROJECT_DIR}"
    exit 1
fi

print_test "Check VMs are running"
if vagrant status | grep -q "running"; then
    print_pass "VMs are running"
else
    print_fail "VMs are not running. Please run 'make up' first"
    exit 1
fi

print_header "2. CONFIGURATION VERIFICATION"

print_info "Checking configuration in confs/config.yaml (Vagrantfile is dynamic)..."
echo ""

print_test "config.yaml exists"
if [ -f "confs/config.yaml" ]; then
    print_pass "confs/config.yaml exists"
else
    print_fail "confs/config.yaml not found"
fi

print_test "Login is correct in config.yaml"
if grep -qE "^login:\s*${LOGIN}\b" confs/config.yaml; then
    print_pass "login: ${LOGIN}"
else
    print_fail "login is not ${LOGIN} in confs/config.yaml"
fi

print_test "VM names are configured in config.yaml"
if grep -qE "name:\s*S\b" confs/config.yaml && grep -qE "name:\s*SW\b" confs/config.yaml; then
    print_pass "VM names S and SW are present"
else
    print_fail "VM names S/SW not found in confs/config.yaml"
fi

print_test "IP addresses are configured in config.yaml"
if grep -qE "ip:\s*192\.168\.56\.110\b" confs/config.yaml && grep -qE "ip:\s*192\.168\.56\.111\b" confs/config.yaml; then
    print_pass "IP addresses 192.168.56.110 and 192.168.56.111 are present"
else
    print_fail "IP addresses not found/mismatched in confs/config.yaml"
fi

print_header "3. SERVER VM (${SERVER_NAME}) TESTS"

print_test "SSH connection to server"
if vagrant ssh "${SERVER_NAME}" -c "exit" > /dev/null 2>&1; then
    print_pass "SSH connection successful"
else
    print_fail "Cannot SSH to server"
fi

print_test "Server hostname"
HOSTNAME=$(vagrant ssh "${SERVER_NAME}" -c "hostname" 2>/dev/null | tr -d '\r')
if [ "$HOSTNAME" = "${SERVER_NAME}" ]; then
    print_pass "Hostname is correct: $HOSTNAME"
else
    print_fail "Hostname is incorrect. Expected: ${SERVER_NAME}, Got: $HOSTNAME"
fi

print_test "Server IP address on eth1"
SERVER_IP_ACTUAL=$(vagrant ssh "${SERVER_NAME}" -c "ip a show eth1 2>/dev/null | grep 'inet ' | awk '{print \$2}' | cut -d'/' -f1" 2>/dev/null | tr -d '\r')
if [ "$SERVER_IP_ACTUAL" = "$SERVER_IP" ]; then
    print_pass "Server IP is correct: $SERVER_IP_ACTUAL"
else
    print_fail "Server IP is incorrect. Expected: $SERVER_IP, Got: $SERVER_IP_ACTUAL"
fi

print_test "K3s is installed on server"
if vagrant ssh "${SERVER_NAME}" -c "which k3s" > /dev/null 2>&1; then
    print_pass "K3s is installed"
else
    print_fail "K3s is not installed"
fi

print_test "kubectl is available on server"
if vagrant ssh "${SERVER_NAME}" -c "which kubectl" > /dev/null 2>&1; then
    print_pass "kubectl is available"
else
    print_fail "kubectl is not available"
fi

print_test "K3s server is running"
if vagrant ssh "${SERVER_NAME}" -c "sudo systemctl is-active k3s" > /dev/null 2>&1; then
    print_pass "K3s server is running"
else
    print_fail "K3s server is not running"
fi

print_header "4. WORKER VM (${WORKER_NAME}) TESTS"

print_test "SSH connection to worker"
if vagrant ssh "${WORKER_NAME}" -c "exit" > /dev/null 2>&1; then
    print_pass "SSH connection successful"
else
    print_fail "Cannot SSH to worker"
fi

print_test "Worker hostname"
HOSTNAME=$(vagrant ssh "${WORKER_NAME}" -c "hostname" 2>/dev/null | tr -d '\r')
if [ "$HOSTNAME" = "${WORKER_NAME}" ]; then
    print_pass "Hostname is correct: $HOSTNAME"
else
    print_fail "Hostname is incorrect. Expected: ${WORKER_NAME}, Got: $HOSTNAME"
fi

print_test "Worker IP address on eth1"
WORKER_IP_ACTUAL=$(vagrant ssh "${WORKER_NAME}" -c "ip a show eth1 2>/dev/null | grep 'inet ' | awk '{print \$2}' | cut -d'/' -f1" 2>/dev/null | tr -d '\r')
if [ "$WORKER_IP_ACTUAL" = "$WORKER_IP" ]; then
    print_pass "Worker IP is correct: $WORKER_IP_ACTUAL"
else
    print_fail "Worker IP is incorrect. Expected: $WORKER_IP, Got: $WORKER_IP_ACTUAL"
fi

print_test "K3s agent is installed on worker"
if vagrant ssh "${WORKER_NAME}" -c "which k3s" > /dev/null 2>&1; then
    print_pass "K3s is installed"
else
    print_fail "K3s is not installed"
fi

print_test "K3s agent is running"
if vagrant ssh "${WORKER_NAME}" -c "sudo systemctl is-active k3s-agent" > /dev/null 2>&1; then
    print_pass "K3s agent is running"
else
    print_fail "K3s agent is not running"
fi

print_header "5. CLUSTER INFORMATION (for evaluation)"

print_info "Running: kubectl get nodes -o wide"
echo ""
vagrant ssh "${SERVER_NAME}" -c "kubectl get nodes -o wide" 2>/dev/null || true

echo ""
print_info "Running: kubectl get pods -A"
echo ""
vagrant ssh "${SERVER_NAME}" -c "kubectl get pods -A" 2>/dev/null || true

print_header "TEST RESULTS SUMMARY"

echo -e "Total tests:  ${TOTAL_TESTS}"
echo -e "${GREEN}Passed:       ${PASSED_TESTS}${NC}"
echo -e "${RED}Failed:       ${FAILED_TESTS}${NC}"
echo ""

if [ "${FAILED_TESTS}" -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! Your setup is correct.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please review the output above.${NC}"
    exit 1
fi