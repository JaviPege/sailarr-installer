#!/bin/bash
# setup-api.sh - API interaction functions
# Library directory
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Handles all HTTP/API calls to services

source "${LIB_DIR}/setup-common.sh"

# Generic API call function
api_call() {
    log_function_enter "api_call" "method=$1 service=$2 port=$3 endpoint=$4"

    local method=$1      # GET, POST, PUT, DELETE
    local service=$2     # Service name (radarr, sonarr, prowlarr)
    local port=$3        # Service port
    local endpoint=$4    # API endpoint (without /api/v3/)
    local api_key=$5     # API key for authentication
    local data=$6        # JSON data (optional)
    local api_version=${7:-"v3"}  # API version (default v3)

    local url="http://localhost:${port}/api/${api_version}/${endpoint}"
    local response
    local http_code

    log_operation "API_CALL" "$method $url"
    log_trace "api_call" "Data length: ${#data} bytes"

    # Build curl command
    local curl_cmd="curl -s -w '\n%{http_code}' -X $method '$url' \
        -H 'X-Api-Key: $api_key' \
        -H 'Content-Type: application/json'"

    # Add data if provided
    if [ -n "$data" ]; then
        curl_cmd="$curl_cmd -d '$data'"
        log_trace "api_call" "Request includes JSON payload"
    fi

    # Execute and capture response
    log_trace "api_call" "Executing curl command"
    response=$(eval $curl_cmd)
    http_code=$(echo "$response" | tail -n1)
    response=$(echo "$response" | sed '$d')

    log_trace "api_call" "HTTP Status: $http_code, Response length: ${#response} bytes"

    # Check HTTP status
    if [[ "$http_code" =~ ^2 ]]; then
        log_function_exit "api_call" 0 "HTTP $http_code"
        echo "$response"
        return 0
    else
        log_error "API call failed: $method $endpoint (HTTP $http_code)"
        log_error "Response: $response"
        log_function_exit "api_call" 1 "HTTP $http_code"
        return 1
    fi
}

# Extract API key from service config
extract_api_key() {
    log_function_enter "extract_api_key" "$@"

    local container_name=$1
    local config_file=${2:-"/config/config.xml"}
    local max_attempts=${3:-30}
    local attempt=0

    log_info "Extracting API key from $container_name..."
    log_operation "GREP" "docker exec $container_name cat $config_file | grep ApiKey"

    while [ $attempt -lt $max_attempts ]; do
        local api_key=$(docker exec "$container_name" cat "$config_file" 2>/dev/null | grep -oP '(?<=<ApiKey>)[^<]+' 2>/dev/null)

        if [ -n "$api_key" ] && [ "$api_key" != "0000000000000000000000000000000" ]; then
            log_success "API key extracted from $container_name"
            echo "$api_key"
            return 0
        fi

        attempt=$((attempt + 1))
        sleep 2
    done

    log_error "Failed to extract API key from $container_name after $max_attempts attempts"
    return 1
}

# Add root folder to *arr service
add_root_folder() {
    local service=$1      # radarr or sonarr
    local port=$2
    local api_key=$3
    local path=$4         # /data/media/movies or /data/media/tv
    local name=${5:-"Media"}

    log_info "Adding root folder to $service: $path"

    local data="{
        \"path\": \"$path\",
        \"name\": \"$name\"
    }"

    if api_call "POST" "$service" "$port" "rootfolder" "$api_key" "$data"; then
        log_success "Root folder added to $service"
        return 0
    else
        log_error "Failed to add root folder to $service"
        return 1
    fi
}

# Add download client to *arr service
add_download_client() {
    local service=$1      # radarr or sonarr
    local port=$2
    local api_key=$3
    local client_name=$4  # Decypharr or RDTClient
    local client_host=$5  # decypharr or rdtclient
    local client_port=$6
    local client_api_key=$7
    local category=$8     # movies, tv, radarr, or sonarr

    log_info "Adding download client '$client_name' to $service"

    # Determine category field names based on service
    local category_fields=""
    if [ "$service" = "radarr" ]; then
        category_fields="{\"name\": \"movieCategory\", \"value\": \"$category\"},
            {\"name\": \"recentMoviePriority\", \"value\": 0},
            {\"name\": \"olderMoviePriority\", \"value\": 0},"
    else
        category_fields="{\"name\": \"tvCategory\", \"value\": \"$category\"},
            {\"name\": \"recentTvPriority\", \"value\": 0},
            {\"name\": \"olderTvPriority\", \"value\": 0},"
    fi

    local data="{
        \"enable\": true,
        \"protocol\": \"torrent\",
        \"priority\": 1,
        \"removeCompletedDownloads\": true,
        \"removeFailedDownloads\": true,
        \"name\": \"$client_name\",
        \"fields\": [
            {\"name\": \"host\", \"value\": \"$client_host\"},
            {\"name\": \"port\", \"value\": $client_port},
            {\"name\": \"useSsl\", \"value\": false},
            {\"name\": \"urlBase\", \"value\": \"\"},
            {\"name\": \"username\", \"value\": \"http://$service:$port\"},
            {\"name\": \"password\", \"value\": \"$client_api_key\"},
            $category_fields
            {\"name\": \"initialState\", \"value\": 0},
            {\"name\": \"sequentialOrder\", \"value\": false},
            {\"name\": \"firstAndLast\", \"value\": false}
        ],
        \"implementationName\": \"qBittorrent\",
        \"implementation\": \"QBittorrent\",
        \"configContract\": \"QBittorrentSettings\",
        \"tags\": []
    }"

    if api_call "POST" "$service" "$port" "downloadclient" "$api_key" "$data"; then
        log_success "Download client added to $service"
        return 0
    else
        log_error "Failed to add download client to $service"
        return 1
    fi
}

# Add *arr application to Prowlarr
add_arr_to_prowlarr() {
    log_function_enter "add_arr_to_prowlarr" "$1 $2 [api_key] $4 [prowlarr_key]"

    local service=$1          # radarr or sonarr
    local service_port=$2     # 7878 or 8989
    local service_api_key=$3
    local prowlarr_port=$4
    local prowlarr_api_key=$5

    log_info "Adding $service as application in Prowlarr"
    log_debug "Service: $service, Port: $service_port, Prowlarr Port: $prowlarr_port"
    log_debug "Service API key length: ${#service_api_key}, Prowlarr API key length: ${#prowlarr_api_key}"

    # Determine sync categories based on service
    local sync_categories=""
    local contract_name=""
    if [ "$service" = "radarr" ]; then
        sync_categories="[2000,2010,2020,2030,2040,2045,2050,2060]"
        contract_name="RadarrSettings"
    else
        sync_categories="[5000,5010,5020,5030,5040,5045,5050,5060,5070,5080,5090]"
        contract_name="SonarrSettings"
    fi

    local data="{
        \"name\": \"${service^}\",
        \"syncLevel\": \"fullSync\",
        \"implementation\": \"${service^}\",
        \"implementationName\": \"${service^}\",
        \"configContract\": \"$contract_name\",
        \"fields\": [
            {\"name\": \"prowlarrUrl\", \"value\": \"http://prowlarr:$prowlarr_port\"},
            {\"name\": \"baseUrl\", \"value\": \"http://$service:$service_port\"},
            {\"name\": \"apiKey\", \"value\": \"$service_api_key\"},
            {\"name\": \"syncCategories\", \"value\": $sync_categories}
        ],
        \"tags\": []
    }"

    if api_call "POST" "prowlarr" "$prowlarr_port" "applications" "$prowlarr_api_key" "$data" "v1"; then
        log_success "${service^} application added to Prowlarr"
        return 0
    else
        log_error "Failed to add ${service^} application to Prowlarr"
        return 1
    fi
}

# Add remote path mapping
add_remote_path_mapping() {
    local service=$1
    local port=$2
    local api_key=$3
    local remote_path=$4
    local local_path=$5
    local host=${6:-"decypharr"}

    log_info "Adding remote path mapping to $service"

    local data="{
        \"host\": \"$host\",
        \"remotePath\": \"$remote_path\",
        \"localPath\": \"$local_path\"
    }"

    if api_call "POST" "$service" "$port" "remotepathmapping" "$api_key" "$data"; then
        log_success "Remote path mapping added to $service"
        return 0
    else
        log_warning "Failed to add remote path mapping to $service (may already exist)"
        return 0  # Don't fail on this
    fi
}

# Get quality profiles from service
get_quality_profiles() {
    local service=$1
    local port=$2
    local api_key=$3

    api_call "GET" "$service" "$port" "qualityprofile" "$api_key"
}

# Delete quality profile
delete_quality_profile() {
    local service=$1
    local port=$2
    local api_key=$3
    local profile_id=$4

    api_call "DELETE" "$service" "$port" "qualityprofile/$profile_id" "$api_key"
}

# Export functions
export -f api_call
export -f extract_api_key
export -f add_root_folder
export -f add_download_client
export -f add_arr_to_prowlarr
export -f add_remote_path_mapping
export -f get_quality_profiles
export -f delete_quality_profile
