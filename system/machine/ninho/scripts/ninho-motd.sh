#!/usr/bin/env bash

# Color definitions
RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[38;5;46m'
CYAN='\033[38;5;51m'
YELLOW='\033[38;5;226m'
RED='\033[38;5;196m'

# User info
USER_HOME="$HOME"
FIRST_LOGIN_FLAG="$USER_HOME/.ninho_welcomed"

# Show banner
/etc/nixos/ninho-banner.sh

# Check if first login
if [ ! -f "$FIRST_LOGIN_FLAG" ]; then
    # FIRST LOGIN MESSAGE
    echo ""
    echo -e "${BOLD}${YELLOW}Welcome to Ninho, $USER!${RESET}"
    echo -e "${RED}Please change your password: ${CYAN}passwd${RESET}"
    echo ""
    echo -e "${BOLD}Storage:${RESET}"
    echo -e "  ${CYAN}/home/$USER/${RESET}  - NVMe SSDs (fast, limited space)"
    echo -e "  ${CYAN}/storage/${RESET}    - HDDs (large, for media)"
    echo ""
    echo -e "${BOLD}Commands:${RESET}"
    echo -e "  ${CYAN}ninho-status${RESET}  - System health"
    echo -e "  ${CYAN}ninho-cheat${RESET}   - Command reference"
    echo ""

    # Create flag file
    touch "$FIRST_LOGIN_FLAG"
else
    # SUBSEQUENT LOGIN MESSAGE
    echo ""
    echo -e "${BOLD}${GREEN}Welcome back, $USER!${RESET}"

    # System info
    echo -e "${CYAN}Uptime:${RESET} $(uptime | cut -d',' -f1 | sed 's/up //')"

    # Disk space warnings
    NVME_USAGE=$(df /home 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
    HDD_USAGE=$(df /storage 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')

    if [ ! -z "$NVME_USAGE" ] && [ "$NVME_USAGE" -gt 80 ]; then
        echo -e "${RED}⚠  NVMe: ${NVME_USAGE}% full${RESET}"
    fi

    if [ ! -z "$HDD_USAGE" ] && [ "$HDD_USAGE" -gt 80 ]; then
        echo -e "${RED}⚠  Storage: ${HDD_USAGE}% full${RESET}"
    fi

    # Check for tmux sessions
    if command -v tmux &> /dev/null; then
        TMUX_SESSIONS=$(tmux list-sessions 2>/dev/null | wc -l)
        if [ "$TMUX_SESSIONS" -gt 0 ]; then
            echo -e "${YELLOW}Active tmux sessions: $TMUX_SESSIONS${RESET} (${CYAN}tmux attach${RESET})"
        fi
    fi

    echo ""
fi
