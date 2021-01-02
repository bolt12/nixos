#! /usr/bin/env bash

# Shows the output of every command
set +x

# Pin Nixpkgs to NixOS 20.09
export PINNED_NIX_PKGS="https://github.com/NixOS/nixpkgs/archive/20.09.tar.gz"

# Switch to the 20.09 channel
# sudo nix-channel --add https://nixos.org/channels/nixos-20.09 nixos

# Nix configuration
sudo cp system/configuration.nix /etc/nixos/
sudo cp -r system/machine/ /etc/nixos/
sudo cp -r system/wm/ /etc/nixos/
sudo nixos-rebuild -I nixpkgs=$PINNED_NIX_PKGS switch --upgrade

# Manual steps
# mkdir -p $HOME/.config/polybar/logs
# touch $HOME/.config/polybar/logs/bottom.log
# touch $HOME/.config/polybar/logs/top.log
# mkdir -p $HOME/.cache/fzf-hoogle
# touch $HOME/.cache/fzf-hoogle/cache.json

# Home manager
mkdir -p $HOME/.config/nixpkgs/
cp -r home/* $HOME/.config/nixpkgs/
nix-channel --add https://github.com/rycee/home-manager/archive/release-20.09.tar.gz home-manager
nix-channel --update
export NIX_PATH=$HOME/.nix-defexpr/channels${NIX_PATH:+:}$NIX_PATH
nix-shell '<home-manager>' -A install
cp home/nixos.png $HOME/Pictures/
home-manager --show-trace switch

# Set screenlock wallpaper
betterlockscreen -u home/nixos.png
