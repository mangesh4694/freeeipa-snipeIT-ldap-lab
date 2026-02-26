# 🚨 Troubleshooting Guide — FreeIPA + Snipe-IT LDAP Integration

This document captures every issue encountered during the lab and the exact steps used to resolve them.

---

## Issue #1 — `Can't contact LDAP server`

### Symptom
When testing LDAP connection in Snipe-IT UI:
```
Could not bind to LDAP: Can't contact LDAP server
```

### Root Cause Identified
The Snipe-IT Docker container could **not resolve** the hostname `ipa.theonetech.lab`.
Docker containers use their own DNS, which had no knowledge of the internal lab domain.

### Investigation Steps

**Step 1 — Test DNS resolution on the host VM:**
```bash
getent hosts ipa.theonetech.lab
# Expected: 192.168.1.10 ipa.theonetech.lab
```

**Step 2 — Test DNS resolution inside the container:**
```bash
docker exec -it snipeit bash
getent hosts ipa.theonetech.lab
# Result: (nothing — resolution failed)
```

**Step 3 — Test direct IP connectivity:**
```bash
docker exec -it snipeit ping 192.168.1.10
# Result: Works — confirming it's a DNS issue, not network
```

### Fix Applied

**Option A — Add entry to container's /etc/hosts:**
```bash
# Find container ID
docker ps

# Enter container
docker exec -it snipeit bash

# Add hosts entry
echo "192.168.1.10 ipa.theonetech.lab" >> /etc/hosts

# Verify
getent hosts ipa.theonetech.lab
```

**Option B — Pass hosts entry at container startup (preferred):**
```bash
docker run -d \
  -p 8080:80 \
  --name snipeit \
  --add-host=ipa.theonetech.lab:192.168.1.10 \
  snipe/snipe-it
```

**Option C — Configure Docker DNS:**
```bash
# Edit Docker daemon config
nano /etc/docker/daemon.json
```
```json
{
  "dns": ["192.168.1.10", "8.8.8.8"]
}
```
```bash
systemctl restart docker
```

### Result
DNS resolved correctly. Hostname `ipa.theonetech.lab` → `192.168.1.10`.

---

## Issue #2 — Port 389 Not Reachable

### Symptom
```bash
nc -zv ipa.theonetech.lab 389
# Connection refused / timed out
```

### Root Cause
Firewall (`ufw`) on the FreeIPA VM was blocking port 389.

### Fix Applied
```bash
# On FreeIPA VM
sudo ufw allow 389/tcp
sudo ufw allow 636/tcp
sudo ufw allow 88/tcp
sudo ufw allow 88/udp
sudo ufw allow 53/tcp
sudo ufw allow 53/udp
sudo ufw reload

# Verify FreeIPA services are running
ipactl status
```

### Verification
```bash
# From Docker host
nc -zv 192.168.1.10 389
# Expected: Connection to 192.168.1.10 389 port [tcp/ldap] succeeded!
```

---

## Issue #3 — LDAP Bind DN Rejected

### Symptom
```
LDAP bind failed: Invalid credentials (49)
```

### Root Cause
Wrong Bind DN format. FreeIPA uses a specific DN path for users:
```
uid=admin,cn=users,cn=accounts,dc=theonetech,dc=lab
```
Not the typical OpenLDAP format like:
```
cn=admin,dc=theonetech,dc=lab   ← WRONG for FreeIPA
```

### Fix Applied
Updated Snipe-IT LDAP config to use the correct FreeIPA Bind DN:
```
uid=admin,cn=users,cn=accounts,dc=theonetech,dc=lab
```

### Verification
```bash
ldapsearch -x \
  -H ldap://ipa.theonetech.lab \
  -D "uid=admin,cn=users,cn=accounts,dc=theonetech,dc=lab" \
  -W \
  -b "dc=theonetech,dc=lab" \
  "(objectClass=person)"
```

---

## Issue #4 — SSL/TLS Certificate Errors (LDAPS)

### Symptom
When attempting LDAPS on port 636:
```
SSL_connect: SSL_ERROR_SYSCALL
ldap_sasl_bind(SIMPLE): Can't contact LDAP server
```

### Root Cause
FreeIPA uses a self-signed certificate from its internal CA. The Docker container does not trust this CA by default.

### Fix Applied

**Step 1 — Export FreeIPA CA certificate:**
```bash
# On FreeIPA server
cat /etc/ipa/ca.crt
```

**Step 2 — Copy CA cert to Docker host:**
```bash
scp root@192.168.1.10:/etc/ipa/ca.crt /usr/local/share/ca-certificates/ipa-ca.crt
```

**Step 3 — Trust the certificate:**
```bash
update-ca-certificates
```

**Step 4 — Copy cert into running container:**
```bash
docker cp /etc/ipa/ca.crt snipeit:/usr/local/share/ca-certificates/ipa-ca.crt
docker exec -it snipeit update-ca-certificates
```

**Step 5 — Restart container:**
```bash
docker restart snipeit
```

---

## Issue #5 — FreeIPA Service Not Starting

### Symptom
After VM reboot, LDAP not responding.

### Root Cause
FreeIPA services require a specific startup order and can fail silently.

### Diagnosis
```bash
ipactl status
# Shows which services failed

journalctl -u dirsrv@THEONETECH-LAB -n 50
# Check Directory Server logs
```

### Fix Applied
```bash
# Restart all IPA services in correct order
ipactl restart

# If still failing, check individual service
systemctl status dirsrv@THEONETECH-LAB
systemctl start dirsrv@THEONETECH-LAB
```

---

## General Diagnostic Commands

### On FreeIPA Server

```bash
# Check all IPA services
ipactl status

# Check LDAP port is listening
ss -tulnp | grep 389
ss -tulnp | grep 636

# Test local LDAP query
ldapsearch -x -H ldap://localhost \
  -D "uid=admin,cn=users,cn=accounts,dc=theonetech,dc=lab" \
  -W -b "dc=theonetech,dc=lab"

# Check firewall rules
ufw status

# View IPA logs
journalctl -u ipa -f
tail -f /var/log/dirsrv/slapd-THEONETECH-LAB/errors
```

### On Docker Host

```bash
# Check container is running
docker ps

# View container logs
docker logs snipeit
docker logs -f snipeit   # follow

# Enter container shell
docker exec -it snipeit bash

# Check DNS resolution inside container
docker exec snipeit getent hosts ipa.theonetech.lab

# Test port from host
nc -zv ipa.theonetech.lab 389

# Run full LDAP bind test
ldapsearch -x \
  -H ldap://ipa.theonetech.lab \
  -D "uid=admin,cn=users,cn=accounts,dc=theonetech,dc=lab" \
  -W \
  -b "dc=theonetech,dc=lab" \
  "(objectClass=person)"
```

---

## LDAP Error Codes Reference

| Code | Error | Meaning |
|---|---|---|
| 49 | `invalidCredentials` | Wrong password or Bind DN |
| 32 | `noSuchObject` | Base DN doesn't exist |
| 34 | `invalidDNSyntax` | Malformed DN string |
| -1 | `Can't contact LDAP server` | Network/DNS issue |
| 13 | `confidentialityRequired` | Server requires TLS |
| 48 | `inappropriateAuthentication` | Auth method not allowed |

---

## Lessons Learned

1. **Always test DNS first** before blaming LDAP — most "can't contact LDAP" errors are DNS failures
2. **FreeIPA's DN format is different** from plain OpenLDAP — always use `uid=admin,cn=users,cn=accounts,...`
3. **Docker containers have isolated DNS** — use `--add-host` flag or configure `daemon.json`
4. **Test step by step**: DNS → ping → nc port → ldapsearch → Snipe-IT config
5. **Firewall is often the silent culprit** — always check `ufw status` and `ss -tulnp`
