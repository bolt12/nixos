#! /usr/bin/env bash

set -euo pipefail

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          NixOS Configuration Manager                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "This script helps you apply NixOS configurations and build images."
echo ""

# ============================================================================
# NixOS System Configurations
# ============================================================================

apply_bolt_nixos() {
    echo -e "${GREEN}Applying bolt-nixos configuration (X1 Carbon laptop)...${NC}"
    sudo nixos-rebuild switch --flake .#bolt-nixos --upgrade
}

apply_ninho_nixos() {
    echo -e "${GREEN}Applying ninho-nixos configuration (Home server)...${NC}"
    sudo nixos-rebuild switch --flake .#ninho-nixos --upgrade
}

test_bolt_nixos() {
    echo -e "${YELLOW}Testing bolt-nixos configuration (no switch)...${NC}"
    sudo nixos-rebuild test --flake .#bolt-nixos
}

test_ninho_nixos() {
    echo -e "${YELLOW}Testing ninho-nixos configuration (no switch)...${NC}"
    sudo nixos-rebuild test --flake .#ninho-nixos
}

# ============================================================================
# SD Image Builds
# ============================================================================

build_rpi5_sd_image() {
    echo -e "${GREEN}Building Raspberry Pi 5 SD image...${NC}"
    nix build '.#nixosConfigurations.bolt-rpi5-sd-image'
    echo -e "${GREEN}Image built successfully!${NC}"
    echo "Location: result/"
    ls -lh result/
}

# ============================================================================
# Home Manager Configurations
# ============================================================================

apply_hm_bolt() {
    echo -e "${GREEN}Applying home-manager for bolt (headless)...${NC}"
    home-manager switch --flake .#bolt
}

apply_hm_bolt_with_de() {
    echo -e "${GREEN}Applying home-manager for bolt-with-de (desktop)...${NC}"
    home-manager switch --flake .#bolt-with-de
}

apply_hm_pollard() {
    echo -e "${GREEN}Applying home-manager for pollard...${NC}"
    home-manager switch --flake .#pollard
}

apply_hm_steam_deck() {
    echo -e "${GREEN}Applying home-manager for Steam Deck...${NC}"
    home-manager switch --flake .#steam-deck
}

# ============================================================================
# Utility Functions
# ============================================================================

check_flake() {
    echo -e "${YELLOW}Checking flake validity...${NC}"
    nix flake check
}

update_flake() {
    echo -e "${YELLOW}Updating flake inputs...${NC}"
    nix flake update
}

show_system_info() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}System Information${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo "Hostname: $(hostname)"
    echo "NixOS Version: $(nixos-version 2>/dev/null || echo 'Not a NixOS system')"
    echo "Current Generation: $(nixos-rebuild list-generations 2>/dev/null | tail -1 || echo 'N/A')"
    echo ""
}

# ============================================================================
# Main Menu
# ============================================================================

show_main_menu() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Main Menu${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

show_system_info

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Available Configurations${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}NixOS System Configurations:${NC}"
echo "  1) Apply: bolt-nixos (X1 Carbon Laptop)"
echo "  2) Apply: ninho-nixos (Home Server)"
echo "  3) Test: bolt-nixos (no activation)"
echo "  4) Test: ninho-nixos (no activation)"
echo ""
echo -e "${YELLOW}SD Image Builds:${NC}"
echo "  5) Build: Raspberry Pi 5 SD Image"
echo ""
echo -e "${YELLOW}Home Manager Configurations:${NC}"
echo "  6) Apply HM: bolt (headless)"
echo "  7) Apply HM: bolt-with-de (desktop)"
echo "  8) Apply HM: pollard"
echo "  9) Apply HM: steam-deck"
echo ""
echo -e "${YELLOW}Utilities:${NC}"
echo " 10) Check flake validity"
echo " 11) Update flake inputs"
echo ""
echo " 12) Quit"
echo ""

read -p "Please select an option (1-12): " choice

case $choice in
    1)
        apply_bolt_nixos
        ;;
    2)
        apply_ninho_nixos
        ;;
    3)
        test_bolt_nixos
        ;;
    4)
        test_ninho_nixos
        ;;
    5)
        build_rpi5_sd_image
        ;;
    6)
        apply_hm_bolt
        ;;
    7)
        apply_hm_bolt_with_de
        ;;
    8)
        apply_hm_pollard
        ;;
    9)
        apply_hm_steam_deck
        ;;
    10)
        check_flake
        ;;
    11)
        update_flake
        ;;
    12)
        echo -e "${GREEN}Exiting...${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option: $choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Operation completed!${NC}"
