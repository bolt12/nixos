#! /usr/bin/env bash

# Define the script's purpose
echo "NixOS Configuration Script"
echo "Select the configuration to apply:"

# Function for NixOS configuration
apply_nixos_config() {
    sudo nixos-rebuild --flake .#bolt-nixos switch
}

# Function for steam deck Home Manager configuration
apply_steam_deck_config() {
    home-manager --flake .#steam-deck switch
}

# Present options
PS3='Please enter your choice: '
options=("NixOS Configuration" "Steam Deck Home Manager Configuration" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "NixOS Configuration")
            echo "Applying NixOS Configuration..."
            apply_nixos_config
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
