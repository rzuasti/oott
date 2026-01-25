{overlays}: {
  simple-go-server = import ./oott-service.nix;

  overlayNixpkgsForThisInstance = {pkgs, ...}: {
    nixpkgs = {
      inherit overlays;
    };
  };
}
