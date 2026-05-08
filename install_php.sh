#!/bin/bash

set -e

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()     { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo -e "\n${BLUE}──── $1 ────${NC}"; }

# ── Prerequisites ─────────────────────────────────────────────────────────────
section "Updating packages & installing prerequisites"
sudo apt-get update -y
sudo apt-get install -y software-properties-common curl gnupg2 lsb-release ca-certificates

# ── PHP PPA ───────────────────────────────────────────────────────────────────
section "Adding ondrej/php PPA"
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get update -y

# ── Version selection ─────────────────────────────────────────────────────────
echo -e "\n${BLUE}Available PHP versions:${NC} 8.0  8.1  8.2  8.3  8.4  8.5"
read -rp "Enter the PHP version to install (e.g., 8.4): " php_version

[[ "$php_version" =~ ^8\.[0-5]$ ]] || error "Invalid version '$php_version'. Choose from 8.0–8.5."

# ── Core extensions (required) ────────────────────────────────────────────────
section "Installing PHP $php_version — core packages"
sudo apt-get install -y \
    php${php_version} \
    php${php_version}-cli \
    php${php_version}-common \
    php${php_version}-fpm \
    php${php_version}-curl \
    php${php_version}-gd \
    php${php_version}-intl \
    php${php_version}-mbstring \
    php${php_version}-mysql \
    php${php_version}-opcache \
    php${php_version}-readline \
    php${php_version}-xml \
    php${php_version}-xsl \
    php${php_version}-zip \
    php${php_version}-bz2 \
    php${php_version}-sqlite3 \
    php${php_version}-bcmath \
    php${php_version}-soap \
    php${php_version}-pgsql \
    php${php_version}-ldap

# ── Optional extensions (best-effort) ────────────────────────────────────────
# Some extensions may not yet be published for the latest PHP version.
section "Installing PHP $php_version — optional extensions"
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
        sudo apt-get install -y "$ext" \
            && log "Installed: $ext" \
            || warn "Install failed (skipping): $ext"
    else
        warn "Not available in repository (skipping): $ext"
    fi
done

# ── Set default CLI PHP ───────────────────────────────────────────────────────
sudo update-alternatives --set php /usr/bin/php${php_version} 2>/dev/null || true

# ── Start PHP-FPM ─────────────────────────────────────────────────────────────
section "Enabling PHP-FPM"
sudo systemctl enable php${php_version}-fpm
sudo systemctl start php${php_version}-fpm

# ── Verify ────────────────────────────────────────────────────────────────────
section "Verification"
php -v
echo -e "\n${GREEN}PHP $php_version installed and running.${NC}"
