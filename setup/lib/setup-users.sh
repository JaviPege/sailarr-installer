#!/bin/bash
# setup-users.sh - User and group management functions
# Library directory
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Handles creation and configuration of system users and groups

source "${LIB_DIR}/setup-common.sh"

# Find next available UID starting from a base
find_available_uid() {
    local base_uid=$1
    local uid=$base_uid

    while getent passwd $uid >/dev/null 2>&1; do
        ((uid++))
    done

    echo $uid
}

# Find next available GID starting from a base
find_available_gid() {
    local base_gid=$1
    local gid=$base_gid

    while getent group $gid >/dev/null 2>&1; do
        ((gid++))
    done

    echo $gid
}

# Create a system user if it doesn't exist
create_system_user() {
    local username=$1
    local uid=$2
    local gid=$3
    local description=${4:-"Mediacenter service user"}

    if ! getent passwd "$username" >/dev/null 2>&1; then
        sudo useradd -r -u "$uid" -g "$gid" -s /usr/sbin/nologin -c "$description" "$username"
        log_success "Created user: $username (UID: $uid)"
    else
        log_info "User already exists: $username"
    fi
}

# Create a system group if it doesn't exist
create_system_group() {
    local groupname=$1
    local gid=$2

    if ! getent group "$groupname" >/dev/null 2>&1; then
        sudo groupadd -r -g "$gid" "$groupname"
        log_success "Created group: $groupname (GID: $gid)"
    else
        log_info "Group already exists: $groupname"
    fi
}

# Add user to a group
add_user_to_group() {
    local username=$1
    local groupname=$2

    if ! groups "$username" 2>/dev/null | grep -q "\b$groupname\b"; then
        sudo usermod -a -G "$groupname" "$username"
        log_success "Added $username to group: $groupname"
    else
        log_info "$username is already in group: $groupname"
    fi
}

# Create all mediacenter users and groups
setup_mediacenter_users() {
    log_function_enter "setup_mediacenter_users" "$@"

    local base_uid=${1:-1000}
    local base_gid=${2:-1000}

    log_section "Setting up Users and Groups"
    log_debug "Base UID: $base_uid, Base GID: $base_gid"

    # Find available IDs
    log_operation "UID/GID Allocation" "Finding available IDs starting from UID:$base_uid GID:$base_gid"
    local mediacenter_gid=$(find_available_gid $base_gid)
    local rclone_uid=$(find_available_uid $base_uid)
    local sonarr_uid=$(find_available_uid $((rclone_uid + 1)))
    local radarr_uid=$(find_available_uid $((sonarr_uid + 1)))
    local bazarr_uid=$(find_available_uid $((bazarr_uid + 1)))
    local recyclarr_uid=$(find_available_uid $((radarr_uid + 1)))
    local prowlarr_uid=$(find_available_uid $((recyclarr_uid + 1)))
    local overseerr_uid=$(find_available_uid $((prowlarr_uid + 1)))
    local plex_uid=$(find_available_uid $((overseerr_uid + 1)))
    local decypharr_uid=$(find_available_uid $((plex_uid + 1)))
    local autoscan_uid=$(find_available_uid $((decypharr_uid + 1)))
    local pinchflat_uid=$(find_available_uid $((autoscan_uid + 1)))
    local zilean_uid=$(find_available_uid $((pinchflat_uid + 1)))
    local zurg_uid=$(find_available_uid $((zilean_uid + 1)))
    local tautulli_uid=$(find_available_uid $((zurg_uid + 1)))
    local homarr_uid=$(find_available_uid $((tautulli_uid + 1)))
    local plextraktsync_uid=$(find_available_uid $((homarr_uid + 1)))

    # Create main group
    create_system_group "mediacenter" "$mediacenter_gid"

    # Create service users
    create_system_user "rclone" "$rclone_uid" "$mediacenter_gid" "Rclone"
    create_system_user "sonarr" "$sonarr_uid" "$mediacenter_gid" "Sonarr"
    create_system_user "radarr" "$radarr_uid" "$mediacenter_gid" "Radarr"
    create_system_user "bazarr" "$bazarr_uid" "$mediacenter_gid" "Bazarr"
    create_system_user "recyclarr" "$recyclarr_uid" "$mediacenter_gid" "Recyclarr"
    create_system_user "prowlarr" "$prowlarr_uid" "$mediacenter_gid" "Prowlarr"
    create_system_user "overseerr" "$overseerr_uid" "$mediacenter_gid" "Overseerr"
    create_system_user "plex" "$plex_uid" "$mediacenter_gid" "Plex Media Server"
    create_system_user "decypharr" "$decypharr_uid" "$mediacenter_gid" "Decypharr"
    create_system_user "autoscan" "$autoscan_uid" "$mediacenter_gid" "Autoscan"
    create_system_user "pinchflat" "$pinchflat_uid" "$mediacenter_gid" "Pinchflat"
    create_system_user "zilean" "$zilean_uid" "$mediacenter_gid" "Zilean"
    create_system_user "zurg" "$zurg_uid" "$mediacenter_gid" "Zurg"
    create_system_user "tautulli" "$tautulli_uid" "$mediacenter_gid" "Tautulli"
    create_system_user "homarr" "$homarr_uid" "$mediacenter_gid" "Homarr"
    create_system_user "plextraktsync" "$plextraktsync_uid" "$mediacenter_gid" "PlexTraktSync"

    # Export UIDs/GIDs for use in .env files
    export MEDIACENTER_GID=$mediacenter_gid
    export RCLONE_UID=$rclone_uid
    export SONARR_UID=$sonarr_uid
    export RADARR_UID=$radarr_uid
    export BAZARR_UID=$bazarr_uid
    export RECYCLARR_UID=$recyclarr_uid
    export PROWLARR_UID=$prowlarr_uid
    export OVERSEERR_UID=$overseerr_uid
    export PLEX_UID=$plex_uid
    export DECYPHARR_UID=$decypharr_uid
    export AUTOSCAN_UID=$autoscan_uid
    export PINCHFLAT_UID=$pinchflat_uid
    export ZILEAN_UID=$zilean_uid
    export ZURG_UID=$zurg_uid
    export TAUTULLI_UID=$tautulli_uid
    export HOMARR_UID=$homarr_uid
    export PLEXTRAKTSYNC_UID=$plextraktsync_uid

    log_success "All users and groups created successfully"
}

# Export functions
export -f find_available_uid
export -f find_available_gid
export -f create_system_user
export -f create_system_group
export -f add_user_to_group
export -f setup_mediacenter_users
