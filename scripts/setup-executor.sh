#!/bin/bash
# Setup Executor - Executes template setup configurations dynamically
# Reads setup.json files and executes corresponding functions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/../templates"
ROOT_DIR="${ROOT_DIR:-/mediacenter}"  # Use environment variable or default to /mediacenter

# Source library functions
source "${SCRIPT_DIR}/../setup/lib/setup-common.sh"
source "${SCRIPT_DIR}/../setup/lib/setup-api.sh"
source "${SCRIPT_DIR}/../setup/lib/setup-services.sh"

# Global variable storage for API keys and other runtime data
declare -A RUNTIME_VARS

# Execute a single step
execute_step() {
    local step_json=$1
    local action=$(echo "$step_json" | jq -r '.action')
    local description=$(echo "$step_json" | jq -r '.description')
    local params=$(echo "$step_json" | jq -r '.params')

    log_info "Executing: $description"

    case "$action" in
        wait_for_service)
            local service=$(echo "$params" | jq -r '.service')
            local port=$(echo "$params" | jq -r '.port')
            local timeout=$(echo "$params" | jq -r '.timeout // 120')
            wait_for_service "$service" "$port" "$timeout"
            ;;

        extract_api_key)
            local service=$(echo "$params" | jq -r '.service')
            local output_var=$(echo "$params" | jq -r '.output_var')
            local api_key=$(extract_api_key "$service")
            RUNTIME_VARS[$output_var]="$api_key"
            log_trace "setup-executor" "Stored $output_var=${api_key}"
            ;;

        add_root_folder)
            local service=$(echo "$params" | jq -r '.service')
            local port=$(echo "$params" | jq -r '.port')
            local api_key_var=$(echo "$params" | jq -r '.api_key_var')
            local path=$(echo "$params" | jq -r '.path')
            local name=$(echo "$params" | jq -r '.name')
            local api_key="${RUNTIME_VARS[$api_key_var]}"
            add_root_folder "$service" "$port" "$api_key" "$path" "$name"
            ;;

        add_download_client)
            local service=$(echo "$params" | jq -r '.service')
            local port=$(echo "$params" | jq -r '.port')
            local api_key_var=$(echo "$params" | jq -r '.api_key_var')
            local client_name=$(echo "$params" | jq -r '.client_name')
            local client_host=$(echo "$params" | jq -r '.client_host')
            local client_port=$(echo "$params" | jq -r '.client_port')
            local api_key="${RUNTIME_VARS[$api_key_var]}"
            add_download_client "$service" "$port" "$api_key" "$client_name" "$client_host" "$client_port"
            ;;

        add_indexer_to_prowlarr)
            local prowlarr_port=$(echo "$params" | jq -r '.prowlarr_port')
            local prowlarr_api_key_var=$(echo "$params" | jq -r '.prowlarr_api_key_var')
            local indexer_name=$(echo "$params" | jq -r '.indexer_name')
            local indexer_url=$(echo "$params" | jq -r '.indexer_url')
            local prowlarr_api_key="${RUNTIME_VARS[$prowlarr_api_key_var]}"
            # Call appropriate function (needs to be created)
            log_info "Adding $indexer_name to Prowlarr"
            ;;

        add_arr_to_prowlarr)
            local service=$(echo "$params" | jq -r '.service')
            local service_port=$(echo "$params" | jq -r '.service_port')
            local service_api_key_var=$(echo "$params" | jq -r '.service_api_key_var')
            local prowlarr_port=$(echo "$params" | jq -r '.prowlarr_port')
            local prowlarr_api_key_var=$(echo "$params" | jq -r '.prowlarr_api_key_var')
            local service_api_key="${RUNTIME_VARS[$service_api_key_var]}"
            local prowlarr_api_key="${RUNTIME_VARS[$prowlarr_api_key_var]}"
            add_arr_to_prowlarr "$service" "$service_port" "$service_api_key" "$prowlarr_port" "$prowlarr_api_key"
            ;;

        delete_default_quality_profiles)
            local service=$(echo "$params" | jq -r '.service')
            local port=$(echo "$params" | jq -r '.port')
            local api_key_var=$(echo "$params" | jq -r '.api_key_var')
            local api_key="${RUNTIME_VARS[$api_key_var]}"

            log_info "Deleting default quality profiles from $service"
            local profiles=$(get_quality_profiles "$service" "$port" "$api_key")
            local profile_ids=$(echo "$profiles" | jq -r '.[] | select(.name | test("^(Any|HD-1080p|SD|HD-720p|Ultra-HD|HD - 720p/1080p)$")) | .id')

            local count=0
            for profile_id in $profile_ids; do
                log_debug "Deleting profile ID $profile_id from $service"
                delete_quality_profile "$service" "$port" "$api_key" "$profile_id"
                ((count++))
            done
            log_success "Removed $count quality profile(s) from $service"
            ;;

        run_recyclarr)
            local radarr_api_key_var=$(echo "$params" | jq -r '.radarr_api_key_var')
            local sonarr_api_key_var=$(echo "$params" | jq -r '.sonarr_api_key_var')
            local radarr_api_key="${RUNTIME_VARS[$radarr_api_key_var]}"
            local sonarr_api_key="${RUNTIME_VARS[$sonarr_api_key_var]}"

            log_info "Running Recyclarr to create TRaSH Guide profiles"

            # Create temporary config with API keys
            local temp_config="/tmp/recyclarr-temp-$$.yml"
            awk -v radarr_key="${radarr_api_key}" -v sonarr_key="${sonarr_api_key}" '
                /^radarr:/ {in_radarr=1; in_sonarr=0}
                /^sonarr:/ {in_radarr=0; in_sonarr=1}
                /api_key:$/ {
                    if (in_radarr) {print "    api_key: " radarr_key; next}
                    if (in_sonarr) {print "    api_key: " sonarr_key; next}
                }
                {print}
            ' "${ROOT_DIR}/config/recyclarr.yml" > "$temp_config"

            docker run --rm \
                --network mediacenter \
                -v "${temp_config}:/config/recyclarr.yml:ro" \
                ghcr.io/recyclarr/recyclarr:latest \
                sync

            rm -f "$temp_config"
            log_success "Recyclarr profiles created successfully"
            ;;

        log_info)
            local message=$(echo "$params" | jq -r '.message')
            # Expand variables in message
            message=$(eval "echo \"$message\"")
            log_info "$message"
            ;;

        log_success)
            local message=$(echo "$params" | jq -r '.message')
            message=$(eval "echo \"$message\"")
            log_success "$message"
            ;;

        log_warning)
            local message=$(echo "$params" | jq -r '.message')
            message=$(eval "echo \"$message\"")
            log_warning "$message"
            ;;

        sleep)
            local seconds=$(echo "$params" | jq -r '.seconds // 5')
            local reason=$(echo "$params" | jq -r '.reason // "Waiting for service to stabilize"')
            log_info "$reason (${seconds}s)"
            sleep "$seconds"
            ;;

        *)
            log_error "Unknown action: $action"
            return 1
            ;;
    esac
}

# Execute setup for a single service
execute_service_setup() {
    local service=$1
    local service_json="${TEMPLATES_DIR}/../templates/services/${service}.json"

    # If no JSON file exists, skip (service doesn't need configuration)
    if [ ! -f "$service_json" ]; then
        log_trace "setup-executor" "No configuration file for service: $service (skipping)"
        return 0
    fi

    # Validate JSON
    if ! jq empty "$service_json" 2>/dev/null; then
        log_error "Invalid JSON in $service_json"
        return 1
    fi

    local description=$(jq -r '.description' "$service_json")
    local setup_steps=$(jq -r '.setup.steps' "$service_json")

    # If no setup steps, skip
    if [ "$setup_steps" = "null" ] || [ -z "$setup_steps" ]; then
        log_trace "setup-executor" "No setup steps for service: $service"
        return 0
    fi

    log_section "Configuring: $description"

    # Get number of steps
    local step_count=$(jq '.setup.steps | length' "$service_json")
    log_info "Executing $step_count configuration step(s)..."
    echo ""

    # Execute each step
    local i=0
    while [ $i -lt $step_count ]; do
        local step=$(jq ".setup.steps[$i]" "$service_json")
        execute_step "$step" || return 1
        i=$((i + 1))  # Avoid ((i++)) with set -e as it can cause exit on non-zero result
    done

    log_success "$service configured successfully"
    echo ""
}

# Execute setup for a template (processes all services in order)
execute_template_setup() {
    local template=$1
    local services_file="${TEMPLATES_DIR}/${template}/services.list"

    if [ ! -f "$services_file" ]; then
        log_warning "No services.list found for template: $template"
        return 0
    fi

    log_section "Processing template: $template"

    # Read services.list and execute setup for each service
    while IFS= read -r service || [ -n "$service" ]; do
        # Skip comments and empty lines
        [[ "$service" =~ ^#.*$ ]] && continue
        [[ -z "$service" ]] && continue

        # Trim whitespace
        service=$(echo "$service" | xargs)

        # Execute service setup
        execute_service_setup "$service"
    done < "${services_file}"
}

# Main execution
main() {
    local templates=("$@")

    if [ ${#templates[@]} -eq 0 ]; then
        log_error "No templates specified"
        echo "Usage: $0 <template1> [template2] ..."
        exit 1
    fi

    log_info "Setup Executor - Dynamic Template Configuration"
    echo "========================================"
    echo ""

    # Execute setup for each template
    for template in "${templates[@]}"; do
        execute_template_setup "$template"
    done

    log_success "All templates configured successfully!"
}

# Only run main if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    main "$@"
fi
