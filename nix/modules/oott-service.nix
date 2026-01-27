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
  };

  # Service implementation
  config = mkIf cfg.enable {
    environment.systemPackages = [pkgs.oott];
    systemd.services.oott = {
      description = "oott - network device scanner";
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        ExecStart = "${pkgs.oott}/bin/oott ${
          builtins.toFile "oott.json"
          (generators.toJSON {} cfg)
        }";
        # ExecStart = "${pkgs.oott}/bin/oott";
        ProtectHome = "read-only";
        Restart = "on-failure";
        Type = "exec";
      };
    };
  };
}
