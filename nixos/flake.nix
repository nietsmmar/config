{
  description = "nixos flake";

  inputs = {
    nixpkgs = { url = "github:NixOS/nixpkgs/nixos-unstable"; };
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      overlay = final: prev: {
        betterbird = prev.callPackage ./packages/betterbird/package.nix { };
        android-studio-flutter = prev.callPackage ./packages/android-studio-wrapper.nix { };
      };
    in
    rec {
      nixosConfigurations = {
        pc = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            { nixpkgs.overlays = [ overlay ]; }
            ./configuration.nix
            ./custom/pc.nix
            ./hardware/pc.nix
            { networking.hostName = "pc"; }
          ];
        };
        laptop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            { nixpkgs.overlays = [ overlay ]; }
            ./configuration.nix
            ./custom/laptop.nix
            ./hardware/laptop.nix
            { networking.hostName = "laptop"; }
          ];
        };
      };

      # Development shells
      devShells.x86_64-linux =
        let
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
        in
        {
          flutter = import ./packages/flutter-shell.nix { inherit pkgs; };
        };
    };
}
