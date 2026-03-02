#!/usr/bin/env python3
"""
Pull real infrastructure data from Meraki Dashboard API and generate
stack configuration files (.env, SmokePing Targets, Prometheus file_sd).

Usage:
    export MERAKI_API_KEY=your-api-key-here
    python3 meraki-pull-infrastructure.py

    # Or pass key directly:
    python3 meraki-pull-infrastructure.py --api-key YOUR_KEY

    # Non-interactive (auto-select first org, generate all):
    python3 meraki-pull-infrastructure.py --auto

    # Dry run (print what would be generated, don't write files):
    python3 meraki-pull-infrastructure.py --dry-run

Generates:
    .env                                  — populated with real gateway IPs, SNMP settings
    smokeping/Targets                     — real site names and gateway IPs
    prometheus/file_sd/windows-fleet.json — per-site target groups with subnet placeholders
    meraki-device-inventory.txt           — full device list for LibreNMS import reference

Meraki API docs: https://developer.cisco.com/meraki/api-v1/
"""

import argparse
import json
import os
import secrets
import string
import sys
import textwrap
import urllib.error
import urllib.request
from datetime import datetime

BASE_URL = "https://api.meraki.com/api/v1"


# ── Meraki API client (stdlib only) ─────────────────────────────


def meraki_get(path, api_key):
    """GET request to Meraki Dashboard API. Returns parsed JSON."""
    url = f"{BASE_URL}{path}"
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "X-Cisco-Meraki-API-Key": api_key,  # Legacy header, kept for compat
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode() if e.fp else ""
        print(f"  API error: {e.code} {e.reason} — {path}")
        if e.code == 401:
            print("  Check your MERAKI_API_KEY — it may be invalid or expired.")
        if body:
            print(f"  Response: {body[:200]}")
        return None
    except urllib.error.URLError as e:
        print(f"  Network error: {e.reason} — {path}")
        return None


def pick_one(items, label, name_key="name", auto=False):
    """Interactive picker. Returns selected item or None."""
    if not items:
        print(f"  No {label} found.")
        return None
    if len(items) == 1 or auto:
        chosen = items[0]
        print(f"  Selected {label}: {chosen.get(name_key, 'unknown')}")
        return chosen
    print(f"\n  Available {label}:")
    for i, item in enumerate(items, 1):
        print(f"    {i}. {item.get(name_key, 'unknown')}")
    while True:
        try:
            choice = int(input(f"  Select {label} [1-{len(items)}]: "))
            if 1 <= choice <= len(items):
                return items[choice - 1]
        except (ValueError, EOFError):
            pass
        print(f"  Enter a number 1-{len(items)}")


def generate_password(length=24):
    """Generate a random password for service credentials."""
    chars = string.ascii_letters + string.digits
    return "".join(secrets.choice(chars) for _ in range(length))


# ── Data collection ──────────────────────────────────────────────


def collect_infrastructure(api_key, auto=False):
    """Query Meraki API and return structured infrastructure data."""
    print("Connecting to Meraki Dashboard API...")

    # 1. Organizations
    orgs = meraki_get("/organizations", api_key)
    if not orgs:
        return None
    org = pick_one(orgs, "organization", auto=auto)
    if not org:
        return None
    org_id = org["id"]
    print(f"  Organization: {org['name']} (ID: {org_id})")

    # 2. SNMP settings
    print("\nFetching SNMP settings...")
    snmp = meraki_get(f"/organizations/{org_id}/snmp", api_key)
    snmp_community = None
    if snmp:
        if snmp.get("v2cEnabled"):
            snmp_community = snmp.get("v2CommunityString", "")
            print("  SNMP v2c enabled, community string found")
        elif snmp.get("v3Enabled"):
            print(f"  SNMP v3 enabled (v3 auth user: {snmp.get('v3AuthUser', 'N/A')})")
            print("  Note: v3 credentials must be configured manually in LibreNMS")
        else:
            print(
                "  SNMP not enabled on this org — enable in Meraki Dashboard → Organization → Settings → SNMP"
            )

    # 3. Networks
    print("\nFetching networks...")
    networks = meraki_get(f"/organizations/{org_id}/networks", api_key)
    if not networks:
        return None
    # Filter to networks with appliance (MX) — these are our sites
    site_networks = [n for n in networks if "appliance" in n.get("productTypes", [])]
    all_networks = networks
    print(
        f"  Found {len(networks)} networks, {len(site_networks)} with MX appliance (sites)"
    )

    # 4. Devices and VLANs per site
    sites = []
    all_devices = []
    for net in site_networks:
        net_id = net["id"]
        net_name = net["name"]
        print(f"\n  Site: {net_name}")

        # Devices in this network
        devices = meraki_get(f"/networks/{net_id}/devices", api_key) or []
        all_devices.extend(devices)

        # Find MX appliance — its LAN IP is the gateway
        mx_devices = [d for d in devices if d.get("model", "").startswith("MX")]
        gateway_ip = None
        mx_serial = None
        if mx_devices:
            mx = mx_devices[0]
            mx_serial = mx["serial"]
            gateway_ip = mx.get("lanIp")
            print(
                f"    MX: {mx.get('model')} (serial: {mx_serial}, LAN IP: {gateway_ip})"
            )

        # If no lanIp on device, try VLANs
        if not gateway_ip:
            vlans = meraki_get(f"/networks/{net_id}/appliance/vlans", api_key)
            if vlans:
                # Use the first VLAN's applianceIp as gateway
                for vlan in vlans:
                    if vlan.get("applianceIp"):
                        gateway_ip = vlan["applianceIp"]
                        print(f"    Gateway from VLAN {vlan.get('id')}: {gateway_ip}")
                        break

        # Count device types
        switches = [d for d in devices if d.get("model", "").startswith("MS")]
        aps = [d for d in devices if d.get("model", "").startswith("MR")]
        print(
            f"    Devices: {len(mx_devices)} MX, {len(switches)} switches, {len(aps)} APs"
        )

        # Try to get subnet info from VLANs (for windows fleet target hints)
        subnets = []
        vlans = meraki_get(f"/networks/{net_id}/appliance/vlans", api_key)
        if vlans:
            for vlan in vlans:
                subnet = vlan.get("subnet")
                if subnet:
                    subnets.append(
                        {
                            "id": vlan.get("id"),
                            "name": vlan.get("name", f"VLAN {vlan.get('id')}"),
                            "subnet": subnet,
                            "gateway": vlan.get("applianceIp"),
                        }
                    )

        sites.append(
            {
                "name": net_name,
                "network_id": net_id,
                "gateway_ip": gateway_ip,
                "mx_serial": mx_serial,
                "devices": devices,
                "switch_count": len(switches),
                "ap_count": len(aps),
                "subnets": subnets,
            }
        )

    return {
        "org": org,
        "snmp_community": snmp_community,
        "snmp_raw": snmp,
        "sites": sites,
        "all_devices": all_devices,
        "all_networks": all_networks,
    }


# ── File generators ──────────────────────────────────────────────


def generate_env(data):
    """Generate .env content from Meraki infrastructure data."""
    sites = data["sites"]
    snmp = data["snmp_community"] or "changeme-snmp-community"

    # Map sites to gateway vars
    gw_lines = []
    if sites:
        gw_lines.append(
            f"SITE_MAIN_GATEWAY={sites[0].get('gateway_ip') or '192.168.1.1'}"
        )
        for i, site in enumerate(sites[1:], 2):
            gw_ip = site.get("gateway_ip") or "0.0.0.0"
            gw_lines.append(f"SITE{i}_GATEWAY={gw_ip}")
        # Pad to at least 4 sites
        for i in range(len(sites) + 1, 5):
            gw_lines.append(f"SITE{i}_GATEWAY=0.0.0.0")
    else:
        gw_lines = [
            "SITE_MAIN_GATEWAY=192.168.1.1",
            "SITE2_GATEWAY=0.0.0.0",
            "SITE3_GATEWAY=0.0.0.0",
            "SITE4_GATEWAY=0.0.0.0",
        ]

    # Site name comments
    site_comments = []
    for i, site in enumerate(sites):
        label = "Main site" if i == 0 else f"Site {i + 1}"
        site_comments.append(f"# {label}: {site['name']}")

    db_pass = generate_password()
    grafana_pass = generate_password(16)

    return textwrap.dedent(f"""\
        # Experity Fleet Monitoring Stack — Environment Configuration
        # Generated from Meraki Dashboard API on {datetime.now().strftime("%Y-%m-%d %H:%M")}
        # Organization: {data["org"]["name"]}

        # ─── General ────────────────────────────────────────────────────────
        TZ=America/Denver
        PUID=1000
        PGID=1000

        # ─── Meraki API (used by meraki-pull-infrastructure.py) ─────────────
        # MERAKI_API_KEY=your-key-here

        # ─── Experity Targets ──────────────────────────────────────────────
        EXPERITY_APP_HOST=app.experity.com
        EXPERITY_LOGIN_HOST=login.experity.com

        # ─── Site Gateways (from Meraki Dashboard API) ───────────────────
        {chr(10).join(site_comments)}
        {chr(10).join(gw_lines)}

        # ─── SmokePing ─────────────────────────────────────────────────────
        SMOKEPING_PORT=8080

        # ─── LibreNMS ──────────────────────────────────────────────────────
        LIBRENMS_PORT=8000
        LIBRENMS_DB_PASSWORD={db_pass}
        LIBRENMS_DB_NAME=librenms
        LIBRENMS_DB_USER=librenms
        LIBRENMS_DB_HOST=librenms-db
        LIBRENMS_APP_URL=http://localhost:8000
        SNMP_COMMUNITY={snmp}

        # ─── Prometheus ────────────────────────────────────────────────────
        PROMETHEUS_PORT=9090
        PROMETHEUS_RETENTION=15d
        PROMETHEUS_SERVER_IP={sites[0].get("gateway_ip", "192.168.1.10").rsplit(".", 1)[0] + ".10" if sites else "192.168.1.10"}

        # ─── Grafana ───────────────────────────────────────────────────────
        GRAFANA_PORT=3000
        GRAFANA_ADMIN_PASSWORD={grafana_pass}

        # ─── Windows Exporter Targets ──────────────────────────────────────
        # Add your Windows machines here (port 9182)
        # Or edit prometheus/file_sd/windows-fleet.json directly for >5 machines
        WIN_TARGET_1=REPLACE_WITH_WINDOWS_IP:9182
        WIN_TARGET_2=REPLACE_WITH_WINDOWS_IP:9182
        WIN_TARGET_3=REPLACE_WITH_WINDOWS_IP:9182
    """)


def generate_smokeping_targets(data):
    """Generate SmokePing Targets file from Meraki infrastructure data."""
    sites = data["sites"]

    lines = [
        "*** Targets ***",
        "",
        "probe = FPing",
        "",
        "menu = Top",
        f"title = {data['org']['name']} — Network Latency Monitor",
        "remark = Auto-generated from Meraki Dashboard API",
        "",
        "+ Experity",
        "menu = Experity Cloud",
        "title = Experity Cloud Services",
        "",
        "++ App",
        "menu = Experity App",
        "title = Experity Application Server",
        "host = app.experity.com",
        "",
        "++ Login",
        "menu = Experity Login",
        "title = Experity Login Portal",
        "host = login.experity.com",
        "",
        "+ Internet",
        "menu = Internet Health",
        "title = Internet Connectivity Baseline",
        "",
        "++ GoogleDNS",
        "menu = Google DNS",
        "title = Google Public DNS (baseline)",
        "host = 8.8.8.8",
        "",
        "++ CloudflareDNS",
        "menu = Cloudflare DNS",
        "title = Cloudflare Public DNS",
        "host = 1.1.1.1",
        "",
        "+ Sites",
        "menu = Site Gateways",
        "title = Multi-Site VPN Gateway Latency",
    ]

    for i, site in enumerate(sites):
        # Sanitize name for SmokePing (alphanumeric + underscore only)
        safe_name = "".join(c if c.isalnum() else "_" for c in site["name"])
        safe_name = safe_name.strip("_")[:20]
        gw = site.get("gateway_ip")
        if not gw:
            continue
        label = "Main Site" if i == 0 else site["name"]
        vpn_note = " (LAN)" if i == 0 else " (via VPN)"

        lines.extend(
            [
                "",
                f"++ {safe_name}",
                f"menu = {label}",
                f"title = {site['name']} Gateway{vpn_note}",
                f"host = {gw}",
            ]
        )

    lines.append("")
    return "\n".join(lines)


def generate_file_sd(data):
    """Generate Prometheus file_sd JSON from Meraki site/subnet data."""
    entries = []
    for i, site in enumerate(data["sites"]):
        safe_slug = "".join(
            c if c.isalnum() or c == "-" else "-" for c in site["name"].lower()
        )
        # Use first subnet to hint at target range, or use gateway subnet
        hint_base = None
        if site.get("subnets"):
            # Use first VLAN's gateway as base
            gw = site["subnets"][0].get("gateway")
            if gw:
                hint_base = gw.rsplit(".", 1)[0]
        elif site.get("gateway_ip"):
            hint_base = site["gateway_ip"].rsplit(".", 1)[0]

        if hint_base:
            targets = [f"{hint_base}.101:9182", f"{hint_base}.102:9182"]
        else:
            targets = ["REPLACE_WITH_IP:9182"]

        entries.append(
            {
                "targets": targets,
                "labels": {
                    "site": safe_slug,
                    "location": site["name"],
                },
            }
        )

    return json.dumps(entries, indent=2) + "\n"


def generate_device_inventory(data):
    """Generate a text inventory of all Meraki devices for LibreNMS reference."""
    lines = [
        f"# Meraki Device Inventory — {data['org']['name']}",
        f"# Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        f"# Total devices: {len(data['all_devices'])}",
        "#",
        "# Use this list to verify LibreNMS auto-discovery found all devices.",
        "# Add devices manually in LibreNMS if auto-discovery misses them.",
        "#",
        f"# {'Model':<16} {'Name':<30} {'Serial':<16} {'LAN IP':<16} {'Network'}",
        f"# {'-' * 14}   {'-' * 28}   {'-' * 14}   {'-' * 14}   {'-' * 20}",
    ]

    for site in data["sites"]:
        lines.append(f"\n# --- {site['name']} ({len(site['devices'])} devices) ---")
        for dev in sorted(site["devices"], key=lambda d: d.get("model", "")):
            model = dev.get("model", "unknown")
            name = dev.get("name", dev.get("serial", "unnamed"))[:28]
            serial = dev.get("serial", "N/A")
            lan_ip = dev.get("lanIp", "N/A")
            lines.append(
                f"  {model:<16} {name:<30} {serial:<16} {lan_ip:<16} {site['name']}"
            )

    lines.append("")
    return "\n".join(lines)


# ── Main ─────────────────────────────────────────────────────────


def main():
    parser = argparse.ArgumentParser(
        description="Pull Meraki infrastructure data and generate stack config files."
    )
    parser.add_argument(
        "--api-key", help="Meraki API key (or set MERAKI_API_KEY env var)"
    )
    parser.add_argument(
        "--auto", action="store_true", help="Non-interactive: auto-select first org"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print generated config, don't write files",
    )
    args = parser.parse_args()

    api_key = args.api_key or os.environ.get("MERAKI_API_KEY")
    if not api_key:
        print("Error: Meraki API key required.")
        print("  Set MERAKI_API_KEY environment variable, or pass --api-key YOUR_KEY")
        print(
            "  Get your key: Meraki Dashboard → Organization → Settings → Dashboard API access"
        )
        sys.exit(1)

    # Collect data from Meraki API
    data = collect_infrastructure(api_key, auto=args.auto)
    if not data:
        print(
            "\nFailed to collect infrastructure data. Check API key and network connectivity."
        )
        sys.exit(1)

    # Summary
    print(f"\n{'=' * 60}")
    print(f"Organization: {data['org']['name']}")
    print(f"Sites: {len(data['sites'])}")
    print(f"Total devices: {len(data['all_devices'])}")
    print(f"SNMP: {'v2c enabled' if data['snmp_community'] else 'not configured'}")
    for site in data["sites"]:
        gw = site.get("gateway_ip", "unknown")
        print(
            f"  {site['name']}: gateway={gw}, {site['switch_count']} switches, {site['ap_count']} APs"
        )
    print(f"{'=' * 60}")

    # Generate files
    env_content = generate_env(data)
    targets_content = generate_smokeping_targets(data)
    file_sd_content = generate_file_sd(data)
    inventory_content = generate_device_inventory(data)

    if args.dry_run:
        print("\n── .env ──")
        print(env_content)
        print("\n── smokeping/Targets ──")
        print(targets_content)
        print("\n── prometheus/file_sd/windows-fleet.json ──")
        print(file_sd_content)
        print("\n── meraki-device-inventory.txt ──")
        print(inventory_content)
        print("\nDry run complete — no files written.")
        return

    # Write files
    files_written = []

    with open(".env", "w") as f:
        f.write(env_content)
    files_written.append(".env")

    with open("smokeping/Targets", "w") as f:
        f.write(targets_content)
    files_written.append("smokeping/Targets")

    with open("prometheus/file_sd/windows-fleet.json", "w") as f:
        f.write(file_sd_content)
    files_written.append("prometheus/file_sd/windows-fleet.json")

    with open("meraki-device-inventory.txt", "w") as f:
        f.write(inventory_content)
    files_written.append("meraki-device-inventory.txt")

    print("\nFiles written:")
    for path in files_written:
        print(f"  ✓ {path}")

    print("\nNext steps:")
    print(
        "  1. Review .env — set LIBRENMS_DB_PASSWORD, GRAFANA_ADMIN_PASSWORD if needed"
    )
    print(
        "  2. Edit prometheus/file_sd/windows-fleet.json — replace placeholder IPs with actual Windows machines"
    )
    print("  3. Run: bash validate-stack-config.sh")
    print("  4. Run: docker compose up -d")
    if not data["snmp_community"]:
        print("  5. Enable SNMP in Meraki Dashboard → Organization → Settings → SNMP")


if __name__ == "__main__":
    main()
