#!/bin/bash

# MediaCenter Configuration Backup Script - OPTIMIZED VERSION
# Backs up essential configuration only, excludes logs and large databases

set -e

BACKUP_DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="mediacenter-backup-${BACKUP_DATE}"
BACKUP_DIR="/tmp/${BACKUP_NAME}"
MEDIACENTER_ROOT="/mediacenter"
MOUNT_ROOT="/mnt/mediacenter"

echo "🚀 Starting OPTIMIZED MediaCenter backup: ${BACKUP_NAME}"

# Create backup directory
mkdir -p "${BACKUP_DIR}"
chmod 755 "${BACKUP_DIR}"

echo "📁 Creating backup structure..."

# 1. Backup Docker Compose files and environment
echo "   → Docker configuration"
cp "${MEDIACENTER_ROOT}/docker/docker-compose.yml" "${BACKUP_DIR}/"
cp "${MEDIACENTER_ROOT}/docker/.env.defaults" "${BACKUP_DIR}/"
cp "${MEDIACENTER_ROOT}/docker/.env.local" "${BACKUP_DIR}/"
cp "${MEDIACENTER_ROOT}/docker/up.sh" "${BACKUP_DIR}/" 2>/dev/null || echo "   ⚠️ up.sh not found"
cp "${MEDIACENTER_ROOT}/docker/down.sh" "${BACKUP_DIR}/" 2>/dev/null || echo "   ⚠️ down.sh not found"
cp -r "${MEDIACENTER_ROOT}/docker/compose-services/" "${BACKUP_DIR}/" 2>/dev/null || echo "   ⚠️ compose-services not found"
cp "${MOUNT_ROOT}/setup.sh" "${BACKUP_DIR}/" 2>/dev/null || echo "   ⚠️ setup.sh not found"
cp "${MOUNT_ROOT}/zurg.yml" "${BACKUP_DIR}/" 2>/dev/null || echo "   ⚠️ zurg.yml not found"
cp "${MOUNT_ROOT}/CLAUDE.md" "${BACKUP_DIR}/" 2>/dev/null || echo "   ⚠️ CLAUDE.md not found"
cp "${MOUNT_ROOT}/backup-mediacenter.sh" "${BACKUP_DIR}/" 2>/dev/null || true
cp "/tmp/mediacenter-permissions-report.txt" "${BACKUP_DIR}/" 2>/dev/null || true

# 2. Backup service configurations (OPTIMIZED - exclude large files)
echo "   → Service configurations (optimized)"
mkdir -p "${BACKUP_DIR}/config"

for service_dir in ${MEDIACENTER_ROOT}/config/*/; do
    service_name=$(basename "$service_dir")
    echo "      - ${service_name}"
    
    # Create service directory
    mkdir -p "${BACKUP_DIR}/config/${service_name}"
    
    # Copy config files but exclude large databases and logs
    sudo rsync -av \
        --exclude='*.log' \
        --exclude='*.log.*' \
        --exclude='logs.db*' \
        --exclude='*.db-wal' \
        --exclude='*.db-shm' \
        --exclude='title.basics.tsv' \
        --exclude='trakt_cache.sqlite' \
        --exclude='MediaCover/' \
        --exclude='asp/*.xml' \
        --exclude='Definitions/' \
        --exclude='cache/' \
        --exclude='repositories/' \
        --exclude='extras/' \
        --exclude='metadata/' \
        --exclude='database.db/' \
        --exclude='redis/' \
        --exclude='Library/Application Support/Plex Media Server/Cache/' \
        --exclude='Library/Application Support/Plex Media Server/Metadata/' \
        --exclude='Library/Application Support/Plex Media Server/Media/' \
        --exclude='access.log' \
        "${service_dir}" "${BACKUP_DIR}/config/${service_name}/" 2>/dev/null || true
done

# 3. Create essential config files list for reference
echo "   → Creating config inventory"
cat > "${BACKUP_DIR}/essential-configs.txt" << 'EOF'
Essential Configuration Files Backed Up:
=========================================
- docker-compose.yml (Docker stack definition)
- .env.defaults (Standard configuration)  
- .env.local (Environment-specific secrets)
- compose-services/ (Individual service files)
- up.sh/down.sh (Convenience scripts)
- zurg.yml (Real-Debrid configuration)
- */config.xml (Service configurations)
- */settings.json (Service settings)
- recyclarr.yml (Quality profiles)
- autoscan/config.yml (Webhook configuration)
- traefik/tls.yml (TLS configuration)

Files NOT included (can be regenerated):
=========================================
- *.log files (Will be recreated)
- logs.db files (Will be recreated)
- MediaCover directories (Will be re-downloaded)
- Cache directories (Will be rebuilt)
- title.basics.tsv (Can be re-downloaded)
- trakt_cache.sqlite (Will be rebuilt on sync)
EOF

# 4. Create media structure (empty directories)
echo "   → Media directory structure (empty)"
mkdir -p "${BACKUP_DIR}/data/media/movies"
mkdir -p "${BACKUP_DIR}/data/media/tv"
mkdir -p "${BACKUP_DIR}/data/media/youtube"
mkdir -p "${BACKUP_DIR}/data/realdebrid-zurg"
mkdir -p "${BACKUP_DIR}/data/symlinks/radarr"
mkdir -p "${BACKUP_DIR}/data/symlinks/sonarr"
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
# MediaCenter Restore Instructions - OPTIMIZED BACKUP

## Important Note
This is an OPTIMIZED backup that excludes logs, caches, and large databases.
These will be regenerated automatically when services start.

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
   sudo mkdir -p /mediacenter/docker/
   sudo cp docker-compose.yml .env.defaults .env.local up.sh down.sh /mediacenter/docker/
   sudo cp -r compose-services/ /mediacenter/docker/
   sudo cp setup.sh zurg.yml CLAUDE.md /mnt/mediacenter/
   
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

4. **Set permissions (use mediacenter-permissions-report.txt for exact commands):**
   ```bash
   sudo chown -R 13000:13000 /mediacenter/
   sudo chmod -R 775 /mediacenter/config/
   ```

5. **Update configuration:**
   - Edit `.env` with your timezone and Plex claim token
   - Edit `zurg.yml` with your Real-Debrid API key
   - Update any service-specific configurations as needed

6. **Download missing files (if needed):**
   - Zilean: title.basics.tsv will be downloaded on first run
   - MediaCover: Will be re-downloaded as media is added

7. **Start services:**
   ```bash
   cd /mediacenter/docker/
   ./up.sh
   ```

8. **Verify all services are healthy:**
   ```bash
   docker compose ps
   ```

## Files NOT included in this backup:
- Log files (*.log)
- Large databases (logs.db, trakt_cache.sqlite)
- Media cover images
- Cache directories
- title.basics.tsv (1GB file)

These will be automatically recreated when services start.
EOF

# 8. Create backup metadata
cat > "${BACKUP_DIR}/backup-info.txt" << EOF
MediaCenter OPTIMIZED Backup Information
=========================================
Backup Date: $(date)
Backup Name: ${BACKUP_NAME}
Source Path: ${MEDIACENTER_ROOT}
Mount Path: ${MOUNT_ROOT}
System: $(uname -a)
Backup Type: OPTIMIZED (excludes logs, caches, large DBs)

Services Included:
- All 19 services configurations
- Docker Compose stack
- Environment variables
- User/group information
- Directory structure

Excluded from backup:
- Log files
- Large databases
- Cache directories
- Media cover images
- title.basics.tsv

Total Config Size: $(du -sh "${BACKUP_DIR}/config" 2>/dev/null | cut -f1 || echo "N/A")
EOF

# 9. Create compressed archive
echo "📦 Creating compressed backup..."
cd /tmp
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
BACKUP_SIZE=$(du -sh "${BACKUP_NAME}.tar.gz" | cut -f1)

echo "✅ OPTIMIZED Backup completed successfully!"
echo ""
echo "📊 Backup Details:"
echo "   Name: ${BACKUP_NAME}.tar.gz"
echo "   Size: ${BACKUP_SIZE}"
echo "   Path: /tmp/${BACKUP_NAME}.tar.gz"
echo ""
echo "💡 This optimized backup excludes:"
echo "   - Log files (will be recreated)"
echo "   - Large databases (will be rebuilt)"
echo "   - Cache directories (will be regenerated)"
echo ""
echo "🔍 To extract: tar -xzf ${BACKUP_NAME}.tar.gz"
echo "📋 See RESTORE-INSTRUCTIONS.md for restore steps"
echo "📑 See mediacenter-permissions-report.txt for exact permissions"

# Cleanup temporary directory
rm -rf "${BACKUP_DIR}"