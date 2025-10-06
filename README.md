# Icarus Dedicated Server Management Scripts

A collection of Bash scripts for managing Icarus Dedicated Server Docker containers with automatic update detection and container lifecycle management.

## Overview

This project provides three main scripts that work together to automate the deployment, monitoring, and updating of Icarus Dedicated Server instances using Docker containers:

- **`icarus-common.sh`** - Core script for deploying and running Icarus server containers
- **`icarus-update-check.sh`** - Monitors Steam for Icarus server updates and triggers container updates
- **`icarus-update-containers.sh`** - Handles the restart and update process for multiple server containers

## Features

- 🚀 **Automated Deployment** - Easy setup and configuration of Icarus dedicated servers
- 🔄 **Update Detection** - Monitors Steam for game updates using SteamCMD
- 🐳 **Docker Integration** - Full Docker container lifecycle management
- 🔧 **Flexible Configuration** - Environment-based configuration with sensible defaults
- 📊 **Multi-Server Support** - Manage multiple server instances simultaneously
- � **Safe Updates** - Performs fresh server binary installs while preserving game saves and world data
- 🗂️ **Shared Binary Storage** - Defaults to a single binary installation directory saving disk space and reducing download time and bandwidth utilization.
- �🛡️ **Robust Error Handling** - (Fairly) Comprehensive validation and error checking
- 📝 **Not Terrible Logging** - Logging for monitoring and debugging - yeah, it could be better

## Prerequisites

- Linux system (tested on Ubuntu/Debian)
- Docker
- Bash 4.0 or later
- Write permissions to configured directories

**Important**: These scripts run the game server as a non-root user for security. It is assumed that a "steam" user will be used and that these scripts will be run by the steam user. Please update all paths in the examples to reflect your actual user's home directory and desired locations (e.g., replace `/home/steam/` with `/home/yourusername/` if using a different user).

## Quick Start
NOTE: You will really want to edit the configuration files
1. **Clone the repository**:
   ```bash
   cd ~ # This changes to the current user's home directory
   git clone https://github.com/Spafbi/icarus-dedicated-server-docker-wrappers.git
   cd icarus-update-check
   ```

2. **Make scripts executable**:
   ```bash
   chmod +x *.sh
   ```

3. **Create configuration and game-server directories**:
   ```bash
   mkdir -p ~/.icarus
   mkdir -p  ~/game-servers
   ```

4. **Create shared basic configuration** (see [Configuration](#configuration) section for details):
   ```bash
   cat > ~/.icarus/default << 'EOF'
   BIN_DIR=/home/steam/game-servers/icarus-bin
   DOCKER_CONTAINER_LIST=icarus-main
   ICARUS_SCRIPTS_DIR=/home/steam/icarus-update-check
   UPDATE_SCRIPT=/home/steam/icarus-update-check/icarus-update-containers.sh
   EOF
   ```

5. **Create server-specific configuration and overrides** (see [Configuration](#configuration) section for details):
   ```bash
   cat > ~/.icarus/icarus-main << 'EOF'
   ADMIN_PASSWORD="AdminPassword"
   CONTAINER_NAME=icarus-main
   DATA_PATH=/home/steam/game-servers/icarus-main
   JOIN_PASSWORD="PlayersJoinPassword"
   PORT=17779
   QUERYPORT=27017
   SERVERNAME="Your Icarus Server Name"
   EOF
   ```

6. **Deploy your first server**:
   ```bash
   ./icarus-common.sh -s ~/.icarus/icarus-main
   ```

7. **Set up automatic update checking** (optional):
   ```bash
   # Add to crontab to check for updates every hour
   echo "0 * * * * /path/to/icarus-update-check.sh" | crontab -
   ```

## Scripts Documentation

### icarus-common.sh

The core deployment script that handles the setup and running of individual Icarus server containers.

**Usage:**
```bash
./icarus-common.sh [-d DELETE_BIN_DIR] [-e ENV_FILE] [-p FORCE_PULL] [-s SERVER_CONFIG]
```

**Parameters:**
- `-d DELETE_BIN_DIR`: Whether to delete the binary directory before deployment (default: `no`)
- `-e ENV_FILE`: Path to environment configuration file (default: `~/.icarus/default`)
- `-p FORCE_PULL`: Whether or not to force a pull of Nerodon's Docker image (default: `yes`)
- `-s SERVER_CONFIG`: Path to server-specific configuration file (default: `~/.icarus/server`)

**Key Features:**
- Pulls the latest `nerodon/icarus-dedicated` Docker image
- Configures networking (host networking or port mapping)
- Sets up persistent data and binary directories
- Handles container lifecycle (stop, remove, create, start)
- Validates directory permissions and requirements

### icarus-update-check.sh

Monitors Steam for Icarus Dedicated Server updates and triggers container updates when detected.

**Usage:**
```bash
./icarus-update-check.sh [-e ENV_FILE]
```

**Parameters:**
- `-e ENV_FILE`: Path to environment configuration file (default: `~/.icarus/default`)

**Key Features:**
- Uses SteamCMD to check for buildid changes
- Supports both `public` and `experimental` branches
- Maintains semaphore files to track last known build versions
- Comprehensive logging of update check results
- Automatic execution of update script when updates are detected

**Return Codes:**
- `0`: No update detected (or first run)
- `1`: Update detected, update script executed
- `2`: Error - could not retrieve buildid
- `3`: Error - invalid parameters

### icarus-update-containers.sh

Handles the coordinated restart and update process for multiple Icarus server containers.

**Usage:**
```bash
./icarus-update-containers.sh [-e ENV_FILE]
```

**Parameters:**
- `-e ENV_FILE`: Path to environment configuration file (default: `~/.icarus/default`)

**Key Features:**
- Manages multiple containers simultaneously
- Ensures clean binary installation for the first container
- Monitors container logs for successful startup
- Configurable timeout for startup validation
- Optional removal of old containers for clean state

## Configuration

### Environment Files

The scripts use two types of configuration files:

#### Default Configuration (`~/.icarus/default`)
Update these to your desired values. Contains global settings shared across all servers:

```bash
# Server Identity
SERVERNAME=My Icarus Server
ADMIN_PASSWORD=secure_admin_password
JOIN_PASSWORD=optional_join_password

# Capacity and Networking
MAX_PLAYERS=8
PORT=17777
QUERYPORT=27015
HOST_NETWORKING=true

# Directories
BIN_DIR=/home/steam/game-servers/icarus-bin

# Update Management
BRANCH=public
UPDATE_SCRIPT=/home/steam/icarus-update-check/icarus-update-containers.sh
DOCKER_CONTAINER_LIST=icarus-main,icarus-experimental,icarus-private

# Behavioral Settings
SHUTDOWN_EMPTY_FOR=-1
SHUTDOWN_NOT_JOINED_FOR=-1
ALLOW_NON_ADMINS_LAUNCH=True
ALLOW_NON_ADMINS_DELETE=False
RESUME_PROSPECT=True
```

#### Server-Specific Configuration (`~/.icarus/server` or `~/.icarus/container-name`)
Override settings for individual servers:

```bash
# Server-specific overrides
DATA_PATH=/home/steam/game-servers/icarus-data
JOIN_PASSWORD="server2_password"
PORT=17778
QUERYPORT=27016
SERVERNAME="Icarus Server #2"
```

### Configuration Variables

#### Core Server Settings
- **SERVERNAME**: Display name for the server
- **ADMIN_PASSWORD**: Administrator password (required)
- **JOIN_PASSWORD**: Password required to join server (optional)
- **MAX_PLAYERS**: Maximum number of concurrent players (1-8)
- **PORT**: Game server port (default: 17777)
- **QUERYPORT**: Query port for server browser (default: 27015)

#### Directory Configuration
- **DATA_PATH**: Directory for persistent server data (each server must have its own unique data path)
- **BIN_DIR**: Directory for Icarus server binaries
- **SEMAPHORE_AND_LOG_DIR**: Directory for update tracking and logs (default: /var/tmp)

**Note**: Avoid using directory paths with spaces or non-alphanumeric characters, as these scripts have not been tested with such paths and may break. Additionally, `DATA_PATH` and `BIN_DIR` should never be the same directory.

#### Network Configuration
- **HOST_NETWORKING**: Use host networking (true) or port mapping (false)
- **RESTART_CONTAINER**: Docker restart policy (default: unless-stopped)

#### Game Behavior
- **BRANCH**: Steam branch to use (public/experimental)
- **SHUTDOWN_EMPTY_FOR**: Auto-shutdown after empty time in seconds (-1 = disabled)
- **SHUTDOWN_NOT_JOINED_FOR**: Auto-shutdown if no one joins in seconds (-1 = disabled)
- **ALLOW_NON_ADMINS_LAUNCH**: Allow non-admins to start prospects
- **ALLOW_NON_ADMINS_DELETE**: Allow non-admins to delete prospects
- **RESUME_PROSPECT**: Automatically resume the last prospect on startup

#### Update Management
- **UPDATE_SCRIPT**: Path to the update script (for icarus-update-check.sh)
- **DOCKER_CONTAINER_LIST**: Comma-separated list of containers to manage (container names must match their configuration file names)
- **REMOVE_OLD_CONTAINERS**: Remove containers before restart (true/false)
- **TIMEOUT**: Timeout in seconds for startup validation (default: 600)

#### Advanced Settings
- **STEAM_USERID**: User ID for file ownership (default: current user)
- **STEAM_GROUPID**: Group ID for file ownership (default: current group)
- **STEAM_ASYNC_TIMEOUT**: Steam operation timeout in seconds

## Multi-Server Setup

**Important**: For each server managed by these scripts, the Docker container names and their respective server-specific configuration files must have matching names. This ensures proper association between containers and their configurations.

**Naming Convention Examples**:
- Container: `icarus-main` ↔ Config file: `~/.icarus/icarus-main`
- Container: `icarus-experimental` ↔ Config file: `~/.icarus/icarus-experimental`  
- Container: `icarus-private` ↔ Config file: `~/.icarus/icarus-private`

To run multiple Icarus servers:

1. **Configure container list**:
   ```bash
   # In ~/.icarus/default
   DOCKER_CONTAINER_LIST=icarus-main,icarus-experimental,icarus-private
   ```

2. **Create server-specific configs** (each server must have unique ports and data paths):
   ```bash
   # ~/.icarus/icarus-main
   SERVERNAME="Main Server"
   DATA_PATH=/home/steam/game-servers/icarus-main
   PORT=17777
   QUERYPORT=27015
   
   # ~/.icarus/icarus-experimental  
   SERVERNAME="Experimental Server"
   DATA_PATH=/home/steam/game-servers/icarus-experimental
   PORT=17778
   QUERYPORT=27016
   BRANCH=experimental
   
   # ~/.icarus/icarus-private
   SERVERNAME="Private Server"
   DATA_PATH=/home/steam/game-servers/icarus-private
   PORT=17779
   QUERYPORT=27017
   JOIN_PASSWORD="private123"
   ```

3. **Deploy servers individually**:
   ```bash
   ./icarus-common.sh -s ~/.icarus/icarus-main
   ./icarus-common.sh -s ~/.icarus/icarus-experimental
   ./icarus-common.sh -s ~/.icarus/icarus-private
   ```

## Automation Setup

### Cron Job for Update Checking

Add to your crontab to automatically check for updates:

```bash
# Check for updates every hour
0 * * * * /path/to/icarus-update-check.sh >/dev/null 2>&1

# Check for updates every 30 minutes with logging
*/30 * * * * /path/to/icarus-update-check.sh >> /var/log/icarus-updates.log 2>&1
```

### Systemd Timer (Alternative)

Create a systemd timer to run update checks every 15 minutes:

**Timer unit** (`/etc/systemd/system/icarus-update-check.timer`):
```ini
[Unit]
Description=Icarus Update Check Timer
Requires=icarus-update-check.service

[Timer]
OnCalendar=*:0/15
Persistent=true

[Install]
WantedBy=timers.target
```

**Service unit** (`/etc/systemd/system/icarus-update-check.service`):
```ini
[Unit]
Description=Icarus Update Check
After=docker.service

[Service]
Type=oneshot
ExecStart=/home/steam/icarus-update-check/icarus-update-check.sh
User=steam
```

**Enable and start the timer**:
```bash
sudo systemctl daemon-reload
sudo systemctl enable icarus-update-check.timer
sudo systemctl start icarus-update-check.timer

# Check timer status
sudo systemctl status icarus-update-check.timer
sudo systemctl list-timers icarus-update-check.timer
```

## Monitoring and Logging

### Log Files
- **Update checks**: `${SEMAPHORE_AND_LOG_DIR}/steam_app_2089300_${BRANCH}_check.log`
- **Container logs**: `docker logs <container-name>`
- **Semaphore files**: `${SEMAPHORE_AND_LOG_DIR}/steam_app_2089300_${BRANCH}_buildid`

### Monitoring Commands

```bash
# Check container status
docker ps --filter "name=icarus"

# View recent update check logs
tail -f /var/tmp/steam_app_2089300_public_check.log

# Monitor container logs
docker logs -f icarus-server

# Check for updates manually
./icarus-update-check.sh

# Force container restart
./icarus-update-containers.sh
```

## Troubleshooting

### Common Issues

**1. Permission Denied Errors**
```bash
# Ensure directories have correct permissions
sudo chown -R $(id -u):$(id -g) $DATA_PATH $BIN_DIR
chmod -R 755 $DATA_PATH $BIN_DIR
```

**2. Docker Container Won't Start**
```bash
# Check Docker logs
docker logs icarus-server

# Verify network ports aren't in use
netstat -tulpn | grep -E "(17777|27015)"

# Check Docker image
docker pull nerodon/icarus-dedicated:latest
```

**3. SteamCMD Issues**
```bash
# Verify SteamCMD installation
which steamcmd
steamcmd +login anonymous +quit

# Check Steam API connectivity
curl -s "https://api.steampowered.com/ISteamApps/GetAppList/v2/" | grep -i icarus
```

**4. Update Detection Not Working**
```bash
# Check semaphore file permissions
ls -la /var/tmp/steam_app_2089300_*

# Manual update check with verbose output
bash -x ./icarus-update-check.sh
```

### Debug Mode

Run any script with debug output:
```bash
bash -x ./icarus-common.sh
```

### Configuration Validation

Verify your configuration:
```bash
# Test configuration loading
source ~/.icarus/default && env | grep -E "(SERVERNAME|DATA_PATH|BIN_DIR)"
```

## Security Considerations

- **Strong Passwords**: Use secure passwords for `ADMIN_PASSWORD` and `JOIN_PASSWORD`
- **File Permissions**: Ensure configuration files have restricted permissions (600)
- **Network Security**: Consider firewall rules for exposed ports
- **Container Security**: Regularly update the Docker image
- **Log Security**: Protect log files containing potentially sensitive information

```bash
# Secure configuration files
chmod 600 ~/.icarus/*
```

## Performance Optimization

### System Requirements
- **CPU**: 2+ cores recommended per server instance
- **RAM**: 4GB+ per server instance
- **Storage**: Fast SSD recommended for game data
- **Network**: Stable connection with adequate bandwidth

### Optimization Tips
- Use host networking for better performance
- Mount game directories on fast storage
- Monitor resource usage with `htop` (or, even better, `btop`!) and `docker stats`
- Consider container resource limits for multi-server setups

## Special Thanks

**🙏 Special thanks to [Nerodon](https://hub.docker.com/u/nerodon) for creating and maintaining the excellent [`nerodon/icarus-dedicated`](https://hub.docker.com/r/nerodon/icarus-dedicated) Docker container image!**

This project wouldn't be possible without Nerodon's outstanding work on the Icarus Dedicated Server Docker container. The container handles all the complex aspects of running the Icarus server, including:

- Automated SteamCMD integration for server binary downloads
- Proper Wine configuration for running Windows binaries on Linux
- Seamless file permission management between host and container
- Robust startup and shutdown procedures
- Support for all Icarus server configuration options

Nerodon's container makes deploying and managing Icarus servers incredibly straightforward and reliable. Be sure to check out the [official container documentation](https://hub.docker.com/r/nerodon/icarus-dedicated) for additional configuration options and updates.

## License

This project is provided as-is under the MIT License. See individual script headers for specific licensing information.

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request with clear documentation

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review container and script logs
3. Open an issue with detailed information about your setup and the problem

## Version History

- **v1.0**: Initial release with basic functionality
- Current version includes comprehensive error handling and multi-server support

---

**Note**: This project is not officially affiliated with Icarus or RocketWerkz. It's a community-created tool for server management.
