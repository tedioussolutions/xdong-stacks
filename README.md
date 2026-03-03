# xdong-stacks

Docker Compose stacks companion to [xdong.sh](https://github.com/tedioussolutions/xdong) self-hosting guides.

Each directory is a self-contained stack with `docker-compose.yml`, `.env.example`, and all config files needed to deploy.

## Stacks

| Stack | Services | Guide |
|-------|----------|-------|
| `experity-fleet/` | SmokePing + LibreNMS + Prometheus + Grafana | Experity Fleet Troubleshooting |
| `local-homelab/` | Caddy + Homepage + Docker Socket Proxy + Arcane + n8n | Local Homelab Stack |

## Usage

```bash
cd <stack>/
cp .env.example .env
nano .env
docker compose up -d
```
