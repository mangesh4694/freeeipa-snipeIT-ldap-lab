#!/bin/bash
# =============================================================================
# FreeIPA Server Installation Script
# Project: FreeIPA + Snipe-IT LDAP Integration Lab
# =============================================================================
# USAGE:
#   sudo bash freeipa-install.sh
#
# REQUIREMENTS:
#   - Ubuntu 22.04 or Debian 11
#   - Static IP configured (e.g., 192.168.1.10)
#   - At least 4 GB RAM
#   - Hostname must be FQDN (e.g., ipa.theonetech.lab)
# =============================================================================

set -e

# --- CONFIGURATION ---
# Edit these variables before running
IPA_DOMAIN="theonetech.lab"
IPA_REALM="THEONETECH.LAB"
IPA_SERVER_IP="192.168.1.10"
IPA_HOSTNAME="ipa.theonetech.lab"
IPA_ADMIN_PASSWORD="YourSecureAdminPassword123!"
IPA_DS_PASSWORD="YourSecureDSPassword123!"

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- PRE-FLIGHT CHECKS ---
log "Starting FreeIPA installation script..."

if [ "$EUID" -ne 0 ]; then
    error "Please run as root: sudo bash freeipa-install.sh"
fi

log "Checking system requirements..."

# Check minimum RAM (4GB recommended)
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 3000 ]; then
    warn "Less than 4GB RAM detected ($TOTAL_RAM MB). FreeIPA may be slow."
fi

# --- STEP 1: SET HOSTNAME ---
log "Setting system hostname to $IPA_HOSTNAME..."
hostnamectl set-hostname "$IPA_HOSTNAME"

# --- STEP 2: CONFIGURE /etc/hosts ---
log "Configuring /etc/hosts..."
# Remove existing entry for this hostname if present
sed -i "/$IPA_HOSTNAME/d" /etc/hosts

# Add correct entry
echo "$IPA_SERVER_IP $IPA_HOSTNAME ipa" >> /etc/hosts

log "Verifying hostname resolution..."
getent hosts "$IPA_HOSTNAME" || error "Hostname not resolving. Check /etc/hosts."

# --- STEP 3: UPDATE SYSTEM ---
log "Updating system packages..."
apt-get update -y
apt-get upgrade -y

# --- STEP 4: INSTALL FREEIPA ---
log "Installing FreeIPA server packages..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    freeipa-server \
    freeipa-server-dns \
    freeipa-server-trust-ad

# --- STEP 5: RUN FREEIPA INSTALLER ---
log "Running FreeIPA server installer (this takes 5-15 minutes)..."
log "Domain: $IPA_DOMAIN"
log "Realm:  $IPA_REALM"

ipa-server-install \
    --unattended \
    --domain="$IPA_DOMAIN" \
    --realm="$IPA_REALM" \
    --hostname="$IPA_HOSTNAME" \
    --ip-address="$IPA_SERVER_IP" \
    --admin-password="$IPA_ADMIN_PASSWORD" \
    --ds-password="$IPA_DS_PASSWORD" \
    --setup-dns \
    --auto-forwarders \
    --no-ntp

# --- STEP 6: CONFIGURE FIREWALL ---
log "Configuring firewall rules..."
if command -v ufw &>/dev/null; then
    ufw allow 53/tcp comment "FreeIPA DNS"
    ufw allow 53/udp comment "FreeIPA DNS"
    ufw allow 80/tcp comment "FreeIPA HTTP"
    ufw allow 443/tcp comment "FreeIPA HTTPS"
    ufw allow 389/tcp comment "FreeIPA LDAP"
    ufw allow 636/tcp comment "FreeIPA LDAPS"
    ufw allow 88/tcp comment "FreeIPA Kerberos"
    ufw allow 88/udp comment "FreeIPA Kerberos"
    ufw allow 464/tcp comment "FreeIPA Kpasswd"
    ufw allow 464/udp comment "FreeIPA Kpasswd"
    ufw --force enable
    log "Firewall rules applied."
else
    warn "ufw not found. Please configure firewall manually."
fi

# --- STEP 7: VERIFY INSTALLATION ---
log "Verifying FreeIPA installation..."

echo ""
log "Checking IPA services status..."
ipactl status

echo ""
log "Checking LDAP port (389)..."
ss -tulnp | grep 389 && log "LDAP port 389 is OPEN" || warn "LDAP port 389 not found!"

echo ""
log "Checking LDAPS port (636)..."
ss -tulnp | grep 636 && log "LDAPS port 636 is OPEN" || warn "LDAPS port 636 not found!"

# --- STEP 8: TEST LDAP ---
log "Testing LDAP connectivity..."
echo "$IPA_ADMIN_PASSWORD" | kinit admin && log "Kerberos authentication: OK" || warn "Kerberos auth failed"

# --- DONE ---
echo ""
echo "=============================================="
echo -e "${GREEN}✅ FreeIPA Installation Complete!${NC}"
echo "=============================================="
echo ""
echo "Web UI:      https://$IPA_HOSTNAME"
echo "Domain:      $IPA_DOMAIN"
echo "Realm:       $IPA_REALM"
echo "Admin User:  admin"
echo ""
echo "LDAP Details for Snipe-IT:"
echo "  Server:   ldap://$IPA_HOSTNAME"
echo "  Bind DN:  uid=admin,cn=users,cn=accounts,dc=$(echo $IPA_DOMAIN | sed 's/\./,dc=/g')"
echo "  Base DN:  dc=$(echo $IPA_DOMAIN | sed 's/\./,dc=/g')"
echo ""
echo "Next step: Run scripts/docker-snipeit.sh on VM2"
echo "=============================================="
