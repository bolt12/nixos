#! /usr/bin/env bash

# Shows the output of every command
set +x

# Pin Nixpkgs to nixos-23.05
export PINNED_NIX_PKGS="https://github.com/NixOS/nixpkgs/archive/0561103cedb11e7554cf34cea81e5f5d578a4753.tar.gz"

# Nix configuration
# Manual steps
sudo cp -a system/. /etc/nixos/
sudo cp -a nix /etc/nixos/

rm -rf $HOME/.config/nixpkgs/
mkdir -p /etc/nixos/home-manager

cp -r nix /etc/nixos/home-manager/
cp -r home/* /etc/nixos/home-manager/

mkdir -p $HOME/Documents
cp home/background.png $HOME/Documents/

# Switch to the 23.05 channel
sudo nix-channel --add https://nixos.org/channels/nixos-23.05 nixos
nix-channel --add https://nixos.org/channels/nixos-23.05 nixpkgs
sudo nix-channel --add https://github.com/nix-community/home-manager/archive/refs/heads/release-23.05.tar.gz home-manager
nix-channel --add https://github.com/nix-community/home-manager/archive/refs/heads/release-23.05.tar.gz home-manager-user
sudo nix-channel --update
nix-channel --update

sudo nixos-rebuild -I nixpkgs=$PINNED_NIX_PKGS switch --upgrade-all --show-trace
