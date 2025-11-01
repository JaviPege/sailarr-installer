# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sailarr Installer is an automated Docker-based media streaming stack that leverages Real-Debrid and the *Arr ecosystem to create an "infinite" media library. This is a microservices architecture project using Docker Compose to orchestrate multiple services including Plex, Overseerr, Radarr, Sonarr, Bazarr, Prowlarr, Zilean, Zurg, Decypharr, Recyclarr, Autoscan, Tautulli, Homarr, Pinchflat, PlexTraktSync, and Watchtower.

## Essential Commands

### Initial Setup (Run Once)
```bash
chmod +x setup.sh
./setup.sh
sudo reboot  # Required after setup
```

### Stack Management
```bash
# Navigate to docker directory
cd /YOUR_INSTALL_DIR/docker

# Start the entire stack (using helper scripts - recommended)
./up.sh
./down.sh
./restart.sh

# Or using docker compose directly with required env files
docker compose --env-file .env.defaults --env-file .env.local up -d
docker compose --env-file .env.defaults --env-file .env.local down
docker compose --env-file .env.defaults --env-file .env.local restart [service_name]

# For Traefik profile
docker compose --env-file .env.defaults --env-file .env.local --profile traefik up -d

# Monitor logs
docker compose logs -f [service_name]

# Update quality profiles
/YOUR_INSTALL_DIR/scripts/recyclarr-sync.sh
```

### Debugging and Monitoring
```bash
# Check service health
docker ps -a

# View specific service logs
docker logs radarr
docker logs sonarr
docker logs bazarr
docker logs zurg

# Monitor container resources
docker stats

# Check health check logs
tail -f /YOUR_INSTALL_DIR/logs/plex-mount-healthcheck.log
tail -f /YOUR_INSTALL_DIR/logs/arrs-mount-healthcheck.log

# Verify cron jobs
crontab -l | grep healthcheck

# Manual health check execution
/YOUR_INSTALL_DIR/scripts/health/plex-mount-healthcheck.sh
/YOUR_INSTALL_DIR/scripts/health/arrs-mount-healthcheck.sh
```

## Architecture & Key Concepts

### Data Flow Pattern
The system uses a **symlink-based architecture** optimized for hardlinking:
1. **Request**: Overseerr → Radarr/Sonarr → Prowlarr → Zilean/Torrentio/Public Indexers
2. **Download**: Decypharr → Real-Debrid → Zurg → Rclone Mount
3. **Media**: Symlinks → Media folders → Plex → Autoscan refresh → PlexTraktSync tracking

### Services List

**Core Media Stack:**
- **Plex** - Media server (host network mode)
- **Overseerr** - Request management interface (port 5055)
- **Radarr** - Movie management (port 7878)
- **Sonarr** - TV show management (port 8989)
- **Prowlarr** - Indexer manager (port 9696)
- **Bazarr** - Substitles management (port 6767)

**Download & Storage:**
- **Zurg** - Real-Debrid WebDAV interface (port 9999)
- **Rclone** - Mount Real-Debrid storage
- **Decypharr** - Download client with Debrid integration (port 8282)

**Indexers:**
- **Zilean** - DMM torrent indexer (port 8181)
- **Torrentio** - Stremio indexer integration
- **Public Indexers** - 1337x, TPB, YTS, EZTV

**Automation & Monitoring:**
- **Recyclarr** - Automated quality profiles via TRaSH Guides
- **Autoscan** - Plex library auto-update (port 3030)
- **Tautulli** - Plex statistics and monitoring (port 8282)
- **PlexTraktSync** - Sync Plex watch history to Trakt
- **Watchtower** - Automatic container updates
- **Homarr** - Dashboard for all services (port 7575)
- **Pinchflat** - YouTube download manager (port 8945)

**Optional:**
- **Traefik** - Reverse proxy with HTTPS (ports 80, 443) - requires network configuration

### Directory Structure
```
${ROOT_DIR}/
├── config/              # Container configurations (created by setup.sh)
│   ├── plex-config/
│   ├── radarr-config/
│   ├── sonarr-config/
│   ├── bazarr-config/
│   ├── prowlarr-config/
│   ├── overseerr-config/
│   ├── zilean-config/
│   ├── zurg-config/
│   ├── autoscan-config/
│   ├── decypharr-config/
│   ├── tautulli-config/
│   ├── homarr-config/
│   ├── pinchflat-config/
│   ├── plextraktsync-config/
│   └── traefik-config/  # Only if Traefik enabled
├── data/
│   ├── media/
│   │   ├── movies/      # Radarr movies
│   │   ├── tv/          # Sonarr TV shows
│   │   ├── radarr/      # Radarr symlinks for downloads
│   │   └── sonarr/      # Sonarr symlinks for downloads
│   └── realdebrid-zurg/ # Rclone mount point
└── logs/                # Health check logs
```

### Repository Structure
```
/repository-root/
├── setup.sh             # Main installation script
├── README.md            # User documentation
├── INSTALLATION.md      # Detailed installation guide
├── LICENSE              # MIT License
├── CLAUDE.md            # This file - Claude Code guidance
│
├── setup/               # Setup scripts and libraries
│   ├── lib/            # Modular function libraries
│   │   ├── setup-common.sh    # Logging, validation, wait functions
│   │   ├── setup-users.sh     # User/group management
│   │   ├── setup-api.sh       # Generic API functions
│   │   └── setup-services.sh  # High-level service config
│   └── utils/          # Setup utilities
│       └── split-compose.py   # Compose file splitter
│
├── scripts/            # Maintenance scripts
│   ├── health/        # Health check scripts
│   │   ├── arrs-mount-healthcheck.sh
│   │   └── plex-mount-healthcheck.sh
│   ├── maintenance/   # Backup scripts
│   │   ├── backup-mediacenter.sh
│   │   └── backup-mediacenter-optimized.sh
│   └── recyclarr-sync.sh  # Manual profile update
│
├── config/            # Configuration templates
│   ├── recyclarr.yml  # TRaSH Guide quality profiles
│   ├── rclone.conf    # Rclone configuration
│   ├── autoscan/
│   │   └── config.yml # Autoscan webhook config
│   └── indexers/
│       ├── zilean.yml # Zilean indexer definition
│       └── zurg.yml   # Zurg indexer definition
│
└── docker/            # Docker Compose configuration
    ├── .env.defaults  # Default environment variables
    ├── .env.local     # User-specific variables (created by setup.sh)
    ├── up.sh          # Helper script to start stack
    ├── down.sh        # Helper script to stop stack
    ├── restart.sh     # Helper script to restart stack
    └── compose-services/  # Split compose files
        ├── core.yml
        ├── plex.yml
        ├── radarr.yml
        └── ... (one file per service)
```

### Critical Configuration Files
- **`docker/.env.defaults`**: Default environment variables
- **`docker/.env.local`**: User-specific variables (UIDs, tokens, created by setup.sh)
- **`docker/compose-services/*.yml`**: Modular Docker service definitions
- **`config/recyclarr.yml`**: Automated quality profiles with TRaSH-Guides compliance
- **`config/autoscan/config.yml`**: Webhook configuration for Plex library updates
- **`config/indexers/zilean.yml`**: Zilean indexer definition for Prowlarr
- **`config/indexers/zurg.yml`**: Zurg indexer definition for Prowlarr

## Development Requirements

### Prerequisites
- Active Real-Debrid subscription and API key
- Docker Engine + Docker Compose
- Ubuntu Server (recommended: 8GB RAM, 20GB+ disk)
- Static IP configuration (recommended)

### Permission System
The setup.sh script creates system users with dynamic UIDs/GIDs starting from 1000 and sets critical permissions (775/664, umask 002). All containers run with these user IDs for proper file access.

**System users created:**
- rclone, sonarr, radarr, bazarr, recyclarr, prowlarr, overseerr, plex, decypharr, autoscan, pinchflat, zilean, zurg, tautulli, homarr, plextraktsync

All users are added to the `mediacenter` group for shared access.

## Important Notes

### First-Run Behavior
- **Plex claim token**: Valid for only 4 minutes, obtain from https://plex.tv/claim and set in .env.local
- **Real-Debrid token**: Must be configured during setup.sh interactive prompts
- **Zilean database**: Initial torrent indexing can take >1.5 days (Zilean indexer disabled by default until ready)
- **Health checks**: Installed as cron jobs, run every 30-35 minutes to verify mounts

### Updates & Maintenance
- **Watchtower**: Automatically updates containers daily at 4 AM
- **Manual updates**: `docker compose pull && ./up.sh`
- **Quality profiles**: Run `/YOUR_INSTALL_DIR/scripts/recyclarr-sync.sh` after changes
- **Health check logs**: Located in `/YOUR_INSTALL_DIR/logs/`

### Modular Architecture
The project uses a modular approach:
- **Setup libraries**: Reusable bash functions in `setup/lib/`
- **Split compose files**: One file per service in `docker/compose-services/`
- **Organized configs**: Templates in `config/`, runtime configs in `${ROOT_DIR}/config/`

### Filesystem Design
The project uses symlinks to maintain hardlink compatibility between download clients and media servers. The path structure is:
- Downloads: `/data/media/radarr/` and `/data/media/sonarr/` (symlinks managed by Radarr/Sonarr)
- Final media: `/data/media/movies/` and `/data/media/tv/` (actual files after import)

Never modify the symlink structure directly - let Radarr/Sonarr manage these paths.

## No Testing Framework
This is a configuration-heavy deployment project without formal tests. Validation is done through:
- Docker Compose health checks
- Web UI functionality testing
- Integration testing via full stack deployment
- Bash script syntax validation (`bash -n`)

## Code Style & Conventions

### Bash Scripts
- Use `set -e` for error handling
- Modular functions in `setup/lib/` with clear exports
- Color-coded logging: blue (info), green (success), yellow (warning), red (error)
- Comprehensive error messages with actionable guidance

### Docker Compose
- Split services into individual files in `compose-services/`
- Use `network_mode: host` only for Plex
- All other services use `mediacenter` bridge network
- Health checks defined for all critical services
- Environment variables from `.env.defaults` and `.env.local`

### Documentation
- Keep README.md user-focused with quick start guide
- INSTALLATION.md contains detailed step-by-step instructions
- CLAUDE.md (this file) for technical/architectural details
- Inline comments in complex bash functions

## Common Issues & Solutions

### Rclone Mount Issues
If Plex or *Arr services can't access media:
```bash
# Check mount status
mountpoint /YOUR_INSTALL_DIR/data/realdebrid-zurg

# Check Zurg logs
docker logs zurg

# Restart rclone container
docker restart rclone
```

### API Key Issues
If auto-configuration fails during setup:
```bash
# Manually retrieve API keys
docker exec radarr cat /config/config.xml | grep ApiKey
docker exec sonarr cat /config/config.xml | grep ApiKey
docker exec prowlarr cat /config/config.xml | grep ApiKey
```

### Permission Issues
If containers show permission denied errors:
```bash
# Fix ownership (run from install directory parent)
sudo chown -R $MEDIACENTER_UID:mediacenter /YOUR_INSTALL_DIR/
```

## Author & Credits

**Created by:** JaviPege (https://github.com/JaviPege)

**Built with guidance from:** Claude Code (Anthropic)

**Inspired by & Thanks to:**
- Ashwin Shenoy's [setup-scripts](https://github.com/shanmukhateja/setup-scripts) - Initial foundation
- TRaSH Guides - Quality profiles and custom formats
- Recyclarr - Automated TRaSH Guide implementation
- The entire *Arr community and maintainers
