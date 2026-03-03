# Worklab Stack

A portable self-hosted lab stack for development and productivity. 10 services behind a Caddy reverse proxy, all accessible via `*.work.lab` subdomains.

## Services

| URL | Service | Purpose |
|-----|---------|---------|
| http://home.work.lab | Homepage | Dashboard — links to all services |
| http://code.work.lab | Code-Server | VS Code in the browser |
| http://tools.work.lab | IT-Tools | Developer utility toolbox (encoding, hashing, etc.) |
| http://netdata.work.lab | Netdata | Real-time system and container monitoring |
| http://pdf.work.lab | Stirling-PDF | PDF merge, split, compress, convert |
| http://convert.work.lab | ConvertX | File format converter |
| http://karakeep.work.lab | Karakeep | Bookmark manager with full-text search |
| http://feeds.work.lab | CommafFeed | RSS feed reader |
| http://calendar.work.lab | Fluid-Calendar | Intelligent calendar and task scheduling |
| http://books.work.lab | Audiobookshelf | Audiobook and podcast server |

**Infrastructure (internal only — no UI):**
- Caddy — reverse proxy
- Meilisearch — search engine for Karakeep
- PostgreSQL — database for Fluid-Calendar

## Quick Start

```bash
# 1. Copy and edit the environment file
cp .env.example .env
nano .env

# 2. Generate required secrets (run these commands, paste output into .env)
echo "MEILI_MASTER_KEY=$(openssl rand -base64 32)"
echo "KARAKEEP_NEXTAUTH_SECRET=$(openssl rand -base64 32)"
echo "POSTGRES_PASSWORD=$(openssl rand -base64 16)"
echo "CALENDAR_NEXTAUTH_SECRET=$(openssl rand -base64 32)"

# 3. Validate configuration
bash validate-stack-config.sh

# 4. Start the stack
docker compose up -d

# 5. Check status
docker compose ps
```

## DNS Setup

All services are accessed via `*.work.lab` subdomains. You must configure DNS to resolve these to your server's IP.

### Option A: Pi-hole / AdGuard Home (recommended)

Add a wildcard DNS record pointing `*.work.lab` to your server's IP address.

In Pi-hole: **Local DNS → DNS Records** → add `*.work.lab → <your-server-ip>`

### Option B: /etc/hosts (quick testing)

Add all subdomains manually:

```bash
echo '192.168.1.x  home.work.lab code.work.lab tools.work.lab netdata.work.lab pdf.work.lab convert.work.lab karakeep.work.lab feeds.work.lab calendar.work.lab books.work.lab' | sudo tee -a /etc/hosts
```

Replace `192.168.1.x` with your server's actual IP address.

## Configuration

Edit `.env` before starting the stack. Key variables:

| Variable | Description |
|----------|-------------|
| `TZ` | Timezone (e.g., `America/Denver`) |
| `CODE_SERVER_PASSWORD` | Password for Code-Server web UI |
| `MEILI_MASTER_KEY` | Meilisearch master key — required for Karakeep search |
| `KARAKEEP_NEXTAUTH_SECRET` | Karakeep session secret — generate with `openssl rand -base64 32` |
| `POSTGRES_PASSWORD` | PostgreSQL password for Fluid-Calendar database |
| `CALENDAR_NEXTAUTH_SECRET` | Fluid-Calendar session secret |
| `KARAKEEP_URL` | URL for Karakeep (default: `http://karakeep.work.lab`) |
| `CALENDAR_URL` | URL for Fluid-Calendar (default: `http://calendar.work.lab`) |
| `AUDIOBOOKS_PATH` | Host path to audiobooks directory (default: `./media/audiobooks`) |
| `PODCASTS_PATH` | Host path to podcasts directory (default: `./media/podcasts`) |

> ⚠️ **Secret values must not be left empty.** The validation script checks for empty secrets before deployment.

## Troubleshooting

**Karakeep won't start / search not working**
Karakeep requires Meilisearch. Check that `MEILI_MASTER_KEY` is set in `.env` and the meilisearch container is running:
```bash
docker compose logs meilisearch
docker compose logs karakeep
```

**Fluid-Calendar database error on startup**
Fluid-Calendar runs database migrations on first start. Check that PostgreSQL is healthy first:
```bash
docker compose logs postgres
docker compose logs fluid-calendar
```

**Code-Server returns 502 Bad Gateway**
Code-Server serves HTTPS internally. The Caddyfile uses `tls_insecure_skip_verify` to handle this. If you see 502, check the caddy and code-server containers:
```bash
docker compose logs caddy
docker compose logs code-server
```

**Service accessible on port 80 but not via subdomain**
DNS is not configured. Follow the DNS Setup section above. Verify with:
```bash
ping home.work.lab
```

**Audiobookshelf shows empty library**
Audiobookshelf needs media directories mounted. Point `AUDIOBOOKS_PATH` and `PODCASTS_PATH` in `.env` to your actual media directories and restart:
```bash
docker compose restart audiobookshelf
```

**Port 80 or 443 already in use**
Another web server is running on those ports. Check with `ss -tlnp | grep -E ':80|:443'`. Stop the conflicting service or change `CADDY_HTTP_PORT` and `CADDY_HTTPS_PORT` in `.env`.

## Useful Commands

```bash
# View logs for a specific service
docker compose logs -f karakeep

# Restart a single service
docker compose restart karakeep

# Pull latest images and recreate containers
docker compose pull && docker compose up -d

# Stop the stack (data volumes preserved)
docker compose down

# Stop and remove all data (destructive!)
docker compose down -v
```

## Security Notes

- Meilisearch is not exposed on any host port — it is accessible only within the Docker proxy network. The `MEILI_MASTER_KEY` protects its API.
- The Docker socket is mounted read-only (`:ro`) into Homepage and Netdata for container status monitoring.
- Code-Server's password is set via `CODE_SERVER_PASSWORD`. For production use, consider placing it behind an additional auth layer.
