#!/bin/bash

# Mediacenter Setup Script
# This script collects installation information and creates .env.install
# Then performs an unattended installation

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script with sudo or as root!"
    echo "The script will request sudo permissions when needed."
    echo ""
    echo "Please run: ./setup.sh"
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Load setup libraries
LIB_DIR="${SCRIPT_DIR}/setup/lib"
source "${LIB_DIR}/setup-common.sh"
source "${LIB_DIR}/setup-users.sh"
source "${LIB_DIR}/setup-api.sh"
source "${LIB_DIR}/setup-services.sh"

# Initialize logging
init_logging

log_section "Sailarr Installer"
log_info "Script directory: ${SCRIPT_DIR}"
log_info "Logs directory: ${SETUP_LOG_DIR}"
echo ""

# Check if .env.install exists - if yes, skip configuration and go straight to install
if [ -f "$SCRIPT_DIR/docker/.env.install" ]; then
    echo "========================================="
    echo ".env.install found - Using existing configuration"
    echo "========================================="
    echo ""
    read -p "Do you want to use existing .env.install configuration? (y/n): " -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Load existing configuration
        set -a
        source "$SCRIPT_DIR/docker/.env.defaults"
        source "$SCRIPT_DIR/docker/.env.install"
        set +a
        SKIP_CONFIGURATION=true
    else
        echo "Creating new configuration..."
        SKIP_CONFIGURATION=false
    fi
else
    SKIP_CONFIGURATION=false
fi

# ========================================
# PHASE 1: CONFIGURATION
# ========================================

if [ "$SKIP_CONFIGURATION" = false ]; then
    echo ""
    echo "========================================="
    echo "Mediacenter Installation - Configuration"
    echo "========================================="
    echo ""

    # Load defaults
    set -a
    source "$SCRIPT_DIR/docker/.env.defaults"
    set +a

    # Ask for installation directory
    echo "Installation Directory"
    echo "----------------------"
    echo "Current default: ${ROOT_DIR:-/mediacenter}"
    read -p "Enter installation directory [press Enter for default]: " INSTALL_DIR
    INSTALL_DIR=${INSTALL_DIR:-${ROOT_DIR:-/mediacenter}}
    echo ""

    # Ask for timezone
    echo "Timezone Configuration"
    echo "----------------------"
    echo "Current default: ${TIMEZONE:-Europe/Madrid}"
    echo "Examples: Europe/Madrid, America/New_York, Asia/Tokyo"
    read -p "Enter timezone [press Enter for default]: " USER_TIMEZONE
    USER_TIMEZONE=${USER_TIMEZONE:-${TIMEZONE:-Europe/Madrid}}
    echo ""

    # Ask for Real-Debrid token
    echo "Real-Debrid API Token"
    echo "---------------------"
    echo "Get your API token from: https://real-debrid.com/apitoken"
    echo "This is required for Zurg and Decypharr to work."
    read -p "Enter Real-Debrid API token: " REALDEBRID_TOKEN
    while [ -z "$REALDEBRID_TOKEN" ]; do
        echo "ERROR: Real-Debrid token is required!"
        read -p "Enter Real-Debrid API token: " REALDEBRID_TOKEN
    done
    echo ""

    # Ask for Plex claim token (optional)
    echo "Plex Claim Token (Optional)"
    echo "---------------------------"
    echo "Get claim token from: https://www.plex.tv/claim/"
    echo "NOTE: Claim tokens expire in 4 minutes. Leave empty to configure later."
    read -p "Enter Plex claim token [press Enter to skip]: " PLEX_CLAIM
    echo ""

    # Ask for authentication credentials (optional)
    echo "Service Authentication (Optional)"
    echo "----------------------------------"
    echo "Configure username/password for Radarr, Sonarr, and Prowlarr web UI."
    echo "Leave empty to skip and configure manually later."
    read -p "Do you want to configure authentication? (y/n): " -r
    echo ""

    AUTH_ENABLED=false
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter username: " AUTH_USERNAME
        while [ -z "$AUTH_USERNAME" ]; do
            echo "ERROR: Username cannot be empty!"
            read -p "Enter username: " AUTH_USERNAME
        done

        read -sp "Enter password: " AUTH_PASSWORD
        echo ""
        while [ -z "$AUTH_PASSWORD" ]; do
            echo "ERROR: Password cannot be empty!"
            read -sp "Enter password: " AUTH_PASSWORD
            echo ""
        done

        AUTH_ENABLED=true
        echo "✓ Authentication will be configured"
    else
        echo "Authentication skipped - configure manually later"
    fi
    echo ""

    # Ask for Traefik configuration
    echo "Traefik Reverse Proxy (Optional)"
    echo "---------------------------------"
    echo "Traefik provides a reverse proxy for accessing services via domain names."
    echo "If disabled, services will be accessible via their direct ports."
    read -p "Do you want to enable Traefik? (y/n): " -r
    echo ""

    TRAEFIK_ENABLED=true
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        TRAEFIK_ENABLED=false
        USER_DOMAIN="localhost"
        echo "Traefik disabled - services will use direct port access"
    else
        TRAEFIK_ENABLED=true
        echo "✓ Traefik will be enabled"
        echo ""

        # Ask for domain name (only if Traefik is enabled)
        echo "Domain/Hostname Configuration"
        echo "------------------------------"
        echo "This will be used for Traefik routing (e.g., radarr.yourdomain.local)"
        echo "Current default: ${DOMAIN_NAME:-mediacenter.local}"
        read -p "Enter domain/hostname [press Enter for default]: " USER_DOMAIN
        USER_DOMAIN=${USER_DOMAIN:-${DOMAIN_NAME:-mediacenter.local}}
    fi
    echo ""

    # Service Selection
    echo "Service Selection"
    echo "-----------------"
    echo "Choose which services to install. You can select:"
    echo "  - Media server (Plex or none)"
    echo "  - Optional services (Overseerr, Tautulli, Homarr, etc.)"
    echo ""
    read -p "Do you want to customize service selection? (y/n): " -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Execute interactive template selector
        SELECTED_TEMPLATES=$(${SCRIPT_DIR}/scripts/template-selector.sh)
        TEMPLATE_SELECTOR_EXIT=$?

        if [ $TEMPLATE_SELECTOR_EXIT -ne 0 ]; then
            echo "Template selection cancelled."
            exit 1
        fi

        echo ""
        log_info "Selected templates: $SELECTED_TEMPLATES"
    else
        # Default configuration: core + plex + overseerr
        SELECTED_TEMPLATES="core mediaplayers/plex extras/overseerr"
        echo "Using default configuration: Core + Plex + Overseerr"
        log_info "To customize, run setup again and choose 'y' for service selection"
    fi
    echo ""

    # Check and auto-fix UID/GID conflicts
    echo "Checking for UID/GID conflicts..."
    echo ""

    CONFLICTS_FOUND=false
    CONFLICT_DETAILS=""

    # Check GID
    if getent group $MEDIACENTER_GID >/dev/null 2>&1 && ! getent group mediacenter >/dev/null 2>&1; then
        CONFLICTS_FOUND=true
        EXISTING_GROUP=$(getent group $MEDIACENTER_GID | cut -d: -f1)
        CONFLICT_DETAILS="${CONFLICT_DETAILS}  - GID $MEDIACENTER_GID is used by: $EXISTING_GROUP\n"
    fi

    # Check UIDs
    declare -A USERS=(
        ["RCLONE_UID"]="rclone"
        ["SONARR_UID"]="sonarr"
        ["RADARR_UID"]="radarr"
        ["RECYCLARR_UID"]="recyclarr"
        ["PROWLARR_UID"]="prowlarr"
        ["OVERSEERR_UID"]="overseerr"
        ["PLEX_UID"]="plex"
        ["DECYPHARR_UID"]="decypharr"
        ["AUTOSCAN_UID"]="autoscan"
    )

    for var_name in "${!USERS[@]}"; do
        username="${USERS[$var_name]}"
        uid_value="${!var_name}"

        if getent passwd $uid_value >/dev/null 2>&1 && ! id "$username" >/dev/null 2>&1; then
            CONFLICTS_FOUND=true
            EXISTING_USER=$(getent passwd $uid_value | cut -d: -f1)
            CONFLICT_DETAILS="${CONFLICT_DETAILS}  - UID $uid_value ($var_name for $username) is used by: $EXISTING_USER\n"
        fi
    done

    # Handle conflicts - auto-assign available UIDs/GIDs
    if [ "$CONFLICTS_FOUND" = true ]; then
        echo "UID/GID Conflicts Detected:"
        echo -e "$CONFLICT_DETAILS"
        echo "Auto-assigning available UIDs/GIDs..."
        echo ""

        # Find and assign GID
        if getent group $MEDIACENTER_GID >/dev/null 2>&1 && ! getent group mediacenter >/dev/null 2>&1; then
            ORIGINAL_GID=$MEDIACENTER_GID
            MEDIACENTER_GID=$(find_available_gid $MEDIACENTER_GID)
            echo "  → Assigned GID $MEDIACENTER_GID for mediacenter group (was $ORIGINAL_GID, in use)"
        fi

        # Find and assign UIDs
        for var_name in "${!USERS[@]}"; do
            username="${USERS[$var_name]}"
            uid_value="${!var_name}"

            if getent passwd $uid_value >/dev/null 2>&1 && ! id "$username" >/dev/null 2>&1; then
                ORIGINAL_UID=$uid_value
                NEW_UID=$(find_available_uid $uid_value)
                eval "$var_name=$NEW_UID"
                echo "  → Assigned UID $NEW_UID for $username (was $ORIGINAL_UID, in use)"
            fi
        done
        echo ""
    else
        echo "No UID/GID conflicts detected. Using defaults."
        echo ""
    fi

    # Create .env.install with all configuration
    echo "Creating .env.install configuration file..."

    cat > "$SCRIPT_DIR/docker/.env.install" <<EOF
# =============================================================================
# MEDIACENTER - INSTALLATION CONFIGURATION
# Generated on $(date)
# DO NOT SHARE - Contains secrets and tokens
# =============================================================================

# =============================================================================
# USER/ENVIRONMENT SETTINGS
# =============================================================================
TIMEZONE=$USER_TIMEZONE
ROOT_DIR=$INSTALL_DIR

# =============================================================================
# SECRETS & TOKENS - KEEP PRIVATE
# =============================================================================

# Plex claim token (valid for 4 minutes after generation)
# Get from: https://www.plex.tv/claim/
PLEX_CLAIM=${PLEX_CLAIM:-}

# Real-Debrid API token
# Get from: https://real-debrid.com/apitoken
REALDEBRID_TOKEN=$REALDEBRID_TOKEN

# =============================================================================
# AUTHENTICATION CONFIGURATION
# =============================================================================
AUTH_ENABLED=$AUTH_ENABLED
AUTH_USERNAME=${AUTH_USERNAME:-}
AUTH_PASSWORD=${AUTH_PASSWORD:-}

# =============================================================================
# TRAEFIK CONFIGURATION
# =============================================================================
TRAEFIK_ENABLED=$TRAEFIK_ENABLED

# =============================================================================
# DNS/DOMAIN CONFIGURATION
# =============================================================================
DOMAIN_NAME=$USER_DOMAIN

# =============================================================================
# TEMPLATE SELECTION
# =============================================================================
SELECTED_TEMPLATES="$SELECTED_TEMPLATES"

# =============================================================================
# SYSTEM CONFIGURATION - UIDs/GIDs
# =============================================================================
MEDIACENTER_GID=$MEDIACENTER_GID

# User IDs
RCLONE_UID=${RCLONE_UID}
SONARR_UID=${SONARR_UID}
RADARR_UID=${RADARR_UID}
RECYCLARR_UID=${RECYCLARR_UID}
PROWLARR_UID=${PROWLARR_UID}
OVERSEERR_UID=${OVERSEERR_UID}
PLEX_UID=${PLEX_UID}
DECYPHARR_UID=${DECYPHARR_UID}
AUTOSCAN_UID=${AUTOSCAN_UID}

# =============================================================================
# CUSTOM PATHS - Default values
# =============================================================================
DOCKER_SOCKET_PATH=/var/run/docker.sock
HOST_MOUNT_PATH=/
EOF

    # Reload configuration from .env.install
    set -a
    source "$SCRIPT_DIR/docker/.env.defaults"
    source "$SCRIPT_DIR/docker/.env.install"
    set +a

    echo "Configuration saved to: $SCRIPT_DIR/docker/.env.install"
    echo ""
fi

# ========================================
# PHASE 2: SHOW SUMMARY
# ========================================

echo ""
echo "========================================="
echo "Installation Summary"
echo "========================================="
echo ""
echo "GENERAL CONFIGURATION"
echo "---------------------"
echo "Installation directory: ${ROOT_DIR}"
echo "Docker configuration:   $SCRIPT_DIR/docker/"
echo "Timezone:              ${TIMEZONE}"
echo "Domain:                ${DOMAIN_NAME}"
echo ""
echo "TEMPLATES SELECTED"
echo "------------------"
for template in $SELECTED_TEMPLATES; do
    if [ -f "${SCRIPT_DIR}/templates/${template}/template.conf" ]; then
        source "${SCRIPT_DIR}/templates/${template}/template.conf"
        echo "  ✓ $DESCRIPTION"
    else
        echo "  ✓ $template (core stack)"
    fi
done
echo ""
echo "CREDENTIALS"
echo "-----------"
echo "Real-Debrid token:     ${REALDEBRID_TOKEN:0:20}... (configured)"
if [ -n "$PLEX_CLAIM" ]; then
    echo "Plex claim token:      ${PLEX_CLAIM:0:20}... (configured)"
else
    echo "Plex claim token:      (skipped - configure later)"
fi
echo ""
echo "USERS TO BE CREATED"
echo "-------------------"
echo "  - rclone (UID: ${RCLONE_UID})"
echo "  - sonarr (UID: ${SONARR_UID})"
echo "  - radarr (UID: ${RADARR_UID})"
echo "  - recyclarr (UID: ${RECYCLARR_UID})"
echo "  - prowlarr (UID: ${PROWLARR_UID})"
echo "  - overseerr (UID: ${OVERSEERR_UID})"
echo "  - plex (UID: ${PLEX_UID})"
echo "  - decypharr (UID: ${DECYPHARR_UID})"
echo "  - autoscan (UID: ${AUTOSCAN_UID})"
echo "  - pinchflat (UID: ${PINCHFLAT_UID})"
echo ""
echo "GROUP TO BE CREATED"
echo "-------------------"
echo "  - mediacenter (GID: ${MEDIACENTER_GID})"
echo ""
echo "DIRECTORIES TO BE CREATED"
echo "-------------------------"
echo "  - ${ROOT_DIR}/config/{sonarr,radarr,recyclarr,prowlarr,overseerr,plex,autoscan,zilean,decypharr}-config"
echo "  - ${ROOT_DIR}/data/symlinks/{radarr,sonarr}"
echo "  - ${ROOT_DIR}/data/realdebrid-zurg"
echo "  - ${ROOT_DIR}/data/media/{movies,tv}"
echo ""
echo "ADDITIONAL TASKS"
echo "----------------"
echo "  - Download Torrentio indexer for Prowlarr"
echo "  - Configure Zurg with Real-Debrid token"
echo "  - Configure Decypharr with Real-Debrid token"
echo "  - Set permissions (775/664)"
echo "  - Add current user ($USER) to mediacenter group"
echo ""
echo "========================================="
read -p "Do you want to proceed with the installation? (y/n): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled by user."
    echo "Your configuration has been saved to: $SCRIPT_DIR/docker/.env.install"
    echo "You can run this script again to install with the same configuration."
    exit 0
fi

# ========================================
# PHASE 3: UNATTENDED INSTALLATION
# ========================================

echo ""
echo "========================================="
echo "Starting Unattended Installation"
echo "========================================="
echo ""

# Validate installation directory exists
if [ ! -d "${ROOT_DIR}" ]; then
    echo "Creating installation directory: ${ROOT_DIR}"
    sudo mkdir -p "${ROOT_DIR}"
    sudo chown $USER:$USER "${ROOT_DIR}"
fi

# Create users and groups using library function
setup_mediacenter_users $INSTALL_UID $MEDIACENTER_GID

# Set base directory permissions
sudo chown -R $INSTALL_UID:mediacenter "${ROOT_DIR}"
sudo chmod 775 "${ROOT_DIR}"
log_success "Base directory permissions set"

# Add current user to mediacenter group
add_user_to_group $USER mediacenter

# Generate docker-compose.yml from selected templates
echo ""
echo "Generating docker-compose.yml from selected templates..."
log_operation "COMPOSE_GEN" "Generating docker-compose.yml"

cd "$SCRIPT_DIR"
./scripts/compose-generator.sh $SELECTED_TEMPLATES

if [ $? -ne 0 ]; then
    log_error "Failed to generate docker-compose.yml"
    exit 1
fi
log_success "docker-compose.yml generated successfully"

# Get list of services that need config directories
CONFIG_SERVICES=$(./scripts/get-config-dirs.sh $SELECTED_TEMPLATES)
log_debug "Services needing config directories: $CONFIG_SERVICES"

# Create directories
echo ""
echo "Creating directory structure..."

# Create config directories dynamically
for service in $CONFIG_SERVICES; do
    sudo mkdir -p "${ROOT_DIR}/config/${service}-config"
    log_debug "Created ${ROOT_DIR}/config/${service}-config"
done

# Data directories (always needed for *arr stack)
sudo mkdir -p "${ROOT_DIR}/data/symlinks"/{radarr,sonarr}
sudo mkdir -p "${ROOT_DIR}/data/realdebrid-zurg"
sudo mkdir -p "${ROOT_DIR}/data/media"/{movies,tv}
log_success "Directory structure created"

# Set permissions
echo ""
echo "Setting permissions..."
sudo chmod -R a=,a+rX,u+w,g+w ${ROOT_DIR}/data/
sudo chmod -R a=,a+rX,u+w,g+w ${ROOT_DIR}/config/

sudo chown -R $INSTALL_UID:mediacenter ${ROOT_DIR}/data/
sudo chown -R $INSTALL_UID:mediacenter ${ROOT_DIR}/config/

# Set ownership for each service's config directory (only if user exists)
for service in $CONFIG_SERVICES; do
    if id "$service" &>/dev/null; then
        sudo chown -R ${service}:mediacenter "${ROOT_DIR}/config/${service}-config"
        log_debug "Set ownership for ${service}-config"
    else
        log_debug "User ${service} does not exist, skipping ownership"
    fi
done
log_success "Permissions set"

# Copy docker directory to installation location if different
if [ "$ROOT_DIR" != "$SCRIPT_DIR" ]; then
    echo ""
    echo "Copying docker configuration to installation directory..."
    log_operation "COPY" "docker directory to ${ROOT_DIR}/docker"
    sudo cp -r "$SCRIPT_DIR/docker" "${ROOT_DIR}/"
    sudo chown -R $INSTALL_UID:mediacenter "${ROOT_DIR}/docker"
    echo "✓ Docker configuration copied to ${ROOT_DIR}/docker"

    # Copy recyclarr configuration
    log_operation "COPY" "recyclarr.yml and recyclarr-sync.sh to ${ROOT_DIR}/"
    sudo cp "$SCRIPT_DIR/config/recyclarr.yml" "${ROOT_DIR}/"
    sudo cp "$SCRIPT_DIR/scripts/recyclarr-sync.sh" "${ROOT_DIR}/"
    sudo chown $INSTALL_UID:mediacenter "${ROOT_DIR}/recyclarr.yml" "${ROOT_DIR}/recyclarr-sync.sh"
    sudo chmod +x "${ROOT_DIR}/recyclarr-sync.sh"
    echo "✓ Recyclarr configuration copied to ${ROOT_DIR}/"
fi

# Copy rclone.conf (ALWAYS needed, even if ROOT_DIR == SCRIPT_DIR)
echo ""
log_operation "COPY" "rclone.conf to ${ROOT_DIR}/"

# Verify source is a file
if [ ! -f "$SCRIPT_DIR/config/rclone.conf" ]; then
    log_error "Source rclone.conf is not a file: $SCRIPT_DIR/config/rclone.conf"
    exit 1
fi

# Remove destination if it's a directory
if [ -d "${ROOT_DIR}/rclone.conf" ]; then
    log_warning "Destination rclone.conf is a directory, removing it"
    sudo rm -rf "${ROOT_DIR}/rclone.conf"
fi

sudo cp "$SCRIPT_DIR/config/rclone.conf" "${ROOT_DIR}/"
sudo chown rclone:mediacenter "${ROOT_DIR}/rclone.conf"

# Verify it was copied as a file
if [ ! -f "${ROOT_DIR}/rclone.conf" ]; then
    log_error "Failed to copy rclone.conf as a file to ${ROOT_DIR}/"
    exit 1
fi

log_success "rclone.conf copied successfully to ${ROOT_DIR}/"

# Download custom indexer definitions for Prowlarr
echo ""
echo "Downloading custom indexer definitions..."
log_operation "MKDIR" "${ROOT_DIR}/config/prowlarr-config/Definitions/Custom"
sudo mkdir -p ${ROOT_DIR}/config/prowlarr-config/Definitions/Custom

# Download Torrentio from official repository
log_operation "DOWNLOAD" "Torrentio indexer definition from GitHub"
curl -sL https://github.com/dreulavelle/Prowlarr-Indexers/raw/main/Custom/torrentio.yml -o /tmp/torrentio.yml
sudo cp /tmp/torrentio.yml ${ROOT_DIR}/config/prowlarr-config/Definitions/Custom/
sudo chown prowlarr:mediacenter ${ROOT_DIR}/config/prowlarr-config/Definitions/Custom/torrentio.yml
sudo rm /tmp/torrentio.yml
echo "  ✓ Torrentio indexer definition downloaded"

# Download Zilean from official repository
curl -sL https://github.com/dreulavelle/Prowlarr-Indexers/raw/main/Custom/zilean.yml -o /tmp/zilean.yml
sudo cp /tmp/zilean.yml ${ROOT_DIR}/config/prowlarr-config/Definitions/Custom/
sudo chown prowlarr:mediacenter ${ROOT_DIR}/config/prowlarr-config/Definitions/Custom/zilean.yml
sudo rm /tmp/zilean.yml
echo "  ✓ Zilean indexer definition downloaded"

echo "✓ Custom indexer definitions configured"

# Configure Zurg with Real-Debrid token
echo ""
echo "Configuring Zurg with Real-Debrid token..."
sudo mkdir -p ${ROOT_DIR}/config/zurg-config
cat <<EOF | sudo tee ${ROOT_DIR}/config/zurg-config/config.yml > /dev/null
# Zurg configuration version
zurg: v1

# Provide your Real-Debrid API token
token: ${REALDEBRID_TOKEN} # https://real-debrid.com/apitoken

# Host and port settings
host: "[::]"
port: 9999

# Checking for changes in Real-Debrid API more frequently (every 60 seconds)
check_for_changes_every_secs: 60

# File handling and renaming settings
retain_rd_torrent_name: true
retain_folder_name_extension: true
expose_full_path: false

# Torrent management settings
enable_repair: false
auto_delete_rar_torrents: true

# Streaming and download link verification settings
serve_from_rclone: false
verify_download_link: false

# Network and API settings
force_ipv6: false

directories:
  torrents:
    group: 1
    filters:
      - regex: /.*/
EOF
sudo chown rclone:mediacenter ${ROOT_DIR}/config/zurg-config/config.yml
echo "✓ Zurg configured with Real-Debrid token"

# Configure Decypharr with Real-Debrid token
echo ""
echo "Configuring Decypharr with Real-Debrid token..."
sudo mkdir -p ${ROOT_DIR}/config/decypharr-config/{cache,logs,rclone}

# Create initial config.json
cat <<EOF | sudo tee ${ROOT_DIR}/config/decypharr-config/config.json > /dev/null
{
  "url_base": "/",
  "port": "8282",
  "log_level": "info",
  "debrids": [
    {
      "name": "realdebrid",
      "api_key": "${REALDEBRID_TOKEN}",
      "download_api_keys": [
        "${REALDEBRID_TOKEN}"
      ],
      "folder": "/data/realdebrid-zurg/torrents",
      "download_uncached": true,
      "rate_limit": "250/minute",
      "minimum_free_slot": 1
    }
  ],
  "qbittorrent": {
    "download_folder": "/data/media",
    "refresh_interval": 15
  },
  "arrs": [],
  "repair": {
    "enabled": true,
    "interval": "6",
    "auto_process": true,
    "use_webdav": true,
    "workers": 4,
    "strategy": "per_torrent"
  },
  "webdav": {},
  "rclone": {
    "enabled": true,
    "mount_path": "/mnt/remote",
    "rc_port": "5572",
    "vfs_cache_mode": "off",
    "vfs_cache_max_age": "1h",
    "vfs_cache_poll_interval": "1m",
    "vfs_read_chunk_size": "128M",
    "vfs_read_chunk_size_limit": "off",
    "vfs_read_ahead": "128k",
    "async_read": false,
    "transfers": 4,
    "uid": ${DECYPHARR_UID},
    "gid": ${MEDIACENTER_GID},
    "attr_timeout": "1s",
    "dir_cache_time": "5m",
    "log_level": "INFO"
  },
  "allowed_file_types": [
    "3gp", "ac3", "aiff", "alac", "amr", "ape", "asf", "asx", "avc", "avi",
    "bin", "bivx", "dat", "divx", "dts", "dv", "dvr-ms", "flac", "fli", "flv",
    "ifo", "m2ts", "m2v", "m3u", "m4a", "m4p", "m4v", "mid", "midi", "mk3d",
    "mka", "mkv", "mov", "mp2", "mp3", "mp4", "mpa", "mpeg", "mpg", "nrg",
    "nsv", "nuv", "ogg", "ogm", "ogv", "pva", "qt", "ra", "rm", "rmvb", "strm",
    "svq3", "ts", "ty", "viv", "vob", "voc", "vp3", "wav", "webm", "wma", "wmv",
    "wpl", "wtv", "wv", "xvid"
  ],
  "use_auth": false
}
EOF

# Create empty auth.json (will be populated on first run)
echo '{}' | sudo tee ${ROOT_DIR}/config/decypharr-config/auth.json > /dev/null

# Create empty torrents.json
echo '{}' | sudo tee ${ROOT_DIR}/config/decypharr-config/torrents.json > /dev/null

# Set permissions
sudo chown -R decypharr:mediacenter ${ROOT_DIR}/config/decypharr-config
sudo chmod 644 ${ROOT_DIR}/config/decypharr-config/*.json
echo "✓ Decypharr configured with Real-Debrid token"

# Mount healthcheck auto-repair system
echo ""
echo "========================================="
echo "Mount Healthcheck Auto-Repair System"
echo "========================================="
echo "This system monitors if containers (Radarr, Sonarr, Decypharr, Plex) can access"
echo "the rclone mount and automatically restarts them if they lose access."
echo ""
read -p "Do you want to install the mount healthcheck auto-repair system? (y/n): " -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Installing mount healthcheck scripts..."

    # Copy healthcheck scripts to /usr/local/bin/
    sudo cp "$SCRIPT_DIR/scripts/health/arrs-mount-healthcheck.sh" /usr/local/bin/
    sudo cp "$SCRIPT_DIR/scripts/health/plex-mount-healthcheck.sh" /usr/local/bin/

    # Set permissions
    sudo chmod 775 /usr/local/bin/arrs-mount-healthcheck.sh
    sudo chmod 775 /usr/local/bin/plex-mount-healthcheck.sh
    sudo chown $USER:$USER /usr/local/bin/arrs-mount-healthcheck.sh
    sudo chown $USER:$USER /usr/local/bin/plex-mount-healthcheck.sh

    # Create logs directory
    sudo mkdir -p ${ROOT_DIR}/logs
    sudo chown $USER:$USER ${ROOT_DIR}/logs

    # Note: Test file will be created after rclone mounts
    INSTALL_HEALTHCHECK_FILES=true

    echo "✓ Healthcheck scripts installed successfully"
    echo ""
    read -p "Do you want to add cron jobs for automatic healthchecks? (y/n): " -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Add cron jobs if they don't already exist
        (crontab -l 2>/dev/null | grep -v "arrs-mount-healthcheck"; echo "*/30 * * * * /usr/local/bin/arrs-mount-healthcheck.sh") | crontab -
        (crontab -l 2>/dev/null | grep -v "plex-mount-healthcheck"; echo "*/35 * * * * /usr/local/bin/plex-mount-healthcheck.sh") | crontab -
        echo "✓ Cron jobs added successfully"
    else
        echo "Skipping cron job configuration. You can add them manually later:"
        echo "  */30 * * * * /usr/local/bin/arrs-mount-healthcheck.sh"
        echo "  */35 * * * * /usr/local/bin/plex-mount-healthcheck.sh"
    fi
else
    echo "Skipping mount healthcheck installation."
fi

# ========================================
# PHASE 4: AUTO-CONFIGURATION VIA API
# ========================================

echo ""
echo "========================================="
echo "Auto-Configuration via API"
echo "========================================="
echo ""
read -p "Do you want to auto-configure Radarr, Sonarr, and Prowlarr? (y/n): " -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting auto-configuration process..."
    echo ""

    # Determine docker directory location
    DOCKER_DIR="${ROOT_DIR}/docker"

    # Generate .env.local from .env.install for docker compose
    echo "Creating .env.local from .env.install..."
    cp "$DOCKER_DIR/.env.install" "$DOCKER_DIR/.env.local"
    echo "✓ .env.local created"

    # Start services
    echo ""
    echo "Starting Docker services (this may take a few minutes)..."
    cd "$DOCKER_DIR"

    if [ "$TRAEFIK_ENABLED" = true ]; then
        echo "Traefik enabled - starting with reverse proxy..."
    else
        echo "Traefik disabled - using direct port access..."
    fi

    # Start all services (up.sh will handle Traefik profile automatically based on .env.local)
    log_operation "DOCKER_COMPOSE" "Starting all services"
    ./up.sh

    # Capture docker compose exit code
    COMPOSE_EXIT_CODE=$?

    if [ $COMPOSE_EXIT_CODE -ne 0 ]; then
        log_error "Docker Compose failed to start services (exit code: $COMPOSE_EXIT_CODE)"
        log_error "Check the output above for errors"
        exit 1
    fi

    # Validate all services started successfully
    echo ""
    log_info "Validating all services started correctly..."

    # Get expected services dynamically from selected templates
    cd "$SCRIPT_DIR"
    ALL_SERVICES=$(./scripts/get-services-list.sh $SELECTED_TEMPLATES)

    # Filter out setup-only services (like recyclarr) and infrastructure (networks, volumes)
    EXPECTED_SERVICES=()
    for service in $ALL_SERVICES; do
        # Skip setup-only and infrastructure services
        if [[ "$service" != "recyclarr" && "$service" != "networks" && "$service" != "volumes" ]]; then
            EXPECTED_SERVICES+=("$service")
        fi
    done

    log_debug "Expected services from templates: ${EXPECTED_SERVICES[@]}"

    # Count running containers
    RUNNING_COUNT=$(docker ps --filter "status=running" --format "{{.Names}}" | wc -l)
    EXPECTED_COUNT=${#EXPECTED_SERVICES[@]}

    log_debug "Expected services: $EXPECTED_COUNT, Running containers: $RUNNING_COUNT"

    # Check if all expected services are running
    FAILED_SERVICES=()
    for service in "${EXPECTED_SERVICES[@]}"; do
        if ! docker ps --format "{{.Names}}" | grep -q "^${service}$"; then
            FAILED_SERVICES+=("$service")
        fi
    done

    # Check for unhealthy containers
    UNHEALTHY_SERVICES=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" 2>/dev/null || true)

    # Report results
    if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
        log_error "The following services failed to start:"
        for service in "${FAILED_SERVICES[@]}"; do
            echo "  - $service"
            log_debug "Check logs with: docker logs $service"
        done
        echo ""
        log_error "Installation aborted due to failed services"
        log_error "Run 'docker compose logs' to see detailed error messages"
        exit 1
    fi

    if [ -n "$UNHEALTHY_SERVICES" ]; then
        log_warning "The following services are unhealthy (may still be starting):"
        echo "$UNHEALTHY_SERVICES" | while read service; do
            echo "  - $service"
        done
        echo ""
        log_info "Waiting 60 seconds for services to become healthy..."
        sleep 60

        # Check again
        STILL_UNHEALTHY=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" 2>/dev/null || true)
        if [ -n "$STILL_UNHEALTHY" ]; then
            log_error "The following services are still unhealthy after waiting:"
            echo "$STILL_UNHEALTHY" | while read service; do
                echo "  - $service"
                echo "  Check logs: docker logs $service"
            done
            echo ""
            log_error "Installation aborted due to unhealthy services"
            exit 1
        fi
    fi

    log_success "All $EXPECTED_COUNT services started successfully"
    echo "✓ Service validation passed"

    # Auto-configure services using setup-executor
    echo ""
    echo "Configuring services automatically..."
    log_operation "AUTO_CONFIG" "Running setup-executor for selected templates"

    cd "$SCRIPT_DIR"
    ./scripts/setup-executor.sh $SELECTED_TEMPLATES

    SETUP_EXIT_CODE=$?

    if [ $SETUP_EXIT_CODE -eq 0 ]; then
        log_success "All services configured successfully!"
        echo "✓ Auto-configuration completed"
    else
        log_error "Service configuration failed (exit code: $SETUP_EXIT_CODE)"
        echo "You may need to configure services manually"
        echo "Check the logs above for errors"
    fi

    # Restart services to apply configuration changes
    echo ""
    echo "Restarting services to apply configuration..."
    cd "$DOCKER_DIR"
    ./up.sh
    log_success "All services restarted with new configuration"
else
    echo "Skipping auto-configuration."
    echo "You will need to configure services manually after starting them."
fi

# Create healthcheck test file if healthchecks were installed
if [ "$INSTALL_HEALTHCHECK_FILES" = true ]; then
    echo ""
    echo "Creating healthcheck test file..."
    # Wait a bit for rclone mount to be ready
    sleep 5

    # Create test file
    if [ -d "${ROOT_DIR}/data/realdebrid-zurg/torrents" ]; then
        echo "HEALTHCHECK TEST FILE - DO NOT DELETE" | sudo tee ${ROOT_DIR}/data/realdebrid-zurg/torrents/.healthcheck_test.txt > /dev/null
        sudo chown rclone:mediacenter ${ROOT_DIR}/data/realdebrid-zurg/torrents/.healthcheck_test.txt

        # Create symlink in media directory
        sudo mkdir -p ${ROOT_DIR}/data/media/.healthcheck
        sudo ln -sf ${ROOT_DIR}/data/realdebrid-zurg/torrents/.healthcheck_test.txt ${ROOT_DIR}/data/media/.healthcheck/test_symlink.txt

        echo "✓ Healthcheck test file created"
    else
        echo "⚠ Warning: rclone mount not ready yet. Create test file manually later:"
        echo "  echo 'HEALTHCHECK TEST FILE' | sudo tee ${ROOT_DIR}/data/realdebrid-zurg/torrents/.healthcheck_test.txt"
    fi
fi

# Final message
echo ""
echo "========================================="
echo "Installation Complete!"
echo "========================================="
echo ""
echo "Configuration file: ${ROOT_DIR}/docker/.env.install"
echo "Installation directory: ${ROOT_DIR}"
echo ""
echo "SERVICES AUTOMATICALLY CONFIGURED:"
echo "  ✓ Zurg - Real-Debrid token configured"
echo "  ✓ Decypharr - Real-Debrid token and settings configured"
echo "  ✓ Radarr - Root folder + Decypharr download client + quality profiles"
echo "  ✓ Sonarr - Root folder + Decypharr download client + quality profiles"
echo "  ✓ Prowlarr - 6 indexers (Torrentio, Zilean, 1337x, TPB, YTS, EZTV)"
echo "             - Radarr/Sonarr sync enabled (indexers auto-synced)"
echo "  ✓ Recyclarr - Quality profiles and naming conventions from TRaSH Guides"
echo ""
echo "SERVICES REQUIRING MANUAL CONFIGURATION:"
echo "  • Plex - Add media libraries (/data/media/movies, /data/media/tv)"
echo "  • Overseerr - Connect to Plex and Radarr/Sonarr (optional)"
echo "  • Prowlarr - Add more indexers if needed (optional)"
echo ""
echo "IMPORTANT - ZILEAN INDEXER:"
echo "  ⚠ Zilean may take 10-30 minutes to import DMM data on first run"
echo "  • The Zilean indexer is currently DISABLED in Prowlarr"
echo "  • Once Zilean finishes importing, enable it in Prowlarr > Indexers"
echo "  • Check Zilean status: docker logs zilean -f"
echo ""
echo "Next steps:"
echo "1. All services are now running! You can access them at:"
if [ "$TRAEFIK_ENABLED" = true ]; then
    echo "   • Traefik Dashboard: http://${DOMAIN_NAME}:8080"
    echo "   • Prowlarr:  http://prowlarr.${DOMAIN_NAME}  (already configured!)"
    echo "   • Radarr:    http://radarr.${DOMAIN_NAME}    (already configured!)"
    echo "   • Sonarr:    http://sonarr.${DOMAIN_NAME}    (already configured!)"
    echo "   • Overseerr: http://overseerr.${DOMAIN_NAME}"
    echo "   • Plex:      http://${DOMAIN_NAME}:32400/web"
else
    echo "   • Prowlarr:  http://${DOMAIN_NAME}:9696  (already configured!)"
    echo "   • Radarr:    http://${DOMAIN_NAME}:7878  (already configured!)"
    echo "   • Sonarr:    http://${DOMAIN_NAME}:8989  (already configured!)"
    echo "   • Overseerr: http://${DOMAIN_NAME}:5055"
    echo "   • Plex:      http://${DOMAIN_NAME}:32400/web"
fi
echo ""
echo "2. Configure remaining services manually:"
echo ""
echo "   PLEX - Add media libraries:"
echo "   • Movies: /data/media/movies"
echo "   • TV Shows: /data/media/tv"
echo "   • YouTube: /data/media/youtube"
echo ""
echo "   OVERSEERR - Connect to Plex and Radarr/Sonarr:"
echo "   • Sign in with Plex account"
echo "   • Add Radarr and Sonarr with their API keys (see below)"
echo "   • Configure quality profiles and root folders"
echo "   • Detailed guide: docker/POST-INSTALL.md"
echo ""
echo "   API KEYS FOR OVERSEERR CONFIGURATION:"
echo "   • Radarr API Key: ${RADARR_API_KEY}"
echo "   • Sonarr API Key: ${SONARR_API_KEY}"
echo "   • Prowlarr API Key: ${PROWLARR_API_KEY}"
echo ""
echo "   PINCHFLAT - Configure YouTube downloads (optional)"
echo "   TAUTULLI - Connect to Plex for statistics (optional)"
echo ""
echo "   RECYCLARR - Update quality profiles (optional):"
echo "   • To manually update profiles: cd ${ROOT_DIR} && ./recyclarr-sync.sh"
echo "   • Recommended after TRaSH Guides updates or profile changes"
echo ""
echo "3. IMPORTANT: Apply group changes to current session:"
echo "   newgrp mediacenter"
echo ""
echo "   Or logout and login again for permanent effect."
echo ""
echo "4. To manage services:"
echo "   cd ${ROOT_DIR}/docker"
echo "   ./up.sh      # Start all services"
echo "   ./down.sh    # Stop all services"
echo "   ./restart.sh # Restart all services"
echo ""
echo "For detailed setup guide, visit the documentation."
echo ""
echo "========================================="
echo "Installation logs saved to:"
echo "  ${SETUP_LOG_FILE}"
echo "  ${SETUP_TRACE_FILE}"
echo "========================================="
log_info "Installation completed successfully"
log_to_file "COMPLETE" "Installation finished at $(date)"

# Ask if user wants to remove the installer repository
echo ""
echo "========================================="
echo "Cleanup"
echo "========================================="
echo ""
echo "The installer repository is no longer needed. All configuration"
echo "files have been copied to ${ROOT_DIR}."
echo ""
echo "Installation directory: $(pwd)"
echo ""
read -p "Do you want to remove the installer repository? [y/N]: " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Use SCRIPT_DIR that was calculated at the start of the script
    # This is more reliable than recalculating from BASH_SOURCE
    log_info "Removing installer repository: ${SCRIPT_DIR}"

    # Move to parent directory before deletion
    cd "${SCRIPT_DIR}/.."

    # Remove the installer directory
    rm -rf "${SCRIPT_DIR}"

    if [ $? -eq 0 ]; then
        log_success "Installer repository removed successfully"
        echo ""
        echo "The sailarr-installer directory has been deleted."
        echo "All your configuration is preserved in ${ROOT_DIR}"
    else
        log_error "Failed to remove installer repository"
        echo "You can manually delete it later: rm -rf ${SCRIPT_DIR}"
    fi
else
    log_info "Installer repository kept at: ${SCRIPT_DIR}"
    echo ""
    echo "You can manually remove it later if needed:"
    echo "  rm -rf ${SCRIPT_DIR}"
fi

echo ""
