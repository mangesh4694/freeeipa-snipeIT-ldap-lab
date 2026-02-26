# 🏗️ Lab Architecture — FreeIPA + Snipe-IT LDAP Integration

## Overview

This lab simulates an enterprise environment where IT assets are managed through Snipe-IT and user identities are centrally managed via FreeIPA. Authentication between the two systems happens over LDAP.

---

## Network Diagram

```
┌─────────────────────────────────────────────────────────┐
│                     Proxmox VE Host                     │
│                                                         │
│  ┌──────────────────────────┐  ┌──────────────────────┐ │
│  │   VM1: FreeIPA Server    │  │  VM2: Docker Host    │ │
│  │   IP: 192.168.1.10       │  │  IP: 192.168.1.20    │ │
│  │                          │  │                      │ │
│  │  ┌────────────────────┐  │  │  ┌────────────────┐  │ │
│  │  │ FreeIPA Services   │  │  │  │  Snipe-IT      │  │ │
│  │  │                    │  │  │  │  Container     │  │ │
│  │  │ • DNS    (53)      │◄─┼──┼─►│  Port 8080     │  │ │
│  │  │ • LDAP   (389)     │  │  │  │                │  │ │
│  │  │ • LDAPS  (636)     │  │  │  └────────────────┘  │ │
│  │  │ • Kerberos (88)    │  │  │                      │ │
│  │  │ • HTTP   (80/443)  │  │  │                      │ │
│  │  └────────────────────┘  │  └──────────────────────┘ │
│  └──────────────────────────┘                           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## VM Specifications

### VM1 — FreeIPA Server
| Parameter | Value |
|---|---|
| OS | Ubuntu 22.04 LTS / Debian 11 |
| IP Address | 192.168.1.10 |
| Hostname | ipa.theonetech.lab |
| Domain | theonetech.lab |
| RAM | 4 GB (minimum) |
| CPU | 2 vCPUs |
| Disk | 20 GB |

### VM2 — Docker Host
| Parameter | Value |
|---|---|
| OS | Ubuntu 22.04 LTS |
| IP Address | 192.168.1.20 |
| Hostname | docker.theonetech.lab |
| RAM | 2 GB |
| CPU | 2 vCPUs |
| Disk | 20 GB |

---

## Communication Flow

```
User Login Attempt in Snipe-IT
        │
        ▼
Snipe-IT (Docker Container)
        │
        │  LDAP Bind Request
        │  Port 389 / 636
        ▼
FreeIPA LDAP Service (VM1)
        │
        │  Validates credentials
        │  Returns user attributes
        ▼
Snipe-IT grants access
```

---

## FreeIPA Services

| Service | Port | Protocol | Purpose |
|---|---|---|---|
| DNS | 53 | UDP/TCP | Name resolution |
| LDAP | 389 | TCP | Directory queries |
| LDAPS | 636 | TCP | Encrypted directory queries |
| Kerberos | 88 | UDP/TCP | Ticket-based auth |
| Kerberos (kpasswd) | 464 | UDP/TCP | Password changes |
| HTTP | 80 | TCP | Web UI redirect |
| HTTPS | 443 | TCP | Web UI (secure) |

---

## LDAP Directory Structure (DIT)

```
dc=theonetech,dc=lab
│
├── cn=accounts
│   ├── cn=users          ← All user accounts live here
│   │   ├── uid=admin
│   │   ├── uid=jdoe
│   │   └── uid=asmith
│   │
│   └── cn=groups         ← All groups live here
│       ├── cn=admins
│       └── cn=helpdesk
│
├── cn=kerberos           ← Kerberos configuration
└── cn=services           ← Service accounts
```

---

## Key LDAP Attributes Used

| Attribute | Description | Example |
|---|---|---|
| `uid` | Username | `jdoe` |
| `cn` | Common Name (full name) | `John Doe` |
| `givenName` | First name | `John` |
| `sn` | Surname / Last name | `Doe` |
| `mail` | Email address | `jdoe@theonetech.lab` |
| `dn` | Distinguished Name | `uid=jdoe,cn=users,...` |

---

## Design Decisions

### Why FreeIPA over plain OpenLDAP?
FreeIPA combines LDAP + DNS + Kerberos + PKI in one integrated package. This is closer to what you'd find in production environments (similar to Active Directory).

### Why Docker for Snipe-IT?
Docker allows fast deployment and easy reset. In production, Snipe-IT would typically run on a dedicated VM or Kubernetes pod.

### Why LDAP (389) vs LDAPS (636)?
Lab started with plaintext LDAP for simplicity during troubleshooting. LDAPS with proper CA trust is listed as a future improvement for production hardening.
