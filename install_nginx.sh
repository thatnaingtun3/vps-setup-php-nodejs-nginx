#!/bin/bash

set -e

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()     { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo -e "\n${BLUE}──── $1 ────${NC}"; }

section "Nginx Installation"

log "Updating package list..."
sudo apt-get update -y

log "Installing Nginx..."
sudo apt-get install -y nginx

log "Enabling and starting Nginx..."
sudo systemctl enable nginx
sudo systemctl start nginx

section "Verification"
nginx -v
sudo systemctl status nginx --no-pager | grep -E "Active|running" || true
echo -e "\n${GREEN}Nginx installed and running.${NC}"

