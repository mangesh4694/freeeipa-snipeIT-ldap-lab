#!/bin/bash
# =============================================================================
# Docker + Snipe-IT Deployment Script
# Project: FreeIPA + Snipe-IT LDAP Integration Lab
# =============================================================================
# USAGE:
#   sudo bash docker-snipeit.sh
#
# REQUIREMENTS:
#   - Ubuntu 22.04 or Debian 11
#   - Internet access for pulling Docker images
#   - FreeIPA server already deployed on VM1
# =============================================================================

set -e

# --- CONFIGURATION ---
FREEIPA_IP="192.168.1.10"
FREEIPA_HOSTNAME="ipa.theonetech.lab"
SNIPEIT_PORT="8080"
SNIPEIT_APP_KEY="base64:$(openssl rand -base64 32)"
SNIPEIT_DB_PASSWORD="snipeit_db_pass_$(openssl rand -hex 6)"

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- PRE-FLIGHT CHECKS ---
if [ "$EUID" -ne 0 ]; then
    error "Please run as root: sudo bash docker-snipeit.sh"
fi

log "Starting Docker + Snipe-IT deployment..."

# --- STEP 1: INSTALL DOCKER ---
log "Installing Docker..."

if command -v docker &>/dev/null; then
    log "Docker already installed: $(docker --version)"
else
    apt-get update -y
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    systemctl enable docker
    systemctl start docker
    log "Docker installed: $(docker --version)"
fi

# --- STEP 2: INSTALL LDAP UTILS ---
log "Installing LDAP utilities for testing..."
apt-get install -y ldap-utils

# --- STEP 3: FIX DNS FOR FREEIPA ---
log "Configuring DNS resolution for FreeIPA..."

# Add to host /etc/hosts
if ! grep -q "$FREEIPA_HOSTNAME" /etc/hosts; then
    echo "$FREEIPA_IP $FREEIPA_HOSTNAME" >> /etc/hosts
    log "Added $FREEIPA_HOSTNAME to /etc/hosts"
else
    log "$FREEIPA_HOSTNAME already in /etc/hosts"
fi

# Verify resolution
log "Verifying FreeIPA DNS resolution..."
getent hosts "$FREEIPA_HOSTNAME" && log "DNS resolution: OK" || warn "DNS resolution failed — check /etc/hosts"

# --- STEP 4: TEST FREEIPA CONNECTIVITY ---
log "Testing connectivity to FreeIPA server..."

ping -c 2 "$FREEIPA_IP" &>/dev/null && log "Ping to FreeIPA: OK" || warn "Cannot ping FreeIPA at $FREEIPA_IP"

log "Testing LDAP port 389..."
timeout 5 bash -c "echo >/dev/tcp/$FREEIPA_IP/389" 2>/dev/null && \
    log "LDAP port 389: REACHABLE" || \
    warn "LDAP port 389 not reachable. Check firewall on FreeIPA server."

# --- STEP 5: COPY IPA CA CERTIFICATE ---
log "Attempting to retrieve FreeIPA CA certificate..."
if curl -sk "https://$FREEIPA_HOSTNAME/ipa/config/ca.crt" -o /usr/local/share/ca-certificates/ipa-ca.crt 2>/dev/null; then
    update-ca-certificates
    log "FreeIPA CA certificate installed."
else
    warn "Could not auto-retrieve CA cert. Copy manually:"
    warn "  scp root@$FREEIPA_IP:/etc/ipa/ca.crt /usr/local/share/ca-certificates/ipa-ca.crt"
    warn "  update-ca-certificates"
fi

# --- STEP 6: CREATE ENV FILE ---
log "Creating Snipe-IT environment file..."

cat > /opt/snipeit.env <<EOF
# Snipe-IT Application Config
APP_ENV=production
APP_DEBUG=false
APP_KEY=${SNIPEIT_APP_KEY}
APP_URL=http://localhost:${SNIPEIT_PORT}
APP_TIMEZONE=UTC
APP_LOCALE=en-US

# Database Config
DB_CONNECTION=mysql
DB_HOST=snipeit-db
DB_DATABASE=snipeit
DB_USERNAME=snipeit
DB_PASSWORD=${SNIPEIT_DB_PASSWORD}

# Mail Config (optional)
MAIL_DRIVER=log
MAIL_HOST=localhost
MAIL_PORT=587
MAIL_FROM_ADDR=snipeit@theonetech.lab
MAIL_FROM_NAME=Snipe-IT

# LDAP Config (set via Snipe-IT UI or here)
LDAP_ENABLED=true
LDAP_SERVER=${FREEIPA_HOSTNAME}
LDAP_PORT=389
LDAP_BASEDN=dc=theonetech,dc=lab
LDAP_BINDDN=uid=admin,cn=users,cn=accounts,dc=theonetech,dc=lab
EOF

chmod 600 /opt/snipeit.env
log "Environment file created at /opt/snipeit.env"

# --- STEP 7: CREATE DOCKER COMPOSE ---
log "Creating Docker Compose file..."

mkdir -p /opt/snipeit

cat > /opt/snipeit/docker-compose.yml <<EOF
version: '3.8'

services:
  snipeit-db:
    image: mysql:8.0
    container_name: snipeit-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: root_${SNIPEIT_DB_PASSWORD}
      MYSQL_DATABASE: snipeit
      MYSQL_USER: snipeit
      MYSQL_PASSWORD: ${SNIPEIT_DB_PASSWORD}
    volumes:
      - snipeit-db:/var/lib/mysql
    networks:
      - snipeit-net

  snipeit:
    image: snipe/snipe-it:latest
    container_name: snipeit
    restart: unless-stopped
    depends_on:
      - snipeit-db
    ports:
      - "${SNIPEIT_PORT}:80"
    env_file:
      - /opt/snipeit.env
    extra_hosts:
      - "${FREEIPA_HOSTNAME}:${FREEIPA_IP}"
    volumes:
      - snipeit-data:/var/lib/snipeit
      - /usr/local/share/ca-certificates/ipa-ca.crt:/usr/local/share/ca-certificates/ipa-ca.crt:ro
    networks:
      - snipeit-net

volumes:
  snipeit-db:
  snipeit-data:

networks:
  snipeit-net:
    driver: bridge
EOF

log "Docker Compose file created at /opt/snipeit/docker-compose.yml"

# --- STEP 8: LAUNCH SNIPE-IT ---
log "Launching Snipe-IT via Docker Compose..."
cd /opt/snipeit
docker compose up -d

log "Waiting for containers to start..."
sleep 10

# --- STEP 9: VERIFY ---
log "Verifying containers..."
docker ps

# --- DONE ---
echo ""
echo "=============================================="
echo -e "${GREEN}✅ Snipe-IT Deployment Complete!${NC}"
echo "=============================================="
echo ""
echo "Access Snipe-IT at: http://$(hostname -I | awk '{print $1}'):$SNIPEIT_PORT"
echo ""
echo "Initial setup: Open the URL above and complete the web setup wizard."
echo ""
echo "LDAP Settings to configure in Snipe-IT UI:"
echo "  Server:   $FREEIPA_HOSTNAME"
echo "  Port:     389"
echo "  Base DN:  dc=theonetech,dc=lab"
echo "  Bind DN:  uid=admin,cn=users,cn=accounts,dc=theonetech,dc=lab"
echo "  Username Field:   uid"
echo "  First Name Field: givenName"
echo "  Last Name Field:  sn"
echo "  Email Field:      mail"
echo ""
echo "Next step: Run scripts/ldap-test.sh to verify LDAP connectivity"
echo "=============================================="
