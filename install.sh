#! /usr/bin/env bash

# Shows the output of every command
set +x

# Pin Nixpkgs to NixOS 22.11
# export PINNED_NIX_PKGS="https://github.com/NixOS/nixpkgs/archive/refs/tags/22.11.tar.gz"
export PINNED_NIX_PKGS="https://github.com/NixOS/nixpkgs/archive/4d2b37a84fad1091b9de401eb450aae66f1a741e.tar.gz"

# Switch to the 22.11 channel
sudo nix-channel --add https://nixos.org/channels/nixos-22.11 nixos
nix-channel --add https://nixos.org/channels/nixos-22.11 nixos
sudo nix-channel --update
nix-channel --update

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
sudo nix-channel --add https://github.com/nix-community/home-manager/archive/refs/heads/release-22.11.tar.gz home-manager
nix-channel --add https://github.com/nix-community/home-manager/archive/refs/heads/release-22.11.tar.gz home-manager
sudo nix-channel --update
nix-channel --update
export NIX_PATH=$HOME/.nix-defexpr/channels${NIX_PATH:+:}$NIX_PATH
nix-shell '<home-manager>' -A install
cp home/background.png $HOME/Documents/
home-manager --show-trace switch

# Set screenlock wallpaper
# betterlockscreen -u home/background.png
