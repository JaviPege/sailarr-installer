#!/bin/bash
# setup-common.sh - Common utility functions
# Provides basic utilities used across the setup process

# Colors for output
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[0;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_RESET='\033[0m'

# Logging functions
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $1"
}

log_success() {
    echo -e "${COLOR_GREEN}[✓]${COLOR_RESET} $1"
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $1"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1"
}

log_section() {
    echo ""
    echo "========================================="
    echo "$1"
    echo "========================================="
    echo ""
}

# Wait for a service to be healthy
wait_for_service() {
    local service_name=$1
    local port=$2
    local timeout=${3:-300}  # Default 5 minutes
    local endpoint=${4:-""}

    log_info "Waiting for $service_name to be ready..."

    local elapsed=0
    local interval=5

    while [ $elapsed -lt $timeout ]; do
        if docker ps --filter "name=$service_name" --filter "health=healthy" --format "{{.Names}}" | grep -q "$service_name"; then
            log_success "$service_name is healthy"
            return 0
        fi

        sleep $interval
        elapsed=$((elapsed + interval))

        if [ $((elapsed % 30)) -eq 0 ]; then
            log_info "Still waiting for $service_name... (${elapsed}s elapsed)"
        fi
    done

    log_error "$service_name failed to become healthy after ${timeout}s"
    return 1
}

# Check if a port is listening
check_port() {
    local port=$1
    netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "
}

# Retry a command with exponential backoff
retry_command() {
    local max_attempts=$1
    shift
    local command="$@"
    local attempt=1
    local delay=2

    while [ $attempt -le $max_attempts ]; do
        if eval "$command"; then
            return 0
        fi

        if [ $attempt -lt $max_attempts ]; then
            log_warning "Command failed (attempt $attempt/$max_attempts). Retrying in ${delay}s..."
            sleep $delay
            delay=$((delay * 2))  # Exponential backoff
        fi

        attempt=$((attempt + 1))
    done

    log_error "Command failed after $max_attempts attempts"
    return 1
}

# Validate that a variable is not empty
validate_required() {
    local var_name=$1
    local var_value=$2

    if [ -z "$var_value" ]; then
        log_error "$var_name is required but not set"
        return 1
    fi
    return 0
}

# Validate directory exists
validate_directory() {
    local dir=$1

    if [ ! -d "$dir" ]; then
        log_error "Directory does not exist: $dir"
        return 1
    fi
    return 0
}

# Create directory with proper permissions
create_directory() {
    local dir=$1
    local owner=$2
    local mode=${3:-755}

    if [ ! -d "$dir" ]; then
        sudo mkdir -p "$dir"
        if [ -n "$owner" ]; then
            sudo chown "$owner" "$dir"
        fi
        sudo chmod "$mode" "$dir"
        log_success "Created directory: $dir"
    fi
}

# Export functions
export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f log_section
export -f wait_for_service
export -f check_port
export -f retry_command
export -f validate_required
export -f validate_directory
export -f create_directory
