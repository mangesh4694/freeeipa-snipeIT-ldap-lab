#  FreeIPA + Snipe-IT LDAP Integration Lab

> Enterprise IAM + Asset Management Integration** — A hands-on homelab project demonstrating centralized identity management with LDAP authentication using FreeIPA and Snipe-IT inside a Proxmox virtualized environment.

---

##  Project Overview

This project demonstrates a real-world **LDAP integration** between:
- **FreeIPA** — Centralized Identity Management Server (LDAP + DNS + Kerberos)
- **Snipe-IT** — Open Source IT Asset Management System (running in Docker)

### Goals
- Deploy FreeIPA as a centralized identity provider
- Deploy Snipe-IT inside Docker on a separate VM
- Configure and troubleshoot LDAP authentication
- Achieve successful LDAP user synchronization
- Simulate an enterprise IAM + Asset Management integration

---

## Lab Architecture

```
Proxmox Host
│
├── VM1: FreeIPA Server (192.168.1.10)
│   ├── DNS (Port 53)
│   ├── LDAP (Port 389)
│   └── Kerberos (Port 88)
│
└── VM2: Docker Host (192.168.1.20)
    └── Snipe-IT Container (Port 8080)
```

---

## 🖥️ Technologies Used

| Technology | Purpose |
|---|---|
| Proxmox VE | Hypervisor / Lab Virtualization |
| FreeIPA | Identity Management (LDAP + DNS + Kerberos) |
| Docker | Container Runtime |
| Snipe-IT | IT Asset Management |
| LDAP | Authentication Protocol |
| DNS | Name Resolution |
| Ubuntu/Debian | Base OS |
| OpenSSL | Certificate Handling |
| ldap-utils | LDAP CLI Testing |

---

##  Repository Structure

```
freeipa-snipeit-ldap-lab/
│
├── README.md                  # This file
├── docs/
│   ├── architecture.md        # Detailed architecture notes
│   ├── troubleshooting.md     # All issues and fixes
│   └── ldap-concepts.md       # LDAP concepts reference
│
├── scripts/
│   ├── freeipa-install.sh     # FreeIPA installation script
│   ├── docker-snipeit.sh      # Docker + Snipe-IT deployment
│   ├── ldap-test.sh           # LDAP connectivity test script
│   └── fix-dns.sh             # DNS fix script for container
│
├── configs/
│   ├── snipeit-ldap.env       # Snipe-IT LDAP environment config
│   ├── docker-compose.yml     # Docker Compose for Snipe-IT
│   └── hosts-entry.txt        # /etc/hosts fix reference
│
└── screenshots/               # Add your lab screenshots here
    └── README.md              # Screenshot guide
```

---

##  Quick Start

### Prerequisites
- Proxmox VE host
- Two VMs: one for FreeIPA, one for Docker
- Network connectivity between VMs
- Ubuntu 22.04 or Debian 11 on both VMs

### Step 1 — FreeIPA Setup
```bash
git clone https://github.com/YOUR_USERNAME/freeipa-snipeit-ldap-lab.git
cd freeipa-snipeit-ldap-lab
chmod +x scripts/freeipa-install.sh
sudo bash scripts/freeipa-install.sh
```

### Step 2 — Deploy Snipe-IT
```bash
chmod +x scripts/docker-snipeit.sh
sudo bash scripts/docker-snipeit.sh
```

### Step 3 — Test LDAP Connection
```bash
chmod +x scripts/ldap-test.sh
sudo bash scripts/ldap-test.sh
```

---

##  Configuration Summary

### FreeIPA LDAP Details
| Parameter | Value |
|---|---|
| LDAP Server | `ldap://ipa.theonetech.lab` |
| Base DN | `dc=theonetech,dc=lab` |
| Bind DN | `uid=admin,cn=users,cn=accounts,dc=theonetech,dc=lab` |
| LDAP Port | `389` |
| LDAPS Port | `636` |

### Snipe-IT LDAP Settings (UI)
| Field | Value |
|---|---|
| LDAP Server | `ipa.theonetech.lab` |
| Port | `389` |
| Base DN | `dc=theonetech,dc=lab` |
| Bind Username | `uid=admin,cn=users,cn=accounts,dc=theonetech,dc=lab` |
| Username Field | `uid` |
| Last Name Field | `sn` |
| First Name Field | `givenName` |
| Email Field | `mail` |

---

##  Issues Faced & Fixes

| # | Issue | Root Cause | Fix |
|---|---|---|---|
| 1 | `Can't contact LDAP server` | DNS not resolving inside container | Added `/etc/hosts` entry |
| 2 | Container can't resolve hostname | No DNS configured in Docker | Used `--add-host` flag |
| 3 | Port 389 not reachable | Firewall blocking | Opened port with `ufw allow 389` |
| 4 | SSL cert errors | CA not trusted | Ran `update-ca-certificates` |
| 5 | Bind DN rejected | Wrong DN format | Corrected to FreeIPA format |

> Full troubleshooting details: [docs/troubleshooting.md](docs/troubleshooting.md)

---

##  Final Results

-  DNS resolution working inside Docker container
-  LDAP port 389 reachable from container
-  Successful bind to FreeIPA LDAP
-  LDAP user synchronization working in Snipe-IT
-  Enterprise-style IAM lab fully functional

--

---

## 📸 Screenshots

See the [screenshots/](screenshots/) folder.

Suggested screenshots to add:
- FreeIPA web dashboard
- Snipe-IT LDAP configuration page
- Successful LDAP sync result
- `ldapsearch` terminal output
- Docker container status (`docker ps`)
---

##  Author

Mangesh Mundhava
- LinkedIn: www.linkedin.com/in/mangesh-mundhava-ab494a300

---

>  If this helped you, please star the repo!
