# Installation Guide

This guide walks you through the complete installation process, explaining each step and configuration option.

## Prerequisites

Before starting the installation, ensure you have:

1. **A server running Ubuntu 20.04+ or Debian 11+**
   - Minimum 8GB RAM (16GB recommended)
   - At least 20GB free disk space (50GB+ recommended)
   - Root or sudo access

2. **Docker and Docker Compose installed**
   ```bash
   # Check if Docker is installed
   docker --version
   docker compose version

   # If not installed, follow the official Docker installation guide:
   # https://docs.docker.com/engine/install/
   ```

3. **Real-Debrid account with API token**
   - Sign up at https://real-debrid.com/
   - Get your API token from https://real-debrid.com/apitoken
   - Keep this token ready for the installation

4. **Plex claim token (optional)**
   - Only needed if you want hardware transcoding or remote access
   - Get it from https://www.plex.tv/claim/
   - The token expires after 4 minutes, so get it right before installation

## Installation Steps

### Step 1: Clone the Repository

```bash
git clone https://github.com/JaviPege/sailarr-installer.git
cd sailarr-installer
```

### Step 2: Make the Script Executable

```bash
chmod +x setup.sh
```

### Step 3: Run the Installer

```bash
./setup.sh
```

The installer will now guide you through the configuration process.

## Configuration Questions

The installer will ask you several configuration questions. Here's what each one means and how to answer:

### Question 1: Installation Directory

```
Enter the root directory for the installation (default: /mediacenter):
```

**What it does:** This is where all your configuration files, media, and Docker volumes will be stored.

**Default:** `/mediacenter`

**When to change it:**
- If `/mediacenter` doesn't exist or you don't have permissions
- If you want to use a different mount point (e.g., `/mnt/storage`)
- If you're testing and want to isolate the installation

**Example paths:**
- `/mediacenter` - Standard installation
- `/mnt/storage/mediacenter` - Using external storage
- `/home/username/mediacenter` - User home directory (for testing)

**What gets created:**
```
/mediacenter/
├── config/         # All application configurations
├── data/          # Media files and symlinks
├── logs/          # Health check logs
└── docker/        # Docker Compose files
```

### Question 2: Real-Debrid API Token

```
Enter your Real-Debrid API token (get it from https://real-debrid.com/apitoken):
```

**What it does:** This token authenticates your Real-Debrid account so the download client and Zurg can access your cached torrents.

**How to get it:**
1. Go to https://real-debrid.com/apitoken
2. Log in to your Real-Debrid account
3. Copy the API token shown on the page

**Format:** A long alphanumeric string (e.g., `ABC123XYZ789...`)

**Important:**
- Keep this token secret - it gives full access to your Real-Debrid account
- If you accidentally expose it, regenerate a new token from the Real-Debrid website
- The installer stores it in configuration files that are protected by file permissions

**What uses this token:**
- Zurg: To mount your Real-Debrid library
- Decypharr: To add torrents to Real-Debrid

### Question 3: Plex Claim Token (Optional)

```
Enter your Plex claim token (optional, get it from https://www.plex.tv/claim/):
Press Enter to skip if you don't want to claim the server now.
```

**What it does:** Claims your Plex server to your Plex account, enabling remote access and hardware transcoding.

**How to get it:**
1. Go to https://www.plex.tv/claim/
2. Log in to your Plex account
3. Copy the claim token shown

**Format:** Starts with `claim-` followed by alphanumeric characters (e.g., `claim-AbCdEfGhIjKlMnOp`)

**Important:**
- The token expires after 4 minutes - get it right before you need to enter it
- If it expires, just get a new one from the same URL

**When to use it:**
- You want to access Plex remotely (outside your local network)
- You want hardware transcoding support
- You want to use Plex features that require authentication

**When to skip it:**
- You only need local network access
- You'll claim the server manually later through the Plex web interface
- You're testing and don't want to connect to your main Plex account

**Can you add it later?** Yes! You can claim the server later by:
1. Going to `http://YOUR_SERVER_IP:32400/web`
2. Logging in with your Plex account
3. Following the setup wizard

### Question 4: Timezone

```
Enter timezone [press Enter for default]:
```

**What it does:** Sets the timezone for all containers and log timestamps.

**Default:** `Europe/Madrid`

**How to find your timezone:**
- Use the format `Continent/City` (e.g., `America/New_York`, `America/Los_Angeles`, `Asia/Tokyo`)
- Check available timezones: `timedatectl list-timezones`

### Question 5: Authentication (Optional)

```
Do you want to configure authentication? (y/n):
```

**What it does:** Enables password protection for all services when using Traefik.

**When to enable:**
- You're exposing services to the internet
- You want an extra security layer
- Multiple users will access the server

**When to skip:**
- Only accessing locally on your network
- You have other security measures (VPN, firewall)
- Testing/development environment

**If enabled, you'll be asked:**
- **Username:** Your login username
- **Password:** Your password (hidden when typing)

### Question 6: Traefik (Reverse Proxy)

```
Do you want to enable Traefik? (y/n):
```

**What it does:** Enables Traefik reverse proxy with automatic HTTPS support.

**Benefits:**
- Access services via subdomains (e.g., `radarr.yourdomain.com`)
- Automatic HTTPS certificates
- Single entry point for all services
- Better security with authentication

**Requirements:**
- A domain name pointing to your server
- Ports 80 and 443 open on your firewall

**If enabled, you'll be asked:**
- **Domain/Hostname:** Your domain name (e.g., `mediacenter.example.com`)

**When to enable:**
- You have a domain name
- You want HTTPS access
- You're accessing services remotely

**When to skip:**
- Local network only
- Don't have a domain
- Prefer direct port access

**Important:** The installer only configures Traefik and the containers. You must handle these network configurations yourself:
- **DNS:** Create DNS A/AAAA records pointing your domain/subdomains to your server's public IP
- **Port Forwarding:** Configure your router to forward ports 80 and 443 to your server
- **Firewall:** Ensure your firewall allows incoming traffic on ports 80 and 443
- **Domain Ownership:** You must own or control the domain you configure

These networking requirements are outside the scope of this installer.

### Download Client

**The installer automatically uses Decypharr** as the download client.

**About Decypharr:**
- Lightweight and fast
- Lower resource usage
- Handles Real-Debrid integration seamlessly
- Creates symlinks automatically

**Web UI:** `http://YOUR_SERVER_IP:8283`

**Note:** RDTClient is available in the compose files as legacy support but is not configured by the installer. If you need RDTClient, you'll have to configure it manually after installation.

## Installation Process

After answering all questions, the installer will:

### 1. Create Directory Structure (10-15 seconds)
- Creates `/mediacenter` and subdirectories
- Sets up proper ownership and permissions
- Creates user groups

### 2. Generate Configuration Files (5 seconds)
- Creates Docker Compose files
- Generates environment files
- Configures Zurg with your Real-Debrid token
- Sets up rclone configuration

### 3. Deploy Docker Containers (2-5 minutes)
- Pulls Docker images (this can take a while on first run)
- Starts all containers
- Waits for each service to become healthy

**Services started:**
- Zurg (Real-Debrid WebDAV)
- Rclone (Mount manager)
- Plex Media Server
- Radarr (Movies)
- Sonarr (TV Shows)
- Prowlarr (Indexers)
- Zilean (DMM Indexer)
- PostgreSQL (Zilean database)
- Decypharr (Download client)
- Overseerr (Request management)
- Autoscan (Library updates)
- Traefik (if enabled)
- Optional services (if selected)

### 4. Extract API Keys (30 seconds)
- Waits for services to generate API keys
- Automatically extracts keys from configuration files
- Stores them for automatic configuration

### 5. Configure Services (1-2 minutes)

#### Prowlarr Configuration
- Adds Zilean indexer
- Configures connection to `http://zilean:8181`
- Sets up API key authentication

#### Radarr Configuration
- Adds Prowlarr as indexer source
- Configures Decypharr as download client
- Sets root folder to `/data/media/movies`
- Configures quality profiles

#### Sonarr Configuration
- Adds Prowlarr as indexer source
- Configures Decypharr as download client
- Sets root folder to `/data/media/tv`
- Configures quality profiles

#### Decypharr Configuration
- Sets up Real-Debrid API token
- Configures symlink paths
- Sets minimum file size filters
- Configures mount paths for Zurg/Rclone

### 6. Quality Profiles (30 seconds)
- Removes all default quality profiles
- Runs Recyclarr to create TRaSH Guide profiles:
  - **Recyclarr-1080p**: HD content up to Remux-1080p
  - **Recyclarr-2160p**: 4K content up to Remux-2160p
  - **Recyclarr-Any**: Any quality, prefers best

### 7. Health Monitoring Setup (5 seconds)
- Installs cron jobs for mount health checks
- Plex: Every 35 minutes
- Arrs: Every 30 minutes
- Creates log files in `/mediacenter/logs/`

## Post-Installation

### Verify Installation

Check that all containers are running:

```bash
docker ps
```

You should see all services with status "Up" and "healthy".

### Access Your Services

Access URLs depend on whether you enabled Traefik or not.

#### Without Traefik (Direct Port Access)

- **Plex:** `http://YOUR_SERVER_IP:32400/web`
- **Radarr:** `http://YOUR_SERVER_IP:7878`
- **Sonarr:** `http://YOUR_SERVER_IP:8989`
- **Prowlarr:** `http://YOUR_SERVER_IP:9696`
- **Overseerr:** `http://YOUR_SERVER_IP:5055`
- **Zilean:** `http://YOUR_SERVER_IP:8181`
- **Decypharr:** `http://YOUR_SERVER_IP:8283`
- **Tautulli:** `http://YOUR_SERVER_IP:8282`
- **Homarr:** `http://YOUR_SERVER_IP:7575`
- **Dashdot:** `http://YOUR_SERVER_IP:3001`
- **Pinchflat:** `http://YOUR_SERVER_IP:8945`
- **Autoscan:** `http://YOUR_SERVER_IP:3030`

Replace `YOUR_SERVER_IP` with your server's IP address.

#### With Traefik Enabled

All services are accessible via subdomains:

- **Plex:** `https://plex.YOUR_DOMAIN`
- **Radarr:** `https://radarr.YOUR_DOMAIN`
- **Sonarr:** `https://sonarr.YOUR_DOMAIN`
- **Prowlarr:** `https://prowlarr.YOUR_DOMAIN`
- **Overseerr:** `https://overseerr.YOUR_DOMAIN`
- **Zilean:** `https://zilean.YOUR_DOMAIN`
- **Decypharr:** `https://decypharr.YOUR_DOMAIN`
- **Tautulli:** `https://tautulli.YOUR_DOMAIN`
- **Homarr:** `https://homarr.YOUR_DOMAIN`
- **Dashdot:** `https://dashdot.YOUR_DOMAIN`
- **Pinchflat:** `https://pinchflat.YOUR_DOMAIN`
- **Traefik Dashboard:** `https://traefik.YOUR_DOMAIN`

Replace `YOUR_DOMAIN` with the domain you configured during installation.

**Note:** If you enabled authentication, you'll be prompted for username/password when accessing services through Traefik.

### Initial Setup Tasks

1. **Plex Library Setup:**
   - Access Plex at your configured URL
   - Add movie library: `/data/media/movies`
   - Add TV library: `/data/media/tv`
   - Configure metadata preferences
   - Set library scanner to run automatically

2. **Overseerr Setup:**
   - Open Overseerr
   - Connect to your Plex server
   - Configure Radarr and Sonarr connections
   - Set up user access and permissions

3. **Wait for Zilean:**
   - Zilean needs to populate its database
   - Initial population: 1-2 hours
   - Full database: Can take up to 24 hours
   - Check progress: `docker logs zilean`

### First Request

1. Open Overseerr
2. Search for a movie or TV show
3. Click "Request"
4. Wait a few minutes
5. Check Radarr/Sonarr for activity
6. Once imported, it will appear in Plex

## Troubleshooting

### No Services Accessible

**Check if containers are running:**
```bash
docker ps -a
```

**Check container logs:**
```bash
docker logs <container_name>
```

### Real-Debrid Connection Failed

**Verify your API token:**
1. Check `/mediacenter/config/zurg-config/config.yml`
2. Verify the token matches your Real-Debrid account
3. Test the token at https://api.real-debrid.com/rest/1.0/user (in browser)

### Plex Not Accessible

**If you used a claim token:**
- Make sure it didn't expire (4-minute limit)
- Try accessing locally first: http://localhost:32400/web

**If you skipped the claim token:**
- Access via http://YOUR_SERVER_IP:32400/web
- Sign in and claim the server manually

### No Search Results in Radarr/Sonarr

**Wait for Zilean to populate:**
```bash
docker logs zilean | grep -i "scraping\|complete"
```

**Check Prowlarr connection:**
1. Open Prowlarr
2. Go to Indexers
3. Test the Zilean indexer
4. Check sync status with Radarr/Sonarr

### Symlinks Not Created

**Check download client logs:**
```bash
docker logs decypharr
# or
docker logs rdtclient
```

**Verify mount is working:**
```bash
docker exec rclone ls /data/realdebrid-zurg/
```

**Check health logs:**
```bash
tail -f /mediacenter/logs/arrs-mount-healthcheck.log
```

### Permission Errors

**Check directory ownership:**
```bash
ls -la /mediacenter/
```

**Fix permissions if needed:**
```bash
sudo chown -R 1000:mediacenter /mediacenter/config
sudo chown -R 1000:mediacenter /mediacenter/data
```

## Advanced Configuration

### Update Quality Profiles

After installation, you can update quality profiles:

```bash
cd /mediacenter
./scripts/recyclarr-sync.sh
```

### Add More Indexers

1. Open Prowlarr
2. Go to Settings > Indexers
3. Add your preferred indexers
4. Sync to Radarr/Sonarr

### Customize Quality Settings

Edit `/mediacenter/config/recyclarr.yml` and run:
```bash
./scripts/recyclarr-sync.sh
```

### Enable Traefik (Reverse Proxy)

If you want HTTPS and domain names:

1. Edit `/mediacenter/docker/.env`
2. Set `TRAEFIK_ENABLED=true`
3. Configure domain names
4. Restart: `docker compose up -d`

## Maintenance

### Update Containers

```bash
cd /mediacenter/docker
docker compose pull
docker compose up -d
```

### View Logs

```bash
# All containers
docker compose logs -f

# Specific container
docker logs -f <container_name>

# Health checks
tail -f /mediacenter/logs/*.log
```

### Restart Services

```bash
# All services
cd /mediacenter/docker
docker compose restart

# Specific service
docker restart <container_name>
```

### Backup Configuration

```bash
# Backup config directory
tar -czf mediacenter-backup-$(date +%Y%m%d).tar.gz /mediacenter/config/
```

## Getting Help

If you encounter issues:

1. Check container logs: `docker logs <container_name>`
2. Verify all containers are healthy: `docker ps`
3. Check health monitoring logs: `tail -f /mediacenter/logs/*.log`
4. Review the Troubleshooting section above
5. Consult the service-specific documentation (Radarr, Sonarr, etc.)

## Next Steps

Once installation is complete:

1. Configure Overseerr for content requests
2. Set up Plex libraries and metadata
3. Customize quality profiles in Recyclarr
4. Add additional indexers in Prowlarr
5. Configure notifications in Radarr/Sonarr
6. Set up remote access (optional)
7. Start requesting content and enjoy!
