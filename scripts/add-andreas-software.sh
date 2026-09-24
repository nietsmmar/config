#!/usr/bin/env bash

set -euo pipefail

config_dir="${CONFIG:-$HOME/dev/config}"
host_config="$config_dir/nixos/custom/andreas-pc.nix"
marker="# ANDREAS_SOFTWARE_MARKER"

usage() {
  echo "Usage: add PACKAGE [PACKAGE ...]"
  echo "Example: add spotify"
}

if (( $# == 0 )); then
  usage
  exit 2
fi

if [[ ! -f "$host_config" ]]; then
  echo "Error: cannot find $host_config" >&2
  exit 1
fi

if ! grep -Fq "$marker" "$host_config"; then
  echo "Error: package insertion marker is missing from $host_config" >&2
  exit 1
fi

packages=()
for package in "$@"; do
  if [[ ! "$package" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*$ ]]; then
    echo "Error: '$package' is not a valid Nix package attribute." >&2
    exit 2
  fi

  if grep -Eq "^[[:space:]]+${package//./\\.}[[:space:]]*(#.*)?$" "$host_config"; then
    echo "Already installed: $package"
  else
    echo "Checking package: $package"
    if ! nix eval --raw \
      "$config_dir/nixos#nixosConfigurations.andreas-pc.pkgs.${package}.drvPath" \
      >/dev/null 2>&1; then
      echo "Error: '$package' is not a package in the andreas-pc nixpkgs revision." >&2
      echo "Search for the correct name at https://search.nixos.org/packages" >&2
      exit 1
    fi
    packages+=("$package")
  fi
done

if (( ${#packages[@]} == 0 )); then
  echo "Nothing to add."
  exit 0
fi

temp_file="$(mktemp "${host_config}.XXXXXX")"
trap 'rm -f "$temp_file"' EXIT

awk -v marker="$marker" -v packages="${packages[*]}" '
  { print }
  index($0, marker) {
    count = split(packages, package, " ")
    for (i = 1; i <= count; i++) {
      print "    " package[i]
    }
  }
' "$host_config" > "$temp_file"

chmod --reference="$host_config" "$temp_file"
mv "$temp_file" "$host_config"
trap - EXIT

printf 'Added to andreas-pc.nix:'
printf ' %s' "${packages[@]}"
printf '\nRebuilding andreas-pc...\n'

# This is the command behind the interactive `nrbpc` alias.
sudo nixos-rebuild switch --flake "$config_dir/nixos#andreas-pc"
