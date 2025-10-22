#!/bin/bash
# Plex Mount Healthcheck Script
# Verifies that Plex can access the rclone mount
# If not, restarts the container

LOG_FILE="/mediacenter/logs/plex-mount-healthcheck.log"
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

# Check Plex
if ! check_container "plex"; then
    log "FAILED: Plex cannot access $TEST_FILE"
    restart_container "plex"
else
    log "OK: Plex mount check passed"
fi
