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

# Parse command line arguments for -e path
while [[ $# -gt 0 ]]; do
    case $1 in
        -e)
            ENV_FILE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Set default ENV_FILE if not provided
ENV_FILE=${ENV_FILE:-~/.icarus/default}

# Set default PRESERVE_BIN_DIR if not provided
PRESERVE_BIN_DIR=${PRESERVE_BIN_DIR:-no}

# Load variables from environment file if it exists
if [[ -f "$ENV_FILE" ]]; then
    load_env_file "$ENV_FILE"
fi

# DOCKER_CONTAINER_LIST is a comma-separated list of Docker container names to restart.
DOCKER_CONTAINER_LIST=${DOCKER_CONTAINER_LIST}

# Check if DOCKER_CONTAINER_LIST is defined and not empty
if [[ -z "$DOCKER_CONTAINER_LIST" ]]; then
    echo "ERROR: DOCKER_CONTAINER_LIST is not defined or empty. Please define it as a comma-separated list of container names in ${ENV_FILE}."
    exit 1
fi

# ICARUS_SCRIPTS_DIR is the directory where the game server scripts are located
ICARUS_SCRIPTS_DIR=${ICARUS_SCRIPTS_DIR:-/home/steam/icarus-update-check}

# BIN_DIR is where the Icarus server binaries will be installed by the first container to run.
BIN_DIR=${BIN_DIR:-/home/steam/game-servers/icarus-bin}

# REMOVE_OLD_CONTAINERS controls whether to remove old containers before restarting them.
# Set to true to remove old containers, false to keep them.
# Removing old containers ensures a clean state and applies any changes to the Docker images.
# It also resets Docker logs for the containers.
# If set to false, old containers will be kept, which may retain old state and logs
REMOVE_OLD_CONTAINERS=${REMOVE_OLD_CONTAINERS:-true}

# Timeout in seconds to wait for the success string in logs. Increase this value if you have a slow connection.
TIMEOUT=${TIMEOUT:-600}

####################################################
# Below this line should not need to be changed
####################################################
first_container=true

# Convert the comma-separated list into an array
IFS=',' read -r -a docker_containers <<< "$DOCKER_CONTAINER_LIST"

# Stop all containers before restarting them
docker stop "${docker_containers[@]}" 2>/dev/null

# Check if any containers are still running and exit if so
for container in "${docker_containers[@]}"; do
    if docker ps --format "table {{.Names}}" | grep -q "^${container}$"; then
        echo "ERROR: Container ${container} is still running. Exiting."
        exit 1
    fi
done

# Remove old containers if configured to do so
if [[ "${REMOVE_OLD_CONTAINERS,,}" =~ ^(true|1|y|yes)$ ]] ; then
    echo "INFO: Removing old containers before restart."
    docker rm "${docker_containers[@]}" 2>/dev/null
else
    echo "INFO: Keeping old containers. If you want to remove them, set REMOVE_OLD_CONTAINERS to true."
fi

# Loop through each container, restart it, and watch its logs for the success string
for i in "${!docker_containers[@]}"; do
    container="${docker_containers[i]}"
    echo "INFO: Restarting Docker container: ${container}..."
    
    # If this is the first container being processed, delete and recreate the BIN_DIR to ensure a fresh install
    if [[ "${first_container,,}" =~ ^(true|1|y|yes)$ ]] ; then
        # Check if PRESERVE_BIN_DIR is set to preserve the binary directory
        if [[ "${PRESERVE_BIN_DIR,,}" =~ ^(true|1|y|yes)$ ]]; then
            delete_bin_dir=no
        else
            delete_bin_dir=yes
        fi
        force_pull=yes
    else
        delete_bin_dir=no
        force_pull=no
    fi

    ##### BEGIN CONTAINER START COMMAND BLOCK #####
    # This uses icarus-common.sh.sh to start the container, but you can modify this to use your own script if needed.
    ${ICARUS_SCRIPTS_DIR}/icarus-common.sh -e $ENV_FILE -s ~/.icarus/${container} -p $force_pull -d $delete_bin_dir
    ##### END CONTAINER START COMMAND BLOCK #####

    # Now watch the logs for the success string or timeout
    echo "INFO: Watching for 'Success! App '2089300' fully installed' in logs for ${container}..."
    while true; do
        # Use timeout with docker logs --follow for more efficient monitoring
        if timeout "${TIMEOUT}" docker logs --follow "${container}" 2>&1 | grep -q "Success! App '2089300' fully installed"; then
            echo "INFO: Success string found for ${container}. Continuing..."
            if [[ "${first_container,,}" =~ ^(true|1|y|yes)$ ]] ; then
                first_container=false
                echo "INFO: Icarus server binaries should now be installed in ${BIN_DIR}."
            fi
            break
        else
            echo "WARN: Timeout or error - Success string not found within ${TIMEOUT} seconds for ${container}."
        fi
    done
done
echo "INFO: All specified containers have been processed."