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
  options.services.oott = {
    enable = mkEnableOption "Enable oott as a service";

    package = mkOption {
      type = types.package;
      default = self.packages.${system}.oott;
      description = "oott package to use";
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
        # ExecStart = "${cfg.package}/bin/oott ${
        #   builtins.toFile "oott.toml"
        #   (generators.toTOML {} cfg)
        # }";
        ExecStart = "${cfg.package}/bin/oott";
        ProtectHome = "read-only";
        Restart = "on-failure";
        Type = "exec";
      };
    };
  };
}
