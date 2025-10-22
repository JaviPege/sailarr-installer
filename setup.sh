#!/bin/bash

# Mediacenter Setup Script
# This script collects installation information and creates .env.install
# Then performs an unattended installation

# ========================================
# ATOMIC FUNCTIONS
# ========================================

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        echo "ERROR: Do not run this script with sudo or as root!"
        echo "The script will request sudo permissions when needed."
        echo ""
        echo "Please run: ./setup.sh"
        exit 1
    fi
}

# Ask user for input with standard format
# Usage: ask_user_input "title" "description" "prompt" "default_value" "required" "output_var"
ask_user_input() {
    local title="$1"
    local description="$2"
    local prompt="$3"
    local default_value="$4"
    local required="$5"
    local output_var="$6"

    if [ -n "$title" ]; then
        echo "$title"
        echo "$(printf '%*s' ${#title} '' | tr ' ' '-')"
    fi

    if [ -n "$description" ]; then
        echo "$description"
    fi

    if [ -n "$default_value" ]; then
        echo "Current default: $default_value"
    fi

    read -p "$prompt" user_input

    # Apply default if empty
    user_input="${user_input:-$default_value}"

    # Validate if required
    if [ "$required" = "true" ]; then
        while [ -z "$user_input" ]; do
            echo "ERROR: This field is required!"
            read -p "$prompt" user_input
            user_input="${user_input:-$default_value}"
        done
    fi

    echo ""

    # Store in output variable
    eval "$output_var='$user_input'"
}

# Ask user for password (hidden input)
# Usage: ask_password "prompt" "required" "output_var"
ask_password() {
    local prompt="$1"
    local required="$2"
    local output_var="$3"

    read -sp "$prompt" user_password
    echo ""

    # Validate if required
    if [ "$required" = "true" ]; then
        while [ -z "$user_password" ]; do
            echo "ERROR: This field is required!"
            read -sp "$prompt" user_password
            echo ""
        done
    fi

    # Store in output variable
    eval "$output_var='$user_password'"
}

# Check if UID is in conflict and return available UID
# Usage: new_uid=$(check_uid_conflict "username" "desired_uid")
check_uid_conflict() {
    local username="$1"
    local desired_uid="$2"

    # If user already exists, return its current UID
    if id "$username" >/dev/null 2>&1; then
        id -u "$username"
        return 0
    fi

    # If UID is available, return it
    if ! getent passwd "$desired_uid" >/dev/null 2>&1; then
        echo "$desired_uid"
        return 0
    fi

    # UID is in conflict, find available one
    local available_uid=$(find_available_uid "$desired_uid")
    echo "$available_uid"
}

# Check if GID is in conflict and return available GID
# Usage: new_gid=$(check_gid_conflict "groupname" "desired_gid")
check_gid_conflict() {
    local groupname="$1"
    local desired_gid="$2"

    # If group already exists, return its current GID
    if getent group "$groupname" >/dev/null 2>&1; then
        getent group "$groupname" | cut -d: -f3
        return 0
    fi

    # If GID is available, return it
    if ! getent group "$desired_gid" >/dev/null 2>&1; then
        echo "$desired_gid"
        return 0
    fi

    # GID is in conflict, find available one
    local available_gid=$(find_available_gid "$desired_gid")
    echo "$available_gid"
}

# Create .env.install configuration file
create_env_install() {
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
}

# Create folder with permissions (atomic, reusable)
# Usage: create_folder "/path/to/folder" "owner:group" "permissions"
create_folder() {
    local folder_path="$1"
    local owner="${2:-$USER:$USER}"
    local permissions="${3:-755}"

    sudo mkdir -p "$folder_path"
    sudo chown "$owner" "$folder_path"
    sudo chmod "$permissions" "$folder_path"
}

# Set permissions on path (atomic, reusable)
# Usage: set_permissions "/path" "permissions" "owner:group"
set_permissions() {
    local path="$1"
    local permissions="$2"
    local owner="$3"

    if [ -n "$permissions" ]; then
        sudo chmod -R "$permissions" "$path"
    fi

    if [ -n "$owner" ]; then
        sudo chown -R "$owner" "$path"
    fi
}

# Copy file with permissions (atomic, reusable)
# Usage: copy_file "source" "destination" "owner:group" "permissions"
copy_file() {
    local source="$1"
    local destination="$2"
    local owner="${3:-}"
    local permissions="${4:-}"

    sudo cp "$source" "$destination"

    if [ -n "$owner" ]; then
        sudo chown "$owner" "$destination"
    fi

    if [ -n "$permissions" ]; then
        sudo chmod "$permissions" "$destination"
    fi
}

# Download file from URL with permissions (atomic, reusable)
# Usage: download_file "url" "destination" "owner:group" "permissions"
download_file() {
    local url="$1"
    local destination="$2"
    local owner="${3:-}"
    local permissions="${4:-}"

    local temp_file="/tmp/download-$$-$(basename "$destination")"

    curl -sL "$url" -o "$temp_file"
    sudo cp "$temp_file" "$destination"
    rm -f "$temp_file"

    if [ -n "$owner" ]; then
        sudo chown "$owner" "$destination"
    fi

    if [ -n "$permissions" ]; then
        sudo chmod "$permissions" "$destination"
    fi
}

# Create file from content with permissions (atomic, reusable)
# Usage: create_file_from_content "destination" "content" "owner:group" "permissions"
create_file_from_content() {
    local destination="$1"
    local content="$2"
    local owner="${3:-}"
    local permissions="${4:-}"

    echo "$content" | sudo tee "$destination" > /dev/null

    if [ -n "$owner" ]; then
        sudo chown "$owner" "$destination"
    fi

    if [ -n "$permissions" ]; then
        sudo chmod "$permissions" "$destination"
    fi
}

# Run docker compose up with validation (atomic, reusable)
# Usage: run_docker_compose_up "/path/to/docker/dir"
# Returns: 0 if success, 1 if failed
run_docker_compose_up() {
    local compose_dir="$1"

    cd "$compose_dir" || return 1
    ./up.sh
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        log_error "Docker Compose failed to start services (exit code: $exit_code)" >&2
        return 1
    fi

    return 0
}

# Validate that ONE docker service is running (atomic, call N times)
# Usage: validate_docker_service "service_name"
# Returns: 0 if running, 1 if not running
validate_docker_service() {
    local service_name="$1"

    if docker ps --format "{{.Names}}" | grep -q "^${service_name}$"; then
        return 0
    else
        return 1
    fi
}

# Get docker container health status (atomic, call N times)
# Usage: get_docker_health_status "container_name" "output_var"
get_docker_health_status() {
    local container_name="$1"
    local output_var="$2"
    local status

    status=$(docker inspect -f '{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none")

    eval "$output_var='$status'"
}

# Wait for HTTP service to be ready (atomic, call N times)
# Usage: wait_for_http_service "service_name" "url" "max_attempts" "sleep_seconds"
# Returns: 0 if ready, 1 if timeout
wait_for_http_service() {
    local service_name="$1"
    local service_url="$2"
    local max_attempts="${3:-60}"
    local sleep_seconds="${4:-2}"
    local attempt=1

    echo -n "Waiting for $service_name to be ready"
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$service_url" > /dev/null 2>&1; then
            echo " ✓"
            return 0
        fi
        echo -n "."
        sleep $sleep_seconds
        attempt=$((attempt + 1))
    done
    echo " ✗ (timeout)"
    return 1
}

# Wait for docker container to be healthy (atomic, call N times)
# Usage: wait_for_docker_health "container_name" "max_attempts" "sleep_seconds"
# Returns: 0 if healthy, 1 if timeout
wait_for_docker_health() {
    local container_name="$1"
    local max_attempts="${2:-60}"
    local sleep_seconds="${3:-2}"
    local attempt=1
    local status

    echo -n "Waiting for $container_name to be ready"
    while [ $attempt -le $max_attempts ]; do
        status=$(docker inspect -f '{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none")
        if [ "$status" = "healthy" ]; then
            echo " ✓"
            return 0
        fi
        echo -n "."
        sleep $sleep_seconds
        attempt=$((attempt + 1))
    done
    echo " ✗ (timeout)"
    return 1
}

# Generic GET request with API key (atomic, reusable)
# Usage: api_get_request "url" "api_key" "output_var"
# Returns: 0 if success, 1 if failed
api_get_request() {
    local url="$1"
    local api_key="$2"
    local output_var="$3"
    local response

    response=$(curl -s "$url" -H "X-Api-Key: $api_key")

    if [ -z "$response" ]; then
        return 1
    fi

    eval "$output_var='$response'"
    return 0
}

# Generic PUT request with API key and HTTP code validation (atomic, reusable)
# Usage: api_put_request "url" "api_key" "json_data"
# Returns: 0 if 2xx, 1 if error
api_put_request() {
    local url="$1"
    local api_key="$2"
    local json_data="$3"
    local response
    local http_code

    response=$(curl -s -w '\n%{http_code}' -X PUT "$url" \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d "$json_data")

    http_code=$(echo "$response" | tail -n1)

    if [[ "$http_code" =~ ^2 ]]; then
        return 0
    else
        log_error "PUT request failed with HTTP $http_code" >&2
        return 1
    fi
}

# Generic POST request with API key (atomic, reusable)
# Usage: api_post_request "url" "api_key" "json_data"
# Returns: 0 if success, 1 if failed
api_post_request() {
    local url="$1"
    local api_key="$2"
    local json_data="$3"

    if curl -s -X POST "$url" \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d "$json_data" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Configure authentication for *arr service (atomic, call N times)
# Usage: configure_arr_authentication "service_name" "port" "api_key" "username" "password" ["api_version"]
# Returns: 0 if success, 1 if failed
configure_arr_authentication() {
    local service_name="$1"
    local port="$2"
    local api_key="$3"
    local username="$4"
    local password="$5"
    local api_version="${6:-v3}"  # Default to v3 for Radarr/Sonarr, v1 for Prowlarr
    local config
    local updated_config

    echo "  ⟳ Configuring $service_name authentication..." >&2

    # Get current config
    if ! api_get_request "http://localhost:$port/api/$api_version/config/host" "$api_key" config; then
        log_error "Failed to get $service_name config for authentication setup" >&2
        return 1
    fi

    if [ -z "$config" ]; then
        log_error "Failed to get $service_name config for authentication setup" >&2
        return 1
    fi

    # Update authentication settings
    updated_config=$(echo "$config" | jq --arg user "$username" --arg pass "$password" \
        '. + {authenticationMethod: "forms", username: $user, password: $pass, passwordConfirmation: $pass, authenticationRequired: "enabled"}')

    # Send update
    if api_put_request "http://localhost:$port/api/$api_version/config/host" "$api_key" "$updated_config"; then
        echo "  ✓ $service_name authentication configured" >&2
        return 0
    else
        log_error "Failed to configure $service_name authentication" >&2
        return 1
    fi
}

# Get Prowlarr application ID by name (atomic, call N times)
# Usage: get_prowlarr_app_id "port" "api_key" "app_name" "output_var"
# Returns: 0 if found, 1 if not found
get_prowlarr_app_id() {
    local port="$1"
    local api_key="$2"
    local app_name="$3"
    local output_var="$4"
    local apps_json
    local app_id

    if ! api_get_request "http://localhost:$port/api/v1/applications" "$api_key" apps_json; then
        return 1
    fi

    app_id=$(echo "$apps_json" | jq -r ".[] | select(.name == \"$app_name\") | .id")

    if [ -z "$app_id" ] || [ "$app_id" = "null" ]; then
        return 1
    fi

    eval "$output_var='$app_id'"
    return 0
}

# Trigger Prowlarr indexer sync to ONE application (atomic, call N times)
# Usage: trigger_prowlarr_sync "port" "api_key" "app_id"
# Returns: 0 if success, 1 if failed
trigger_prowlarr_sync() {
    local port="$1"
    local api_key="$2"
    local app_id="$3"
    local json_payload

    json_payload="{\"name\": \"ApplicationIndexerSync\", \"applicationIds\": [$app_id]}"

    if api_post_request "http://localhost:$port/api/v1/command" "$api_key" "$json_payload"; then
        return 0
    else
        return 1
    fi
}

# Run recyclarr sync with API keys injected (atomic, reusable)
# Usage: run_recyclarr_sync "config_file" "radarr_api_key" "sonarr_api_key"
# Returns: exit code from docker run
run_recyclarr_sync() {
    local config_file="$1"
    local radarr_key="$2"
    local sonarr_key="$3"
    local temp_file="/tmp/recyclarr-temp.yml"

    # Inject API keys using awk
    awk -v radarr_key="$radarr_key" -v sonarr_key="$sonarr_key" '
        /^radarr:/ {in_radarr=1; in_sonarr=0}
        /^sonarr:/ {in_radarr=0; in_sonarr=1}
        /api_key:$/ {
            if (in_radarr) {print "    api_key: " radarr_key; next}
            if (in_sonarr) {print "    api_key: " sonarr_key; next}
        }
        {print}
    ' "$config_file" > "$temp_file"

    # Run recyclarr
    docker run --rm \
        --network mediacenter \
        -v "$temp_file:/config/recyclarr.yml:ro" \
        ghcr.io/recyclarr/recyclarr:latest \
        sync

    local exit_code=$?

    # Clean up
    rm -f "$temp_file"

    return $exit_code
}

# Append content to file (atomic, reusable)
# Usage: append_to_file "file_path" "content"
append_to_file() {
    local file_path="$1"
    local content="$2"

    echo "$content" >> "$file_path"
}

# Show installation summary
show_installation_summary() {
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
}

# Check for existing configuration
check_existing_config() {
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
}

# ========================================
# MAIN SCRIPT
# ========================================

# Check if running as root
check_root

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
check_existing_config

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
    ask_user_input \
        "Installation Directory" \
        "" \
        "Enter installation directory [press Enter for default]: " \
        "${ROOT_DIR:-/mediacenter}" \
        "false" \
        "INSTALL_DIR"

    # Ask for timezone
    ask_user_input \
        "Timezone Configuration" \
        "Examples: Europe/Madrid, America/New_York, Asia/Tokyo" \
        "Enter timezone [press Enter for default]: " \
        "${TIMEZONE:-Europe/Madrid}" \
        "false" \
        "USER_TIMEZONE"

    # Ask for Real-Debrid token
    ask_user_input \
        "Real-Debrid API Token" \
        "Get your API token from: https://real-debrid.com/apitoken
This is required for Zurg and Decypharr to work." \
        "Enter Real-Debrid API token: " \
        "" \
        "true" \
        "REALDEBRID_TOKEN"

    # Ask for Plex claim token (optional)
    ask_user_input \
        "Plex Claim Token (Optional)" \
        "Get claim token from: https://www.plex.tv/claim/
NOTE: Claim tokens expire in 4 minutes. Leave empty to configure later." \
        "Enter Plex claim token [press Enter to skip]: " \
        "" \
        "false" \
        "PLEX_CLAIM"

    # Ask for authentication credentials (optional)
    ask_user_input \
        "Service Authentication (Optional)" \
        "Configure username/password for Radarr, Sonarr, and Prowlarr web UI.
Leave empty to skip and configure manually later." \
        "Do you want to configure authentication? (y/n): " \
        "" \
        "false" \
        "auth_choice"

    AUTH_ENABLED=false
    if [[ $auth_choice =~ ^[Yy]$ ]]; then
        ask_user_input \
            "" \
            "" \
            "Enter username: " \
            "" \
            "true" \
            "AUTH_USERNAME"

        ask_password "Enter password: " "true" "AUTH_PASSWORD"

        AUTH_ENABLED=true
        echo "✓ Authentication will be configured"
    else
        echo "Authentication skipped - configure manually later"
    fi
    echo ""

    # Ask for Traefik configuration
    ask_user_input \
        "Traefik Reverse Proxy (Optional)" \
        "Traefik provides a reverse proxy for accessing services via domain names.
If disabled, services will be accessible via their direct ports." \
        "Do you want to enable Traefik? (y/n): " \
        "" \
        "false" \
        "traefik_choice"

    TRAEFIK_ENABLED=true
    if [[ $traefik_choice =~ ^[Nn]$ ]]; then
        TRAEFIK_ENABLED=false
        USER_DOMAIN="localhost"
        echo "Traefik disabled - services will use direct port access"
        echo ""
    else
        TRAEFIK_ENABLED=true
        echo "✓ Traefik will be enabled"
        echo ""

        # Ask for domain name (only if Traefik is enabled)
        ask_user_input \
            "Domain/Hostname Configuration" \
            "This will be used for Traefik routing (e.g., radarr.yourdomain.local)" \
            "Enter domain/hostname [press Enter for default]: " \
            "${DOMAIN_NAME:-mediacenter.local}" \
            "false" \
            "USER_DOMAIN"
    fi

    # Check and auto-fix UID/GID conflicts
    echo "Checking for UID/GID conflicts..."
    echo ""

    # Check GID for mediacenter group
    ORIGINAL_GID=$MEDIACENTER_GID
    MEDIACENTER_GID=$(check_gid_conflict "mediacenter" "$MEDIACENTER_GID")
    if [ "$MEDIACENTER_GID" != "$ORIGINAL_GID" ]; then
        echo "  → Assigned GID $MEDIACENTER_GID for mediacenter group (was $ORIGINAL_GID, in use)"
    fi

    # Check UIDs for all users
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

        new_uid=$(check_uid_conflict "$username" "$uid_value")

        if [ "$new_uid" != "$uid_value" ]; then
            echo "  → Assigned UID $new_uid for $username (was $uid_value, in use)"
            eval "$var_name=$new_uid"
        fi
    done

    echo ""
    echo "No UID/GID conflicts detected. Using defaults."
    echo ""

    # Create .env.install with all configuration
    create_env_install
fi

# ========================================
# PHASE 2: SHOW SUMMARY
# ========================================

show_installation_summary

ask_user_input \
    "" \
    "" \
    "Do you want to proceed with the installation? (y/n): " \
    "" \
    "false" \
    "install_confirm"

if [[ ! $install_confirm =~ ^[Yy]$ ]]; then
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

# Create directories
echo ""
echo "Creating directory structure..."

# Config directories for each service
create_folder "${ROOT_DIR}/config/sonarr-config" "$INSTALL_UID:mediacenter" "775"
create_folder "${ROOT_DIR}/config/radarr-config" "$INSTALL_UID:mediacenter" "775"
create_folder "${ROOT_DIR}/config/recyclarr-config" "$INSTALL_UID:mediacenter" "775"
create_folder "${ROOT_DIR}/config/prowlarr-config" "$INSTALL_UID:mediacenter" "775"
create_folder "${ROOT_DIR}/config/overseerr-config" "$INSTALL_UID:mediacenter" "775"
create_folder "${ROOT_DIR}/config/plex-config" "$INSTALL_UID:mediacenter" "775"
create_folder "${ROOT_DIR}/config/autoscan-config" "$INSTALL_UID:mediacenter" "775"
create_folder "${ROOT_DIR}/config/zilean-config" "$INSTALL_UID:mediacenter" "775"
create_folder "${ROOT_DIR}/config/decypharr-config" "$INSTALL_UID:mediacenter" "775"
create_folder "${ROOT_DIR}/config/pinchflat-config" "$INSTALL_UID:mediacenter" "775"

# Data directories
create_folder "${ROOT_DIR}/data/symlinks/radarr" "$INSTALL_UID:mediacenter" "775"
create_folder "${ROOT_DIR}/data/symlinks/sonarr" "$INSTALL_UID:mediacenter" "775"
create_folder "${ROOT_DIR}/data/realdebrid-zurg" "$INSTALL_UID:mediacenter" "775"
create_folder "${ROOT_DIR}/data/media/movies" "$INSTALL_UID:mediacenter" "775"
create_folder "${ROOT_DIR}/data/media/tv" "$INSTALL_UID:mediacenter" "775"

echo "✓ Directory structure created"

# Set permissions
echo ""
echo "Setting permissions..."

set_permissions "${ROOT_DIR}/data/" "a=,a+rX,u+w,g+w" "$INSTALL_UID:mediacenter"
set_permissions "${ROOT_DIR}/config/" "a=,a+rX,u+w,g+w" "$INSTALL_UID:mediacenter"
set_permissions "${ROOT_DIR}/config/sonarr-config" "" "sonarr:mediacenter"
set_permissions "${ROOT_DIR}/config/radarr-config" "" "radarr:mediacenter"
set_permissions "${ROOT_DIR}/config/recyclarr-config" "" "recyclarr:mediacenter"
set_permissions "${ROOT_DIR}/config/prowlarr-config" "" "prowlarr:mediacenter"
set_permissions "${ROOT_DIR}/config/overseerr-config" "" "overseerr:mediacenter"
set_permissions "${ROOT_DIR}/config/plex-config" "" "plex:mediacenter"
set_permissions "${ROOT_DIR}/config/decypharr-config" "" "decypharr:mediacenter"
set_permissions "${ROOT_DIR}/config/autoscan-config" "" "autoscan:mediacenter"
set_permissions "${ROOT_DIR}/config/pinchflat-config" "" "pinchflat:mediacenter"

echo "✓ Permissions set"

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
    copy_file "$SCRIPT_DIR/config/recyclarr.yml" "${ROOT_DIR}/recyclarr.yml" "$INSTALL_UID:mediacenter"
    copy_file "$SCRIPT_DIR/scripts/recyclarr-sync.sh" "${ROOT_DIR}/recyclarr-sync.sh" "$INSTALL_UID:mediacenter" "+x"
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

copy_file "$SCRIPT_DIR/config/rclone.conf" "${ROOT_DIR}/rclone.conf" "rclone:mediacenter"

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
create_folder "${ROOT_DIR}/config/prowlarr-config/Definitions/Custom" "prowlarr:mediacenter" "755"

# Download Torrentio from official repository
log_operation "DOWNLOAD" "Torrentio indexer definition from GitHub"
download_file \
    "https://github.com/dreulavelle/Prowlarr-Indexers/raw/main/Custom/torrentio.yml" \
    "${ROOT_DIR}/config/prowlarr-config/Definitions/Custom/torrentio.yml" \
    "prowlarr:mediacenter"
echo "  ✓ Torrentio indexer definition downloaded"

# Download Zilean from official repository
download_file \
    "https://github.com/dreulavelle/Prowlarr-Indexers/raw/main/Custom/zilean.yml" \
    "${ROOT_DIR}/config/prowlarr-config/Definitions/Custom/zilean.yml" \
    "prowlarr:mediacenter"
echo "  ✓ Zilean indexer definition downloaded"

echo "✓ Custom indexer definitions configured"

# Configure Zurg with Real-Debrid token
echo ""
echo "Configuring Zurg with Real-Debrid token..."
create_folder "${ROOT_DIR}/config/zurg-config" "rclone:mediacenter" "755"

ZURG_CONFIG="# Zurg configuration version
zurg: v1

# Provide your Real-Debrid API token
token: ${REALDEBRID_TOKEN} # https://real-debrid.com/apitoken

# Host and port settings
host: \"[::]\"
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
      - regex: /.*/"

create_file_from_content "${ROOT_DIR}/config/zurg-config/config.yml" "$ZURG_CONFIG" "rclone:mediacenter"
echo "✓ Zurg configured with Real-Debrid token"

# Configure Decypharr with Real-Debrid token
echo ""
echo "Configuring Decypharr with Real-Debrid token..."
create_folder "${ROOT_DIR}/config/decypharr-config/cache" "decypharr:mediacenter" "755"
create_folder "${ROOT_DIR}/config/decypharr-config/logs" "decypharr:mediacenter" "755"
create_folder "${ROOT_DIR}/config/decypharr-config/rclone" "decypharr:mediacenter" "755"

# Create initial config.json
DECYPHARR_CONFIG='{
  "url_base": "/",
  "port": "8282",
  "log_level": "info",
  "debrids": [
    {
      "name": "realdebrid",
      "api_key": "'${REALDEBRID_TOKEN}'",
      "download_api_keys": [
        "'${REALDEBRID_TOKEN}'"
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
    "uid": '${DECYPHARR_UID}',
    "gid": '${MEDIACENTER_GID}',
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
}'

create_file_from_content "${ROOT_DIR}/config/decypharr-config/config.json" "$DECYPHARR_CONFIG" "decypharr:mediacenter"

# Create empty auth.json and torrents.json
create_file_from_content "${ROOT_DIR}/config/decypharr-config/auth.json" "{}" "decypharr:mediacenter"
create_file_from_content "${ROOT_DIR}/config/decypharr-config/torrents.json" "{}" "decypharr:mediacenter"
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

ask_user_input \
    "" \
    "" \
    "Do you want to install the mount healthcheck auto-repair system? (y/n): " \
    "" \
    "false" \
    "healthcheck_choice"

if [[ $healthcheck_choice =~ ^[Yy]$ ]]; then
    echo "Installing mount healthcheck scripts..."

    # Copy healthcheck scripts to /usr/local/bin/
    copy_file "$SCRIPT_DIR/scripts/health/arrs-mount-healthcheck.sh" "/usr/local/bin/arrs-mount-healthcheck.sh" "$USER:$USER" "775"
    copy_file "$SCRIPT_DIR/scripts/health/plex-mount-healthcheck.sh" "/usr/local/bin/plex-mount-healthcheck.sh" "$USER:$USER" "775"

    # Create logs directory
    create_folder "${ROOT_DIR}/logs" "$USER:$USER" "755"

    # Note: Test file will be created after rclone mounts
    INSTALL_HEALTHCHECK_FILES=true

    echo "✓ Healthcheck scripts installed successfully"
    echo ""

    ask_user_input \
        "" \
        "" \
        "Do you want to add cron jobs for automatic healthchecks? (y/n): " \
        "" \
        "false" \
        "cron_choice"

    if [[ $cron_choice =~ ^[Yy]$ ]]; then
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

ask_user_input \
    "" \
    "" \
    "Do you want to auto-configure Radarr, Sonarr, and Prowlarr? (y/n): " \
    "" \
    "false" \
    "autoconfig_choice"

if [[ $autoconfig_choice =~ ^[Yy]$ ]]; then
    echo "Starting auto-configuration process..."
    echo ""

    # Determine docker directory location
    DOCKER_DIR="${ROOT_DIR}/docker"

    # Generate .env.local from .env.install for docker compose
    echo "Creating .env.local from .env.install..."
    copy_file "$DOCKER_DIR/.env.install" "$DOCKER_DIR/.env.local"
    echo "✓ .env.local created"

    # Start services
    echo ""
    echo "Starting Docker services (this may take a few minutes)..."

    if [ "$TRAEFIK_ENABLED" = true ]; then
        echo "Traefik enabled - starting with reverse proxy..."
    else
        echo "Traefik disabled - using direct port access..."
    fi

    # Start all services using atomic function
    log_operation "DOCKER_COMPOSE" "Starting all services"
    if ! run_docker_compose_up "$DOCKER_DIR"; then
        log_error "Check the output above for errors"
        exit 1
    fi

    # Validate all services started successfully
    echo ""
    log_info "Validating all services started correctly..."

    # Define expected services (exclude optional ones like traefik, rdtclient)
    EXPECTED_SERVICES=(
        "zurg"
        "rclone"
        "decypharr"
        "prowlarr"
        "radarr"
        "sonarr"
        "overseerr"
        "plex"
        "zilean"
        "zilean-postgres"
        "homarr"
        "dashdot"
        "autoscan"
        "tautulli"
        "watchtower"
        "plextraktsync"
        "pinchflat"
    )

    # Add traefik services if enabled
    if [ "$TRAEFIK_ENABLED" = true ]; then
        EXPECTED_SERVICES+=("traefik" "traefik-socket-proxy")
    fi

    # Count expected services
    EXPECTED_COUNT=${#EXPECTED_SERVICES[@]}
    RUNNING_COUNT=$(docker ps --filter "status=running" --format "{{.Names}}" | wc -l)
    log_debug "Expected services: $EXPECTED_COUNT, Running containers: $RUNNING_COUNT"

    # Check if all expected services are running using atomic function
    FAILED_SERVICES=()
    for service in "${EXPECTED_SERVICES[@]}"; do
        if ! validate_docker_service "$service"; then
            FAILED_SERVICES+=("$service")
        fi
    done

    # Report failed services
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

    # Check for unhealthy containers using atomic function
    UNHEALTHY_SERVICES=()
    for service in "${EXPECTED_SERVICES[@]}"; do
        status=""
        get_docker_health_status "$service" status
        if [ "$status" = "unhealthy" ]; then
            UNHEALTHY_SERVICES+=("$service")
        fi
    done

    # Handle unhealthy services
    if [ ${#UNHEALTHY_SERVICES[@]} -gt 0 ]; then
        log_warning "The following services are unhealthy (may still be starting):"
        for service in "${UNHEALTHY_SERVICES[@]}"; do
            echo "  - $service"
        done
        echo ""
        log_info "Waiting 60 seconds for services to become healthy..."
        sleep 60

        # Check again
        STILL_UNHEALTHY=()
        for service in "${UNHEALTHY_SERVICES[@]}"; do
            local status
            get_docker_health_status "$service" status
            if [ "$status" = "unhealthy" ]; then
                STILL_UNHEALTHY+=("$service")
            fi
        done

        if [ ${#STILL_UNHEALTHY[@]} -gt 0 ]; then
            log_error "The following services are still unhealthy after waiting:"
            for service in "${STILL_UNHEALTHY[@]}"; do
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

    # Wait for services to be ready
    echo ""

    if [ "$TRAEFIK_ENABLED" = true ]; then
        wait_for_http_service "Traefik" "http://localhost:${TRAEFIK_DASHBOARD_PORT}/api/version" 60 2
    fi

    wait_for_http_service "Radarr" "http://localhost:${RADARR_PORT}" 60 2
    wait_for_http_service "Sonarr" "http://localhost:${SONARR_PORT}" 60 2
    wait_for_http_service "Prowlarr" "http://localhost:${PROWLARR_PORT}" 60 2

    # Skip Zilean wait - it can take 10-30 minutes to import DMM data on first run
    echo "Zilean starting in background (will import DMM data, can take 10-30 minutes)"

    # Decypharr doesn't have HTTP API, use docker health check
    wait_for_docker_health "decypharr" 60 2

    # Get API keys from config files
    echo ""
    echo "Retrieving API keys..."

    # Wait a bit more for config files to be written
    sleep 5

    # Extract API keys using library function
    RADARR_API_KEY=$(extract_api_key "radarr" | tail -1)
    SONARR_API_KEY=$(extract_api_key "sonarr" | tail -1)
    PROWLARR_API_KEY=$(extract_api_key "prowlarr" | tail -1)

    if [ -z "$RADARR_API_KEY" ] || [ -z "$SONARR_API_KEY" ] || [ -z "$PROWLARR_API_KEY" ]; then
        log_error "Failed to retrieve API keys. Services may not be fully initialized."
        log_error "Missing API keys:"
        [ -z "$RADARR_API_KEY" ] && log_error "  - Radarr API key is empty"
        [ -z "$SONARR_API_KEY" ] && log_error "  - Sonarr API key is empty"
        [ -z "$PROWLARR_API_KEY" ] && log_error "  - Prowlarr API key is empty"
        log_error "Check service logs: docker logs radarr | docker logs sonarr | docker logs prowlarr"
        log_error "Installation aborted - cannot continue without API keys"
        exit 1
    fi

    log_success "API keys retrieved"
    echo "  - Radarr:   $RADARR_API_KEY"
    echo "  - Sonarr:   $SONARR_API_KEY"
    echo "  - Prowlarr: $PROWLARR_API_KEY"

        # Configure Radarr
        RADARR_API_KEY=$(configure_arr_service "radarr" "$RADARR_PORT" "movies" "decypharr" "$DECYPHARR_CONTAINER_PORT" "$RADARR_API_KEY" | tail -1)

        # Configure Radarr authentication if enabled using atomic function
        if [ "$AUTH_ENABLED" = true ]; then
            if ! configure_arr_authentication "Radarr" "$RADARR_PORT" "$RADARR_API_KEY" "$AUTH_USERNAME" "$AUTH_PASSWORD"; then
                log_error "Installation aborted - authentication configuration failed"
                exit 1
            fi
        fi

        # Configure Sonarr
        SONARR_API_KEY=$(configure_arr_service "sonarr" "$SONARR_PORT" "tv" "decypharr" "$DECYPHARR_CONTAINER_PORT" "$SONARR_API_KEY" | tail -1)

        # Configure Sonarr authentication if enabled using atomic function
        if [ "$AUTH_ENABLED" = true ]; then
            if ! configure_arr_authentication "Sonarr" "$SONARR_PORT" "$SONARR_API_KEY" "$AUTH_USERNAME" "$AUTH_PASSWORD"; then
                log_error "Installation aborted - authentication configuration failed"
                exit 1
            fi
        fi

        # Configure Prowlarr
        echo ""
        echo "Configuring Prowlarr..."

        # Add Torrentio indexer using atomic function
        TORRENTIO_JSON='{
            "definitionName": "torrentio",
            "enable": true,
            "appProfileId": 1,
            "protocol": "torrent",
            "priority": 5,
            "name": "Torrentio",
            "fields": [
                {"order": 0, "name": "definitionFile", "value": "torrentio", "type": "textbox", "advanced": false, "hidden": "hidden", "privacy": "normal", "isFloat": false},
                {"order": 1, "name": "baseUrl", "type": "select", "advanced": false, "selectOptionsProviderAction": "getUrls", "privacy": "normal", "isFloat": false},
                {"order": 1, "name": "default_opts", "value": "providers=yts,eztv,rarbg,1337x,thepiratebay,kickasstorrents,torrentgalaxy,magnetdl,horriblesubs,nyaasi|sort=qualitysize|qualityfilter=480p,scr,cam", "type": "textbox", "advanced": false, "privacy": "normal", "isFloat": false},
                {"order": 3, "name": "debrid_provider_key", "value": "'"$REALDEBRID_TOKEN"'", "type": "textbox", "advanced": false, "privacy": "normal", "isFloat": false},
                {"order": 4, "name": "debrid_provider", "value": 5, "type": "select", "advanced": false, "privacy": "normal", "isFloat": false}
            ],
            "implementationName": "Cardigann",
            "implementation": "Cardigann",
            "configContract": "CardigannSettings",
            "tags": []
        }'
        api_post_request "http://localhost:${PROWLARR_PORT}/api/v1/indexer" "$PROWLARR_API_KEY" "$TORRENTIO_JSON"
        echo "  ✓ Indexer added: Torrentio"

        # Add Zilean indexer (disabled initially) using atomic function
        ZILEAN_JSON='{
            "definitionName": "zilean",
            "enable": false,
            "appProfileId": 1,
            "protocol": "torrent",
            "priority": 25,
            "name": "Zilean",
            "fields": [
                {"order": 0, "name": "definitionFile", "value": "zilean", "type": "textbox", "advanced": false, "hidden": "hidden", "privacy": "normal", "isFloat": false},
                {"order": 1, "name": "baseUrl", "value": "http://zilean:8181", "type": "select", "advanced": false, "selectOptionsProviderAction": "getUrls", "privacy": "normal", "isFloat": false}
            ],
            "implementationName": "Cardigann",
            "implementation": "Cardigann",
            "configContract": "CardigannSettings",
            "tags": []
        }'
        api_post_request "http://localhost:${PROWLARR_PORT}/api/v1/indexer" "$PROWLARR_API_KEY" "$ZILEAN_JSON"
        echo "  ✓ Indexer added: Zilean (disabled - enable after DMM data is indexed)"

        # Add The Pirate Bay indexer using atomic function
        TPB_JSON='{
            "definitionName": "thepiratebay",
            "enable": true,
            "appProfileId": 1,
            "protocol": "torrent",
            "priority": 25,
            "name": "The Pirate Bay",
            "fields": [
                {"order": 0, "name": "definitionFile", "value": "thepiratebay", "type": "textbox", "advanced": false, "hidden": "hidden", "privacy": "normal", "isFloat": false},
                {"order": 1, "name": "baseUrl", "type": "select", "advanced": false, "selectOptionsProviderAction": "getUrls", "privacy": "normal", "isFloat": false}
            ],
            "implementationName": "Cardigann",
            "implementation": "Cardigann",
            "configContract": "CardigannSettings",
            "tags": []
        }'
        api_post_request "http://localhost:${PROWLARR_PORT}/api/v1/indexer" "$PROWLARR_API_KEY" "$TPB_JSON"
        echo "  ✓ Indexer added: The Pirate Bay"

        # Add YTS indexer using atomic function
        YTS_JSON='{
            "definitionName": "yts",
            "enable": true,
            "appProfileId": 1,
            "protocol": "torrent",
            "priority": 25,
            "name": "YTS",
            "fields": [
                {"order": 0, "name": "definitionFile", "value": "yts", "type": "textbox", "advanced": false, "hidden": "hidden", "privacy": "normal", "isFloat": false},
                {"order": 1, "name": "baseUrl", "type": "select", "advanced": false, "selectOptionsProviderAction": "getUrls", "privacy": "normal", "isFloat": false}
            ],
            "implementationName": "Cardigann",
            "implementation": "Cardigann",
            "configContract": "CardigannSettings",
            "tags": []
        }'
        api_post_request "http://localhost:${PROWLARR_PORT}/api/v1/indexer" "$PROWLARR_API_KEY" "$YTS_JSON"
        echo "  ✓ Indexer added: YTS"

        # Add Radarr and Sonarr as applications in Prowlarr
        if ! add_arr_to_prowlarr "radarr" "$RADARR_PORT" "$RADARR_API_KEY" "$PROWLARR_PORT" "$PROWLARR_API_KEY"; then
            log_error "Installation aborted - failed to add Radarr to Prowlarr"
            exit 1
        fi

        if ! add_arr_to_prowlarr "sonarr" "$SONARR_PORT" "$SONARR_API_KEY" "$PROWLARR_PORT" "$PROWLARR_API_KEY"; then
            log_error "Installation aborted - failed to add Sonarr to Prowlarr"
            exit 1
        fi

        # Trigger indexer sync to all applications using atomic functions
        echo ""
        echo "Triggering indexer sync to Radarr and Sonarr..."

        # Get Radarr app ID and trigger sync
        if get_prowlarr_app_id "$PROWLARR_PORT" "$PROWLARR_API_KEY" "Radarr" RADARR_APP_ID; then
            if trigger_prowlarr_sync "$PROWLARR_PORT" "$PROWLARR_API_KEY" "$RADARR_APP_ID"; then
                echo "  ✓ Triggered sync to Radarr"
            fi
        fi

        # Get Sonarr app ID and trigger sync
        if get_prowlarr_app_id "$PROWLARR_PORT" "$PROWLARR_API_KEY" "Sonarr" SONARR_APP_ID; then
            if trigger_prowlarr_sync "$PROWLARR_PORT" "$PROWLARR_API_KEY" "$SONARR_APP_ID"; then
                echo "  ✓ Triggered sync to Sonarr"
            fi
        fi

        echo "  ✓ Indexer sync completed"

        # Configure quality profiles and naming with Recyclarr
        echo ""
        echo "Configuring quality profiles and naming conventions with Recyclarr..."
        echo "This will:"
        echo "  • Remove default quality profiles"
        echo "  • Create TRaSH Guide profiles (Recyclarr-1080p, Recyclarr-2160p, Recyclarr-Any)"
        echo "  • Configure custom formats from TRaSH Guides"
        echo "  • Set up media naming conventions for Plex compatibility"
        echo ""

        # Delete default quality profiles
        remove_default_profiles "radarr" "$RADARR_PORT" "$RADARR_API_KEY"
        remove_default_profiles "sonarr" "$SONARR_PORT" "$SONARR_API_KEY"
        echo ""

        # Run Recyclarr to create TRaSH Guide profiles using atomic function
        echo "Creating TRaSH Guide quality profiles..."

        if run_recyclarr_sync "${ROOT_DIR}/recyclarr.yml" "$RADARR_API_KEY" "$SONARR_API_KEY"; then
            echo ""
            echo "  ✓ Recyclarr configuration completed"
            echo "  ✓ Quality profiles created: Recyclarr-1080p, Recyclarr-2160p, Recyclarr-Any"
            echo "  ✓ Media naming configured for Plex"
        else
            echo ""
            echo "  ⚠ Recyclarr sync failed (non-critical)"
            echo "  You can run it manually later: ./recyclarr-sync.sh"
        fi

        # Configure Prowlarr authentication if enabled using atomic function
        if [ "$AUTH_ENABLED" = true ]; then
            if ! configure_arr_authentication "Prowlarr" "$PROWLARR_PORT" "$PROWLARR_API_KEY" "$AUTH_USERNAME" "$AUTH_PASSWORD" "v1"; then
                log_error "Failed to configure Prowlarr authentication (non-critical)"
            fi
        fi

        # Save API keys to .env.install using atomic function
        API_KEYS_CONTENT="
# API Keys (auto-generated during setup)
RADARR_API_KEY=$RADARR_API_KEY
SONARR_API_KEY=$SONARR_API_KEY
PROWLARR_API_KEY=$PROWLARR_API_KEY"
        append_to_file "$DOCKER_DIR/.env.install" "$API_KEYS_CONTENT"

        echo ""
        echo "✓ Auto-configuration completed successfully"

    # Restart all services to ensure everything is running with the new configuration
    echo ""
    echo "Restarting all services with final configuration..."
    if ! run_docker_compose_up "$DOCKER_DIR"; then
        log_error "Failed to restart services"
    fi
    echo "✓ All services running"
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
        create_file_from_content \
            "${ROOT_DIR}/data/realdebrid-zurg/torrents/.healthcheck_test.txt" \
            "HEALTHCHECK TEST FILE - DO NOT DELETE" \
            "rclone:mediacenter"

        # Create symlink in media directory
        create_folder "${ROOT_DIR}/data/media/.healthcheck"
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
REMOVE_INSTALLER=""
ask_user_input \
    "Cleanup" \
    "The installer repository is no longer needed. All configuration
files have been copied to ${ROOT_DIR}.

Installation directory: $(pwd)" \
    "Do you want to remove the installer repository? [y/N]: " \
    "n" \
    false \
    REMOVE_INSTALLER

if [[ "$REMOVE_INSTALLER" =~ ^[Yy]$ ]]; then
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
