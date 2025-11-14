# Sailarr Installation Guide - Proxmox LXC

**Repository**: https://github.com/JaviPege/sailarr-installer

---

## Step 1: Create LXC Container

Creating a Debian 12 LXC container with the following specifications:
- **Hostname**: sailarr-test
- **CPU Cores**: 4
- **RAM**: 8GB
- **Swap**: 2GB
- **Disk**: 50GB
- **Network**: DHCP on vmbr0
- **Template**: debian-12-standard_12.12-1_amd64.tar.zst


### Result
```
LXC created successfully
Hostname: sailarr-test
Status: stopped
```

---

## Step 2: Configure LXC Features

### 2.1 Enable Docker Nesting
Docker requires the `nesting` feature to run inside LXC containers.


```bash
pct set <LXC_ID> -features nesting=1
```

### 2.2 Disable AppArmor and Remove Capability Restrictions
AppArmor can block Docker operations. We disable it and remove capability drops.

```bash
# Add to /etc/pve/lxc/<LXC_ID>.conf:
lxc.apparmor.profile: unconfined
lxc.cap.drop:
```

### 2.3 Configure Device Access (GPU and FUSE)
Allow access to GPU devices for hardware transcoding and FUSE for rclone mounts.

```bash
# Add to /etc/pve/lxc/<LXC_ID>.conf:
lxc.cgroup2.devices.allow: c 226:* rwm
lxc.cgroup2.devices.allow: c 10:229 rwm
```

### 2.4 Mount Device Passthrough
Mount GPU and FUSE devices from host to container.

```bash
# Add to /etc/pve/lxc/<LXC_ID>.conf:
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-modeset dev/nvidia-modeset none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file
lxc.mount.entry: /dev/fuse dev/fuse none bind,optional,create=file
```

### Result
All LXC features configured successfully:
- ✅ Nesting enabled
- ✅ AppArmor disabled
- ✅ Capabilities unrestricted
- ✅ Device access granted
- ✅ GPU passthrough configured
- ✅ FUSE device mounted

---

## Step 3: Start LXC Container


```bash
pct start <LXC_ID>
```

### Result
```
Container started successfully
Status: running
IP Address: <CONTAINER_IP>
```

---

## Step 4: Install Base Packages

### 4.1 Update System
Update package lists and upgrade existing packages.


```bash
pct exec <LXC_ID> -- bash -c 'apt update && apt upgrade -y'
```

### 4.2 Install Essential Packages
Install curl, wget, git, jq (JSON processor), and certificate management tools.


```bash
pct exec <LXC_ID> -- apt install -y curl wget git jq ca-certificates gnupg lsb-release
```

### Result
Packages installed successfully:
- ✅ curl
- ✅ wget
- ✅ git
- ✅ jq (JSON processor - required by Sailarr installer)
- ✅ ca-certificates
- ✅ gnupg

---

## Step 5: Install Docker

### 5.1 Add Docker GPG Key and Repository
Add Docker's official repository to install the latest stable version.


```bash
pct exec <LXC_ID> -- bash -c '
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list
apt update
'
```

### 5.2 Install Docker Engine
Install Docker CE, CLI, containerd, and compose plugin.


```bash
pct exec <LXC_ID> -- apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 5.3 Verify Docker Installation
Check Docker and Docker Compose are working correctly.

```bash
pct exec <LXC_ID> -- docker --version
pct exec <LXC_ID> -- docker compose version
pct exec <LXC_ID> -- systemctl status docker
```

### Result
Docker installed successfully:
- ✅ Docker Engine
- ✅ Docker Compose
- ✅ Containerd
- ✅ Service Status: active (running)

---

## Step 6: Run Sailarr Installer

### 6.1 Download Installer Script
Download the Sailarr installation script from GitHub.

```bash
pct exec <LXC_ID> -- bash -c 'cd /root && curl -fsSL https://raw.githubusercontent.com/JaviPege/sailarr-installer/main/install.sh -o install.sh'
```


### 6.2 Clone Sailarr Repository
The installer is located at `setup.sh` in the repository root.

```bash
pct exec <LXC_ID> -- bash -c 'cd /root && git clone https://github.com/JaviPege/sailarr-installer.git'
```

### 6.3 Execute Installer Script
Run the interactive setup script.

```bash
pct exec <LXC_ID> -- bash -c 'cd /root/sailarr-installer && chmod +x setup.sh && ./setup.sh'
```


### 6.4 Create Non-Root User
The Sailarr installer requires a non-root user with sudo privileges.

```bash
# Create user 'sailarr'
pct exec <LXC_ID> -- useradd -m -s /bin/bash -G docker sailarr

# Install sudo
pct exec <LXC_ID> -- apt install -y sudo

# Add user to sudoers
pct exec <LXC_ID> -- usermod -aG sudo sailarr

# Set password (optional)
pct exec <LXC_ID> -- bash -c 'echo "sailarr:sailarr" | chpasswd'

# Copy installer to user home
pct exec <LXC_ID> -- cp -r /root/sailarr-installer /home/sailarr/
pct exec <LXC_ID> -- chown -R sailarr:sailarr /home/sailarr/sailarr-installer
```


### Result
```
User created: sailarr
Password: sailarr
Groups: sailarr, docker, sudo
Home directory: /home/sailarr
Installer copied to: /home/sailarr/sailarr-installer
```

### 6.5 Run Installer as Non-Root User
The installer must be run as the sailarr user.

```bash
# Access the container as sailarr user
pct enter <LXC_ID>
su - sailarr

# Navigate to installer directory
cd /home/sailarr/sailarr-installer

# Run the interactive installer
./setup.sh
```

### Important Notes
The installer is **interactive** and will prompt for:
- Installation directory (default: /mediacenter)
- Real-Debrid API token
- Additional service configurations

Follow the on-screen prompts to complete the installation.

---

## Installation Summary

### Prerequisites Completed
- ✅ LXC Container created
- ✅ Docker nesting enabled
- ✅ AppArmor disabled
- ✅ Device passthrough configured (GPU + FUSE)
- ✅ Docker Engine installed
- ✅ Docker Compose installed
- ✅ Base packages installed (curl, wget, git, jq)
- ✅ Non-root user created with sudo privileges
- ✅ Sailarr installer downloaded and prepared

### Next Steps
1. Access the container: `pct enter <LXC_ID>`
2. Switch to sailarr user: `su - sailarr`
3. Run installer: `cd sailarr-installer && ./setup.sh`
4. Follow interactive prompts
5. Provide Real-Debrid API token when requested
6. Wait for Docker containers to deploy

### System Information
- **Host**: Proxmox VE
- **Container**: LXC (sailarr-test)
- **OS**: Debian 12 (Bookworm)
- **Resources**: 4 cores, 8GB RAM, 50GB disk

### Key Directories
- `/home/sailarr/sailarr-installer` - Installer location
- `/mediacenter` - Default installation directory (created by installer)

---

## Troubleshooting

### Docker Permission Errors
If you encounter permission errors:
```bash
sudo usermod -aG docker sailarr
newgrp docker
```

### FUSE Mount Issues
Verify FUSE device is accessible:
```bash
ls -la /dev/fuse
# Should show: crw-rw-rw- 1 root root 10, 229
```

### GPU Passthrough Verification
Check GPU devices:
```bash
ls -la /dev/dri
ls -la /dev/nvidia*
```

---

## Post-Installation

After the installer completes, services will be available at:
- **Prowlarr**: http://<CONTAINER_IP>:9696
- **Sonarr**: http://<CONTAINER_IP>:8989
- **Radarr**: http://<CONTAINER_IP>:7878
- **Overseerr**: http://<CONTAINER_IP>:5055
- **Plex**: http://<CONTAINER_IP>:32400/web
- **Traefik Dashboard**: http://<CONTAINER_IP>:8080

Verify all containers are running:
```bash
docker ps
```

---

## Installation Result

### ✅ Installation Successful

**Sailarr stack deployed**: 18/18 services running (100%)

### Running Services (18)

**Core Media Stack:**
- ✅ zurg - Real-Debrid client
- ✅ rclone - Media mount
- ✅ prowlarr - Indexer manager (port 9696)
- ✅ sonarr - TV show manager (port 8989)
- ✅ radarr - Movie manager (port 7878)
- ✅ plex - Media server (port 32400)
- ✅ overseerr - Request management (port 5055)

**Infrastructure:**
- ✅ traefik - Reverse proxy (port 80, 8080)
- ✅ traefik-socket-proxy - Docker socket proxy
- ✅ decypharr - Blackhole manager (port 8283)
- ✅ autoscan - Media scanner (port 3030)

**Additional Services:**
- ✅ homarr - Dashboard (port 7575)
- ✅ dashdot - System monitor (port 3001)
- ✅ tautulli - Plex statistics (port 8282)
- ✅ plextraktsync - Trakt integration
- ✅ pinchflat - YouTube downloader (port 8945)
- ✅ zilean - DMM service (port 8181)
- ✅ zilean-postgres - Database

### 📝 Important Notes

**Watchtower Removed**
- Watchtower has been removed from the installer due to Docker API incompatibility
- The installer no longer includes watchtower in the stack
- Manual updates can be performed with: `cd /mediacenter/docker && ./compose.sh pull && ./compose.sh up -d`

### Access URLs

All services accessible via container IP: **<CONTAINER_IP>**

- **Homarr Dashboard**: http://<CONTAINER_IP>:7575
- **Traefik Dashboard**: http://<CONTAINER_IP>:8080
- **Plex**: http://<CONTAINER_IP>:32400/web
- **Overseerr**: http://<CONTAINER_IP>:5055
- **Prowlarr**: http://<CONTAINER_IP>:9696
- **Sonarr**: http://<CONTAINER_IP>:8989
- **Radarr**: http://<CONTAINER_IP>:7878
- **Tautulli**: http://<CONTAINER_IP>:8282
- **Autoscan**: http://<CONTAINER_IP>:3030
- **Dashdot**: http://<CONTAINER_IP>:3001
- **Zilean**: http://<CONTAINER_IP>:8181
- **Decypharr**: http://<CONTAINER_IP>:8283

### Verification Commands

```bash
# List all containers
docker ps -a

# Check specific service logs
docker logs <container_name>

# Restart all services
cd /mediacenter/docker && ./compose.sh restart

# Update services manually
cd /mediacenter/docker && ./compose.sh pull && ./compose.sh up -d
```

---

## Post-Installation Steps

1. **Configure Real-Debrid in Zurg**
   - Already configured during installation

2. **Setup Indexers in Prowlarr**
   - Access Prowlarr at http://<CONTAINER_IP>:9696
   - Add indexers (e.g., The Pirate Bay, 1337x)
   - Sync with Sonarr/Radarr

3. **Configure Sonarr/Radarr**
   - Add root folders pointing to rclone mount
   - Set up quality profiles
   - Connect to Prowlarr

4. **Setup Plex**
   - Claim server (if not done during install)
   - Add libraries pointing to rclone mount
   - Enable hardware transcoding if GPU is available

5. **Configure Overseerr**
   - Connect to Plex
   - Add Sonarr/Radarr API keys
   - Configure request settings

---

## Troubleshooting

### Rclone Mount Issues
Check FUSE device:
```bash
ls -la /dev/fuse
# Should show: crw-rw-rw- 1 root root 10, 229
```

### Container Won't Start
Check logs:
```bash
docker logs <container_name>
```

Restart specific service:
```bash
cd /mediacenter/docker
./compose.sh restart <service_name>
```

---

## Sailarr Installation Complete!

### Core Functionality: ✅ Working
- Media acquisition (Sonarr/Radarr)
- Indexer management (Prowlarr)
- Media streaming (Plex)
- Request management (Overseerr)
- Real-Debrid integration (Zurg + Rclone)

**The Sailarr media automation stack is ready to use!**
