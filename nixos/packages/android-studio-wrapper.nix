# /home/xunil/dev/config/nixos/packages/android-studio-wrapper.nix
{ pkgs }:

pkgs.writeShellScriptBin "android-studio" ''
  #!/usr/bin/env bash
  echo "Starting Android Studio in the flutter development environment..."

  # Run android-studio inside the flake-based devShell
  # Use the CONFIG environment variable which points to the config directory
  exec ${pkgs.nix}/bin/nix develop "''${CONFIG:-$HOME/dev/config}/nixos#flutter" --command android-studio "$@"
''