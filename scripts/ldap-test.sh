#!/bin/bash
# =============================================================================
# LDAP Connectivity Test Script
# Project: FreeIPA + Snipe-IT LDAP Integration Lab
# =============================================================================
# USAGE:
#   bash ldap-test.sh
#
# This script runs a full suite of connectivity tests from the Docker host
# to the FreeIPA LDAP server, helping diagnose any integration issues.
# =============================================================================

# --- CONFIGURATION ---
FREEIPA_IP="192.168.1.10"
FREEIPA_HOSTNAME="ipa.theonetech.lab"
LDAP_PORT="389"
LDAPS_PORT="636"
BASE_DN="dc=theonetech,dc=lab"
BIND_DN="uid=admin,cn=users,cn=accounts,dc=theonetech,dc=lab"

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0

pass() { echo -e "  ${GREEN}✅ PASS${NC} — $1"; ((PASS++)); }
fail() { echo -e "  ${RED}❌ FAIL${NC} — $1"; ((FAIL++)); }
info() { echo -e "  ${BLUE}ℹ️  INFO${NC} — $1"; }
section() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW} $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

echo ""
echo "=============================================="
echo "  LDAP Connectivity Test Suite"
echo "  FreeIPA + Snipe-IT Lab"
echo "=============================================="
echo "  Target:   $FREEIPA_HOSTNAME ($FREEIPA_IP)"
echo "  Base DN:  $BASE_DN"
echo "  Bind DN:  $BIND_DN"
echo "=============================================="

# ─────────────────────────────────────────
# TEST 1: DNS RESOLUTION
# ─────────────────────────────────────────
section "TEST 1: DNS Resolution"

echo "  Running: getent hosts $FREEIPA_HOSTNAME"
RESOLVED_IP=$(getent hosts "$FREEIPA_HOSTNAME" | awk '{print $1}')

if [ -n "$RESOLVED_IP" ]; then
    pass "Hostname resolved to: $RESOLVED_IP"
    if [ "$RESOLVED_IP" = "$FREEIPA_IP" ]; then
        pass "IP matches expected ($FREEIPA_IP)"
    else
        fail "Resolved IP ($RESOLVED_IP) doesn't match expected ($FREEIPA_IP)"
    fi
else
    fail "Cannot resolve $FREEIPA_HOSTNAME"
    info "Fix: echo '$FREEIPA_IP $FREEIPA_HOSTNAME' >> /etc/hosts"
fi

# ─────────────────────────────────────────
# TEST 2: NETWORK CONNECTIVITY (PING)
# ─────────────────────────────────────────
section "TEST 2: Network Connectivity (Ping)"

echo "  Running: ping -c 2 $FREEIPA_IP"
if ping -c 2 "$FREEIPA_IP" &>/dev/null; then
    pass "Ping to $FREEIPA_IP successful"
else
    fail "Cannot ping $FREEIPA_IP"
    info "Check: VM network, routing, and that both VMs are on same subnet"
fi

# ─────────────────────────────────────────
# TEST 3: LDAP PORT (389)
# ─────────────────────────────────────────
section "TEST 3: LDAP Port 389 Connectivity"

echo "  Running: nc -zv $FREEIPA_IP $LDAP_PORT"
if timeout 5 bash -c "echo >/dev/tcp/$FREEIPA_IP/$LDAP_PORT" 2>/dev/null; then
    pass "Port 389 (LDAP) is REACHABLE on $FREEIPA_IP"
else
    fail "Port 389 (LDAP) is NOT reachable on $FREEIPA_IP"
    info "Fix on FreeIPA server: ufw allow 389/tcp && ipactl status"
fi

# ─────────────────────────────────────────
# TEST 4: LDAPS PORT (636)
# ─────────────────────────────────────────
section "TEST 4: LDAPS Port 636 Connectivity"

echo "  Running: nc -zv $FREEIPA_IP $LDAPS_PORT"
if timeout 5 bash -c "echo >/dev/tcp/$FREEIPA_IP/$LDAPS_PORT" 2>/dev/null; then
    pass "Port 636 (LDAPS) is REACHABLE on $FREEIPA_IP"
else
    fail "Port 636 (LDAPS) is NOT reachable on $FREEIPA_IP"
    info "This may be OK if using plaintext LDAP (port 389)"
fi

# ─────────────────────────────────────────
# TEST 5: ANONYMOUS LDAP QUERY
# ─────────────────────────────────────────
section "TEST 5: Anonymous LDAP Query"

if ! command -v ldapsearch &>/dev/null; then
    fail "ldapsearch not installed"
    info "Fix: apt install ldap-utils"
else
    echo "  Running: ldapsearch -x -H ldap://$FREEIPA_HOSTNAME -b '$BASE_DN'"
    ANON_RESULT=$(ldapsearch -x -H "ldap://$FREEIPA_HOSTNAME" -b "$BASE_DN" "(cn=*)" dn 2>&1 | head -5)
    
    if echo "$ANON_RESULT" | grep -q "dn:"; then
        pass "Anonymous LDAP query returned results"
    elif echo "$ANON_RESULT" | grep -q "unwillingToPerform"; then
        pass "LDAP server reachable (anonymous bind disabled — normal for FreeIPA)"
    else
        fail "Anonymous LDAP query failed"
        info "Output: $ANON_RESULT"
    fi
fi

# ─────────────────────────────────────────
# TEST 6: AUTHENTICATED LDAP BIND
# ─────────────────────────────────────────
section "TEST 6: Authenticated LDAP Bind (Admin)"

if ! command -v ldapsearch &>/dev/null; then
    fail "ldapsearch not installed — skipping"
else
    echo ""
    read -s -p "  Enter LDAP admin password (or press ENTER to skip): " LDAP_PASSWORD
    echo ""

    if [ -z "$LDAP_PASSWORD" ]; then
        info "Skipped — no password provided"
    else
        echo "  Running: ldapsearch -x -H ldap://$FREEIPA_HOSTNAME -D '$BIND_DN' -w '***' -b '$BASE_DN'"
        
        BIND_RESULT=$(ldapsearch -x \
            -H "ldap://$FREEIPA_HOSTNAME" \
            -D "$BIND_DN" \
            -w "$LDAP_PASSWORD" \
            -b "$BASE_DN" \
            "(objectClass=person)" \
            uid cn mail \
            2>&1)

        if echo "$BIND_RESULT" | grep -q "result: 0 Success"; then
            pass "Authenticated LDAP bind: SUCCESS"
            USER_COUNT=$(echo "$BIND_RESULT" | grep "^dn:" | wc -l)
            pass "Found $USER_COUNT user(s) in directory"
            echo ""
            echo "  Sample users found:"
            echo "$BIND_RESULT" | grep "^uid:" | head -5 | sed 's/^/    /'
        elif echo "$BIND_RESULT" | grep -q "49"; then
            fail "Bind failed: Invalid credentials (Error 49)"
            info "Check: Bind DN and password are correct"
            info "Bind DN used: $BIND_DN"
        elif echo "$BIND_RESULT" | grep -q "Can't contact"; then
            fail "Bind failed: Can't contact LDAP server"
            info "DNS or port connectivity issue — check Tests 1-4"
        else
            fail "Bind failed — unexpected error"
            info "Output: $(echo "$BIND_RESULT" | head -3)"
        fi
    fi
fi

# ─────────────────────────────────────────
# TEST 7: DOCKER CONTAINER DNS CHECK
# ─────────────────────────────────────────
section "TEST 7: Docker Container DNS Check"

if ! command -v docker &>/dev/null; then
    info "Docker not installed — skipping container test"
elif ! docker ps | grep -q "snipeit"; then
    info "Snipe-IT container not running — skipping"
else
    echo "  Checking DNS resolution inside snipeit container..."
    CONTAINER_RESOLVE=$(docker exec snipeit getent hosts "$FREEIPA_HOSTNAME" 2>/dev/null)
    
    if [ -n "$CONTAINER_RESOLVE" ]; then
        pass "Container can resolve $FREEIPA_HOSTNAME → $CONTAINER_RESOLVE"
    else
        fail "Container CANNOT resolve $FREEIPA_HOSTNAME"
        info "Fix: Recreate container with --add-host=$FREEIPA_HOSTNAME:$FREEIPA_IP"
    fi

    echo "  Checking LDAP port from inside container..."
    if docker exec snipeit bash -c "timeout 3 bash -c 'echo >/dev/tcp/$FREEIPA_IP/$LDAP_PORT'" 2>/dev/null; then
        pass "Container can reach LDAP port 389"
    else
        fail "Container CANNOT reach LDAP port 389"
    fi
fi

# ─────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  RESULTS SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}PASSED: $PASS${NC}"
echo -e "  ${RED}FAILED: $FAIL${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$FAIL" -eq 0 ]; then
    echo -e "  ${GREEN}✅ All tests passed! LDAP integration is ready.${NC}"
else
    echo -e "  ${RED}⚠️  $FAIL test(s) failed. Review the issues above.${NC}"
    echo "  See docs/troubleshooting.md for detailed fixes."
fi
echo ""
