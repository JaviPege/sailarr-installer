#!/bin/bash

# MediaCenter Configuration Backup Script
# Backs up all configuration except media files

set -e

BACKUP_DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="mediacenter-backup-${BACKUP_DATE}"
BACKUP_DIR="/tmp/${BACKUP_NAME}"
MEDIACENTER_ROOT="/mediacenter"
MOUNT_ROOT="/mnt/mediacenter"

echo "🚀 Starting MediaCenter backup: ${BACKUP_NAME}"

# Create backup directory
mkdir -p "${BACKUP_DIR}"
chmod 755 "${BACKUP_DIR}"

echo "📁 Creating backup structure..."

# 1. Backup Docker Compose files and environment
echo "   → Docker configuration"
cp "${MOUNT_ROOT}/compose.yml" "${BACKUP_DIR}/"
cp "${MOUNT_ROOT}/.env" "${BACKUP_DIR}/"
cp "${MOUNT_ROOT}/setup.sh" "${BACKUP_DIR}/" 2>/dev/null || echo "   ⚠️ setup.sh not found"
cp "${MOUNT_ROOT}/zurg.yml" "${BACKUP_DIR}/" 2>/dev/null || echo "   ⚠️ zurg.yml not found"
cp "${MOUNT_ROOT}/CLAUDE.md" "${BACKUP_DIR}/" 2>/dev/null || echo "   ⚠️ CLAUDE.md not found"

# 2. Backup all service configurations
echo "   → Service configurations"
if [ -d "${MEDIACENTER_ROOT}/config" ]; then
    # Use sudo to handle permission issues and exclude problematic files
    sudo cp -r "${MEDIACENTER_ROOT}/config" "${BACKUP_DIR}/" 2>/dev/null || true
    # Skip asp files that cause permission issues
    sudo find "${BACKUP_DIR}/config" -path "*/asp/*.xml" -delete 2>/dev/null || true
else
    echo "   ⚠️ Config directory not found at ${MEDIACENTER_ROOT}/config"
fi

# 3. Create media structure (empty directories)
echo "   → Media directory structure (empty)"
mkdir -p "${BACKUP_DIR}/data/media/movies"
mkdir -p "${BACKUP_DIR}/data/media/tv"
mkdir -p "${BACKUP_DIR}/data/media/youtube"
mkdir -p "${BACKUP_DIR}/data/realdebrid-zurg"
mkdir -p "${BACKUP_DIR}/data/symlinks/radarr"
mkdir -p "${BACKUP_DIR}/data/symlinks/sonarr"

# 4. Create empty .gitkeep files to preserve structure
touch "${BACKUP_DIR}/data/media/.gitkeep"
touch "${BACKUP_DIR}/data/realdebrid-zurg/.gitkeep"

# 5. Backup system user configuration info
echo "   → System users information"
getent group mediacenter > "${BACKUP_DIR}/mediacenter-group.txt" 2>/dev/null || echo "Group mediacenter not found" > "${BACKUP_DIR}/mediacenter-group.txt"
getent passwd | grep -E '^(rclone|sonarr|radarr|prowlarr|overseerr|plex|recyclarr|rdtclient|autoscan|traefik|pinchflat|plextraktsync|homarr|dashdot):' > "${BACKUP_DIR}/mediacenter-users.txt" 2>/dev/null || echo "No mediacenter users found" > "${BACKUP_DIR}/mediacenter-users.txt"

# 6. Docker images list
echo "   → Docker images list"
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}" | grep -E "(mediacenter|traefik|plex|overseerr|prowlarr|sonarr|radarr|zurg|zilean|rclone|autoscan|homarr|dashdot|recyclarr|rdtclient|pinchflat|plextraktsync|watchtower|postgres)" > "${BACKUP_DIR}/docker-images.txt" 2>/dev/null || echo "No mediacenter images found" > "${BACKUP_DIR}/docker-images.txt"

# 7. Create restore instructions
cat > "${BACKUP_DIR}/RESTORE-INSTRUCTIONS.md" << 'EOF'
# MediaCenter Restore Instructions

## Prerequisites
- Ubuntu Server with Docker and Docker Compose installed
- Static IP configuration
- Active Real-Debrid subscription

## Restore Steps

1. **Stop any existing MediaCenter services:**
   ```bash
   docker compose down
   ```

2. **Restore files:**
   ```bash
   # Copy configuration files
   sudo cp -r config/ /mediacenter/
   sudo cp compose.yml .env setup.sh zurg.yml CLAUDE.md /mnt/mediacenter/
   
   # Restore directory structure
   sudo mkdir -p /mediacenter/data/{media/{movies,tv,youtube},realdebrid-zurg,symlinks/{radarr,sonarr}}
   ```

3. **Recreate system users:**
   ```bash
   # Create mediacenter group
   sudo groupadd -g 13000 mediacenter
   
   # Create users (check mediacenter-users.txt for full list)
   sudo useradd -u 13001 -g 13000 -M -s /sbin/nologin rclone
   sudo useradd -u 13002 -g 13000 -M -s /sbin/nologin sonarr  
   sudo useradd -u 13003 -g 13000 -M -s /sbin/nologin radarr
   # ... (continue with all users from mediacenter-users.txt)
   ```

4. **Set permissions:**
   ```bash
   sudo chown -R 13000:13000 /mediacenter/
   sudo chmod -R 775 /mediacenter/config/
   ```

5. **Update configuration:**
   - Edit `.env` with your timezone and Plex claim token
   - Edit `zurg.yml` with your Real-Debrid API key
   - Update any service-specific configurations as needed

6. **Start services:**
   ```bash
   docker compose up -d
   ```

7. **Verify all services are healthy:**
   ```bash
   docker compose ps
   ```

## Important Notes
- Media files are NOT included in this backup
- Update Plex claim token (valid for 4 minutes only)
- Verify Real-Debrid API key in zurg.yml
- Check service-specific configurations for any hardcoded paths or keys

## Service Access
- Homarr Dashboard: http://home.medianita
- Overseerr: http://overseerr.medianita
- Plex: Network host mode
- Other services: Check compose.yml for ports and domains
EOF

# 8. Create backup metadata
cat > "${BACKUP_DIR}/backup-info.txt" << EOF
MediaCenter Backup Information
=============================
Backup Date: $(date)
Backup Name: ${BACKUP_NAME}
Source Path: ${MEDIACENTER_ROOT}
Mount Path: ${MOUNT_ROOT}
System: $(uname -a)

Services Included:
- Plex Media Server
- Overseerr (Request Management)
- Prowlarr (Indexer Management)
- Radarr (Movie Management)
- Sonarr (TV Management)
- RDTClient (Download Client)
- Zurg (Real-Debrid WebDAV)
- Zilean (Torrent Indexer)
- Recyclarr (Quality Profiles)
- Autoscan (Library Updates)
- Traefik (Reverse Proxy)
- Homarr (Dashboard)
- DashDot (System Monitor)
- Pinchflat (YouTube Downloader)
- PlexTraktSync (Trakt Integration)
- Watchtower (Auto Updates)

Total Config Size: $(du -sh "${BACKUP_DIR}/config" 2>/dev/null | cut -f1 || echo "N/A")
EOF

# 9. Create compressed archive
echo "📦 Creating compressed backup..."
cd /tmp
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
BACKUP_SIZE=$(du -sh "${BACKUP_NAME}.tar.gz" | cut -f1)

echo "✅ Backup completed successfully!"
echo ""
echo "📊 Backup Details:"
echo "   Name: ${BACKUP_NAME}.tar.gz"
echo "   Size: ${BACKUP_SIZE}"
echo "   Path: /tmp/${BACKUP_NAME}.tar.gz"
echo ""
echo "🔍 To extract: tar -xzf ${BACKUP_NAME}.tar.gz"
echo "📋 See RESTORE-INSTRUCTIONS.md for restore steps"

# Cleanup temporary directory
rm -rf "${BACKUP_DIR}"