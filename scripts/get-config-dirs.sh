#!/bin/bash
# Get Config Directories - Extracts list of services that need config directories
# Usage: ./get-config-dirs.sh core mediaplayers/plex extras/overseerr
# Output: radarr sonarr prowlarr plex overseerr decypharr autoscan zilean

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/../templates"

# Services that need config directories
# Infrastructure services (networks, volumes) don't need config dirs
# Some services like recyclarr are setup-only and don't need persistent config
CONFIG_REQUIRING_SERVICES=(
    "radarr"
    "sonarr"
    "prowlarr"
    "plex"
    "overseerr"
    "decypharr"
    "autoscan"
    "zilean"
    "tautulli"
    "homarr"
    "pinchflat"
    "jellyfin"
    "jellyseerr"
    "plextraktsync"
)

# Check if a service requires a config directory
requires_config_dir() {
    local service=$1

    for config_service in "${CONFIG_REQUIRING_SERVICES[@]}"; do
        if [ "$service" = "$config_service" ]; then
            return 0
        fi
    done

    return 1
}

# Get all services from templates
get_all_services() {
    "${SCRIPT_DIR}/get-services-list.sh" "$@"
}

# Main execution
main() {
    local templates=("$@")

    if [ ${#templates[@]} -eq 0 ]; then
        echo "ERROR: No templates specified" >&2
        echo "Usage: $0 <template1> [template2] ..." >&2
        exit 1
    fi

    # Get all services
    local all_services=($(get_all_services "${templates[@]}"))

    # Filter to only those that need config directories
    local config_dirs=()

    for service in "${all_services[@]}"; do
        if requires_config_dir "$service"; then
            config_dirs+=("$service")
        fi
    done

    # Output space-separated list
    echo "${config_dirs[@]}"
}

# Only run main if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    main "$@"
fi
