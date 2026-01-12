#!/usr/bin/env bash

# Color definitions
RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[38;5;46m'
CYAN='\033[38;5;51m'
YELLOW='\033[38;5;226m'

echo ""
echo -e "${BOLD}${GREEN}NINHO COMMAND REFERENCE${RESET}"
echo ""

echo -e "${BOLD}System:${RESET}"
echo -e "  ${CYAN}ninho-status${RESET}        System health report"
echo -e "  ${CYAN}htop${RESET}                CPU/RAM monitor"
echo -e "  ${CYAN}nvtop${RESET}               GPU monitor"
echo ""

echo -e "${BOLD}Storage:${RESET}"
echo -e "  ${CYAN}df -h${RESET}               Disk space"
echo -e "  ${CYAN}zfs list${RESET}            ZFS datasets"
echo -e "  ${CYAN}zpool status${RESET}        Pool health"
echo -e "  ${CYAN}ncdu /home/$USER${RESET}    Disk usage analyzer"
echo ""

echo -e "${BOLD}Snapshots:${RESET}"
echo -e "  ${CYAN}zfs list -t snapshot${RESET}           List all snapshots"
echo -e "  ${CYAN}ls ~/.zfs/snapshot/${RESET}            Browse your snapshots"
echo -e "  ${CYAN}cp ~/.zfs/snapshot/NAME/file ./${RESET}  Restore file"
echo ""

echo -e "${BOLD}Packages:${RESET}"
echo -e "  ${CYAN}nix search nixpkgs <pkg>${RESET}  Search packages"
echo -e "  ${CYAN}home-manager switch${RESET}        Apply user packages"
echo -e "  ${CYAN}sudo nixos-rebuild switch${RESET}  Apply system config"
echo ""

echo -e "${BOLD}Tmux:${RESET}"
echo -e "  ${CYAN}tmux${RESET}                Start session"
echo -e "  ${CYAN}tmux attach${RESET}         Attach to session"
echo -e "  ${CYAN}Ctrl+b d${RESET}            Detach session"
echo ""
