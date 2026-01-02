# Hetzner n8n Server

Workflow-Automatisierung mit n8n auf Hetzner Cloud.

## Server-Details

| Eigenschaft | Wert |
|-------------|------|
| **Hostname** | `hetzner-n8n` |
| **Provider** | Hetzner Cloud |
| **OS** | Debian 13 (trixie) |
| **vCPU** | 2 |
| **RAM** | 4 GB |
| **Disk (System)** | 40 GB |
| **Disk (Daten)** | 10 GB (extern, `/mnt/data`) |
| **Öffentliche IP** | 88.198.224.219 |
| **Tailscale IP** | 100.81.212.93 |
| **Tailscale Hostname** | `hetzner-n8n` |

## Zugriff

### n8n Web UI
```
https://n8n.internal.xr-ai.de/
```

### SSH
```bash
ssh n8n-hetzner
# oder
ssh root@hetzner-n8n        # via Tailscale
ssh root@88.198.224.219     # via öffentliche IP
```

## Installierte Dienste

### n8n (Docker)
- **Version**: latest (aktuell 2.1.5)
- **Datenbank**: SQLite
- **Daten-Verzeichnis**: `/mnt/data/n8n/data/`
- **Container-Name**: `n8n`
- **Interner Port**: 5678

### Caddy (Reverse Proxy)
- **Version**: 2.10.2
- **Funktion**: TLS-Terminierung, Reverse Proxy zu n8n
- **Zertifikat**: Let's Encrypt (automatisch)
- **Config**: `/etc/caddy/Caddyfile`

### Tailscale
- **Version**: 1.92.3
- **Funktion**: VPN/Mesh-Netzwerk

## Verzeichnisstruktur

```
/mnt/data/                          # Symlink → /mnt/HC_Volume_104318824
└── n8n/
    ├── docker-compose.yml          # Docker Compose Konfiguration
    └── data/                       # n8n Daten (SQLite DB, Workflows, etc.)
        ├── database.sqlite         # SQLite Datenbank
        ├── config                  # n8n Encryption Key
        └── ...
```

## Konfigurationsdateien

### Docker Compose (`/mnt/data/n8n/docker-compose.yml`)
```yaml
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: always
    ports:
      - "127.0.0.1:5678:5678"
    environment:
      - TZ=Europe/Berlin
      - GENERIC_TIMEZONE=Europe/Berlin
      - N8N_HOST=n8n.internal.xr-ai.de
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://n8n.internal.xr-ai.de/
      - DB_TYPE=sqlite
      - DB_SQLITE_DATABASE=/home/node/.n8n/database.sqlite
    volumes:
      - /mnt/data/n8n/data:/home/node/.n8n
```

### Caddy (`/etc/caddy/Caddyfile`)
```
n8n.internal.xr-ai.de {
    reverse_proxy localhost:5678
}
```

## Firewall (UFW)

```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere          # SSH
80                         ALLOW       100.64.0.0/10     # HTTP (Tailscale only, für Cert-Renewal)
443                        ALLOW       100.64.0.0/10     # HTTPS (Tailscale)
443/tcp                    ALLOW       Anywhere          # HTTPS (öffentlich)
```

**Hinweis**: Zusätzlich ist die Hetzner Cloud Firewall aktiv. Port 22 und 443 müssen dort ebenfalls freigegeben sein.

## TLS-Zertifikat

- **Aussteller**: Let's Encrypt
- **Domain**: `n8n.internal.xr-ai.de`
- **Gültigkeit**: 90 Tage (automatische Erneuerung)
- **Renewal**: Täglich um 3:00 Uhr via Cronjob

### Renewal-Mechanismus

Das Zertifikat wird automatisch erneuert. Da Port 80 nur für Tailscale offen ist, öffnet ein Cronjob temporär Port 80 für die HTTP-01 Challenge:

**Script** (`/usr/local/bin/renew-cert.sh`):
```bash
#!/bin/bash
ufw allow 80/tcp
sleep 5
systemctl reload caddy
sleep 30
ufw delete allow 80/tcp
echo "$(date): Certificate renewal check completed" >> /var/log/cert-renewal.log
```

**Cronjob** (`/etc/cron.d/cert-renewal`):
```
0 3 * * * root /usr/local/bin/renew-cert.sh
```

## Verwaltungsbefehle

### n8n Container
```bash
# Status prüfen
docker ps

# Logs anzeigen
docker logs -f n8n

# Neustart
cd /mnt/data/n8n && docker compose restart

# Update auf neueste Version
cd /mnt/data/n8n && docker compose pull && docker compose up -d

# Container stoppen
cd /mnt/data/n8n && docker compose down
```

### Caddy
```bash
# Status
systemctl status caddy

# Logs
journalctl -u caddy -f

# Reload (z.B. nach Config-Änderung)
systemctl reload caddy

# Neustart
systemctl restart caddy
```

### Tailscale
```bash
# Status
tailscale status

# IP anzeigen
tailscale ip -4
```

## Backup

### n8n Daten sichern
```bash
# Auf dem Server
tar -czvf n8n-backup-$(date +%Y%m%d).tar.gz /mnt/data/n8n/data/

# Vom lokalen Rechner
scp n8n-hetzner:/mnt/data/n8n/data/database.sqlite ./n8n-backup.sqlite
```

### Wichtige Dateien für Backup
- `/mnt/data/n8n/data/database.sqlite` - Workflows, Credentials, Execution History
- `/mnt/data/n8n/data/config` - Encryption Key (WICHTIG für Credentials!)
- `/mnt/data/n8n/docker-compose.yml` - Container-Konfiguration
- `/etc/caddy/Caddyfile` - Reverse Proxy Konfiguration

## DNS

| Record | Typ | Wert | Zweck |
|--------|-----|------|-------|
| `n8n.internal.xr-ai.de` | A | 88.198.224.219 | HTTPS-Zugriff + Let's Encrypt |

DNS wird bei Dogado verwaltet (Domain: xr-ai.de).

## Troubleshooting

### n8n nicht erreichbar
```bash
# Container läuft?
docker ps | grep n8n

# n8n Logs prüfen
docker logs n8n --tail 50

# Caddy läuft?
systemctl status caddy

# Port 5678 offen?
ss -tlnp | grep 5678
```

### 502 Bad Gateway
```bash
# Prüfen ob n8n auf richtigem Port lauscht
docker exec n8n netstat -tlnp | grep LISTEN

# Sollte zeigen: :::5678 LISTEN
# Falls Port 443 oder 80: N8N_PORT Environment Variable prüfen
```

### Zertifikat abgelaufen
```bash
# Manuelles Renewal
/usr/local/bin/renew-cert.sh

# Caddy Logs prüfen
journalctl -u caddy --since "10 minutes ago"
```

### Kein Zugriff über öffentliche IP
1. Hetzner Cloud Firewall prüfen (Port 443 TCP erlaubt?)
2. UFW Status prüfen: `ufw status`
3. Caddy läuft: `systemctl status caddy`

## Installationshistorie

Server wurde am 2026-01-02 eingerichtet:
1. Debian 13 (trixie) - Hetzner Cloud
2. Externes Volume gemountet auf `/mnt/HC_Volume_104318824`
3. Symlink `/mnt/data` erstellt
4. Docker CE installiert (mit gepinnter containerd.io Version wegen CDN-Bug)
5. Tailscale installiert und authentifiziert
6. n8n via Docker Compose deployed
7. Caddy als Reverse Proxy mit Let's Encrypt TLS
8. UFW Firewall konfiguriert
9. Automatisches Cert-Renewal via Cronjob
