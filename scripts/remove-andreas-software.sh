#!/usr/bin/env bash

set -euo pipefail

config_dir="${CONFIG:-$HOME/dev/config}"
host_config="$config_dir/nixos/custom/andreas-pc.nix"

usage() {
  echo "Usage: remove PACKAGE [PACKAGE ...]"
  echo "Example: remove spotify"
}

if (( $# == 0 )); then
  usage
  exit 2
fi

if [[ ! -f "$host_config" ]]; then
  echo "Error: cannot find $host_config" >&2
  exit 1
fi

packages=()
for package in "$@"; do
  if [[ ! "$package" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*$ ]]; then
    echo "Error: '$package' is not a valid Nix package attribute." >&2
    exit 2
  fi

  if awk -v wanted="$package" '
    /environment\.systemPackages = with pkgs; \[/ { in_packages = 1; next }
    in_packages && /^[[:space:]]*\];/ { exit }
    in_packages {
      line = $0
      sub(/[[:space:]]*#.*/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line == wanted) found = 1
    }
    END { exit !found }
  ' "$host_config"; then
    packages+=("$package")
  else
    echo "Not installed: $package"
  fi
done

if (( ${#packages[@]} == 0 )); then
  echo "Nothing to remove."
  exit 0
fi

temp_file="$(mktemp "${host_config}.XXXXXX")"
trap 'rm -f "$temp_file"' EXIT

awk -v packages="${packages[*]}" '
  BEGIN {
    count = split(packages, package, " ")
    for (i = 1; i <= count; i++) remove[package[i]] = 1
  }
  /environment\.systemPackages = with pkgs; \[/ { in_packages = 1 }
  in_packages && /^[[:space:]]*\];/ { in_packages = 0 }
  {
    line = $0
    sub(/[[:space:]]*#.*/, "", line)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
    if (!(in_packages && (line in remove))) print
  }
' "$host_config" > "$temp_file"

chmod --reference="$host_config" "$temp_file"
mv "$temp_file" "$host_config"
trap - EXIT

printf 'Removed from andreas-pc.nix:'
printf ' %s' "${packages[@]}"
printf '\nRebuilding andreas-pc...\n'

# This is the command behind the interactive `nrbpc` alias.
sudo nixos-rebuild switch --flake "$config_dir/nixos#andreas-pc"
