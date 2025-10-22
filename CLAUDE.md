# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MediaCenter is a Docker-based media streaming stack that leverages Real-Debrid and the *Arr ecosystem to create an "infinite" media library. This is a microservices architecture project using Docker Compose to orchestrate 11 services including Plex, Overseerr, Radarr, Sonarr, Prowlarr, Zilean, Zurg, RDTClient, Recyclarr, Autoscan, and Watchtower.

## Essential Commands

### Initial Setup (Run Once)
```bash
chmod +x setup.sh
./setup.sh
sudo reboot  # Required after setup
```

### Stack Management
```bash
# Start the entire stack
docker compose up -d

# Stop the stack
docker compose down

# Monitor logs
docker compose logs -f [service_name]

# Restart individual services
docker compose restart [service_name]

# Update quality profiles
docker compose exec recyclarr recyclarr sync
```

### Debugging and Monitoring
```bash
# Check service health
docker compose ps

# View specific service logs
docker compose logs radarr
docker compose logs sonarr
docker compose logs zurg

# Monitor container resources
docker stats
```

## Architecture & Key Concepts

### Data Flow Pattern
The system uses a **symlink-based architecture** optimized for hardlinking:
1. **Request**: Overseerr → Radarr/Sonarr → Prowlarr → Zilean/Indexers  
2. **Download**: RDTClient → Real-Debrid → Zurg → Rclone Mount
3. **Media**: Symlinks → Media folders → Plex → Autoscan refresh

### Directory Structure
```
${ROOT_DIR}/
├── config/           # Container configurations (created by setup.sh)
├── data/
│   ├── symlinks/     # Download symlinks (radarr/, sonarr/)
│   ├── realdebrid-zurg/  # Rclone mount point
│   └── media/        # Final media library (movies/, tv/)
```

### Critical Configuration Files
- **`.env`**: Environment variables, user IDs (13000-13009), Plex claim token
- **`compose.yml`**: Complete Docker stack with dependencies and health checks
- **`zurg.yml`**: Real-Debrid API integration and WebDAV server config
- **`recyclarr/recyclarr.yml`**: Automated quality profiles with TRaSH-Guides compliance
- **`autoscan/config.yml`**: Webhook configuration for Plex library updates

## Service Ports & Access
- Plex: Host Mode (network_mode: host)
- Overseerr: 5055 (Request management)
- Prowlarr: 9696 (Indexer management)  
- Radarr: 7878 (Movie management)
- Sonarr: 8989 (TV management)
- RDTClient: 6500 (Download client)
- Zurg: 9999 (Real-Debrid WebDAV interface)
- Zilean: 8181 (Torrent indexer)

## Development Requirements

### Prerequisites
- Active Real-Debrid subscription and API key
- Docker Engine + Docker Compose
- Ubuntu Server (recommended: 8GB RAM, 50GB disk)
- Static IP configuration

### Permission System
The setup.sh script creates users with IDs 13000-13009 and sets critical permissions (775/664, umask 002). All containers run with these user IDs for proper file access.

## Important Notes

### First-Run Behavior
- **Plex claim token**: Valid for only 4 minutes, set in .env before deployment
- **Zilean database**: Initial torrent indexing can take >1.5 days
- **Real-Debrid API**: Must be configured in zurg.yml before starting

### Updates & Maintenance  
- **Watchtower**: Automatically updates containers daily at 4 AM
- **Manual updates**: `docker compose pull && docker compose up -d`
- **Quality profiles**: Run `docker compose exec recyclarr recyclarr sync` after changes

### Filesystem Design
The project uses symlinks extensively to maintain hardlink compatibility between download clients and media servers. Never modify the data/symlinks/ structure directly - let Radarr/Sonarr manage these paths.

## No Testing Framework
This is a configuration-heavy deployment project without formal tests. Validation is done through:
- Docker Compose health checks
- Web UI functionality testing
- Integration testing via full stack deployment