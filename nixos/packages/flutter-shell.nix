# ~/dev/config/nixos/packages/flutter-shell.nix
# This file defines the development shell for the flutter project.
{ system ? builtins.currentSystem }:

let
  pkgs = import <nixpkgs> {
    inherit system;
    config.allowUnfree = true; # Allow unfree packages within this shell
  };
in
pkgs.mkShell {
  # These are the packages that will be available in the shell
  buildInputs = with pkgs; [
    clang
    cmake
    ninja
    pkg-config
    gtk3
    webkitgtk_4_1
    xorg.libX11
    util-linux.dev
    xorg.libXdmcp
    xorg.libXtst
    sysprof
    libepoxy
    android-studio
    pre-commit
  ];

  shellHook = ''
    export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [ pkgs.libepoxy ]}:$LD_LIBRARY_PATH
  '';
}
