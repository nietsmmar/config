# /home/xunil/dev/config/nixos/packages/android-studio-wrapper.nix
{ pkgs }:

let
  # Path to the shell definition file.
  shellFile = ./flutter-shell.nix;
in
pkgs.writeShellScriptBin "android-studio" ''
  #!/usr/bin/env bash
  echo "Starting Android Studio in the flutter development environment..."

  # Run android-studio inside the environment defined by flutter-shell.nix
  exec ${pkgs.nix}/bin/nix-shell ${toString shellFile} --run "android-studio $@"
''