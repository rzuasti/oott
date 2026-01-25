{
  description = "OOTT - An easy to setup and use network device monitoring service";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    nix,
  }: let
    # System types to support.
    supportedSystems = ["x86_64-linux"];

    # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
    forEachSystem = nixpkgs.lib.genAttrs supportedSystems;

    # Package overlays to include
    overlayList = [self.overlays.default];

    # Nixpkgs instantiated for supported system types.
    pkgsBySystem = forEachSystem (system:
      import nixpkgs {
        inherit system;
        overlays = overlayList;
      });
  in rec {
    # A Nixpkgs overlay that provides a 'oott' package.
    overlays.default = final: prev: {oott = final.callPackage ./nix/package.nix {};};

    # Package definition
    packages = forEachSystem (system: {
      oott = pkgsBySystem.${system}.oott;
      default = pkgsBySystem.${system}.oott;
    });

    # Modules definition
    nixosModules = import ./nix/modules {overlays = overlayList;};
  };
}
