{
  description = "OOTT - An easy to setup and use network device monitoring service";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    # System types to support.
    supportedSystems = ["x86_64-linux"];

    # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    # Nixpkgs instantiated for supported system types.
    nixpkgsFor = forAllSystems (system: import nixpkgs {inherit system;});

    version = "0.0.1";
    pname = "oott";
  in {
    packages = forAllSystems (system: let
      pkgs = nixpkgsFor.${system};
    in {
      ${pname} = pkgs.rustPlatform.buildRustPackage rec {
        inherit pname;
        inherit version;
        src = ./.;
        cargoLock = ./Cargo.lock;
      };
    });
  };
}
