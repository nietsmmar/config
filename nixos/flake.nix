{
  description = "nixos flake";

  inputs = {
    nixpkgs = { url = "github:NixOS/nixpkgs/nixos-unstable"; };
  };

  outputs = inputs@{ self, nixpkgs, ... }: rec { 
    nixosConfigurations = {
    pc = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
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
        ./configuration.nix
        ./custom/laptop.nix
        ./hardware/laptop.nix
       { networking.hostName = "laptop"; }
      ];
    };
  };
  };
}
