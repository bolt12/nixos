#! /usr/bin/env bash

# Define the script's purpose
echo "NixOS Configuration Script"
echo "Select the configuration to apply:"

# Function for NixOS configuration
apply_nixos_config() {
    sudo nixos-rebuild --flake .#bolt-nixos switch
}

apply_rpi5_nixos_config() {
    sudo nixos-rebuild --flake .#bolt-rpi5-nixos switch
}

build_rpi5_sd_image() {
    nix build '.#nixosConfigurations.bolt-rpi5-nixos.config.system.build.sdImage'
}

# Function for steam deck Home Manager configuration
apply_steam_deck_config() {
    home-manager --flake .#steam-deck switch
}

# Present options
PS3='Please enter your choice: '
options=("NixOS Configuration" "Raspberry Pi 5 NixOS SD Image" "Raspberry Pi 5 NixOS Configuration" "Steam Deck Home Manager Configuration" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "NixOS Configuration")
            echo "Applying NixOS Configuration..."
            apply_nixos_config
            break
            ;;
        "Raspberry Pi 5 NixOS SD Image")
            echo "Building Raspberry Pi 5 NixOS SD Image..."
            build_rpi5_sd_image
            break
            ;;
        "Raspberry Pi 5 NixOS Configuration")
            echo "Applying Raspberry Pi 5 NixOS Configuration..."
            apply_rpi5_nixos_config
            break
            ;;
        "Steam Deck Home Manager Configuration")
            echo "Applying Steam Deck Home Manager Configuration..."
            apply_steam_deck_config
            break
            ;;
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done
