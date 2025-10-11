#!/usr/bin/env bash

# Function to load environment variables from a key-value file
load_env_file() {
    local env_file="$1"
    
    if [[ -z "$env_file" ]]; then
        echo "Error: No file path provided to load_env_file function" >&2
        return 1
    fi
    
    if [[ ! -f "$env_file" ]]; then
        echo "Warning: Environment file not found at $env_file" >&2
        return 1
    fi
    
    echo "INFO: Reading environment file at $env_file"
    while IFS='=' read -r key value; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        # Remove leading/trailing whitespace from key and value
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        # Export the variable
        export "$key"="$value"
    done < "$env_file"
}

# Parse command line arguments for -e path and -s filepath
while [[ $# -gt 0 ]]; do
    case $1 in
        -d)
            DELETE_BIN_DIR="$2"
            shift 2
            ;;
        -e)
            ENV_FILE="$2"
            shift 2
            ;;
        -p)
            FORCE_PULL="$2"
            shift 2
            ;;
        -s)
            SERVER_CONFIG="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Set default ENV_FILE if not provided
ENV_FILE=${ENV_FILE:-~/.icarus/default}

# Set default SERVER_CONFIG if not provided
SERVER_CONFIG=${SERVER_CONFIG:-~/.icarus/server}

# Set default FORCE_PULL if not provided
FORCE_PULL=${FORCE_PULL:-yes}

# Set default FORCE_PULL if not provided
DELETE_BIN_DIR=${DELETE_BIN_DIR:-no}

# Loadd icarus environment file if it exists
if [[ -f "$ENV_FILE" ]]; then
    echo "INFO: Reading environment file at $ENV_FILE"
    load_env_file "$ENV_FILE"
else
    echo "INFO: Environment file not found at $ENV_FILE"
    echo "INFO: We are continuing, but you should create this file to customize server settings."
fi

# Load environment variables for server environment file if it exists
if [[ -f "$SERVER_CONFIG" ]]; then
    echo "INFO: Sourcing server config file at $SERVER_CONFIG"
    load_env_file "$SERVER_CONFIG"
else
    echo "INFO: Server config file not found at $SERVER_CONFIG"
    echo "INFO:  We are continuing, but you should create this file to customize server configuration."
fi

echo "INFO: Using default values for any unset variables. Create the above files to customize settings."

# Define variables with default values if not already set
ADMIN_PASSWORD=${ADMIN_PASSWORD:-"admin"}
ALLOW_NON_ADMINS_DELETE=${ALLOW_NON_ADMINS_DELETE:-False}
ALLOW_NON_ADMINS_LAUNCH=${ALLOW_NON_ADMINS_LAUNCH:-True}
BIN_DIR=${BIN_DIR:-/home/steam/game-servers/icarus-bin}
BRANCH=${BRANCH:-"public"}
CONTAINER_NAME=${CONTAINER_NAME:-"icarus-server"}
CREATE_PROSPECT=${CREATE_PROSPECT:-""}
DATA_PATH=${DATA_PATH:-/home/steam/game-servers/icarus-data}
JOIN_PASSWORD=${JOIN_PASSWORD:-""}
LOAD_PROSPECT=${LOAD_PROSPECT:-""}
MAX_PLAYERS=${MAX_PLAYERS:-8}
PORT=${PORT:-17777}
QUERYPORT=${QUERYPORT:-27015}
RESUME_PROSPECT=${RESUME_PROSPECT:-True}
SERVERNAME=${SERVERNAME:-"Icarus Server"}
SHUTDOWN_EMPTY_FOR=${SHUTDOWN_EMPTY_FOR:--1}
SHUTDOWN_NOT_JOINED_FOR=${SHUTDOWN_NOT_JOINED_FOR:--1}
STEAM_ASYNC_TIMEOUT=${STEAM_ASYNC_TIMEOUT:-60}
STEAM_GROUPID=${STEAM_GROUPID:-$(id -g)}
STEAM_USERID=${STEAM_USERID:-$(id -u)}
HOST_NETWORKING=${HOST_NETWORKING:-true} # Use host networking if true, otherwise use port mapping
RESTART_CONTAINER=${RESTART_CONTAINER:-unless-stopped} # see https://docs.docker.com/reference/cli/docker/container/run/#restart
SAVEGAMEONEXIT=${SAVEGAMEONEXIT:-True} # Whether to force save when the game exits (True/False)
GAMESAVEFREQUENCY=${GAMESAVEFREQUENCY:-600} # How many seconds between each save
FIBERFOLIAGERESPAWN=${FIBERFOLIAGERESPAWN:-True} # Whether to have foliage that was removed respawns over time (True/False) (can help with performance)
LARGESTONERESPAWN=${LARGESTONERESPAWN:-True} # Whether to have large stones that have been mined to respawn over time (True/False) (can help with performance)

# Convert HOST_NETWORKING to lowercase for comparison
HOST_NETWORKING_LOWER=$(echo "${HOST_NETWORKING}" | tr '[:upper:]' '[:lower:]')

# Set network configuration based on HOST_NETWORKING
if [[ "${HOST_NETWORKING_LOWER}" =~ ^(true|1|y|yes)$ ]]; then
    NETWORK_CONFIG="--network host"
else
    NETWORK_CONFIG="-p ${PORT}:${PORT}/udp -p ${QUERYPORT}:${QUERYPORT}/udp"
fi

# Validate required variables
if [[ -z "$DATA_PATH" ]]; then
    echo "Error: DATA_PATH is not set" >&2
    exit 1
fi

if [[ -z "$BIN_DIR" ]]; then
    echo "Error: BIN_DIR is not set" >&2
    exit 1
fi

# Delete BIN_DIR if requested
if [[ "${DELETE_BIN_DIR,,}" =~ ^(true|1|y|yes)$ ]]; then
    echo "INFO: Deleting BIN_DIR: ${BIN_DIR}"
    rm -rf "${BIN_DIR}"
else
    echo "INFO: Keeping existing BIN_DIR: ${BIN_DIR}"
fi

# Ensure necessary directories exist and are writable
mkdir -p "${BIN_DIR}" 2>/dev/null
mkdir -p "${DATA_PATH}" 2>/dev/null

# Check if directories exist
if [[ ! -d "${DATA_PATH}" ]]; then
    echo "Error: DATA_PATH directory does not exist: ${DATA_PATH}" >&2
    exit 1
fi

if [[ ! -d "${BIN_DIR}" ]]; then
    echo "Error: BIN_DIR directory does not exist: ${BIN_DIR}" >&2
    exit 1
fi

# Check write permissions for both directories
if [[ ! -w "${BIN_DIR}" ]]; then
    echo "Error: Cannot write to BIN_DIR: ${BIN_DIR}" >&2
    exit 1
fi

if [[ ! -w "${DATA_PATH}" ]]; then
    echo "Error: Cannot write to DATA_PATH: ${DATA_PATH}" >&2
    exit 1
fi

# Only pull if image doesn't exist locally or if forced
if [[ "${FORCE_PULL,,}" =~ ^(true|1|y|yes)$ ]] || ! docker image inspect nerodon/icarus-dedicated:latest >/dev/null 2>&1; then
    echo "INFO: Pulling latest Docker image..."
    docker pull nerodon/icarus-dedicated:latest
else
    echo "INFO: Using existing Docker image (set FORCE_PULL=true to force update)"
fi
docker stop "${CONTAINER_NAME}" 2>/dev/null
docker rm "${CONTAINER_NAME}" 2>/dev/null

# Run the Docker container
if eval docker run -d \
  ${NETWORK_CONFIG} \
  --restart $RESTART_CONTAINER \
  -v \"${DATA_PATH}\":/home/steam/.wine/drive_c/icarus \
  -v \"${BIN_DIR}\":/game/icarus \
  -e SERVERNAME=\"${SERVERNAME}\" \
  -e PORT=\"${PORT}\" \
  -e QUERYPORT=\"${QUERYPORT}\" \
  -e JOIN_PASSWORD=\"${JOIN_PASSWORD}\" \
  -e MAX_PLAYERS=\"${MAX_PLAYERS}\" \
  -e ADMIN_PASSWORD=\"${ADMIN_PASSWORD}\" \
  -e SHUTDOWN_NOT_JOINED_FOR=\"${SHUTDOWN_NOT_JOINED_FOR}\" \
  -e SHUTDOWN_EMPTY_FOR=\"${SHUTDOWN_EMPTY_FOR}\" \
  -e ALLOW_NON_ADMINS_LAUNCH=\"${ALLOW_NON_ADMINS_LAUNCH}\" \
  -e ALLOW_NON_ADMINS_DELETE=\"${ALLOW_NON_ADMINS_DELETE}\" \
  -e LOAD_PROSPECT=\"${LOAD_PROSPECT}\" \
  -e CREATE_PROSPECT=\"${CREATE_PROSPECT}\" \
  -e RESUME_PROSPECT=\"${RESUME_PROSPECT}\" \
  -e STEAM_USERID=\"${STEAM_USERID}\" \
  -e STEAM_GROUPID=\"${STEAM_GROUPID}\" \
  -e STEAM_ASYNC_TIMEOUT=\"${STEAM_ASYNC_TIMEOUT}\" \
  -e BRANCH=\"${BRANCH}\" \
  -e SAVEGAMEONEXIT=\"${SAVEGAMEONEXIT}\" \
  -e GAMESAVEFREQUENCY=\"${GAMESAVEFREQUENCY}\" \
  -e FIBERFOLIAGERESPAWN=\"${FIBERFOLIAGERESPAWN}\" \
  -e LARGESTONERESPAWN=\"${LARGESTONERESPAWN}\" \
  --name \"${CONTAINER_NAME}\" \
  nerodon/icarus-dedicated:latest; then
    echo "Container ${CONTAINER_NAME} started successfully"
else
    echo "Error: Failed to start container ${CONTAINER_NAME}" >&2
    exit 1
fi