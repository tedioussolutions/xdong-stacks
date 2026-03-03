# Local Homelab Stack

Docker Compose stack for local homelab management: reverse proxy, dashboard, and workflow automation.

| Service | Image | Purpose |
|---------|-------|---------|
| Caddy | `caddy:2-alpine` | Reverse proxy — routes `*.local` domains to services |
| Docker Socket Proxy | `tecnativa/docker-socket-proxy` | Filtered Docker API access (security layer) |
| Homepage | `ghcr.io/gethomepage/homepage` | Self-hosted dashboard with Docker container status |
| n8n | `n8nio/n8n` | Workflow automation |

---

## Prerequisites

- Docker + Docker Compose v2
- Linux (or macOS) host
- DNS configured for `*.local` — see [DNS Setup](#dns-setup) below

---

## Quick Start

**1. Clone and enter the stack directory:**
```bash
cd xdong-stacks/local-homelab
```

**2. Copy and configure environment:**
```bash
cp .env.example .env
nano .env
```

**3. Validate configuration:**
```bash
bash validate-stack-config.sh
```

**4. Deploy:**
```bash
docker compose up -d
docker compose ps
```

**5. Access services** (after DNS setup):
- Homepage: http://homepage.local
- n8n: http://n8n.local

---

## DNS Setup

Services are accessed via `*.local` subdomains. You must configure DNS so these resolve to your server's IP.

### Option A: Pi-hole or AdGuard Home (recommended)

In your Pi-hole/AdGuard Home admin:
1. Go to **Local DNS → DNS Records**
2. Add records for each service:
   ```
   homepage.local  →  YOUR_SERVER_IP
   n8n.local       →  YOUR_SERVER_IP
   ```
   Or add a wildcard CNAME `*.local → YOUR_SERVER_IP` if your DNS server supports it.

### Option B: `/etc/hosts` (quick fallback)

On **each machine** that needs access to the services:
```bash
sudo sh -c 'echo "YOUR_SERVER_IP  homepage.local n8n.local" >> /etc/hosts'
```

Replace `YOUR_SERVER_IP` with your server's LAN IP (e.g. `192.168.1.10`).

> **Note:** `/etc/hosts` changes apply only to that machine. Pi-hole/AdGuard covers your whole network.

---

## Services

### Caddy (Reverse Proxy)

Routes `*.local` subdomains over HTTP. Local domains cannot use Let's Encrypt TLS — HTTP is intentional.

No management UI. Configuration is in `Caddyfile`.

### Docker Socket Proxy

Sits between Homepage and the Docker daemon. Filters which Docker API endpoints are accessible — read-only access for container status display.

No external ports — accessed internally as `docker-socket-proxy:2375`.

### Homepage

Dashboard with container status widgets. Config files are in `homepage/config/`:

| File | Purpose |
|------|---------|
| `settings.yaml` | Theme, title, layout columns |
| `services.yaml` | Service tiles and widgets |
| `docker.yaml` | Docker socket proxy connection |
| `bookmarks.yaml` | Quick links bar |

Edit these files and restart Homepage to apply changes:
```bash
docker compose restart homepage
```

### n8n

Workflow automation. Data persists in the `n8n-data` Docker volume.

- **Webhooks:** Set `N8N_WEBHOOK_URL=http://n8n.local/` in `.env` so n8n knows its public URL for webhook callbacks.
- **Data location:** `/home/node/.n8n` inside the container (named volume `n8n-data`).

---

## Configuration Reference

All configuration is via environment variables in `.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `America/Denver` | Timezone for all services |
| `PUID` / `PGID` | `1000` | User/group ID for file permissions |
| `CADDY_HTTP_PORT` | `80` | Host port for HTTP |
| `CADDY_HTTPS_PORT` | `443` | Host port for HTTPS |
| `N8N_HOST` | `n8n.local` | Hostname n8n is accessed at |
| `N8N_PROTOCOL` | `http` | Protocol (http for local) |
| `N8N_WEBHOOK_URL` | `http://n8n.local/` | Webhook base URL (include trailing slash) |

---

## Troubleshooting

**Services not accessible via `*.local`**
→ DNS not configured. Follow the [DNS Setup](#dns-setup) section. Test with `ping homepage.local`.

**Homepage shows no container status**
→ Verify docker-socket-proxy is running: `docker compose ps docker-socket-proxy`. Check `DOCKER_HOST` is set in homepage service. Check `homepage/config/docker.yaml` has correct host/port.

**Port 80 or 443 already in use**
→ Another service is bound to that port. Check with `ss -tlnp | grep ':80'`. Either stop the conflicting service or change `CADDY_HTTP_PORT`/`CADDY_HTTPS_PORT` in `.env` and update DNS/bookmarks accordingly.

---

## Related

- [xdong.sh guide](https://github.com/tedioussolutions/xdong) — full walkthrough with screenshots
- [Homepage docs](https://gethomepage.dev)
- [n8n docs](https://docs.n8n.io)
