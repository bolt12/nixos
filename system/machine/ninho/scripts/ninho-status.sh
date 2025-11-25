#!/usr/bin/env bash

# Color definitions
RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[38;5;46m'
CYAN='\033[38;5;51m'
YELLOW='\033[38;5;226m'
RED='\033[38;5;196m'
BLUE='\033[38;5;33m'

echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║              🏡  NINHO SYSTEM HEALTH REPORT  🏡                      ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
echo ""

echo -e "${YELLOW}📅 Date:${RESET} $(date)"
echo -e "${YELLOW}⏱️ Uptime:${RESET} $(uptime -p 2>/dev/null || uptime | sed 's/.*up /up /' | sed 's/,.*//')"
echo -e "${YELLOW}👤 Logged in as:${RESET} $USER"
echo ""

echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}💾 ZFS POOL STATUS${RESET}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════${RESET}"
zpool status
echo ""

echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}📊 POOL CAPACITY${RESET}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════${RESET}"
zpool list -o name,size,alloc,free,cap,health
echo ""

echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}📁 DATASET USAGE${RESET}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════${RESET}"
zfs list -o name,used,avail,refer,compressratio,mountpoint
echo ""

echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}📸 RECENT SNAPSHOTS (Last 10)${RESET}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════${RESET}"
zfs list -t snapshot -o name,used,creation -s creation | tail -10
echo ""

echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}🔍 LAST SCRUB STATUS${RESET}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════${RESET}"
zpool status | grep -A 2 "scan:"
echo ""

echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}📈 SYSTEM RESOURCES${RESET}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${YELLOW}Memory:${RESET}"
free -h
echo ""
echo -e "${YELLOW}CPU Load:${RESET}"
uptime
echo ""

echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}🔐 LUKS DEVICES${RESET}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════${RESET}"
lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINT | grep -E "crypt|NAME"
echo ""

echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}✅ REPORT COMPLETE${RESET}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${CYAN}Run ${BOLD}ninho-cheat${RESET}${CYAN} for command reference${RESET}"
