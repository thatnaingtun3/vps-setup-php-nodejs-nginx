#!/bin/bash

# All-in-one VPS setup: PHP (8.0–8.5) + Node.js + Nginx + Composer
set -e

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()     { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo -e "\n${BLUE}════ $1 ════${NC}"; }

# ── 1. Prerequisites ──────────────────────────────────────────────────────────
section "System Update & Prerequisites"
sudo apt-get update -y
sudo apt-get install -y software-properties-common curl gnupg2 lsb-release ca-certificates

# ── 2. PHP ────────────────────────────────────────────────────────────────────
section "PHP"

log "Adding ondrej/php PPA..."
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get update -y

echo -e "\n${BLUE}Available PHP versions:${NC} 8.0  8.1  8.2  8.3  8.4  8.5"
read -rp "Enter the PHP version to install (e.g., 8.4): " php_version
[[ "$php_version" =~ ^8\.[0-5]$ ]] || error "Invalid PHP version '$php_version'."

log "Installing PHP $php_version core packages..."
CORE_PKGS=(
    "php${php_version}"
    "php${php_version}-cli"
    "php${php_version}-common"
    "php${php_version}-fpm"
    "php${php_version}-curl"
    "php${php_version}-gd"
    "php${php_version}-intl"
    "php${php_version}-mbstring"
    "php${php_version}-mysql"
    "php${php_version}-readline"
    "php${php_version}-xml"
    "php${php_version}-xsl"
    "php${php_version}-zip"
    "php${php_version}-bz2"
    "php${php_version}-sqlite3"
    "php${php_version}-bcmath"
    "php${php_version}-soap"
    "php${php_version}-pgsql"
    "php${php_version}-ldap"
)
# OPcache is bundled into PHP 8.5, so there is no php8.5-opcache package.
if [[ "$php_version" != "8.5" ]]; then
    CORE_PKGS+=("php${php_version}-opcache")
fi
sudo apt-get install -y "${CORE_PKGS[@]}"

log "Installing optional PHP $php_version extensions (best-effort)..."
OPTIONAL_EXTS=(
    "php${php_version}-imagick"
    "php${php_version}-igbinary"
    "php${php_version}-redis"
    "php${php_version}-apcu"
    "php${php_version}-mongodb"
    "php${php_version}-memcached"
    "php${php_version}-swoole"
)
for ext in "${OPTIONAL_EXTS[@]}"; do
    if apt-cache show "$ext" &>/dev/null 2>&1; then
        sudo apt-get install -y "$ext" && log "Installed: $ext" || warn "Skipping (install failed): $ext"
    else
        warn "Skipping (not in repo): $ext"
    fi
done

sudo update-alternatives --set php /usr/bin/php${php_version} 2>/dev/null || true
sudo systemctl enable php${php_version}-fpm
sudo systemctl start php${php_version}-fpm

# ── 3. Node.js via NVM ────────────────────────────────────────────────────────
section "Node.js (via NVM)"

NVM_VERSION="v0.40.4"

if [ -d "$HOME/.nvm" ]; then
    warn "NVM already installed — skipping download."
else
    log "Installing NVM $NVM_VERSION..."
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi

export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
command -v nvm &>/dev/null || error "NVM failed to load."

echo -e "\n${BLUE}Node.js version options:${NC}"
echo "  24   — Node.js 24 (latest current)"
echo "  lts  — Latest LTS"
echo "  22   — Node.js 22 LTS"
echo "  20   — Node.js 20 LTS"
read -rp "Enter version to install [default: 24]: " node_version
node_version="${node_version:-24}"

log "Installing Node.js $node_version..."
nvm install "$node_version"
nvm use "$node_version"
nvm alias default "$node_version"

echo -e "\n${BLUE}Package manager(s):${NC}"
echo "  pnpm  — Fast, disk-efficient (recommended)"
echo "  yarn  — Yarn Berry via corepack"
echo "  both  — pnpm AND Yarn"
echo "  none  — npm only"
read -rp "Choice [default: pnpm]: " pkg_mgr
pkg_mgr="${pkg_mgr:-pnpm}"

command -v corepack &>/dev/null || npm install -g corepack

case "$pkg_mgr" in
    pnpm) corepack enable pnpm ;;
    yarn) corepack enable yarn ;;
    both) corepack enable pnpm; corepack enable yarn ;;
    none) log "Skipping extra package managers." ;;
    *)    warn "Unknown option '$pkg_mgr' — skipping." ;;
esac

# ── 4. Nginx ──────────────────────────────────────────────────────────────────
section "Nginx"
sudo apt-get install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# ── 5. Composer ───────────────────────────────────────────────────────────────
section "Composer"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log "Downloading Composer installer..."
php -r "copy('https://getcomposer.org/installer', '$TMPDIR/composer-setup.php');"

log "Verifying installer signature..."
EXPECTED_SIG="$(curl -fsSL https://composer.github.io/installer.sig)"
ACTUAL_SIG="$(php -r "echo hash_file('sha384', '$TMPDIR/composer-setup.php');")"
[ "$EXPECTED_SIG" = "$ACTUAL_SIG" ] || error "Composer installer signature mismatch — aborting."

log "Installing Composer globally..."
php "$TMPDIR/composer-setup.php" --quiet --install-dir="$TMPDIR" --filename=composer
sudo mv "$TMPDIR/composer" /usr/local/bin/composer
sudo chmod +x /usr/local/bin/composer

# ── 6. Verify all ─────────────────────────────────────────────────────────────
section "Verification"
php -v
echo "node   : $(node -v)"
echo "npm    : $(npm -v)"
[[ "$pkg_mgr" =~ ^(pnpm|both)$ ]] && echo "pnpm   : $(pnpm -v)" || true
[[ "$pkg_mgr" =~ ^(yarn|both)$ ]] && echo "yarn   : $(yarn -v)" || true
nginx -v
composer --version

echo -e "\n${BLUE}NVM shell integration${NC} — ensure these lines exist in your ~/.bashrc or ~/.zshrc:"
echo '  export NVM_DIR="$HOME/.nvm"'
echo '  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'

echo -e "\n${GREEN}VPS setup complete!${NC}"
echo -e "  PHP $php_version  |  Node.js $node_version  |  Nginx  |  Composer"
