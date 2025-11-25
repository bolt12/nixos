#!/usr/bin/env bash

# Color definitions
RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[38;5;46m'
CYAN='\033[38;5;51m'
YELLOW='\033[38;5;226m'
ORANGE='\033[38;5;214m'
RED='\033[38;5;196m'
BLUE='\033[38;5;33m'
MAGENTA='\033[38;5;201m'

# User info
USER_HOME="$HOME"
FIRST_LOGIN_FLAG="$USER_HOME/.ninho_welcomed"

# Show banner
/etc/nixos/ninho-banner.sh

# Check if first login
if [ ! -f "$FIRST_LOGIN_FLAG" ]; then
    # FIRST LOGIN MESSAGE
    echo ""
    echo -e "${BOLD}${YELLOW}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${YELLOW}║              👋 Welcome to Ninho, $USER! 👋                    ${RESET}"
    echo -e "${BOLD}${YELLOW}║                   This is your first login!                          ║${RESET}"
    echo -e "${BOLD}${YELLOW}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${BOLD}${RED}🔐 IMPORTANT - First Steps:${RESET}"
    echo ""
    echo -e "${YELLOW}1.${RESET} ${BOLD}Change your password NOW:${RESET}"
    echo -e "   ${CYAN}\$ passwd${RESET}"
    echo ""
    echo -e "${YELLOW}2.${RESET} ${BOLD}Set up SSH keys (recommended):${RESET}"
    echo -e "   ${CYAN}# On your local machine:"
    echo -e "   \$ ssh-copy-id $USER@ninho${RESET}"
    echo ""
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${GREEN}🗄️  FILESYSTEM ORGANIZATION${RESET}"
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "${BOLD}Your files are stored on two different disk systems:${RESET}"
    echo ""
    echo -e "${BLUE}📀 NVMe SSDs (Fast, 1.8TB) - RAID Mirror:${RESET}"
    echo -e "   ${CYAN}/home/$USER/${RESET}          → Your personal files, configs, code"
    echo -e "   ${CYAN}/nix/${RESET}                 → System packages (managed by NixOS)"
    echo ""
    echo -e "   ${ORANGE}⚡ Use for:${RESET} Documents, code projects, configs, databases"
    echo -e "   ${RED}⚠️  Limited space:${RESET} Don't store large media here!"
    echo ""
    echo -e "${BLUE}💾 Hard Drives (Large, 14TB) - RAIDZ1:${RESET}"
    echo -e "   ${CYAN}/storage/${RESET}            → Bulk storage for large files"
    echo ""
    echo -e "   ${ORANGE}📦 Use for:${RESET} Movies, music, photos, backups, archives"
    echo -e "   ${GREEN}✅ Lots of space:${RESET} Perfect for media libraries!"
    echo ""
    echo -e "${BOLD}${YELLOW}💡 Quick tip:${RESET} Check space with: ${CYAN}df -h${RESET}"
    echo ""
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${GREEN}📦 NIXOS BASICS${RESET}"
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "${BOLD}NixOS is different!${RESET} Packages are managed declaratively."
    echo ""
    echo -e "${YELLOW}System-wide packages${RESET} (requires sudo):"
    echo -e "   ${CYAN}sudo nano /etc/nixos/configuration.nix${RESET}"
    echo -e "   ${CYAN}sudo nixos-rebuild switch${RESET}"
    echo ""
    echo -e "${YELLOW}Your personal packages${RESET} (recommended):"
    echo -e "   ${CYAN}nano ~/.config/home-manager/home.nix${RESET}"
    echo -e "   ${CYAN}home-manager switch${RESET}"
    echo ""
    echo -e "${BOLD}📝 home-manager example:${RESET}"
    echo -e "   ${CYAN}{ config, pkgs, ... }:"
    echo -e "   {"
    echo -e "     home.packages = with pkgs; ["
    echo -e "       vim"
    echo -e "       htop"
    echo -e "       git"
    echo -e "     ];"
    echo -e "   }${RESET}"
    echo ""
    echo -e "${YELLOW}💡 Quick package search:${RESET}"
    echo -e "   ${CYAN}nix search nixpkgs firefox${RESET}"
    echo ""
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${GREEN}💾 ZFS COMMANDS${RESET}"
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "${BOLD}Ninho uses ZFS for data protection and snapshots!${RESET}"
    echo ""
    echo -e "${YELLOW}Check disk space:${RESET}"
    echo -e "   ${CYAN}zfs list${RESET}                      # List all datasets"
    echo -e "   ${CYAN}df -h${RESET}                         # Human-readable disk usage"
    echo ""
    echo -e "${YELLOW}View snapshots:${RESET}"
    echo -e "   ${CYAN}zfs list -t snapshot${RESET}          # All snapshots"
    echo -e "   ${CYAN}zfs list -t snapshot | grep home${RESET} # Just /home snapshots"
    echo ""
    echo -e "${YELLOW}Recover deleted files:${RESET}"
    echo -e "   ${CYAN}# List snapshots for your home"
    echo -e "   zfs list -t snapshot | grep rpool/home"
    echo ""
    echo -e "   # View what's in a snapshot"
    echo -e "   ls ~/.zfs/snapshot/"
    echo ""
    echo -e "   # Copy file from snapshot"
    echo -e "   cp ~/.zfs/snapshot/SNAPSHOT_NAME/file.txt ./${RESET}"
    echo ""
    echo -e "${YELLOW}Rollback to snapshot (${RED}CAREFUL!${YELLOW}):${RESET}"
    echo -e "   ${CYAN}sudo zfs rollback rpool/home@SNAPSHOT_NAME${RESET}"
    echo ""
    echo -e "${YELLOW}Pool health:${RESET}"
    echo -e "   ${CYAN}sudo zpool status${RESET}              # Check RAID status"
    echo ""
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${GREEN}🛠️  USEFUL COMMANDS${RESET}"
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "${CYAN}ninho-status${RESET}         # Complete system health report"
    echo -e "${CYAN}ninho-cheat${RESET}          # Show this cheatsheet anytime"
    echo -e "${CYAN}htop${RESET}                 # System resource monitor"
    echo -e "${CYAN}ncdu /home/$USER${RESET}     # Disk usage analyzer"
    echo -e "${CYAN}tmux${RESET}                 # Terminal multiplexer (persistent sessions)"
    echo -e "${CYAN}tmux attach${RESET}          # Attach to existing tmux session"
    echo ""
    echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "${GREEN}✅ After changing your password, this welcome message won't show again.${RESET}"
    echo -e "${GREEN}   Run ${CYAN}ninho-cheat${GREEN} anytime to see the command reference.${RESET}"
    echo ""

    # Create flag file
    touch "$FIRST_LOGIN_FLAG"

else
    # SUBSEQUENT LOGIN MESSAGE
    echo ""
    echo -e "${BOLD}${GREEN}Welcome back, $USER! 💚${RESET}"
    echo ""

    # System info
    echo -e "${CYAN}📊 Quick Status:${RESET}"
    echo -e "   Uptime: $(uptime | cut -d',' -f1 | sed 's/up //')"
    echo -e "   Load: $(uptime | awk -F'load average:' '{print $2}' | xargs)"

    # Disk space warnings
    NVME_USAGE=$(df /home 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
    HDD_USAGE=$(df /storage 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')

    if [ ! -z "$NVME_USAGE" ]; then
        if [ "$NVME_USAGE" -gt 80 ]; then
            echo -e "   ${RED}⚠️  NVMe storage: ${NVME_USAGE}% full${RESET}"
        else
            echo -e "   ${GREEN}✅ NVMe storage: ${NVME_USAGE}% used${RESET}"
        fi
    fi

    if [ ! -z "$HDD_USAGE" ]; then
        if [ "$HDD_USAGE" -gt 80 ]; then
            echo -e "   ${RED}⚠️  HDD storage: ${HDD_USAGE}% full${RESET}"
        else
            echo -e "   ${GREEN}✅ HDD storage: ${HDD_USAGE}% used${RESET}"
        fi
    fi

    # Check for tmux sessions
    echo ""
    if command -v tmux &> /dev/null; then
        TMUX_SESSIONS=$(tmux list-sessions 2>/dev/null)
        if [ -n "$TMUX_SESSIONS" ]; then
            echo -e "${YELLOW}🔄 Active tmux sessions:${RESET}"
            echo "$TMUX_SESSIONS" | while read line; do
                echo -e "   ${CYAN}→ $line${RESET}"
            done
            echo -e "   ${GREEN}Attach with:${RESET} ${CYAN}tmux attach${RESET}"
            echo ""
        fi
    fi

    # Check for system updates (optional)
    if [ -f /run/current-system/nixos-version ]; then
        NIXOS_VERSION=$(cat /run/current-system/nixos-version)
        echo -e "${BLUE}🐧 NixOS:${RESET} $NIXOS_VERSION"
    fi

    echo ""
    echo -e "${CYAN}💡 Commands:${RESET}"
    echo -e "   ${CYAN}ninho-status${RESET}  - Full system health report"
    echo -e "   ${CYAN}ninho-cheat${RESET}   - Command cheatsheet"
    echo ""
fi
