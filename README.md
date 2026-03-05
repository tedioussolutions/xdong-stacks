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

## Usage

```bash
cd <stack>/
cp .env.example .env
nano .env
docker compose up -d
```
