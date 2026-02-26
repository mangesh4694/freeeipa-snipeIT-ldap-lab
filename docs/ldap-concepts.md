# 📚 LDAP Concepts Reference

A quick reference for LDAP concepts used in this project.

---

## What is LDAP?

**LDAP (Lightweight Directory Access Protocol)** is a protocol used to access and maintain distributed directory information services over a network. It's commonly used for:

- User authentication
- Centralized user management
- Single Sign-On (SSO) backends
- Address books

---

## Key LDAP Terminology

### Distinguished Name (DN)
The unique identifier of an entry in the LDAP directory. It's like a full path.

```
uid=jdoe,cn=users,cn=accounts,dc=theonetech,dc=lab
```

### Relative Distinguished Name (RDN)
The leftmost component of a DN.
```
uid=jdoe
```

### Base DN
The starting point for LDAP searches.
```
dc=theonetech,dc=lab
```

### Bind DN
The account used to authenticate (login) to the LDAP server.
```
uid=admin,cn=users,cn=accounts,dc=theonetech,dc=lab
```

### Object Classes
Define what type of object an LDAP entry is and what attributes it can/must have.

| Object Class | Used For |
|---|---|
| `inetOrgPerson` | Standard user accounts |
| `posixAccount` | Unix/Linux users |
| `groupOfNames` | Groups |
| `organizationalUnit` | Containers (ou=) |

### Common Attributes

| Attribute | Full Name | Example |
|---|---|---|
| `uid` | User ID | `jdoe` |
| `cn` | Common Name | `John Doe` |
| `sn` | Surname | `Doe` |
| `givenName` | First Name | `John` |
| `mail` | Email | `jdoe@company.com` |
| `userPassword` | Password (hashed) | `{SSHA}...` |
| `dc` | Domain Component | `theonetech` |
| `ou` | Organizational Unit | `users` |

---

## LDAP Ports

| Port | Protocol | Description |
|---|---|---|
| 389 | TCP | Standard LDAP (plaintext) |
| 636 | TCP | LDAPS — LDAP over SSL/TLS |
| 3268 | TCP | Microsoft Global Catalog |
| 3269 | TCP | Microsoft Global Catalog (SSL) |

---

## LDAP Operations

| Operation | Description |
|---|---|
| **Bind** | Authenticate to the server |
| **Search** | Query the directory |
| **Add** | Create a new entry |
| **Modify** | Change attributes of an entry |
| **Delete** | Remove an entry |
| **Unbind** | Close the connection |

---

## FreeIPA-Specific LDAP Structure

FreeIPA organizes its directory under `cn=accounts`:

```
dc=theonetech,dc=lab
└── cn=accounts
    ├── cn=users          → User accounts
    ├── cn=groups         → Groups
    ├── cn=computers      → Enrolled computers
    ├── cn=services       → Service principals
    └── cn=hostgroups     → Host groups
```

This is **different from OpenLDAP** which typically uses `ou=users,dc=...`

---

## LDAP Authentication Flow

```
1. Client sends Bind Request
   → DN: uid=jdoe,cn=users,cn=accounts,dc=theonetech,dc=lab
   → Password: (user's password)

2. LDAP Server validates credentials

3. Server sends Bind Response
   → Result: success (0) or error code

4. Client sends Search Request
   → Base DN: dc=theonetech,dc=lab
   → Filter: (uid=jdoe)

5. Server returns matching entries with attributes

6. Client processes attributes (name, email, etc.)

7. Application grants or denies access
```

---

## Common ldapsearch Filters

```bash
# Find all users
(objectClass=person)

# Find specific user by username
(uid=jdoe)

# Find all members of a group
(memberOf=cn=admins,cn=groups,cn=accounts,dc=theonetech,dc=lab)

# Find users with email
(&(objectClass=person)(mail=*))

# Find user by email
(mail=jdoe@theonetech.lab)
```

---

## ldapsearch Syntax

```bash
ldapsearch [options] [filter] [attributes]

-x          Simple authentication (not SASL)
-H          LDAP URI (e.g., ldap://server)
-D          Bind DN
-W          Prompt for password
-w          Inline password (use only for testing)
-b          Base DN for search
-s          Search scope (base, one, sub)
-v          Verbose output
-LLL        Clean output (suppress comments)
```

### Example — List all users:
```bash
ldapsearch -x \
  -H ldap://ipa.theonetech.lab \
  -D "uid=admin,cn=users,cn=accounts,dc=theonetech,dc=lab" \
  -W \
  -b "cn=users,cn=accounts,dc=theonetech,dc=lab" \
  "(objectClass=person)" \
  uid cn mail
```

---

## LDAP vs Active Directory

| Feature | OpenLDAP | FreeIPA | Active Directory |
|---|---|---|---|
| Protocol | LDAP | LDAP + Kerberos | LDAP + Kerberos |
| DNS Integration | Manual | Built-in | Built-in |
| Web UI | No | Yes | Yes (ADAC) |
| Platform | Linux | Linux | Windows |
| Kerberos | Optional | Included | Included |
| Certificate Authority | Manual | Built-in | Built-in |
| LDAP DN format | `cn=admin,dc=...` | `uid=admin,cn=users,...` | `CN=admin,CN=Users,...` |
