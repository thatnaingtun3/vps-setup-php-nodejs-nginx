#!/bin/bash

set -e

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()     { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo -e "\n${BLUE}──── $1 ────${NC}"; }

NVM_VERSION="v0.40.4"

section "Node.js Installation via NVM"

# ── Install NVM ───────────────────────────────────────────────────────────────
if [ -d "$HOME/.nvm" ]; then
    warn "NVM directory already exists — skipping NVM download."
else
    log "Installing NVM $NVM_VERSION..."
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi

# Load NVM into the current shell session
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
command -v nvm &>/dev/null || error "NVM failed to load. Try opening a new terminal and re-running."

# ── Node.js version selection ─────────────────────────────────────────────────
echo -e "\n${BLUE}Node.js version options:${NC}"
echo "  24   — Node.js 24 (latest current)"
echo "  lts  — Latest LTS (stable / production recommended)"
echo "  22   — Node.js 22 LTS"
echo "  20   — Node.js 20 LTS"
read -rp "Enter version to install [default: 24]: " node_version
node_version="${node_version:-24}"

log "Installing Node.js $node_version..."
nvm install "$node_version"
nvm use "$node_version"
nvm alias default "$node_version"

# ── Package manager selection ─────────────────────────────────────────────────
echo -e "\n${BLUE}Which package manager(s) do you want?${NC}"
echo "  pnpm  — Fast, disk-efficient (recommended)"
echo "  yarn  — Yarn Berry via corepack"
echo "  both  — Install pnpm AND Yarn"
echo "  none  — npm only (skip)"
read -rp "Choice [pnpm/yarn/both/none, default: pnpm]: " pkg_mgr
pkg_mgr="${pkg_mgr:-pnpm}"

# Enable corepack (ships with Node.js 16.9+)
if ! command -v corepack &>/dev/null; then
    log "Installing corepack globally..."
    npm install -g corepack
fi

case "$pkg_mgr" in
    pnpm)
        log "Enabling pnpm via corepack..."
        corepack enable pnpm
        ;;
    yarn)
        log "Enabling Yarn via corepack..."
        corepack enable yarn
        ;;
    both)
        log "Enabling pnpm and Yarn via corepack..."
        corepack enable pnpm
        corepack enable yarn
        ;;
    none)
        log "Skipping additional package managers."
        ;;
    *)
        warn "Unknown option '$pkg_mgr' — skipping package managers."
        ;;
esac

# ── Verify ────────────────────────────────────────────────────────────────────
section "Verification"
echo "node   : $(node -v)"
echo "npm    : $(npm -v)"
[[ "$pkg_mgr" =~ ^(pnpm|both)$ ]] && echo "pnpm   : $(pnpm -v)" || true
[[ "$pkg_mgr" =~ ^(yarn|both)$ ]] && echo "yarn   : $(yarn -v)" || true

# ── Shell integration reminder ────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}NVM shell integration${NC} — ensure these lines exist in your ~/.bashrc or ~/.zshrc:"
echo '  export NVM_DIR="$HOME/.nvm"'
echo '  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
echo '  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'

echo -e "\n${GREEN}Node.js $node_version installed successfully via NVM.${NC}"
