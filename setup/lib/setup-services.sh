#!/bin/bash
# setup-services.sh - Service configuration functions
# Library directory
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# High-level functions for configuring complete services

source "${LIB_DIR}/setup-common.sh"
source "${LIB_DIR}/setup-api.sh"

# Configure a generic *arr service (Radarr or Sonarr)
configure_arr_service() {
    local service_name=$1      # radarr or sonarr
    local service_port=$2      # 7878 or 8989
    local media_type=$3        # movies or tv
    local download_client=$4   # decypharr or rdtclient
    local download_port=$5
    local download_api_key=$6

    log_section "Configuring $service_name"

    # Extract API key (use tail -1 to get only the key, not log messages)
    local api_key=$(extract_api_key "$service_name" | tail -1)
    if [ -z "$api_key" ]; then
        log_error "Failed to get API key for $service_name"
        log_error "Installation aborted - cannot continue without API key"
        exit 1
    fi

    # Add root folder
    if ! add_root_folder "$service_name" "$service_port" "$api_key" "/data/media/$media_type" "Media"; then
        log_error "Failed to add root folder to $service_name"
        log_error "Installation aborted - critical configuration failed"
        exit 1
    fi

    # Add download client
    if ! add_download_client "$service_name" "$service_port" "$api_key" \
        "Decypharr" "$download_client" "$download_port" "$api_key" "$media_type"; then
        log_error "Failed to add download client to $service_name"
        log_error "Installation aborted - critical configuration failed"
        exit 1
    fi

    # Add remote path mapping (non-critical, just log warning)
    if ! add_remote_path_mapping "$service_name" "$service_port" "$api_key" \
        "/data/media/$service_name" "/data/media/$media_type" "$download_client"; then
        log_warning "Failed to add remote path mapping to $service_name (non-critical)"
    fi

    log_success "$service_name configuration completed"

    # Return API key for later use
    echo "$api_key"
}

# Update service instance name
update_instance_name() {
    local service=$1
    local port=$2
    local api_key=$3

    log_info "Updating instance name for $service"

    # Get current config
    local config=$(api_call "GET" "$service" "$port" "config/host" "$api_key")

    if [ -z "$config" ]; then
        log_warning "Failed to get config for $service, skipping instance name update"
        return 0
    fi

    # Update instance name
    local updated_config=$(echo "$config" | jq '.instanceName = "'${service^}'"')

    if api_call "PUT" "$service" "$port" "config/host" "$api_key" "$updated_config"; then
        log_success "Instance name updated for $service"
    else
        log_warning "Failed to update instance name for $service"
    fi
}

# Configure Prowlarr
configure_prowlarr() {
    local prowlarr_port=$1
    local zilean_api_key=$2

    log_section "Configuring Prowlarr"

    # Extract API key (use tail -1 to get only the key, not log messages)
    local api_key=$(extract_api_key "prowlarr" | tail -1)
    if [ -z "$api_key" ]; then
        log_error "Failed to get API key for Prowlarr"
        exit 1
    fi

    # Add Zilean indexer
    add_zilean_indexer "$prowlarr_port" "$api_key" "$zilean_api_key"

    # Sync indexers to *arr apps
    sync_prowlarr_indexers "$prowlarr_port" "$api_key"

    log_success "Prowlarr configuration completed"

    echo "$api_key"
}

# Add Zilean indexer to Prowlarr
add_zilean_indexer() {
    local prowlarr_port=$1
    local prowlarr_api_key=$2
    local zilean_api_key=$3

    log_info "Adding Zilean indexer to Prowlarr"

    local data='{
        "enable": true,
        "name": "Zilean",
        "fields": [
            {"name": "baseUrl", "value": "http://zilean:8181"},
            {"name": "apiPath", "value": "/"},
            {"name": "apiKey", "value": "'$zilean_api_key'"},
            {"name": "categories", "value": [2000, 5000]}
        ],
        "implementationName": "Torznab",
        "implementation": "Torznab",
        "configContract": "TorznabSettings",
        "protocol": "torrent",
        "priority": 25,
        "tags": []
    }'

    if api_call "POST" "prowlarr" "$prowlarr_port" "indexer" "$prowlarr_api_key" "$data"; then
        log_success "Zilean indexer added to Prowlarr"
        return 0
    else
        log_error "Failed to add Zilean indexer to Prowlarr"
        return 1
    fi
}

# Sync Prowlarr indexers to connected apps
sync_prowlarr_indexers() {
    local prowlarr_port=$1
    local prowlarr_api_key=$2

    log_info "Syncing Prowlarr indexers to connected apps"

    # Trigger sync
    if api_call "POST" "prowlarr" "$prowlarr_port" "command" "$prowlarr_api_key" '{"name":"ApplicationSync"}'; then
        log_success "Prowlarr sync triggered"
        sleep 5  # Give it time to sync
        return 0
    else
        log_warning "Failed to trigger Prowlarr sync"
        return 0  # Don't fail on this
    fi
}

# Configure Decypharr
configure_decypharr() {
    local config_dir=$1
    local rd_api_token=$2

    log_section "Configuring Decypharr"

    # Create auth.json with Real-Debrid token
    local auth_file="${config_dir}/config/decypharr-config/auth.json"

    sudo mkdir -p "$(dirname "$auth_file")"

    local auth_json="{
    \"api_token\": \"$rd_api_token\",
    \"username\": \"\",
    \"password\": \"\"
}"

    echo "$auth_json" | sudo tee "$auth_file" > /dev/null
    sudo chown ${DECYPHARR_UID}:${MEDIACENTER_GID} "$auth_file"
    sudo chmod 600 "$auth_file"

    log_success "Decypharr configuration completed"
}

# Remove default quality profiles from *arr service
remove_default_profiles() {
    local service=$1
    local port=$2
    local api_key=$3

    log_info "Removing default quality profiles from $service"

    # Get all profiles (use tail -1 to get only JSON, not log messages)
    local profiles=$(get_quality_profiles "$service" "$port" "$api_key" | tail -1)

    if [ -z "$profiles" ]; then
        log_error "Failed to get quality profiles from $service"
        log_error "Installation aborted - cannot remove default profiles"
        exit 1
    fi

    # Extract profile IDs into array (avoids subshell issues with while read)
    local profile_ids=($(echo "$profiles" | jq -r '.[].id' 2>/dev/null))

    if [ ${#profile_ids[@]} -eq 0 ]; then
        log_warning "No quality profiles found in $service (may have been removed already)"
        return 0
    fi

    log_debug "Found ${#profile_ids[@]} quality profiles to remove"

    # Delete each profile
    local deleted_count=0
    local failed_count=0

    for profile_id in "${profile_ids[@]}"; do
        if [ -n "$profile_id" ]; then
            log_debug "Deleting profile ID $profile_id from $service"
            if delete_quality_profile "$service" "$port" "$api_key" "$profile_id"; then
                ((deleted_count++))
            else
                log_warning "Failed to delete profile ID $profile_id from $service (may be in use)"
                ((failed_count++))
            fi
        fi
    done

    if [ $deleted_count -gt 0 ]; then
        log_success "Removed $deleted_count quality profile(s) from $service"
    fi

    if [ $failed_count -gt 0 ]; then
        log_warning "$failed_count profile(s) could not be deleted (may be assigned to content)"
    fi
}

# Export functions
export -f configure_arr_service
export -f update_instance_name
export -f configure_prowlarr
export -f add_zilean_indexer
export -f sync_prowlarr_indexers
export -f configure_decypharr
export -f remove_default_profiles
