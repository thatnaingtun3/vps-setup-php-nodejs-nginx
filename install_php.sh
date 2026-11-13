#!/bin/bash

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()     { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo -e "\n${BLUE}──── $1 ────${NC}"; }

# Repository setup
section "Configuring the Sury PHP repository"

# Launchpad's ondrej/php PPA does not publish Ubuntu Resolute packages. Remove
# files created by add-apt-repository before apt-get update, because that stale
# source makes every update fail with a 404.
shopt -s nullglob
old_ppa_files=(
    /etc/apt/sources.list.d/ondrej-ubuntu-php-*.list
    /etc/apt/sources.list.d/ondrej-ubuntu-php-*.sources
)
shopt -u nullglob
if ((${#old_ppa_files[@]})); then
    warn "Removing unsupported ondrej/php Launchpad PPA"
    sudo rm -f -- "${old_ppa_files[@]}"
fi

sudo apt-get update -y
sudo apt-get install -y ca-certificates curl lsb-release

repo_codename="$(lsb_release -sc)"
if ! curl -fsS "https://packages.sury.org/php/dists/${repo_codename}/Release" >/dev/null; then
    error "The Sury PHP repository does not support '${repo_codename}'."
fi

keyring_deb="$(mktemp --suffix=.deb)"
trap 'rm -f "$keyring_deb"' EXIT
curl -fsSLo "$keyring_deb" https://packages.sury.org/debsuryorg-archive-keyring.deb
sudo dpkg -i "$keyring_deb"
echo "deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ ${repo_codename} main" \
    | sudo tee /etc/apt/sources.list.d/php.list >/dev/null
sudo apt-get update -y

# Version selection
echo -e "\n${BLUE}Available PHP versions:${NC} 8.0  8.1  8.2  8.3  8.4  8.5"
php_input="${1:-}"
if [[ -z "$php_input" ]]; then
    read -rp "Enter one or more versions, separated by commas (e.g., 8.2,8.3,8.4): " php_input
fi

# Accept commas and/or whitespace, discard duplicates, and preserve input order.
php_input="${php_input//,/ }"
read -ra requested_versions <<< "$php_input"
((${#requested_versions[@]})) || error "No PHP version was entered."

php_versions=()
for php_version in "${requested_versions[@]}"; do
    [[ "$php_version" =~ ^8\.[0-5]$ ]] \
        || error "Invalid version '$php_version'. Choose from 8.0–8.5."
    if [[ ! " ${php_versions[*]} " =~ " ${php_version} " ]]; then
        php_versions+=("$php_version")
    fi
done

for php_version in "${php_versions[@]}"; do
    apt-cache show "php${php_version}-cli" &>/dev/null \
        || error "PHP $php_version is not available for ${repo_codename}."
done

for php_version in "${php_versions[@]}"; do
    section "Installing PHP $php_version — core packages"
    core_packages=(
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
    # OPcache is built into PHP 8.5 itself, so Sury ships no php8.5-opcache
    # package. Installing it would abort the whole apt run with "Unable to
    # locate package".
    if [[ "$php_version" != "8.5" ]]; then
        core_packages+=("php${php_version}-opcache")
    fi
    sudo apt-get install -y "${core_packages[@]}"

    # Some optional extensions may not be published for every PHP version.
    section "Installing PHP $php_version — optional extensions"
    optional_exts=(imagick igbinary redis apcu mongodb memcached swoole)
    for extension in "${optional_exts[@]}"; do
        ext="php${php_version}-${extension}"
        if apt-cache show "$ext" &>/dev/null; then
            sudo apt-get install -y "$ext" \
                && log "Installed: $ext" \
                || warn "Install failed (skipping): $ext"
        else
            warn "Not available in repository (skipping): $ext"
        fi
    done

    section "Configuring PHP $php_version php.ini (FPM and CLI)"
    declare -A ini_settings=(
        [upload_max_filesize]="500M"
        [post_max_size]="500M"
        [memory_limit]="512M"
        [max_execution_time]="600"
        [max_input_vars]="5000"
    )
    for sapi in fpm cli; do
        ini_file="/etc/php/${php_version}/${sapi}/php.ini"
        [[ -f "$ini_file" ]] || error "${sapi^^} php.ini not found: $ini_file"
        sudo cp -n "$ini_file" "${ini_file}.bak"
        for key in "${!ini_settings[@]}"; do
            value="${ini_settings[$key]}"
            if sudo grep -qE "^[;[:space:]]*${key}[[:space:]]*=" "$ini_file"; then
                sudo sed -i -E "s|^[;[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "$ini_file"
            else
                echo "${key} = ${value}" | sudo tee -a "$ini_file" >/dev/null
            fi
            log "Set ${key} = ${value} (${sapi})"
        done
    done

    section "Enabling PHP $php_version FPM"
    sudo systemctl enable "php${php_version}-fpm"
    sudo systemctl restart "php${php_version}-fpm"
done

# Use the last requested version as the default for the php command.
default_php="${php_versions[${#php_versions[@]}-1]}"
sudo update-alternatives --set php "/usr/bin/php${default_php}"

section "Verification"
php -v
for php_version in "${php_versions[@]}"; do
    systemctl is-active --quiet "php${php_version}-fpm" \
        && log "php${php_version}-fpm is running" \
        || error "php${php_version}-fpm is not running"
done

echo -e "\n${GREEN}PHP ${php_versions[*]} installed and running. Default CLI: PHP ${default_php}.${NC}"

