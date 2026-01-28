# OOTT
Easy to setup and use network device discovery and alert system 

[TOC]

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
