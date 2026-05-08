#!/bin/bash

set -e

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
section() { echo -e "\n${BLUE}════════════════════════════════════════${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}════════════════════════════════════════${NC}"; }

# Run scripts relative to this file's directory so this script works from anywhere
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

section "Step 1 / 4 — PHP"
bash "$SCRIPT_DIR/install_php.sh"

section "Step 2 / 4 — Node.js"
bash "$SCRIPT_DIR/install_nodejs.sh"

section "Step 3 / 4 — Nginx"
bash "$SCRIPT_DIR/install_nginx.sh"

section "Step 4 / 4 — Composer"
bash "$SCRIPT_DIR/install_composer.sh"

echo -e "\n${GREEN}All done! PHP, Node.js, Nginx, and Composer are installed and running.${NC}"
