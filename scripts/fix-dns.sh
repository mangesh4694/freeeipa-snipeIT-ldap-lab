#!/bin/bash
# =============================================================================
# DNS Fix Script — FreeIPA Resolution Inside Docker
# Project: FreeIPA + Snipe-IT LDAP Integration Lab
# =============================================================================
# USAGE:
#   sudo bash fix-dns.sh
#
# This script fixes DNS resolution issues between the Docker container
# and the FreeIPA server. Run this on the Docker Host (VM2).
# =============================================================================

FREEIPA_IP="192.168.1.10"
FREEIPA_HOSTNAME="ipa.theonetech.lab"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[FIX]${NC} $1"; }
warn() { echo -e "${YELLOW}[NOTE]${NC} $1"; }

echo ""
echo "=============================="
echo "  DNS Fix Script"
echo "=============================="
echo ""

# --- FIX 1: Add to host /etc/hosts ---
log "Fix 1: Adding FreeIPA to /etc/hosts on the host machine..."

if grep -q "$FREEIPA_HOSTNAME" /etc/hosts; then
    log "Entry already exists in /etc/hosts"
else
    echo "$FREEIPA_IP $FREEIPA_HOSTNAME" | sudo tee -a /etc/hosts
    log "Added: $FREEIPA_IP $FREEIPA_HOSTNAME"
fi

# Verify
getent hosts "$FREEIPA_HOSTNAME" && log "Host DNS: OK" || warn "Host DNS still failing"

echo ""

# --- FIX 2: Add to running container ---
log "Fix 2: Injecting hosts entry into running Snipe-IT container..."

if docker ps | grep -q snipeit; then
    docker exec snipeit bash -c "grep -q '$FREEIPA_HOSTNAME' /etc/hosts || echo '$FREEIPA_IP $FREEIPA_HOSTNAME' >> /etc/hosts"
    
    # Verify inside container
    if docker exec snipeit getent hosts "$FREEIPA_HOSTNAME" &>/dev/null; then
        log "Container DNS: OK"
    else
        warn "Container DNS still failing — try recreating container"
    fi
else
    warn "Snipe-IT container not running. Start it first with docker-snipeit.sh"
fi

echo ""

# --- FIX 3: Configure Docker daemon DNS ---
log "Fix 3: Configuring Docker daemon to use FreeIPA DNS..."

DAEMON_JSON="/etc/docker/daemon.json"

if [ -f "$DAEMON_JSON" ]; then
    warn "Docker daemon.json already exists. Edit manually to add DNS:"
    warn "  cat $DAEMON_JSON"
else
    cat > "$DAEMON_JSON" <<EOF
{
  "dns": ["$FREEIPA_IP", "8.8.8.8"],
  "dns-search": ["theonetech.lab"]
}
EOF
    log "Docker daemon.json created with FreeIPA DNS"
    
    log "Restarting Docker daemon..."
    systemctl restart docker
    log "Docker restarted. Containers will need to be restarted."
fi

echo ""
echo "=============================="
echo -e "${GREEN}✅ DNS Fix Applied!${NC}"
echo "=============================="
echo ""
echo "To test: bash scripts/ldap-test.sh"
echo ""
