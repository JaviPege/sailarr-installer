#!/usr/bin/env python3
"""
Split the monolithic docker-compose.yml into individual service files
"""

import yaml
import os
from pathlib import Path

# Read the original compose file
with open('/mnt/mediacenter/compose-monolithic.yml.backup', 'r') as f:
    compose_data = yaml.safe_load(f)

# Output directory
output_dir = Path('/mnt/mediacenter/compose-services')
output_dir.mkdir(exist_ok=True)

# Services to extract
services_to_extract = {
    'overseerr': 'overseerr.yml',
    'prowlarr': 'prowlarr.yml',
    'radarr': 'radarr.yml',
    'sonarr': 'sonarr.yml',
    'bazarr': 'bazarr.yml',
    'recyclarr': 'recyclarr.yml',
    'rdtclient': 'rdtclient.yml',
    'zurg': 'zurg.yml',
    'rclone': 'rclone.yml',
    'watchtower': 'watchtower.yml',
    'autoscan': 'autoscan.yml',
    'zilean': 'zilean.yml',
    'zilean-postgres': 'zilean-postgres.yml',
    'pinchflat': 'pinchflat.yml',
    'plextraktsync': 'plextraktsync.yml',
    'homarr': 'homarr.yml',
    'dashdot': 'dashdot.yml'
}

# Template for each service file
template = """# {service_description}
name: mediacenter

{service_yaml}"""

# Extract and save each service
for service_name, filename in services_to_extract.items():
    if service_name in compose_data.get('services', {}):
        service_data = compose_data['services'][service_name]
        
        # Create service description
        descriptions = {
            'overseerr': 'Overseerr - Request Management',
            'prowlarr': 'Prowlarr - Indexer Management',
            'radarr': 'Radarr - Movie Management',
            'sonarr': 'Sonarr - TV Show Management',
            'bazarr': 'Bazarr - Subtitles Management',
            'recyclarr': 'Recyclarr - Quality Profiles Sync',
            'rdtclient': 'RDTClient - Real-Debrid Download Client',
            'zurg': 'Zurg - Real-Debrid WebDAV',
            'rclone': 'Rclone - Mount Real-Debrid Storage',
            'watchtower': 'Watchtower - Automatic Container Updates',
            'autoscan': 'Autoscan - Plex Library Updates',
            'zilean': 'Zilean - Torrent Indexer',
            'zilean-postgres': 'PostgreSQL for Zilean',
            'pinchflat': 'Pinchflat - YouTube Downloader',
            'plextraktsync': 'PlexTraktSync - Trakt.tv Integration',
            'homarr': 'Homarr - Dashboard',
            'dashdot': 'DashDot - System Monitor'
        }
        
        # Convert service data to YAML
        service_dict = {service_name: service_data}
        service_yaml_dict = {'services': service_dict}
        service_yaml = yaml.dump(service_yaml_dict, 
                                 default_flow_style=False, 
                                 sort_keys=False)
        
        # Write to file
        output_file = output_dir / filename
        with open(output_file, 'w') as f:
            f.write(template.format(
                service_description=descriptions.get(service_name, service_name),
                service_yaml=service_yaml
            ))
        
        print(f"Created: {filename}")

print("\nAll services have been split into individual files!")
print("You can now use: docker compose up -d")
print("Or for specific services: docker compose up -d plex overseerr")