# OOTT
Easy to setup and use network device discovery and alert system 

* [What is it?](#what-is-it)
* [Installation & configuration](#installation-configuration)
  * [Install OOTT using Docker](#install-oott-using-docker)
  * [Install OOTT using NixOS flakes](#install-oott-using-nixos-flakes)
  * [Configuration options](#configuration-options)
* [Storage considerations](#storage-considerations)

## What is it?
OOTT provides a service that runs behind the scenes and monitors your local network. It's most relevant features are:
* Scan network regularly using ARP probes
* Notify when a new device is found
* Notify when a device changed it's IP address or network interface vendor (based on its MAC address)
* Notify when a device came back online after a configurable period of being offline

OOTT can be installed as a NixOS module (using flakes) or as a docker image, see below for instructions on how to deploy and configure it.

# Installation & configuration
## Install OOTT using Docker
OOTT is available on Docker Hub as a pre-built image [here](https://hub.docker.com/repository/docker/rzuasti/oott/general).
To use it I recommend using docker compose, you can find a sample compose file [here](https://github.com/rzuasti/oott/blob/main/examples/docker-compose.yml).

If you use our Docker Hub image and docker compose the steps you have to follow are:
1. Create a folder structure in your host
2. Create the configuration file
3. Create the `docker-compose.yml` file
4. Start the service

#### 1. Create a folder structure in your host
You need a place to store the docker-compose.yml file, the OOTT configuration file and the database that will store the application state:
```bash
mkdir -p /docker/oott/config
mkdir -p /docker/oott/db
```

You can choose whatever structure or locations you choose. Note that:
* The user that runs the docker process must have read access to the config folder and read/write access to the db folder
* OOTT uses SQLite and it doesn't really like remote access so the `db/` folder should be local to your docker host

#### 2. Create the configuration file
Create the `oott.toml` file (for example at `/docker/oott/config/oott.toml` in your docker host) and populate it with your preferences. You can use the [provided example](https://github.com/rzuasti/oott/blob/main/examples/sample_oott.toml) as baseline.

> [!IMPORTANT]
> The `database.path` option must always be set to `"/db/oott.db"` when using our docker image.

#### 3. Create the `docker-compose.yml` file
Create a docker compose file to run the container (for example at `/docker/oott/docker-compose.yml`), you can use the [provided example](https://github.com/rzuasti/oott/blob/main/examples/docker-compose.yml) as is or adjust it to match your environment.

#### 4. Start the service
Run `docker compose up -d` from where you placed your `docker-compose.yml` file and verify everything is running smoothly.

You can check the applications log using `docker logs CONTAINER_ID -f`, to see the active containers you can use `docker ps`.

## Install OOTT using NixOS flakes
OOTT comes with a pre-built NixOS flake that you can integrate in your configuration. If you are not using flakes, well you should. If you still won't I guess you can use the [flake code](https://github.com/rzuasti/oott/tree/main/nix) as a baseline and write your own derivation.

To integrate the OOTT flake into your config in most cases you should do the following:
1. Add OOTT to your inputs
2. Add the OOTT module and overlay
3. Enable and setup OOTT in your system configuration

#### 1. Add OOTT to your inputs
In your `flake.nix` inputs section add OOTT:
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

#### 2. Add the OOTT module and overlay
In your `flake.nix` modules section add the OOTT module and overlay:
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
#### 3. Enable and setup OOTT in your system configuration
Finally, in your `configuration.nix` (or in an import file) enable and configure OOTT (note that you should embed the following sections in your file appropriately):
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
    networking.interface = "eth0";
    log.level = "info";
    timings.wait_between_scans = "15m";
    timings.arp_sender_timeout = "20m";
    timings.arp_scan_duration = "30m";
    notifications.method = "pushover";
    notifications.notify_when_not_seen_for = "1w";
    notifications.pushover.token = "YOUR API TOKEN GOES HERE";
    notifications.pushover.user_key = "YOUR USER TOKEN GOES HERE";
    retention.window = "365d";
  };
}
```

## Configuration options
The system configuration is centralized in a single config file, you can use TOML, JSON or YAML to write it.

If you are using the provided NixOS flake you should set all the options via nix in the service definition (see above).

If you are using Docker I recommend writing the config using TOML, [here](https://github.com/rzuasti/oott/blob/main/examples/sample_oott.toml) is a sample with all the supported options.

### Options list
|Option|Sample value|Description|
|------|-------------|-----------|
|`database.path`|`/var/lib/oott.db`|Location of the system database|
|`networking.interface`|`eno1`|Network interface to use for scans|
|`log.level`|`info`|Log level to use (trace, debug, info, warn, error)|
|`timings.wait_between_scans`|`15m`|Time to wait between each network scan (you can express it in seconds, minutes, hours, etc. as a suffix - for example: 30s, 10m, 1h)|
|`timings.arp_sender_timeout`|`1m`|If the ARP sender process takes longer than this it will be stopped (for a class C network - 254 IPs - it should take less than a minute)|
|`timings.arp_scan_duration`|`10m`|How long to wait for response packets on each scan (5m to 10m is a good timeframe for a class B or C network)|
|`notifications.method`|`pushover`|For now just pushover, you can set this to "none" to avoid sending notifications (it will just log)|
|`notifications.notify_when_not_seen_for`|`1w`|Send a notification if a device comes back online after not being seen for this timeframe (you can use hours, weeks, etc.)|
|`notifications.pushover.token`||Your pushover token goes here, just copy&paste from their website after creating the app|
|`notifications.pushover.user_key`||User key goes here, this is the account wide code for pushover|
|`retention.window`|`365d`|How long to retain device events and notifications. Records older than this are purged daily. Accepts duration strings (e.g. `90d`, `1y`, `6m`). Defaults to one year.|

# Storage considerations
OOTT stores a timestamped event in the database for every device detected on every scan. Storage therefore scales with three factors: number of active devices, scan frequency, and the retention window.

## Estimates by network size

The figures below assume a 1-minute scan duration (`arp_scan_duration = 1m`) with a 1-minute wait between scans (`wait_between_scans = 1m`), giving 720 scans per day, and a 365-day retention window. Assume all devices are continuously online (worst case).

| Network size | Active devices | Storage / year |
|---|---|---|
| Home network | 20–50 | ~1–2 GB |
| Homelab | 50–100 | ~2–4 GB |
| Small office | 100–200 | ~4–7 GB |
| Medium office | 200–500 | ~7–18 GB |

The rough formula behind these numbers is:

```
storage ≈ devices × scans_per_day × 145 bytes × retention_days
```

where `145 bytes` covers the database row and its index entry, and `scans_per_day = 86400 / (scan_duration_seconds + wait_between_scans_seconds)`.

## Tuning scan timings and retention to control storage

Storage is directly proportional to scan frequency and retention window. The two main levers are:

**Scan interval** — `timings.wait_between_scans` is the most effective knob. Increasing it reduces scans per day linearly:

| `wait_between_scans` | Scans/day (with 1m scan) | Storage vs. 1m+1m |
|---|---|---|
| `1m` | 720 | 1× (baseline) |
| `4m` | 288 | 0.4× |
| `15m` | 90 | 0.12× |
| `30m` | 48 | 0.07× |

A 15-minute wait (the default) cuts storage to about one eighth of the worst-case figures above — the medium office drops from up to 18 GB to roughly 2 GB per year.

**Retention window** — `retention.window` sets how far back history is kept. Halving the window halves the storage. Useful reference points:

| `retention.window` | Use case |
|---|---|
| `30d` | Minimal footprint, recent activity only |
| `90d` | A quarter's worth of history |
| `180d` | Six months — good middle ground |
| `365d` | One year (default) |

**Recommended starting points by network type:**

| Network | `wait_between_scans` | `retention.window` | Approx. storage |
|---|---|---|---|
| Home | `15m` | `365d` | ~100–250 MB |
| Homelab | `5m` | `180d` | ~350–700 MB |
| Small office | `5m` | `90d` | ~175–350 MB |
| Medium office | `15m` | `90d` | ~175–450 MB |
