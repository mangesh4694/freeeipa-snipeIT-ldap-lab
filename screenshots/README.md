# 📸 Screenshots

Add your lab screenshots here to document the project visually.

## Suggested Screenshots

| Filename | What to Capture |
|---|---|
| `01-proxmox-vms.png` | Proxmox dashboard showing both VMs running |
| `02-freeipa-dashboard.png` | FreeIPA web UI dashboard (https://ipa.theonetech.lab) |
| `03-freeipa-users.png` | FreeIPA users list showing test accounts |
| `04-docker-ps.png` | Terminal showing `docker ps` with snipeit container running |
| `05-snipeit-ldap-config.png` | Snipe-IT Admin > Settings > LDAP configuration page |
| `06-snipeit-ldap-test.png` | Snipe-IT LDAP test result showing success |
| `07-ldapsearch-output.png` | Terminal output of successful `ldapsearch` bind |
| `08-snipeit-users-synced.png` | Snipe-IT Users page showing LDAP-synced users |
| `09-ipactl-status.png` | Terminal showing `ipactl status` with all services running |
| `10-port-check.png` | Terminal showing `ss -tulnp | grep 389` |

## How to Take Screenshots

### Linux Terminal (Ubuntu)
```bash
# Install screenshot tool
apt install gnome-screenshot

# Full screen
gnome-screenshot -f screenshot.png

# Window only
gnome-screenshot -w -f screenshot.png
```

### Or use the Proxmox console "Take Screenshot" button

## Tips for Good Documentation Screenshots
- Use a clean terminal with readable font size (14pt+)
- Show the full command AND output
- For web UIs, show the full page including the URL bar
- Highlight key values (LDAP server, Base DN, success message) with arrows or circles if possible
