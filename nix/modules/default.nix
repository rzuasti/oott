{overlays}: {
  oott = import ./oott-service.nix;

  overlayNixpkgsForThisInstance = {pkgs, ...}: {
    nixpkgs = {
      inherit overlays;
    };
  };
}
