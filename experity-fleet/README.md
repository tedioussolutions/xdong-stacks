# Experity Fleet Monitoring Stack

Full monitoring stack for troubleshooting Windows machines running Experity across a multi-site Meraki VPN environment.

**Services:** SmokePing (latency) + LibreNMS (SNMP) + Prometheus (metrics) + Grafana (dashboards)

**Companion guides:** [xdong.sh](https://github.com/tedioussolutions/xdong) → `guides/business-apps/`

## Quick Start

**Option A — Auto-configure from Meraki API (recommended):**

```bash
export MERAKI_API_KEY=your-api-key-here
python3 meraki-pull-infrastructure.py
# Generates .env, SmokePing Targets, Prometheus file_sd, and device inventory
# from your actual Meraki infrastructure

bash validate-stack-config.sh
docker compose up -d
```

**Option B — Manual configuration:**

```bash
cp .env.example .env
nano .env    # Set gateway IPs, SNMP community, passwords manually

docker compose up -d
docker compose ps
```

## Web UIs

| Service | URL | Default Credentials |
|---------|-----|-------------------|
| SmokePing | http://localhost:8080 | None |
| LibreNMS | http://localhost:8000 | Created on first login |
| Prometheus | http://localhost:9090 | None |
| Grafana | http://localhost:3000 | admin / (from .env) |

## Configuration

### SmokePing Targets

Edit `smokeping/Targets` to add your Experity endpoints and site gateways. Restart after changes:

```bash
docker compose restart smokeping
```

### Windows Fleet Targets

Edit `prometheus/file_sd/windows-fleet.json` to add Windows machines running [Prometheus Windows Exporter](https://github.com/prometheus-community/windows_exporter). Prometheus picks up changes within 60 seconds — no restart needed.

### Alert Rules

Edit `prometheus/alerts/windows-fleet-alert-rules.yml` to adjust thresholds. Reload Prometheus config:

```bash
curl -X POST http://localhost:9090/-/reload
```

### Grafana Dashboards

Import the community Windows Exporter dashboard:
1. Open Grafana → Dashboards → Import
2. Enter dashboard ID: **14694**
3. Select Prometheus datasource

## Architecture

```
[Windows Fleet]──(9182)──→[Prometheus]──→[Grafana]
                                              ↑
[Meraki Gear]───(SNMP)──→[LibreNMS]     dashboards
                                         + alerts
[All Endpoints]──(ICMP)──→[SmokePing]

Triage flow: Grafana alerts → Experity Performance Triage guide → Runbooks A-D
```

## Meraki API Integration

`meraki-pull-infrastructure.py` queries the Meraki Dashboard API and auto-generates all config files:

| What it pulls | Where it goes |
|--------------|---------------|
| MX appliance LAN IPs (per-site gateways) | `.env` SITE_*_GATEWAY vars + `smokeping/Targets` |
| Org SNMP community string | `.env` SNMP_COMMUNITY |
| Network names (sites) | SmokePing target groups, Prometheus file_sd labels |
| VLAN subnets | Prometheus file_sd target hints |
| All device inventory (MX, MS, MR) | `meraki-device-inventory.txt` (LibreNMS reference) |

```bash
# Dry run — preview without writing files
python3 meraki-pull-infrastructure.py --dry-run

# Non-interactive (auto-select first org)
python3 meraki-pull-infrastructure.py --auto

# Pass API key directly
python3 meraki-pull-infrastructure.py --api-key YOUR_KEY
```

Get your API key: Meraki Dashboard → Organization → Settings → Dashboard API access.

## File Structure

```
├── docker-compose.yml              # All 7 containers
├── .env.example                    # Configuration template
├── meraki-pull-infrastructure.py   # Auto-generate config from Meraki API
├── smokeping/
│   └── Targets                     # Ping targets (Experity, sites, internet)
├── prometheus/
│   ├── prometheus.yml              # Scrape config + file_sd
│   ├── alerts/
│   │   └── windows-fleet-alert-rules.yml
│   └── file_sd/
│       └── windows-fleet.json      # Windows machine inventory
└── grafana/
    └── provisioning/
        ├── datasources/
        │   └── prometheus-datasource.yml
        └── dashboards/
            └── dashboard-provisioning-config.yml
```

## Maintenance

```bash
# View logs
docker compose logs -f smokeping
docker compose logs -f librenms

# Update all images
docker compose pull && docker compose up -d

# Stop everything
docker compose down

# Stop and remove data (full reset)
docker compose down -v
```

## Related Guides

- [Network Monitoring (SmokePing + LibreNMS)](https://github.com/tedioussolutions/xdong/blob/main/guides/business-apps/network-monitoring-smokeping-librenms-meraki-snmp.md)
- [Windows Endpoint Monitoring (Prometheus Windows Exporter)](https://github.com/tedioussolutions/xdong/blob/main/guides/business-apps/windows-endpoint-monitoring-prometheus-exporter-grafana-fleet.md)
- [Experity Performance Triage](https://github.com/tedioussolutions/xdong/blob/main/guides/business-apps/experity-performance-triage-network-vs-hardware-runbook.md)
