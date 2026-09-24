{
  description = "nixos flake";

  inputs = {
    # Keep personal machines and Andreas's PC independently updatable.
    nixpkgs-personal.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-andreas.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ self, nixpkgs-personal, nixpkgs-andreas, ... }:
    let
      overlay = final: prev: {
        betterbird = prev.callPackage ./packages/betterbird/package.nix { };
        android-studio-flutter = prev.callPackage ./packages/android-studio-wrapper.nix { };
        qsync = prev.callPackage ./packages/qsync.nix { };
        # Rename "SPR 532" -> "SPR532" in the ccid driver plist so that
        # tk-safe's epa-wrapper whitelist (which checks for "SPR532") matches.
        ccid = prev.ccid.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            sed -i 's/SCM Microsystems Inc\. SPR 532/SCM Microsystems Inc. SPR532/g' \
              $out/pcsc/drivers/ifd-ccid.bundle/Contents/Info.plist
          '';
        });
      };
    in
    rec {
      nixosConfigurations = {
        pc = nixpkgs-personal.lib.nixosSystem {
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
        laptop = nixpkgs-personal.lib.nixosSystem {
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
        andreas-pc = nixpkgs-andreas.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            { nixpkgs.overlays = [ overlay ]; }
            ./custom/andreas-pc.nix
            ./hardware/andreas-pc.nix
            { networking.hostName = "andreas-pc"; }
          ];
        };
      };

      # Development shells
      devShells.x86_64-linux =
        let
          pkgs = import nixpkgs-personal {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
        in
        {
          flutter = import ./packages/flutter-shell.nix { inherit pkgs; };
        };
    };
}
