# OOTT
Easy to setup and use network device discovery and alert system

Licensed under AGPL v3. See [LICENSE](LICENSE).

* [What is OOTT?](#what-is-oott)
* [Getting started](#getting-started)
  * [Simple installation with Docker](#simple-installation-with-docker)
  * [Using the mobile apps](#using-the-mobile-apps)
* [Deeper dive](#deeper-dive)
  * [Installing OOTT as a Nix flake](#installing-oott-as-a-nix-flake)
  * [Full list of configuration options](#full-list-of-configuration-options)
  * [Using HTTPS and domain names with the mobile apps](#using-https-and-domain-names-with-the-mobile-apps)
* [Things to keep in mind](#things-to-keep-in-mind)
  * [Storage considerations](#storage-considerations)
  * [Privileges and network ports](#privileges-and-network-ports)

## What is OOTT?
OOTT runs behind the scenes and monitors your local network, notifying you when something changes. Its most relevant features are:
* Scans the network regularly using ARP probes, with additional mDNS, SSDP, DHCP and (optionally) SNMP discovery
* Notifies you when a new device is found
* Notifies you when a device changes its IP address or network interface vendor (based on its MAC address)
* Notifies you when a device comes back online after a configurable period of being offline

You configure and browse the data it collects through a companion app available on the web, desktop, iOS and Android.

## Getting started

### Simple installation with Docker
This is the quickest way to get OOTT running. OOTT is published on Docker Hub as a pre-built image, [`rzuasti/oott`](https://hub.docker.com/repository/docker/rzuasti/oott/general), and the steps below get you to a running service with the smallest possible configuration.

You need somewhere on the host to store the configuration file and the database (OOTT uses SQLite, so the database folder should be on local — not remote — storage):
```bash
mkdir -p /docker/oott/config
mkdir -p /docker/oott/db
```
The user that runs Docker needs read access to the config folder and read/write access to the db folder. You can use any paths you like as long as you keep the volume mappings below in sync.

Create a minimal `oott.toml` at `/docker/oott/config/oott.toml`:
```toml
[database]
path = "/db/oott.db" # Must be "/db/oott.db" for the Docker image (the mounted volume)

[web_server]
api_key = "CHANGE_ME" # API key the app uses to talk to the backend — change this!

[notifications]
method = "pushover" # Use "none" to only log notifications instead of sending them

[notifications.pushover]
token = ""    # Your Pushover application token
user_key = "" # Your Pushover user key
```
This is enough to start the service; every other option falls back to a sensible default. See [Full list of configuration options](#full-list-of-configuration-options) for everything you can tune, and the [full sample config](https://github.com/rzuasti/oott/blob/main/examples/sample_oott.toml) for a commented, all-options file.

Create a `docker-compose.yml` at `/docker/oott/docker-compose.yml`:
```yaml
name: oott

services:
  oott:
    image: rzuasti/oott:latest
    volumes:
      - /docker/oott/config:/config
      - /docker/oott/db:/db
    network_mode: host
```
Host networking is required so OOTT can see the multicast and broadcast traffic its scanners rely on (see [Privileges and network ports](#privileges-and-network-ports)).

Start the service from where you placed the compose file:
```bash
docker compose up -d
```
That's it. Check that everything is running with `docker ps`, and follow the logs with `docker logs CONTAINER_ID -f`.

### Using the mobile apps
The OOTT app (web, desktop, iOS and Android) talks to the backend exclusively over its REST API on port `3000`. Open the app's settings and point it at your backend's address on the local network over HTTP, for example `http://192.168.1.50:3000`, using the API key you set in `web_server.api_key`.

This is the simplest setup and needs no extra infrastructure, but it only works while your phone is on the same local network as the backend.

> [!IMPORTANT]
> On iOS, the direct HTTP connection only works when you use the backend's **private-range IP address** (`192.168.x.x`, `10.x.x.x`, `172.16–31.x.x`) or a `*.local` (mDNS/Bonjour) name. A custom internal domain (e.g. `oott.mylan.com`) served over plain HTTP is blocked by iOS App Transport Security, even when it resolves to a private IP. Use the IP address directly, or set up HTTPS.

> [!NOTE]
> The first time the iOS app reaches your backend on the local network, iOS shows a one-time "find devices on your local network" prompt. This is expected — tap Allow to continue.

To use a domain name, or to reach the backend from outside the local network, set up TLS as described in [Using HTTPS and domain names with the mobile apps](#using-https-and-domain-names-with-the-mobile-apps).

## Deeper dive

### Installing OOTT as a Nix flake
OOTT comes with a pre-built NixOS flake that you can integrate into your configuration. If you are not using flakes you can use the [flake code](https://github.com/rzuasti/oott/tree/main/nix) as a baseline and write your own derivation.

To integrate the OOTT flake into your config you generally do three things: add OOTT to your inputs, add its module and overlay, then enable and configure the service.

**1. Add OOTT to your inputs** — in your `flake.nix` inputs section:
```nix
inputs = {
  ...
  oott = {
    url = "github:rzuasti/oott";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  ...
};
```

**2. Add the OOTT module and overlay** — in your `flake.nix` modules section:
```nix
...
modules = [
  ...
  oott.nixosModules.oott
  ({pkgs, ...}: {
    nixpkgs.overlays = [
      oott.overlays.default
      ];
  })
  ...
];
...
```

**3. Enable and configure OOTT** — in your `configuration.nix` (or an imported file). Set all options through the service definition; the keys mirror the config file options listed [below](#full-list-of-configuration-options):
```nix
{
  pkgs,
  ...
}
: {
  environment.systemPackages = with pkgs; [
    oott
  ];

  services.oott = {
    enable = true;
    database.path = "/var/lib/oott.db";
    # networking.interface = "eth0"; # Optional: auto-detected if not set
    log.level = "warn";
    arp_scanner.wait_between_scans = "30m";
    arp_scanner.sender_timeout = "1m";
    arp_scanner.scan_duration = "10m";
    notifications.method = "pushover";
    notifications.notify_when_not_seen_for = "1w";
    notifications.pushover.token = "YOUR API TOKEN GOES HERE";
    notifications.pushover.user_key = "YOUR USER TOKEN GOES HERE";
    retention.window = "365d";
    device_events.deduplication_window = "1m";
  };
}
```

### Full list of configuration options
The system configuration lives in a single config file, which you can write in TOML, JSON or YAML. With Docker, TOML is recommended — the [full sample config](https://github.com/rzuasti/oott/blob/main/examples/sample_oott.toml) lists every supported option with comments. With the Nix flake, set the same options through the service definition (see above).

Options marked **Required** have no built-in default and must be set in your config file. Everything else falls back to the default shown if you omit it.

|Option|Default value|Description|
|------|-------------|-----------|
|`database.path`|**Required**|Location of the system database. Must be `/db/oott.db` when using the Docker image.|
|`networking.interface`|auto-detected|Network interface to use for scans. Optional — if not set, the first non-loopback connected interface is used automatically.|
|`log.level`|`warn`|Log level to use (off, error, warn, info, debug, trace)|
|`web_server.ip_address`|`0.0.0.0`|Address the API and web UI bind to. Use `0.0.0.0` to bind all interfaces.|
|`web_server.port`|`3000`|Port the API and web UI listen on.|
|`web_server.api_key`|**Required**|API key the app must present to use the backend.|
|`arp_scanner.enabled`|`true`|Whether to run the ARP scanner. The whole `[arp_scanner]` section is optional; omit it to use the defaults below. Set to `false` to turn it off.|
|`arp_scanner.wait_between_scans`|`30m`|Time to wait between each network scan (you can express it in seconds, minutes, hours, etc. as a suffix - for example: 30s, 10m, 1h)|
|`arp_scanner.sender_timeout`|`1m`|If the ARP sender process takes longer than this it will be stopped (for a class C network - 254 IPs - it should take less than a minute)|
|`arp_scanner.scan_duration`|`10m`|How long to wait for response packets on each scan (5m to 10m is a good timeframe for a class B or C network)|
|`mdns_scanner.enabled`|`true`|Whether to run the mDNS/Bonjour scanner. Set to `false` to turn it off.|
|`mdns_scanner.probe_timeout`|`2s`|When an mDNS-discovered IP is not in the OS ARP cache, how long to wait for a targeted ARP probe reply to resolve its MAC address|
|`ssdp_scanner.enabled`|`true`|Whether to run the SSDP/UPnP scanner. Set to `false` to turn it off.|
|`ssdp_scanner.probe_timeout`|`2s`|When an SSDP/UPnP-discovered IP is not in the OS ARP cache, how long to wait for a targeted ARP probe reply to resolve its MAC address|
|`dhcp_scanner.enabled`|`true`|Whether to run the DHCP scanner. Set to `false` to turn it off.|
|`snmp_scanner.enabled`|`false`|Whether to run the SNMP scanner. The whole `[snmp_scanner]` section is optional and the scanner stays off unless you add it; once the section is present it defaults to `true`.|
|`snmp_scanner.target`|**Required**|SNMP agent to poll, as `host:port` (e.g. your gateway: `192.168.1.1:161`). The scanner reads the agent's ARP table over SNMPv2c — no local probing. Required when the `[snmp_scanner]` section is present.|
|`snmp_scanner.community`|**Required**|SNMPv2c read-only community string. Use a read-only community and never commit a real secret. Required when the `[snmp_scanner]` section is present.|
|`snmp_scanner.wait_between_scans`|`10m`|Time to wait between polls. Keep it well under the agent's ARP cache timeout so active devices aren't missed.|
|`snmp_scanner.timeout`|`5s`|Per-poll SNMP request timeout.|
|`notifications.method`|**Required**|For now just pushover, you can set this to "none" to avoid sending notifications (it will just log)|
|`notifications.notify_when_not_seen_for`|**Required**|Send a notification if a device comes back online after not being seen for this timeframe (you can use hours, weeks, etc.)|
|`notifications.pushover.token`|**Required**|Your pushover token goes here, just copy&paste from their website after creating the app (may be left empty when `method` is `none`)|
|`notifications.pushover.user_key`|**Required**|User key goes here, this is the account wide code for pushover (may be left empty when `method` is `none`)|
|`retention.window`|`365d`|How long to retain device events and notifications. Records older than this are purged daily. Accepts duration strings (e.g. `90d`, `1y`, `6m`).|
|`device_events.deduplication_window`|`1m`|Suppress duplicate device events: if the same scanner sees the same device (same MAC and IPv4) again within this window, only one event is recorded. Accepts duration strings (e.g. `30s`, `1m`, `5m`).|

### Using HTTPS and domain names with the mobile apps
To reach the backend through a domain name, or from outside the local network, put it behind a reverse proxy (nginx, Caddy, Traefik, …) that terminates TLS with a **valid certificate from a trusted CA** (for example [Let's Encrypt](https://letsencrypt.org/)), then point the app at the HTTPS URL (e.g. `https://oott.example.com`). This works on every platform — including iOS — with no further configuration.

Connect using the **domain name the certificate is issued for**, not an IP address. Self-signed certificates are not supported unless they are manually trusted on the device.

## Things to keep in mind

### Storage considerations
OOTT records a timestamped event for every device *sighting*. With the default scanners running, the main driver of storage is how often each scanner re-sights a device — capped by the deduplication window — multiplied by the number of devices and the retention window.

These figures assume the **default configuration** and the four scanners that are **on by default**: ARP, mDNS, SSDP and DHCP. The SNMP scanner is **disabled by default** (it has no universal target) and is therefore **not** included below — see the note at the end if you enable it. The estimates are **typical averages**, not worst case; real numbers are often lower because not every device participates in every protocol.

#### Typical events per device per day
| Scanner | Typical events / device / day | Why |
|---|---|---|
| ARP | ~36 | One sweep per 40-min cycle (`scan_duration` 10m + `wait_between_scans` 30m) |
| mDNS | ~48 | ≈ one recorded announcement every 30 min (devices that speak mDNS) |
| SSDP | ~48 | ≈ one `NOTIFY` refresh every 30 min (typical UPnP cache max-age) |
| DHCP | ~2 | Lease renewals only (hours-scale leases) |
| **Total** | **~134** | |

Bursts can't exceed the deduplication window: at `device_events.deduplication_window = 1m`, each scanner records at most one event per device per minute (≤1440/scanner/day).

#### Estimates by network size
Typical storage with the defaults (all four default scanners, `retention.window = 365d`):

| Network size | Active devices | Typical storage / year |
|---|---|---|
| Home | 20–50 | ~150–350 MB |
| Homelab | 50–100 | ~350–700 MB |
| Small office | 100–200 | ~0.7–1.4 GB |
| Medium office | 200–500 | ~1.4–3.5 GB |

The formula behind these numbers:

```
storage ≈ devices × events_per_device_per_day × 145 bytes × retention_days
```

where `145 bytes` covers the database row and its index entry, and `events_per_device_per_day` is the sum across enabled scanners (each capped at `86400 / deduplication_window_seconds`). For the defaults that sum is ~134, dominated by the three passive scanners.

#### Tuning to control storage
With the default scanners, the two biggest levers are the **retention window** (a linear multiplier on everything) and **how many scanners run**. Scan timing and the dedup window are secondary.

**Retention window** — `retention.window` sets how far back history is kept. Halving the window halves the storage. Useful reference points:

| `retention.window` | Use case |
|---|---|
| `30d` | Minimal footprint, recent activity only |
| `90d` | A quarter's worth of history |
| `180d` | Six months — good middle ground |
| `365d` | One year (default) |

**Disabling scanners** — each scanner you turn off removes its share. The three passive scanners (mDNS/SSDP/DHCP) account for ~98 of the ~134 events/device/day; turning them off leaves the ARP baseline of ~36/device/day (≈1.9 MB/device/year).

**ARP scan interval** — `arp_scanner.wait_between_scans` only affects the ARP share, so its overall effect is modest once the passive scanners are running:

| `wait_between_scans` | ARP events/device/day (10m scan) |
|---|---|
| `15m` | ~58 |
| `30m` (default) | ~36 |
| `1h` | ~21 |
| `2h` | ~11 |

**Event deduplication** — `device_events.deduplication_window` is a safety cap, not a routine lever. In typical operation each scanner reports well under one sighting per minute, so widening it changes little; its job is to bound chatty devices and announcement storms. Narrow it for finer-grained history (raises worst-case storage).

**Recommended starting points:**

| Network | Suggested change from defaults | Typical storage |
|---|---|---|
| Home / Homelab | None — defaults are fine | ~150–700 MB/yr |
| Small office | `retention.window = 180d` | ~0.35–0.7 GB |
| Medium office | `retention.window = 90d` (and consider disabling unused passive scanners) | ~0.35–0.9 GB |

> **SNMP scanner:** disabled by default and excluded from all figures above. If you enable it, add roughly `86400 / snmp_scanner.wait_between_scans` events/device/day (~144/day at the default 10m poll), capped by the dedup window.

### Privileges and network ports
OOTT binds to the following ports on the host where it runs:

|Port|Protocol|Configurable|Used by|
|----|--------|------------|-------|
|`3000`|TCP|Yes (`web_server.port`)|REST API and web UI|
|`5353`|UDP (multicast)|**No — fixed**|mDNS/Bonjour scanner|
|`1900`|UDP (multicast)|**No — fixed**|SSDP/UPnP scanner|
|`67`|UDP (broadcast)|**No — fixed**|DHCP scanner|

The mDNS (UDP `5353`), SSDP (UDP `1900`) and DHCP (UDP `67`) ports are fixed by their respective protocols and **cannot be changed**. They must be available on the server where OOTT runs.

OOTT binds these sockets with address/port reuse, so it can run alongside other responders already listening on them (for example `avahi` on `5353`, `minidlna` on `1900`, or a DHCP server/relay on `67`). However, the ports must not be blocked by a host firewall, and the corresponding multicast/broadcast traffic must be allowed to reach the host — otherwise the scanners will not discover any devices.

> [!IMPORTANT]
> OOTT needs elevated privileges: the ARP scanner requires raw-socket access, and port `67` is a privileged port. The pre-built Docker image and NixOS module already run with what they need.
>
> Under Docker, the scanners require **host networking** (or an equivalent setup that exposes the host's multicast and broadcast traffic to the container), as shown in the [Docker installation](#simple-installation-with-docker) above.
