#!/bin/bash
# Get Services List - Extracts flat list of services from selected templates
# Usage: ./get-services-list.sh core mediaplayers/plex extras/seerr
# Output: networks volumes zurg rclone radarr sonarr prowlarr ... plex seerr

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/../templates"

# Collect services from a single template
collect_services_from_template() {
    local template=$1
    local template_path="${TEMPLATES_DIR}/${template}"
    local services_file="${template_path}/services.list"

    if [ ! -f "$services_file" ]; then
        return 0
    fi

    # Read services.list (skip comments and empty lines)
    while IFS= read -r service || [ -n "$service" ]; do
        # Skip comments and empty lines
        [[ "$service" =~ ^#.*$ ]] && continue
        [[ -z "$service" ]] && continue

        # Trim whitespace
        service=$(echo "$service" | xargs)

        echo "$service"
    done < "$services_file"
}

# Resolve template dependencies recursively
declare -A RESOLVED_TEMPLATES
declare -A VISITING_TEMPLATES

resolve_dependencies() {
    local template=$1

    # Check for circular dependencies
    if [ "${VISITING_TEMPLATES[$template]}" = "1" ]; then
        echo "ERROR: Circular dependency detected: ${template}" >&2
        return 1
    fi

    # Already resolved
    if [ "${RESOLVED_TEMPLATES[$template]}" = "1" ]; then
        return 0
    fi

    # Mark as visiting
    VISITING_TEMPLATES[$template]=1

    # Find template path
    local template_path="${TEMPLATES_DIR}/${template}"
    if [ ! -d "$template_path" ]; then
        echo "ERROR: Template not found: ${template}" >&2
        return 1
    fi

    # Load template config if exists
    if [ -f "${template_path}/template.conf" ]; then
        source "${template_path}/template.conf"

        # Resolve dependencies first
        if [ -n "$DEPENDS" ]; then
            for dep in $DEPENDS; do
                resolve_dependencies "$dep" || return 1
            done
        fi
    fi

    # Mark as resolved
    RESOLVED_TEMPLATES[$template]=1

    # Remove from visiting
    unset VISITING_TEMPLATES[$template]

    return 0
}

# Main execution
main() {
    local templates=("$@")

    if [ ${#templates[@]} -eq 0 ]; then
        echo "ERROR: No templates specified" >&2
        echo "Usage: $0 <template1> [template2] ..." >&2
        exit 1
    fi

    # Resolve all dependencies
    for template in "${templates[@]}"; do
        resolve_dependencies "$template" || exit 1
    done

    # Get sorted list of resolved templates
    local sorted_templates=($(echo "${!RESOLVED_TEMPLATES[@]}" | tr ' ' '\n' | sort))

    # Collect all services (avoiding duplicates)
    declare -A SEEN_SERVICES
    local all_services=()

    for template in "${sorted_templates[@]}"; do
        while IFS= read -r service; do
            if [ -n "$service" ] && [ "${SEEN_SERVICES[$service]}" != "1" ]; then
                all_services+=("$service")
                SEEN_SERVICES[$service]=1
            fi
        done < <(collect_services_from_template "$template")
    done

    # Output space-separated list
    echo "${all_services[@]}"
}

# Only run main if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    main "$@"
fi
