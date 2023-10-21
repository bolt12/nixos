#! /usr/bin/env bash

# Shows the output of every command
set +x

# Pin Nixpkgs to nixos-23.05
export PINNED_NIX_PKGS="https://github.com/NixOS/nixpkgs/archive/679cadfdfed2b90311a247b2d6ef6dfd3d6cab73.tar.gz"

# Switch to the 23.05 channel
sudo nix-channel --add https://nixos.org/channels/nixos-23.05 nixos
nix-channel --add https://nixos.org/channels/nixos-23.05 nixpkgs
sudo nix-channel --update
nix-channel --update

# Nix configuration
sudo cp -a system/. /etc/nixos/
sudo cp -a nix /etc/nixos/
sudo nixos-rebuild -I nixpkgs=$PINNED_NIX_PKGS switch --upgrade-all

# Manual steps
mkdir -p $HOME/Documents

# Home manager
rm -rf $HOME/.config/nixpkgs/
mkdir -p $HOME/.config/nixpkgs/
cp -r nix $HOME/.config/nixpkgs/
cp -r home/* $HOME/.config/nixpkgs/
sudo nix-channel --add https://github.com/nix-community/home-manager/archive/refs/heads/release-23.05.tar.gz home-manager
nix-channel --add https://github.com/nix-community/home-manager/archive/refs/heads/release-23.05.tar.gz home-manager-user
sudo nix-channel --update
nix-channel --update
nix-shell '<home-manager>' -A install
cp home/background.png $HOME/Documents/
home-manager --show-trace -f /home/bolt/.config/nixpkgs/home.nix switch
