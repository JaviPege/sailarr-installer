#!/bin/bash
# setup-common.sh - Common utility functions
# Provides basic utilities used across the setup process

# Colors for output
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[0;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_MAGENTA='\033[0;35m'
export COLOR_CYAN='\033[0;36m'
export COLOR_RESET='\033[0m'

# Setup logging
# Only initialize if not already set (allows sharing log dir across scripts)
if [ -z "$SETUP_LOG_DIR" ]; then
    export SETUP_LOG_DIR="/tmp/sailarr-install-$(date +%Y%m%d-%H%M%S)"
fi
export SETUP_LOG_FILE="${SETUP_LOG_DIR}/install.log"
export SETUP_TRACE_FILE="${SETUP_LOG_DIR}/trace.log"

# Initialize logging
init_logging() {
    mkdir -p "${SETUP_LOG_DIR}"
    touch "${SETUP_LOG_FILE}"
    touch "${SETUP_TRACE_FILE}"

    echo "=== Sailarr Installer - Installation Log ===" | tee -a "${SETUP_LOG_FILE}"
    echo "Started at: $(date)" | tee -a "${SETUP_LOG_FILE}"
    echo "Log directory: ${SETUP_LOG_DIR}" | tee -a "${SETUP_LOG_FILE}"
    echo "" | tee -a "${SETUP_LOG_FILE}"

    log_info "Installation logs will be saved to: ${SETUP_LOG_DIR}"
}

# Log to file (without colors)
log_to_file() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "${SETUP_LOG_FILE}"
}

# Function trace logging
log_trace() {
    local func_name=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [TRACE] ${func_name}: ${message}" >> "${SETUP_TRACE_FILE}"
}

# Function entry/exit logging
log_function_enter() {
    local func_name=$1
    shift
    local params="$@"
    log_trace "${func_name}" "ENTER with params: ${params}"
}

log_function_exit() {
    local func_name=$1
    local exit_code=$2
    local output="${3:-}"
    log_trace "${func_name}" "EXIT with code ${exit_code}${output:+, output: ${output}}"
}

# Logging functions (console + file)
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $1" >&2
    log_to_file "INFO" "$1"
}

log_success() {
    echo -e "${COLOR_GREEN}[✓]${COLOR_RESET} $1" >&2
    log_to_file "SUCCESS" "$1"
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $1" >&2
    log_to_file "WARNING" "$1"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1" >&2
    log_to_file "ERROR" "$1"
}

log_debug() {
    echo -e "${COLOR_CYAN}[DEBUG]${COLOR_RESET} $1" >&2
    log_to_file "DEBUG" "$1"
}

log_section() {
    echo "" >&2
    echo "=========================================" >&2
    echo "$1" >&2
    echo "=========================================" >&2
    echo "" >&2
    log_to_file "SECTION" "$1"
}

log_operation() {
    local operation=$1
    shift
    local details="$@"
    echo -e "${COLOR_MAGENTA}[OP]${COLOR_RESET} ${operation}: ${details}" >&2
    log_to_file "OPERATION" "${operation}: ${details}"
}

# Wait for a service to be healthy
wait_for_service() {
    log_function_enter "wait_for_service" "$@"

    local service_name=$1
    local port=$2
    local timeout=${3:-300}  # Default 5 minutes
    local endpoint=${4:-""}

    log_info "Waiting for $service_name to be ready..."
    log_debug "Timeout: ${timeout}s, Port: ${port}, Endpoint: ${endpoint:-none}"

    # Pre-pull curl image if not already present (prevents slow first-run)
    if ! docker images curlimages/curl:latest --format "{{.Repository}}" 2>/dev/null | grep -q "curlimages/curl"; then
        log_trace "wait_for_service" "Pulling curlimages/curl image for network checks..."
        docker pull curlimages/curl:latest >/dev/null 2>&1 || true
    fi

    local elapsed=0
    local interval=5

    while [ $elapsed -lt $timeout ]; do
        log_trace "wait_for_service" "Checking health of $service_name (elapsed: ${elapsed}s)"

        if docker ps --filter "name=$service_name" --filter "health=healthy" --format "{{.Names}}" | grep -q "$service_name"; then
            # Container is healthy, now verify port is actually accessible from Docker network
            log_trace "wait_for_service" "Container healthy, verifying port ${port} is accessible"

            # Use docker exec to curl from inside a container in the same network
            # This tests connectivity as services will experience it
            if docker run --rm --network mediacenter curlimages/curl:latest -sf -o /dev/null --connect-timeout 2 --max-time 5 "http://${service_name}:${port}${endpoint}" 2>/dev/null; then
                log_success "$service_name is healthy and port ${port} is accessible"
                log_function_exit "wait_for_service" 0 "ready after ${elapsed}s"
                return 0
            else
                log_trace "wait_for_service" "Port ${port} not yet accessible from Docker network, waiting..."
            fi
        fi

        sleep $interval
        elapsed=$((elapsed + interval))

        if [ $((elapsed % 30)) -eq 0 ]; then
            log_info "Still waiting for $service_name... (${elapsed}s elapsed)"
        fi
    done

    log_error "$service_name failed to become healthy after ${timeout}s"
    log_function_exit "wait_for_service" 1 "timeout"
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
export -f init_logging
export -f log_to_file
export -f log_trace
export -f log_function_enter
export -f log_function_exit
export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f log_debug
export -f log_section
export -f log_operation
export -f wait_for_service
export -f check_port
export -f retry_command
export -f validate_required
export -f validate_directory
export -f create_directory
