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
      type = types.str;
      description = "Network interface to use for scans";
      default = "eno1";
    };
    log.level = mkOption {
      type = types.str;
      description = "Log level for the oott service";
      default = "info";
    };
    timings.wait_between_scans = mkOption {
      type = types.str;
      description = "Wait time between scans. This does not include the scan time.";
      default = "15m";
    };
    timings.arp_sender_timeout = mkOption {
      type = types.str;
      description = "If the ARP sender process takes longer than this it will be stopped (for a class C network - 254 IPs - it should take less than a minute).";
      default = "1m";
    };
    timings.arp_scan_duration = mkOption {
      type = types.str;
      description = "How long to wait for response packets on each scan (5m to 10m is a good timeframe for a class B or C network).";
      default = "10m";
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
