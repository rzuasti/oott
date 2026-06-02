{
  config,
  pkgs,
  lib ? pkgs.lib,
  ...
}:
with lib; let
  cfg = config.services.oott;
in {
  # Service options
  options.services.oott = rec {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to run the oott service
      '';
    };
    database.path = mkOption {
      type = types.path;
      description = "Full path to store the database at";
      default = "/var/lib/oott.db";
    };
    networking.interface = mkOption {
      type = types.nullOr types.str;
      description = "Network interface to use for scans. If not set, the first non-loopback connected interface is used automatically.";
      default = null;
    };
    log.level = mkOption {
      type = types.str;
      description = "Log level for the oott service";
      default = "info";
    };
    arp_scanner.enabled = mkOption {
      type = types.bool;
      description = "Whether to run the ARP scanner.";
      default = true;
    };
    arp_scanner.wait_between_scans = mkOption {
      type = types.str;
      description = "Wait time between scans. This does not include the scan time.";
      default = "30m";
    };
    arp_scanner.sender_timeout = mkOption {
      type = types.str;
      description = "If the ARP sender process takes longer than this it will be stopped (for a class C network - 254 IPs - it should take less than a minute).";
      default = "1m";
    };
    arp_scanner.scan_duration = mkOption {
      type = types.str;
      description = "How long to wait for response packets on each scan (5m to 10m is a good timeframe for a class B or C network).";
      default = "10m";
    };
    mdns_scanner.enabled = mkOption {
      type = types.bool;
      description = "Whether to run the mDNS/Bonjour scanner.";
      default = true;
    };
    mdns_scanner.probe_timeout = mkOption {
      type = types.str;
      description = "When an mDNS-discovered IP is not in the OS ARP cache, how long to wait for a targeted ARP probe reply to resolve its MAC address.";
      default = "2s";
    };
    ssdp_scanner.enabled = mkOption {
      type = types.bool;
      description = "Whether to run the SSDP/UPnP scanner.";
      default = true;
    };
    ssdp_scanner.probe_timeout = mkOption {
      type = types.str;
      description = "When an SSDP/UPnP-discovered IP is not in the OS ARP cache, how long to wait for a targeted ARP probe reply to resolve its MAC address.";
      default = "2s";
    };
    dhcp_scanner.enabled = mkOption {
      type = types.bool;
      description = "Whether to run the DHCP scanner.";
      default = true;
    };
    snmp_scanner.enabled = mkOption {
      type = types.bool;
      description = "Whether to run the SNMP scanner. Off by default; requires a target and community to be set.";
      default = false;
    };
    snmp_scanner.target = mkOption {
      type = types.str;
      description = "SNMP agent to poll, as host:port (e.g. the gateway: 192.168.1.1:161). The scanner reads its ARP table over SNMPv2c.";
      default = "";
    };
    snmp_scanner.community = mkOption {
      type = types.str;
      description = "SNMPv2c read-only community string. Use a read-only community and avoid committing real secrets.";
      default = "";
    };
    snmp_scanner.wait_between_scans = mkOption {
      type = types.str;
      description = "Wait time between SNMP polls. Keep it well under the agent's ARP cache timeout so active devices aren't missed.";
      default = "10m";
    };
    snmp_scanner.timeout = mkOption {
      type = types.str;
      description = "Per-poll SNMP request timeout.";
      default = "5s";
    };
    notifications.method = mkOption {
      type = types.str;
      description = "For now just pushover, you can set this to none to avoid sending notifications (it will just log).";
      default = "pushover";
    };
    notifications.notify_when_not_seen_for = mkOption {
      type = types.str;
      description = "Send a notification if a device comes back online after not being seen for this timeframe.";
      default = "1w";
    };
    notifications.pushover.token = mkOption {
      type = types.str;
      description = "Your pushover token goes here, just copy&paste from their website after creating the app.";
      default = "";
    };
    notifications.pushover.user_key = mkOption {
      type = types.str;
      description = "User key goes here, this is the account wide code for pushover.";
      default = "";
    };
    retention.window = mkOption {
      type = types.str;
      description = "How long to retain device events and notifications. Records older than this are purged daily. Accepts duration strings (e.g. 90d, 1y, 6m).";
      default = "365d";
    };
    device_events.deduplication_window = mkOption {
      type = types.str;
      description = "If the same scanner sees the same device (same MAC and IP) again within this window, only one device event is recorded. Keeps the events table from filling with near-identical rows. Accepts duration strings (e.g. 30s, 1m, 5m).";
      default = "1m";
    };
    web_server.ip_address = mkOption {
      type = types.str;
      description = "IP address to bind the web server (API and web UI) to. Use 0.0.0.0 to bind to all interfaces.";
      default = "0.0.0.0";
    };
    web_server.port = mkOption {
      type = types.port;
      description = "Port the web server listens on.";
      default = 3000;
    };
    web_server.api_key = mkOption {
      type = types.str;
      description = "API key required to access the system's API. Change this from the default empty value.";
      default = "";
    };
  };

  # Service implementation
  config = mkIf cfg.enable {
    environment.systemPackages = [pkgs.oott];
    systemd.services.oott = {
      description = "oott - network device scanner";
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        ExecStart = "${pkgs.oott}/bin/oott --config ${
          builtins.toFile "oott.json"
          (generators.toJSON {} cfg)
        }";
        ProtectHome = "read-only";
        Restart = "on-failure";
        Type = "exec";
      };
    };
  };
}
