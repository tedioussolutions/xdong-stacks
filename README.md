# xdong-stacks

Docker Compose stacks companion to [xdong.sh](https://github.com/tedioussolutions/xdong) self-hosting guides.

Each directory is a self-contained stack with `docker-compose.yml`, `.env.example`, and all config files needed to deploy.

## Stacks

| Stack | Services | Guide |
|-------|----------|-------|
| `experity-fleet/` | SmokePing + LibreNMS + Prometheus + Grafana | Experity Fleet Troubleshooting |

## Usage

```bash
cd <stack>/
cp .env.example .env
nano .env
docker compose up -d
```
