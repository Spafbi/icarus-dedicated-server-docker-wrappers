#!/usr/bin/env bash
# This script checks for updates to the Icarus Dedicated Server on Steam
# and triggers an update of the Docker containers if an update is found.
# It uses a semaphore file to track the last known build ID of the app.

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

# Load variables from environment file if it exists
if [[ -f "$ENV_FILE" ]]; then
    load_env_file "$ENV_FILE"
fi

# Icarus Dedicated Server branch to check for updates. Default is "public", the main branch.
# Alternatively, you may use "experimental" for the experimental branch.
BRANCH=${BRANCH:-public}

# Directory to store semaphore files
SEMAPHORE_AND_LOG_DIR=${SEMAPHORE_AND_LOG_DIR:-/var/tmp}

# Check if SEMAPHORE_AND_LOG_DIR is writable by the current user
if [[ ! -w "$SEMAPHORE_AND_LOG_DIR" ]]; then
    echo "ERROR: Directory ${SEMAPHORE_AND_LOG_DIR} is not writable by the current user." >&2
    exit 1
fi

# Directory where the Icarus update scripts are located
ICARUS_SCRIPTS_DIR=${ICARUS_SCRIPTS_DIR:-/home/steam/icarus-update-check}

# Update script to execute if there's an update. Change this to your actual update script path.
UPDATE_SCRIPT=${UPDATE_SCRIPT:-${ICARUS_SCRIPTS_DIR}/icarus-update-containers.sh}

# Convert branch to lowercase
branch=$(echo "$BRANCH" | tr '[:upper:]' '[:lower:]')

# Log file for output
log_file="${SEMAPHORE_AND_LOG_DIR}/steam_app_2089300_${BRANCH}_check.log"

## Function - check_app_update
# Checks a Steam App's public branch for an update to its buildid.
#
# It works by executing steamcmd's `app_info_print` command, parsing the
# output to find the buildid of the "public" branch, and comparing it to a
# previously stored value in a semaphore file located in /tmp.
#
# @param $1 The numeric app ID to check.
#
# @return 0 if the buildid has not changed or if this is the first check.
# @return 1 if the buildid has changed since the last check.
# @return 2 if the buildid could not be found (corresponds to requested -1).
# @return 3 if the app ID was not provided.
##
check_app_update() {
    # Validate branch value
    if [[ "$branch" != "public" && "$branch" != "experimental" ]]; then
        echo "WARNING: Invalid branch '$1' provided. Using 'public' instead." | tee -a "${log_file}" >&2
        branch="public"
    fi

    local semaphore_file="${SEMAPHORE_AND_LOG_DIR}/steam_app_2089300_${branch}_buildid"
    
    echo "INFO: Fetching data for app 2089300..." | tee -a "${log_file}" >&2

    # Fetch app info and parse the public branch buildid.
    # We pipe to `|| true` to prevent `set -o pipefail` from exiting the script
    # if grep finds no match, allowing us to handle the "not found" case.
    local current_buildid
    current_buildid=$(steamcmd +login anonymous +app_info_print "2089300" +quit | \
        grep -A 2 "\"${branch}\"" | \
        grep -F '"buildid"' | \
        awk '{print $2}' | \
        tr -d '"' || true)

    if [[ -z "${current_buildid}" ]]; then
        echo "ERROR: Could not find public buildid for app 2089300." | tee -a "${log_file}" >&2
        return 2
    fi

    if [[ ! -f "${semaphore_file}" ]]; then
        echo "INFO: First run for app 2089300. Storing buildid ${current_buildid}." | tee -a "${log_file}" >&2
        echo "${current_buildid}" > "${semaphore_file}"
        return 0 # Not changed (first run)
    fi

    local last_buildid
    last_buildid=$(cat "${semaphore_file}")

    if [[ "${current_buildid}" != "${last_buildid}" ]]; then
        echo "INFO: Update detected for app 2089300! New buildid: ${current_buildid} (was ${last_buildid})." | tee -a "${log_file}" >&2
        echo "${current_buildid}" > "${semaphore_file}"
        return 1 # Changed
    else
        echo "INFO: No update for app 2089300. Buildid remains: ${last_buildid}." | tee -a "${log_file}" >&2
        return 0 # Not changed
    fi
}

update_required() {
    # Replace this with the actual command or script to restart/update your Icarus containers or instances
    echo "INFO: Executing update script: ${UPDATE_SCRIPT}" | tee -a "${log_file}"
    eval "${UPDATE_SCRIPT}"
}

# Check for updates
echo "INFO: Checking for Icarus dedicated server update at $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "${log_file}"

# Execute the app update check and take action based on the result
check_app_update
status=$?
case ${status} in
  0) echo "INFO: App not updated." | tee -a "${log_file}" ;;
  1) echo "INFO: App was updated. Update required." | tee -a "${log_file}"
    update_required
    ;;
  2) echo "ERROR: Could not find buildid for app." | tee -a "${log_file}" ;;
  *) echo "ERROR: An unexpected error occurred with status ${status}." | tee -a "${log_file}" ;;
esac