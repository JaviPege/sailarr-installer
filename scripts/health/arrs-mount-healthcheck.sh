#!/bin/bash
# Arr's Mount Healthcheck Script
# Verifies that Radarr and Sonarr can access the rclone mount
# If not, restarts the containers

LOG_FILE="/mediacenter/logs/arrs-mount-healthcheck.log"
TEST_FILE="/data/realdebrid-zurg/torrents/.healthcheck_test.txt"
DOCKER_COMPOSE_DIR="/mediacenter/docker"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_container() {
    local container=$1
    if docker exec "$container" test -f "$TEST_FILE" 2>/dev/null; then
        return 0  # Success
    else
        return 1  # Failed
    fi
}

restart_container() {
    local container=$1
    log "RESTART: $container cannot access mount, restarting..."
    cd "$DOCKER_COMPOSE_DIR" || exit 1
    ./restart.sh "$container" >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        log "SUCCESS: $container restarted successfully"
    else
        log "ERROR: Failed to restart $container"
    fi
}

# Check Radarr
if ! check_container "radarr"; then
    log "FAILED: Radarr cannot access $TEST_FILE"
    restart_container "radarr"
else
    log "OK: Radarr mount check passed"
fi

# Check Sonarr
if ! check_container "sonarr"; then
    log "FAILED: Sonarr cannot access $TEST_FILE"
    restart_container "sonarr"
else
    log "OK: Sonarr mount check passed"
fi

# Check Decypharr
if ! check_container "decypharr"; then
    log "FAILED: Decypharr cannot access $TEST_FILE"
    restart_container "decypharr"
else
    log "OK: Decypharr mount check passed"
fi
