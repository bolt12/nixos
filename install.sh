#! /usr/bin/env bash

# Shows the output of every command
set +x

# Pin Nixpkgs to NixOS 21.11
export PINNED_NIX_PKGS="https://github.com/NixOS/nixpkgs/archive/refs/tags/21.11.tar.gz"

# Switch to the 21.05 channel
sudo nix-channel --add https://nixos.org/channels/nixos-21.11 nixos

# Nix configuration
sudo cp -a system/. /etc/nixos/
sudo cp -a nix /etc/nixos/
sudo nixos-rebuild -I nixpkgs=$PINNED_NIX_PKGS switch --upgrade

# Manual steps
mkdir -p $HOME/Documents

# Home manager
mkdir -p $HOME/.config/nixpkgs/
cp -r nix $HOME/.config/nixpkgs/
cp -r home/* $HOME/.config/nixpkgs/
nix-channel --add https://github.com/nix-community/home-manager/archive/refs/heads/release-21.11.tar.gz home-manager
nix-channel --update
export NIX_PATH=$HOME/.nix-defexpr/channels${NIX_PATH:+:}$NIX_PATH
nix-shell '<home-manager>' -A install
cp home/background.png $HOME/Documents/
home-manager --show-trace switch

# Set screenlock wallpaper
betterlockscreen -u home/background.png
