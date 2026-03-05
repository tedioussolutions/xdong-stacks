# xdong-stacks

Docker Compose stacks companion to [xdong.sh](https://github.com/tedioussolutions/xdong) self-hosting guides.

Each directory is a self-contained stack with `docker-compose.yml`, `.env.example`, and all config files needed to deploy.

## Stacks

| Stack | Services | Guide |
|-------|----------|-------|
| `experity-fleet/` | SmokePing + LibreNMS + Prometheus + Grafana | Experity Fleet Troubleshooting |
| `local-homelab/` | Caddy + Homepage + Docker Socket Proxy + Arcane + n8n | Local Homelab Stack |
| `worklab/` | Caddy + Homepage + Code-Server + IT-Tools + Netdata + Stirling-PDF + ConvertX + Karakeep + CommafFeed + Fluid-Calendar + Audiobookshelf + Meilisearch + PostgreSQL | Worklab Stack |
| `local-dev/` | Homepage + Code-Server + Forgejo + Qdrant + Meilisearch + n8n + Dozzle + Bytebase + Open WebUI + Activepieces + CyberChef + AnythingLLM + Postgres + Redis | Local Dev Stack |
| `caddy/` | Caddy reverse proxy (standalone) | Reverse Proxy |
| `jellyfin/` | Jellyfin media server | Media Streaming |
| `vaultwarden/` | Vaultwarden password manager | Password Management |
| `home-assistant/` | Home Assistant + optional Mosquitto MQTT | Home Automation |
| `nextcloud/` | Nextcloud AIO (All-in-One mastercontainer) | File Sync & Cloud |
| `immich/` | Immich server + ML + PostgreSQL + Redis | Photo & Video Backup |
| `ollama/` | Ollama + Open WebUI | Local AI / LLM |
| `adguard/` | AdGuard Home DNS | Network-wide Ad Blocking |

## Usage

```bash
cd <stack>/
cp .env.example .env
nano .env
docker compose up -d
```
