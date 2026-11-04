#!/bin/bash

set -e

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()     { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo -e "\n${BLUE}──── $1 ────${NC}"; }

section "Composer Installation"

# ── PHP check ─────────────────────────────────────────────────────────────────
command -v php &>/dev/null || error "PHP not found. Run install_php.sh first."

# ── Already installed? ────────────────────────────────────────────────────────
if command -v composer &>/dev/null; then
    CURRENT=$(composer --version 2>&1 | head -1)
    warn "Composer already installed: $CURRENT"
    read -rp "Reinstall / update to latest? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log "Skipping Composer installation."
        exit 0
    fi
fi

# ── Download installer ────────────────────────────────────────────────────────
log "Downloading Composer installer..."
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

php -r "copy('https://getcomposer.org/installer', '$TMPDIR/composer-setup.php');"

# ── Verify signature ──────────────────────────────────────────────────────────
log "Verifying installer signature..."
EXPECTED_SIG="$(curl -fsSL https://composer.github.io/installer.sig)"
ACTUAL_SIG="$(php -r "echo hash_file('sha384', '$TMPDIR/composer-setup.php');")"

if [ "$EXPECTED_SIG" != "$ACTUAL_SIG" ]; then
    error "Signature mismatch — installer may be tampered. Aborting."
fi
log "Signature verified."

# ── Run installer ─────────────────────────────────────────────────────────────
log "Running Composer installer..."
php "$TMPDIR/composer-setup.php" --quiet --install-dir="$TMPDIR" --filename=composer

# ── Install globally ──────────────────────────────────────────────────────────
sudo mv "$TMPDIR/composer" /usr/local/bin/composer
sudo chmod +x /usr/local/bin/composer

# ── Verify ────────────────────────────────────────────────────────────────────
section "Verification"
composer --version
echo -e "\n${GREEN}Composer installed successfully.${NC}"

