# Setup Actions Reference

This document describes all available actions for `setup.json` configuration files.

## Action Format

```json
{
  "action": "action_name",
  "description": "Human-readable description",
  "params": {
    "param1": "value1",
    "param2": "value2"
  }
}
```

## Available Actions

### Service Management

#### `wait_for_service`
Wait for a service to become healthy and accessible.

**Parameters:**
- `service` (string): Service name
- `port` (number): Service port
- `timeout` (number, optional): Timeout in seconds (default: 120)

**Example:**
```json
{
  "action": "wait_for_service",
  "description": "Wait for Radarr to be ready",
  "params": {
    "service": "radarr",
    "port": 7878,
    "timeout": 120
  }
}
```

---

### API Key Management

#### `extract_api_key`
Extract API key from a service configuration file.

**Parameters:**
- `service` (string): Service name (radarr, sonarr, prowlarr, etc.)
- `output_var` (string): Variable name to store the API key

**Example:**
```json
{
  "action": "extract_api_key",
  "description": "Extract Radarr API key",
  "params": {
    "service": "radarr",
    "output_var": "RADARR_API_KEY"
  }
}
```

**Usage:** The API key is stored in `RUNTIME_VARS` and can be referenced in subsequent steps using `api_key_var`.

---

### Configuration Actions

#### `add_root_folder`
Add a root folder to a *arr service.

**Parameters:**
- `service` (string): Service name (radarr, sonarr)
- `port` (number): Service port
- `api_key_var` (string): Variable name containing the API key
- `path` (string): Folder path (e.g., "/data/media/movies")
- `name` (string): Friendly name for the folder

**Example:**
```json
{
  "action": "add_root_folder",
  "description": "Add Movies root folder to Radarr",
  "params": {
    "service": "radarr",
    "port": 7878,
    "api_key_var": "RADARR_API_KEY",
    "path": "/data/media/movies",
    "name": "Movies"
  }
}
```

---

#### `add_download_client`
Add a download client to a *arr service.

**Parameters:**
- `service` (string): Service name (radarr, sonarr)
- `port` (number): Service port
- `api_key_var` (string): Variable name containing the API key
- `client_name` (string): Download client name
- `client_host` (string): Download client hostname
- `client_port` (number): Download client port

**Example:**
```json
{
  "action": "add_download_client",
  "description": "Add Decypharr to Radarr",
  "params": {
    "service": "radarr",
    "port": 7878,
    "api_key_var": "RADARR_API_KEY",
    "client_name": "Decypharr",
    "client_host": "decypharr",
    "client_port": 8283
  }
}
```

---

#### `add_indexer_to_prowlarr`
Add an indexer to Prowlarr.

**Parameters:**
- `prowlarr_port` (number): Prowlarr port
- `prowlarr_api_key_var` (string): Variable name containing Prowlarr API key
- `indexer_name` (string): Indexer name
- `indexer_url` (string): Indexer URL

**Example:**
```json
{
  "action": "add_indexer_to_prowlarr",
  "description": "Add Zilean indexer to Prowlarr",
  "params": {
    "prowlarr_port": 9696,
    "prowlarr_api_key_var": "PROWLARR_API_KEY",
    "indexer_name": "Zilean",
    "indexer_url": "http://zilean:8181"
  }
}
```

---

#### `add_arr_to_prowlarr`
Connect a *arr service to Prowlarr for indexer synchronization.

**Parameters:**
- `service` (string): Service name (radarr, sonarr)
- `service_port` (number): Service port
- `service_api_key_var` (string): Variable name containing service API key
- `prowlarr_port` (number): Prowlarr port
- `prowlarr_api_key_var` (string): Variable name containing Prowlarr API key

**Example:**
```json
{
  "action": "add_arr_to_prowlarr",
  "description": "Add Radarr to Prowlarr",
  "params": {
    "service": "radarr",
    "service_port": 7878,
    "service_api_key_var": "RADARR_API_KEY",
    "prowlarr_port": 9696,
    "prowlarr_api_key_var": "PROWLARR_API_KEY"
  }
}
```

---

#### `delete_default_quality_profiles`
Delete default quality profiles from a *arr service.

**Parameters:**
- `service` (string): Service name (radarr, sonarr)
- `port` (number): Service port
- `api_key_var` (string): Variable name containing the API key

**Example:**
```json
{
  "action": "delete_default_quality_profiles",
  "description": "Remove default quality profiles from Radarr",
  "params": {
    "service": "radarr",
    "port": 7878,
    "api_key_var": "RADARR_API_KEY"
  }
}
```

---

#### `run_recyclarr`
Execute Recyclarr to create TRaSH Guide quality profiles.

**Parameters:**
- `radarr_api_key_var` (string): Variable name containing Radarr API key
- `sonarr_api_key_var` (string): Variable name containing Sonarr API key

**Example:**
```json
{
  "action": "run_recyclarr",
  "description": "Create TRaSH Guide quality profiles",
  "params": {
    "radarr_api_key_var": "RADARR_API_KEY",
    "sonarr_api_key_var": "SONARR_API_KEY"
  }
}
```

---

### Logging Actions

#### `log_info`
Display an informational message.

**Parameters:**
- `message` (string): Message to display (supports variable expansion)

**Example:**
```json
{
  "action": "log_info",
  "description": "Display Plex access information",
  "params": {
    "message": "Plex is now accessible at http://${SERVER_IP}:32400/web"
  }
}
```

---

#### `log_success`
Display a success message.

**Parameters:**
- `message` (string): Message to display (supports variable expansion)

**Example:**
```json
{
  "action": "log_success",
  "description": "Confirm completion",
  "params": {
    "message": "Setup completed successfully!"
  }
}
```

---

#### `log_warning`
Display a warning message.

**Parameters:**
- `message` (string): Message to display (supports variable expansion)

**Example:**
```json
{
  "action": "log_warning",
  "description": "Warn about manual configuration",
  "params": {
    "message": "Manual configuration required for Seerr"
  }
}
```

---

## Variable Expansion

Messages support bash variable expansion:
- Environment variables: `${ROOT_DIR}`, `${SERVER_IP}`
- Runtime variables: `${RADARR_API_KEY}`, `${SONARR_API_KEY}`

**Example:**
```json
{
  "action": "log_info",
  "params": {
    "message": "API Keys:\n   • Radarr: ${RADARR_API_KEY}\n   • Sonarr: ${SONARR_API_KEY}"
  }
}
```

---

## Complete Example

```json
{
  "name": "example",
  "description": "Example setup configuration",
  "steps": [
    {
      "action": "wait_for_service",
      "description": "Wait for service",
      "params": {
        "service": "radarr",
        "port": 7878
      }
    },
    {
      "action": "extract_api_key",
      "description": "Get API key",
      "params": {
        "service": "radarr",
        "output_var": "RADARR_API_KEY"
      }
    },
    {
      "action": "add_root_folder",
      "description": "Configure root folder",
      "params": {
        "service": "radarr",
        "port": 7878,
        "api_key_var": "RADARR_API_KEY",
        "path": "/data/media/movies",
        "name": "Movies"
      }
    },
    {
      "action": "log_success",
      "description": "Done",
      "params": {
        "message": "Configuration complete!"
      }
    }
  ]
}
```

---

## Adding New Actions

To add a new action:

1. Add a case in `setup-executor.sh`:
   ```bash
   new_action)
       local param1=$(echo "$params" | jq -r '.param1')
       my_function "$param1"
       ;;
   ```

2. Document it in this file

3. Update template setup.json files as needed
