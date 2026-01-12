#!/usr/bin/env bash

# Color definitions
RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[38;5;46m'
CYAN='\033[38;5;51m'
YELLOW='\033[38;5;226m'

echo -e "${BOLD}${CYAN}NINHO SYSTEM STATUS${RESET}"
echo ""
echo -e "${YELLOW}Date:${RESET} $(date)"
echo -e "${YELLOW}Uptime:${RESET} $(uptime -p 2>/dev/null || uptime | sed 's/.*up //' | sed 's/,.*//')"
echo ""

echo -e "${BOLD}${GREEN}ZFS POOLS${RESET}"
zpool list -o name,size,alloc,free,cap,health
echo ""

echo -e "${BOLD}${GREEN}STORAGE USAGE${RESET}"
zfs list -o name,used,avail,mountpoint | head -20
echo ""

echo -e "${BOLD}${GREEN}MEMORY${RESET}"
free -h
echo ""

echo -e "${BOLD}${GREEN}CPU LOAD${RESET}"
uptime
echo ""

echo -e "${CYAN}Run ${BOLD}ninho-cheat${RESET}${CYAN} for commands${RESET}"
