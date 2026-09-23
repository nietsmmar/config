#!/usr/bin/env bash

set -u

CONFIG="${CONFIG:-$HOME/dev/config}"

make_symlink() {
    local target="$CONFIG/$1"
    local name="$HOME/$2"

    mkdir -p "$(dirname "$name")"

    if [[ -L "$name" ]]; then
        if [[ "$(readlink -f "$name")" != "$target" ]]; then
            echo "Replacing symlink: $name"
            rm "$name"
            ln -s "$target" "$name"
        fi
    elif [[ ! -e "$name" ]]; then
        echo "$target -> $name"
        ln -s "$target" "$name"
    else
        echo "File already exists, leaving it unchanged: $name"
    fi
}

# Minimal desktop configuration for the Cinnamon-based andreas-pc host.
make_symlink kitty/kitty.conf .config/kitty/kitty.conf
make_symlink zsh/zshrc.sh .config/zsh/.zshrc
make_symlink zsh/zshenv .zshenv

mkdir -p "$HOME/.cache/zsh" "$HOME/.local/state/zsh"
