# MediaCenter Modular Docker Compose Structure

## Overview
Each service is defined in its own YAML file for better organization and maintenance.

## File Structure
```
/mnt/mediacenter/
├── docker-compose.yml           # Master file that includes all services
├── .env                         # Environment variables
├── compose-services/            # Individual service definitions
│   ├── networks.yml            # Network configuration
│   ├── volumes.yml             # Volume definitions
│   ├── traefik.yml             # Reverse proxy
│   ├── plex.yml                # Media server
│   ├── seerr.yml           # Request management
│   ├── radarr.yml              # Movie management
│   ├── sonarr.yml              # TV show management
│   └── ...                     # Other services
```

## Usage

### Start all services:
```bash
docker compose up -d
```

### Start specific services:
```bash
# Start only Plex and Seerr
docker compose up -d plex seerr

# Start media management stack
docker compose up -d radarr sonarr prowlarr
```

### Stop all services:
```bash
docker compose down
```

### View specific service logs:
```bash
docker compose logs -f plex
docker compose logs -f radarr
```

### Restart a specific service:
```bash
docker compose restart sonarr
```

### Update a specific service:
```bash
docker compose pull radarr
docker compose up -d radarr
```

## Service Groups

### Core Infrastructure
- `traefik.yml` - Reverse proxy
- `traefik-socket-proxy.yml` - Docker API security
- `networks.yml` - Network configuration
- `volumes.yml` - Shared volumes

### Media Server
- `plex.yml` - Plex Media Server

### Request Management
- `seerr.yml` - Media requests

### Media Management (*arr stack)
- `radarr.yml` - Movies
- `sonarr.yml` - TV Shows
- `prowlarr.yml` - Indexers
- `recyclarr.yml` - Quality profiles

### Download & Streaming
- `rdtclient.yml` - Real-Debrid client
- `zurg.yml` - Real-Debrid WebDAV
- `rclone.yml` - Cloud storage mount

### Indexers
- `zilean.yml` - Torrent indexer
- `zilean-postgres.yml` - Database for Zilean

### Utilities
- `autoscan.yml` - Library updates
- `watchtower.yml` - Auto updates
- `pinchflat.yml` - YouTube downloads
- `plextraktsync.yml` - Trakt sync

### Dashboard & Monitoring
- `homarr.yml` - Main dashboard
- `dashdot.yml` - System monitor

## Benefits of This Structure

1. **Modularity**: Each service can be managed independently
2. **Clarity**: Easy to find and modify specific service configurations
3. **Version Control**: Track changes to individual services
4. **Selective Deployment**: Start only the services you need
5. **Easier Debugging**: Isolate issues to specific services
6. **Team Collaboration**: Different team members can work on different services

## Adding New Services

1. Create a new file in `compose-services/`:
```yaml
# compose-services/newservice.yml
name: mediacenter

services:
  newservice:
    image: newservice:latest
    container_name: newservice
    networks:
      - mediacenter
    # ... rest of configuration
```

2. Add the include to `docker-compose.yml`:
```yaml
include:
  # ... existing includes
  - compose-services/newservice.yml
```

3. Restart the stack:
```bash
docker compose up -d
```

## Backup
To backup this modular structure:
```bash
tar -czf mediacenter-compose-backup.tar.gz \
  docker-compose.yml \
  .env \
  compose-services/
```