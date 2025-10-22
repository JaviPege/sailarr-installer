#!/bin/bash
# Template Selector - Interactive template selection with dependency validation
# Returns selected templates to stdout

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/../templates"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Load template metadata
load_template_metadata() {
    local template_path=$1
    local conf_file="${template_path}/template.conf"

    if [ ! -f "$conf_file" ]; then
        return 1
    fi

    source "$conf_file"
}

# Check if template requires another template
get_template_dependencies() {
    local template=$1
    local template_path="${TEMPLATES_DIR}/${template}"

    if [ ! -f "${template_path}/template.conf" ]; then
        echo ""
        return
    fi

    source "${template_path}/template.conf"
    echo "$DEPENDS"
}

# Get templates that can be selected (filtered by dependencies)
get_available_templates() {
    local selected_media_server=$1
    local templates=()

    # Media servers (mutually exclusive)
    if [ -z "$selected_media_server" ]; then
        if [ -d "${TEMPLATES_DIR}/mediaplayers/plex" ]; then
            templates+=("mediaplayers/plex")
        fi
        # Add jellyfin when available
        # if [ -d "${TEMPLATES_DIR}/mediaplayers/jellyfin" ]; then
        #     templates+=("mediaplayers/jellyfin")
        # fi
    fi

    # Extras - filter based on selected media server
    for extra_dir in "${TEMPLATES_DIR}/extras/"*; do
        if [ ! -d "$extra_dir" ]; then continue; fi

        local template_name="extras/$(basename "$extra_dir")"
        local deps=$(get_template_dependencies "$template_name")

        # Check if dependencies are met
        if [ -n "$selected_media_server" ]; then
            # If media server is selected, check if this extra is compatible
            if echo "$deps" | grep -q "mediaplayers/"; then
                # This extra requires a specific media server
                if echo "$deps" | grep -q "$selected_media_server"; then
                    templates+=("$template_name")
                fi
            else
                # This extra doesn't require a media server
                templates+=("$template_name")
            fi
        else
            # No media server selected yet
            # Only show extras that don't require a media server
            if ! echo "$deps" | grep -q "mediaplayers/"; then
                templates+=("$template_name")
            fi
        fi
    done

    printf '%s\n' "${templates[@]}"
}

# Interactive selection
interactive_select() {
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  MediaCenter Template Selection${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""

    # Core is always included
    echo -e "${GREEN}✓${NC} Core stack (required)"
    echo "  - Radarr, Sonarr, Prowlarr"
    echo "  - Zurg + rclone (Real-Debrid)"
    echo "  - Zilean (indexer)"
    echo "  - Decypharr (download client)"
    echo "  - Autoscan (library scanner)"
    echo ""

    # Select media server
    echo -e "${YELLOW}MEDIA SERVER${NC}"
    echo "-------------"
    echo "Select your media server (required):"
    echo ""
    echo "  1) Plex Media Server"
    echo "  2) None (manual setup later)"
    echo ""
    read -p "Select option [1-2]: " media_choice
    echo ""

    SELECTED_MEDIA_SERVER=""
    case $media_choice in
        1)
            SELECTED_MEDIA_SERVER="mediaplayers/plex"
            echo -e "${GREEN}✓${NC} Plex Media Server selected"
            ;;
        2)
            echo -e "${YELLOW}!${NC} No media server selected (you'll need to set one up manually)"
            ;;
        *)
            echo -e "${RED}✗${NC} Invalid choice, defaulting to Plex"
            SELECTED_MEDIA_SERVER="mediaplayers/plex"
            ;;
    esac
    echo ""

    # Select extras
    echo -e "${YELLOW}OPTIONAL SERVICES${NC}"
    echo "------------------"

    # Get available extras based on media server selection
    local available_extras=($(get_available_templates "$SELECTED_MEDIA_SERVER" | grep "^extras/"))

    if [ ${#available_extras[@]} -eq 0 ]; then
        echo "No optional services available for this configuration."
        echo ""
    else
        echo "Select optional services to install:"
        echo ""

        local extra_choices=()
        local idx=1

        for extra in "${available_extras[@]}"; do
            local template_path="${TEMPLATES_DIR}/${extra}"
            source "${template_path}/template.conf"

            echo "  $idx) $DESCRIPTION"
            extra_choices+=("$extra")
            ((idx++))
        done

        echo ""
        echo "Enter numbers separated by spaces (e.g., '1 3 4'), or press Enter to skip:"
        read -p "Selection: " selections
        echo ""

        SELECTED_EXTRAS=()
        if [ -n "$selections" ]; then
            for num in $selections; do
                if [ "$num" -ge 1 ] && [ "$num" -le ${#extra_choices[@]} ]; then
                    local selected_extra="${extra_choices[$((num-1))]}"
                    SELECTED_EXTRAS+=("$selected_extra")

                    # Load description for confirmation
                    source "${TEMPLATES_DIR}/${selected_extra}/template.conf"
                    echo -e "${GREEN}✓${NC} $DESCRIPTION"
                fi
            done
        fi

        if [ ${#SELECTED_EXTRAS[@]} -eq 0 ]; then
            echo -e "${YELLOW}!${NC} No optional services selected"
        fi
        echo ""
    fi

    # Summary
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  Installation Summary${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
    echo "The following will be installed:"
    echo ""
    echo -e "${GREEN}✓${NC} Core stack (Radarr, Sonarr, Prowlarr, Zilean, Decypharr, Autoscan)"

    if [ -n "$SELECTED_MEDIA_SERVER" ]; then
        source "${TEMPLATES_DIR}/${SELECTED_MEDIA_SERVER}/template.conf"
        echo -e "${GREEN}✓${NC} $DESCRIPTION"
    fi

    for extra in "${SELECTED_EXTRAS[@]}"; do
        source "${TEMPLATES_DIR}/${extra}/template.conf"
        echo -e "${GREEN}✓${NC} $DESCRIPTION"
    done

    echo ""
    read -p "Continue with this configuration? (y/n): " confirm
    echo ""

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 1
    fi

    # Output selected templates (space-separated)
    local all_selected="core"
    [ -n "$SELECTED_MEDIA_SERVER" ] && all_selected="$all_selected $SELECTED_MEDIA_SERVER"
    [ ${#SELECTED_EXTRAS[@]} -gt 0 ] && all_selected="$all_selected ${SELECTED_EXTRAS[*]}"

    echo "$all_selected"
}

# Main execution
main() {
    interactive_select
}

# Only run main if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    main "$@"
fi
