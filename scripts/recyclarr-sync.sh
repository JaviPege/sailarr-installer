#!/bin/bash
# MediaCenter - Recyclarr Sync Script
# Syncs TRaSH Guide quality profiles and naming conventions to Radarr/Sonarr

set -e

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed or not in PATH"
    exit 1
fi

# Get API keys from Radarr and Sonarr
echo "Fetching API keys from Radarr and Sonarr..."

RADARR_API_KEY=$(docker exec radarr cat /config/config.xml 2>/dev/null | grep -oP '(?<=<ApiKey>)[^<]+' || echo "")
SONARR_API_KEY=$(docker exec sonarr cat /config/config.xml 2>/dev/null | grep -oP '(?<=<ApiKey>)[^<]+' || echo "")

if [ -z "$RADARR_API_KEY" ]; then
    echo "ERROR: Could not fetch Radarr API key. Is Radarr running?"
    exit 1
fi

if [ -z "$SONARR_API_KEY" ]; then
    echo "ERROR: Could not fetch Sonarr API key. Is Sonarr running?"
    exit 1
fi

echo "✓ API keys retrieved"
echo ""
echo "Running Recyclarr sync..."
echo "This will:"
echo "  • Create/update quality profiles (Recyclarr-1080p, Recyclarr-2160p, Recyclarr-Any)"
echo "  • Configure custom formats from TRaSH Guides"
echo "  • Set up media naming conventions for Plex"
echo ""

# Run Recyclarr with Docker
docker run --rm \
    --network mediacenter \
    -v "${SCRIPT_DIR}/../config/recyclarr.yml:/config/recyclarr.yml:ro" \
    -e RADARR_API_KEY="${RADARR_API_KEY}" \
    -e SONARR_API_KEY="${SONARR_API_KEY}" \
    ghcr.io/recyclarr/recyclarr:latest \
    sync

echo ""
echo "✓ Recyclarr sync completed successfully!"
echo ""
echo "Quality profiles created:"
echo "  • Recyclarr-1080p - For 1080p content with upgrades to Remux"
echo "  • Recyclarr-2160p - For 4K content with upgrades to Remux"
echo "  • Recyclarr-Any - Accepts any quality, upgrades to best available"
echo ""
echo "Naming conventions configured for Plex compatibility"
