# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sailarr Installer is an automated Docker-based media streaming stack that leverages Real-Debrid and the *Arr ecosystem to create an "infinite" media library. This is a fully automated installer with a modular template system that deploys a microservices architecture using Docker Compose to orchestrate services including Plex, Seerr, Radarr, Sonarr, Bazarr, Prowlarr, Zilean, Zurg, Decypharr, Recyclarr, Autoscan, Tautulli, Homarr, Pinchflat, PlexTraktSync, and Watchtower.

The installer is designed to be run once (`./setup.sh`) and handles everything from user input collection to full stack deployment and service configuration with zero manual steps required.

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
1. **Request**: Seerr → Radarr/Sonarr → Prowlarr → Zilean/Torrentio/Public Indexers
2. **Download**: Decypharr → Real-Debrid → Zurg → Rclone Mount
3. **Media**: Symlinks → Media folders → Plex → Autoscan refresh → PlexTraktSync tracking

### Services List

**Core Media Stack:**
- **Plex** - Media server (host network mode)
- **Seerr** - Request management interface (port 5055)
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
│   ├── seerr-config/
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
├── setup.sh             # Main installation script - entry point
├── .env.install         # User configuration (created by setup.sh)
├── README.md            # User documentation
├── INSTALLATION.md      # Detailed installation guide
├── LICENSE              # MIT License
├── CLAUDE.md            # This file - Claude Code guidance
│
├── setup/               # Setup scripts and libraries
│   ├── lib/            # Modular function libraries (sourced by setup.sh)
│   │   ├── setup-common.sh    # Logging, validation, wait functions
│   │   ├── setup-users.sh     # User/group management
│   │   ├── setup-api.sh       # Generic API functions
│   │   └── setup-services.sh  # High-level service config
│   └── utils/          # Setup utilities
│       └── split-compose.py   # Compose file splitter
│
├── scripts/            # Maintenance and automation scripts
│   ├── compose-generator.sh   # Generates docker-compose.yml from templates
│   ├── setup-executor.sh      # Executes setup.json configurations
│   ├── template-selector.sh   # Interactive template selection
│   ├── get-services-list.sh   # Lists services from templates
│   ├── get-config-dirs.sh     # Lists config directories
│   ├── health/        # Health check scripts
│   │   ├── arrs-mount-healthcheck.sh
│   │   └── plex-mount-healthcheck.sh
│   ├── maintenance/   # Backup scripts
│   │   ├── backup-mediacenter.sh
│   │   └── backup-mediacenter-optimized.sh
│   └── recyclarr-sync.sh  # Manual profile update
│
├── templates/         # Modular service templates (NEW)
│   ├── README.md      # Template system documentation
│   ├── core/          # Required base stack
│   ├── mediaplayers/  # Media server options (plex)
│   ├── services/      # JSON configuration for setup-executor
│   │   ├── plex.json
│   │   ├── radarr.json
│   │   ├── sonarr.json
│   │   └── ... (per-service setup actions)
│   └── extras/        # Optional services
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
    ├── .env.defaults  # Default environment variables (version controlled)
    ├── .env.local     # User-specific variables (created by setup.sh, not in git)
    ├── docker-compose.yml  # Master compose (generated by compose-generator.sh)
    ├── POST-INSTALL.md     # Manual post-install steps (Seerr, Tautulli)
    ├── up.sh          # Helper script to start stack
    ├── down.sh        # Helper script to stop stack
    ├── restart.sh     # Helper script to restart stack
    ├── pull.sh        # Helper script to pull updates
    ├── compose.sh     # Helper script for compose commands
    ├── fix-permissions.sh  # Fix ownership issues
    └── compose-services/   # Split compose files (one per service)
        ├── networks.yml
        ├── volumes.yml
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
- rclone, sonarr, radarr, bazarr, recyclarr, prowlarr, seerr, plex, decypharr, autoscan, pinchflat, zilean, zurg, tautulli, homarr, plextraktsync

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
The project uses a highly modular approach with three key systems:

1. **Setup Library System** (`setup/lib/`)
   - Reusable bash functions sourced by setup.sh
   - `setup-common.sh`: Logging (log_info, log_success, log_error), validation, wait functions
   - `setup-users.sh`: User/group creation and management
   - `setup-api.sh`: Generic API key retrieval and service configuration
   - `setup-services.sh`: High-level service configuration orchestration
   - All functions use `set -e` for error handling and color-coded output

2. **Template System** (`templates/`)
   - **Purpose**: Modular service deployment with dependency management
   - **Structure**: `core/` (required), `mediaplayers/` (plex/jellyfin), `extras/` (optional services)
   - **Template files**:
     - `template.conf`: Metadata (NAME, DESCRIPTION, DEPENDS, REQUIRED)
     - `services.list`: List of compose files to include
     - `setup.sh`: Optional post-deployment configuration
   - **Service JSON** (`templates/services/*.json`): Declarative setup actions executed by setup-executor.sh
   - **Workflow**: User selects templates → compose-generator.sh merges services.list → generates docker-compose.yml → setup-executor.sh runs post-deployment configs

3. **Split Compose System** (`docker/compose-services/`)
   - One YAML file per service for modularity
   - Master `docker-compose.yml` includes all services
   - Allows selective deployment and independent management
   - Uses `mediacenter` bridge network for all services except Plex (host mode)

4. **Configuration Templates** (`config/`)
   - Source templates for runtime configs deployed to `${ROOT_DIR}/config/`
   - Includes indexer definitions, quality profiles, and service configs

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

## Setup.sh Architecture

The main installation script follows a structured flow:

1. **Phase 1: Input Collection**
   - Interactive prompts using `ask_user_input()` and `ask_password()` functions
   - Validates input and checks for conflicts (UID availability)
   - Creates `.env.install` with all configuration
   - Shows summary and asks for confirmation

2. **Phase 2: System Preparation**
   - Creates installation directory structure
   - Sources libraries from `setup/lib/`
   - Creates system users with dynamic UIDs starting from 1000
   - Creates `mediacenter` group for shared access
   - Sets permissions (775/664, umask 002)

3. **Phase 3: Template Processing**
   - Runs `scripts/compose-generator.sh` to merge template service lists
   - Generates `docker/docker-compose.yml` from selected templates
   - Copies configuration templates to runtime directories

4. **Phase 4: Service Deployment**
   - Pulls Docker images via helper scripts
   - Starts containers in dependency order
   - Waits for services to become healthy

5. **Phase 5: Automated Configuration**
   - Executes `scripts/setup-executor.sh` with service JSON files
   - Retrieves API keys from service config files
   - Configures inter-service connections (Prowlarr ↔ *Arrs)
   - Sets up download clients, root folders, indexers
   - Runs Recyclarr to create TRaSH Guide quality profiles

6. **Phase 6: Health Monitoring**
   - Installs health check scripts to `${ROOT_DIR}/scripts/health/`
   - Creates cron jobs for automatic mount verification
   - Sets up logging infrastructure

**Key Design Principles:**
- Atomic functions for reusability
- Extensive logging to `/tmp/sailarr-install-*/`
- Idempotent operations (can re-run safely)
- Defensive programming with validation at every step

## Code Style & Conventions

### Bash Scripts
- Use `set -e` for error handling (fail fast on errors)
- Modular functions in `setup/lib/` with clear exports
- Color-coded logging: blue (info), green (success), yellow (warning), red (error)
- Comprehensive error messages with actionable guidance
- Function documentation with usage examples in comments
- All user-facing paths use `${ROOT_DIR}` variable (default: `/mediacenter`)
- Temporary files go to `/tmp/sailarr-install-TIMESTAMP/`

### Docker Compose
- Split services into individual files in `compose-services/`
- Each file starts with `name: mediacenter` to ensure consistent project name
- Use `network_mode: host` only for Plex (required for DLNA and local network discovery)
- All other services use `mediacenter` bridge network
- Health checks defined for all critical services
- Environment variables from `.env.defaults` (defaults) and `.env.local` (user-specific)
- Use `${VARIABLE:-default}` syntax for environment variables with fallbacks

### Template System
- Each template must have `template.conf` with NAME, DESCRIPTION, DEPENDS
- `services.list` contains one compose file per line (comments supported with #)
- Service JSON files use declarative actions: `wait_for_service`, `get_api_key`, `configure_*`
- All templates should handle missing dependencies gracefully

### Documentation
- Keep README.md user-focused with quick start guide
- INSTALLATION.md contains detailed step-by-step instructions
- CLAUDE.md (this file) for technical/architectural details
- docker/POST-INSTALL.md for manual post-install steps
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
