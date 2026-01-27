# OOTT
Easy to setup and use network device discovery and alert system 

## What is it?
OOTT provides a service that runs behind the scenes and monitors your local network. It's most relevant features are:
* Scan network regularly using ARP probes
* Notify when a new device is found
* Notify when a device changed it's IP address or network interface vendor (based on its MAC address)
* Notify when a device came back online after a configurable period of being offline

OOTT can be installed as a NixOS module (using flakes) or as a docker image, see below for instructions on how to deploy and configure it.

# Installation & configuration
## Install OOTT using Docker
TODO

## Install OOTT using NixOS flakes
OOTT comes with a pre-built NixOS flake that you can integrate in your configuration. If you are not using flakes, well you should. If you still won't I guess you can use the [flake code](https://github.com/rzuasti/oott/tree/main/nix) as a baseline and write your own derivation.

To integrate the OOTT flake into your config in most cases you should do the following:
#### 1. Add OOTT to your inputs
In your `flake.nix` inputs section add OOTT:
```
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
```
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

## Configuration options
The system configuration is centralized in a single config file, you can use TOML, JSON or YAML to write it.

If you are using the provided NixOS flake you should set all the options via nix in the service definition (see above).

If you are using Docker I recommend writing the config using TOML, [here](https://github.com/rzuasti/oott/blob/main/sample_oott.toml) is a sample with all the supported options.

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
