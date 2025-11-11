# Sailarr Template System

This directory contains modular templates for deploying different configurations of the Sailarr media stack.

## Structure

```
templates/
├── core/                 # Required base stack
├── mediaplayers/         # Media server options
│   ├── plex/             # Plex Media Server
│   └── jellyfin/         # Jellyfin Media Server (alternative to Plex)
└── extras/               # Optional services
    ├── overseerr/        # Request management (requires Plex)
    ├── tautulli/         # Plex analytics
    ├── homarr/           # Dashboard
    ├── dashdot/          # System monitoring
    ├── pinchflat/        # YouTube downloader
    ├── plextraktsync/    # Plex/Trakt sync
    ├── watchtower/       # Auto-updates
    └── traefik/          # Reverse proxy with HTTPS
```

## Template Files

Each template directory contains:

- **`template.conf`** - Template metadata (name, description, dependencies)
- **`services.list`** - List of Docker Compose service files to include
- **`setup.sh`** (optional) - Post-deployment configuration script

## Template Types

### Core Templates

**core** (required)
- Minimal *arr stack with Real-Debrid integration
- Services: Zurg, Rclone, Radarr, Sonarr, Prowlarr, Zilean, Decypharr, Autoscan
- No dependencies

### Media Players (mediaplayers/)

**plex**
- Plex Media Server
- Depends on: core

**jellyfin** (future)
- Jellyfin Media Server
- Depends on: core

### Optional Services (extras/)

**overseerr**
- Request management system
- Depends on: core, plex

- **tautulli** - Plex analytics (requires plex)
- **homarr** - Unified dashboard
- **dashdot** - System monitoring
- **pinchflat** - YouTube downloader
- **plextraktsync** - Plex/Trakt synchronization
- **watchtower** - Automatic container updates
- **traefik** - Reverse proxy with automatic HTTPS

## Usage

Templates are selected during installation. The installer will:

1. Read selected template dependencies
2. Merge `services.list` files in dependency order
3. Generate final `docker-compose.yml`
4. Execute setup scripts for each template

## Example Configurations

### Minimal Setup (Core only)
```
templates: core
services: 13 containers
```

### Plex + Overseerr
```
templates: core + mediaplayers/plex + extras/overseerr
services: 15 containers
```

### Full Stack
```
templates: core + mediaplayers/plex + extras/overseerr + extras/tautulli + extras/homarr + extras/traefik
services: 20+ containers
```

## Adding New Templates

1. Create directory in `templates/core/`, `templates/mediaplayers/`, or `templates/extras/`
2. Create `template.conf` with metadata
3. Create `services.list` with service file references
4. (Optional) Create `setup.sh` for post-deployment configuration
5. Update this README

## Template Configuration Format

**template.conf:**
```bash
NAME="template-name"
DESCRIPTION="Template description"
DEPENDS="dependency1 dependency2"  # Space-separated
REQUIRED="true|false"
```

**services.list:**
```
# Comments supported
service1.yml
service2.yml
```

**setup.sh:**
```bash
#!/bin/bash
# Post-deployment configuration
# Executed after containers are running
```
