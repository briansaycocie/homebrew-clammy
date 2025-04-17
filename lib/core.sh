#!/bin/bash
#================================================================
# 🧰 Clammy Core Library
#================================================================
# Core functions for Clammy
# This file should be sourced by all other scripts
#================================================================

# Initialize critical variables with default values to prevent "unbound variable" errors
DEBUG=${DEBUG:-false}
VERBOSE=${VERBOSE:-false}
QUIET_MODE=${QUIET_MODE:-false}

# Default path for log file - will be overridden by configuration
HOME=${HOME:-$(eval echo ~${SUDO_USER:-$USER})}
SECURITY_DIR="${HOME}/Security"
LOG_DIR="${SECURITY_DIR}/logs"
QUARANTINE_DIR="${SECURITY_DIR}/quarantine"
LOGFILE="${LOG_DIR}/clammy.log"

# Get the absolute path to the script's directory
if [ -z "${SCRIPT_DIR:-}" ]; then
  # Determine script location for proper relative paths
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  # Set root directory (one level up from lib)
  CLAMAV_TAP_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
  
  # Debug output
  echo "DEBUG: SCRIPT_DIR=$SCRIPT_DIR" >&2
USER_CONFIG="${HOME}/.config/clammy.conf"
  
  # Export these variables for use by other scripts
  export SCRIPT_DIR CLAMAV_TAP_ROOT
fi

# Override CLAMAV_TAP_ROOT for debugging if it's not set correctly
if [ -z "$CLAMAV_TAP_ROOT" ] || [ ! -d "$CLAMAV_TAP_ROOT" ]; then
  # Try to determine based on current working directory
  if [[ "$PWD" == */clammy* ]]; then
    # We're somewhere in Clammy directory structure
    CLAMAV_TAP_ROOT=$(echo "$PWD" | sed 's/\(.*clammy\).*/\1/')
    echo "DEBUG: Reset CLAMAV_TAP_ROOT based on PWD to $CLAMAV_TAP_ROOT" >&2
  fi
fi

#----------- Configuration Management -----------#

# Load configuration from multiple sources with precedence
# Usage: load_config
load_config() {
  # Special case for debug function since we need it before formal initialization
  if [ "${DEBUG:-false}" = "true" ]; then
    echo "[DEBUG] Loading configuration..." >&2
  fi
  
  # Default configuration file paths
  local config_dir=""
  
  # Try multiple approaches to locate the config directory
  if [ -n "$CLAMAV_TAP_ROOT" ] && [ -d "$CLAMAV_TAP_ROOT" ]; then
    config_dir="${CLAMAV_TAP_ROOT}/config"
    echo "DEBUG: Using config_dir from CLAMAV_TAP_ROOT: $config_dir" >&2
  elif [ -d "$SCRIPT_DIR/../config" ]; then
    config_dir="$SCRIPT_DIR/../config"
    echo "DEBUG: Using config_dir relative to SCRIPT_DIR: $config_dir" >&2
  elif [ -d "./config" ]; then
    config_dir="./config"
    echo "DEBUG: Using config_dir in current directory: $config_dir" >&2
  elif [ -d "/Users/brian/Development/scripts/clammy/config" ]; then
    config_dir="/Users/brian/Development/scripts/clammy/config"
    echo "DEBUG: Using hardcoded config_dir path: $config_dir" >&2
  else
    # Last resort: create in current directory
    config_dir="./config"
    echo "DEBUG: Using fallback config_dir in current directory: $config_dir" >&2
  fi
  
  local default_conf="${config_dir}/default.conf"
  echo "DEBUG: default_conf path: $default_conf" >&2
  
  # Make sure config directory exists
  if [ ! -d "$config_dir" ]; then
    echo "Creating config directory: $config_dir" >&2
    mkdir -p "$config_dir" 2>/dev/null || {
      echo "Error: Failed to create config directory: $config_dir" >&2
      exit 1
    }
  fi
  
  # Check if we need to copy default.conf from the original location
  if [ ! -f "$default_conf" ] && [ -f "${CLAMAV_TAP_ROOT}/default.conf" ]; then
    echo "Moving default.conf to proper location..." >&2
    cp "${CLAMAV_TAP_ROOT}/default.conf" "$default_conf" 2>/dev/null || {
      echo "Error: Failed to copy default.conf to $default_conf" >&2
      exit 1
    }
  fi
  
  echo "DEBUG: Looking for config at $default_conf" >&2
  
  # System and user configuration files
  local system_conf="/etc/clammy.conf"
  local user_conf="$HOME/.config/clammy.conf"
  local local_conf="./clammy.conf"
  
  # Load default configuration first
  if [ -f "$default_conf" ]; then
    debug "Loading default configuration: $default_conf"
    source "$default_conf"
  else
    echo "Error: Default configuration not found at $default_conf" >&2
    echo "CLAMAV_TAP_ROOT=$CLAMAV_TAP_ROOT" >&2
    echo "Current directory: $(pwd)" >&2
    
    # Create a minimal default config if none exists
    cat > "$default_conf" << EOF
#!/bin/bash
#================================================================
# 🔧 ClamAV Scanner Configuration File (Minimal)
#================================================================

#----------- Path Configuration -----------#
SECURITY_DIR="\${HOME}/Security"
LOG_DIR="\${SECURITY_DIR}/logs"
QUARANTINE_DIR="\${SECURITY_DIR}/quarantine"
LOGFILE="\${LOG_DIR}/clammy.log"

#----------- Scan Settings -----------#
MAX_FILE_SIZE=500
MIN_FREE_SPACE=1024
QUARANTINE_ENABLED=true
GENERATE_HTML_REPORT=true
OPEN_REPORT_AUTOMATICALLY=false
QUARANTINE_MAX_AGE=90
EOF
    
    echo "Created minimal default configuration at $default_conf" >&2
    if [ ! -f "$default_conf" ]; then
      echo "Error: Failed to create minimal configuration file" >&2
      exit 1
    fi
  fi
  
  # Load system-wide configuration if it exists
  if [ -f "$system_conf" ]; then
    debug "Loading system configuration: $system_conf"
    source "$system_conf"
  fi
  
  # Load user-specific configuration if it exists
  if [ -f "$user_conf" ]; then
    debug "Loading user configuration: $user_conf"
    source "$user_conf"
  fi
  
  # Load local configuration if it exists
  if [ -f "$local_conf" ]; then
    debug "Loading local configuration: $local_conf"
    source "$local_conf"
  fi
  
  # Load any environment variables that override configuration
  apply_environment_overrides
  
  # Validate the configuration
  validate_config
  
  debug "Configuration loaded successfully"
}

# Apply environment variable overrides to configuration
# Usage: apply_environment_overrides
apply_environment_overrides() {
  debug "Applying environment variable overrides..."
  
  # Path overrides
  [ -n "${CLAMAV_SECURITY_DIR:-}" ] && SECURITY_DIR="$CLAMAV_SECURITY_DIR"
  [ -n "${CLAMAV_LOG_DIR:-}" ] && LOG_DIR="$CLAMAV_LOG_DIR"
  [ -n "${CLAMAV_QUARANTINE_DIR:-}" ] && QUARANTINE_DIR="$CLAMAV_QUARANTINE_DIR"
  [ -n "${CLAMAV_LOGFILE:-}" ] && LOGFILE="$CLAMAV_LOGFILE"
  [ -n "${CLAMAV_DB_DIR:-}" ] && DEFAULT_CLAMAV_DB_DIR="$CLAMAV_DB_DIR"
  
  # Scan setting overrides
  [ -n "${CLAMAV_MAX_FILE_SIZE:-}" ] && MAX_FILE_SIZE="$CLAMAV_MAX_FILE_SIZE"
  [ -n "${CLAMAV_MIN_FREE_SPACE:-}" ] && MIN_FREE_SPACE="$CLAMAV_MIN_FREE_SPACE"
  
  # Quarantine setting overrides
  [ -n "${CLAMAV_QUARANTINE_ENABLED:-}" ] && QUARANTINE_ENABLED="$CLAMAV_QUARANTINE_ENABLED"
  [ -n "${CLAMAV_QUARANTINE_MAX_AGE:-}" ] && QUARANTINE_MAX_AGE="$CLAMAV_QUARANTINE_MAX_AGE"
  
  # Display setting overrides
  [ -n "${VERBOSE:-}" ] && VERBOSE="true"
  [ -n "${DEBUG:-}" ] && VERBOSE="true" && DEBUG="true"
  [ -n "${QUIET_MODE:-}" ] && QUIET_MODE="true"
}

# Validate configuration settings
# Usage: validate_config
validate_config() {
  debug "Validating configuration..."
  
  # Check for critical configuration values
  local missing_configs=()
  
  # Check required directories
  [ -z "${SECURITY_DIR:-}" ] && missing_configs+=("SECURITY_DIR")
  [ -z "${LOG_DIR:-}" ] && missing_configs+=("LOG_DIR")
  [ -z "${QUARANTINE_DIR:-}" ] && missing_configs+=("QUARANTINE_DIR")
  [ -z "${LOGFILE:-}" ] && missing_configs+=("LOGFILE")
  
  # Check required scan settings
  [ -z "${MAX_FILE_SIZE:-}" ] && missing_configs+=("MAX_FILE_SIZE")
  [ -z "${MIN_FREE_SPACE:-}" ] && missing_configs+=("MIN_FREE_SPACE")
  
  # Report missing configurations
  if [ ${#missing_configs[@]} -gt 0 ]; then
    echo "Error: Missing required configuration values:" >&2
    for config in "${missing_configs[@]}"; do
      echo "  - $config" >&2
    done
    exit 1
  fi
  
  # Validate numeric values
  if ! [[ "${MAX_FILE_SIZE:-0}" =~ ^[0-9]+$ ]]; then
    echo "Error: MAX_FILE_SIZE must be a valid number" >&2
    exit 1
  fi
  
  if ! [[ "${MIN_FREE_SPACE:-0}" =~ ^[0-9]+$ ]]; then
    echo "Error: MIN_FREE_SPACE must be a valid number" >&2
    exit 1
  fi
  
  debug "Configuration validation completed"
}

#----------- OS Detection and System Paths -----------#

# Detect OS and set system paths accordingly
# Usage: detect_os_paths
detect_os_paths() {
  debug "Detecting OS and system paths..."
  
  # Detect operating system
  OS_TYPE="$(uname)"
  debug "Detected OS: $OS_TYPE"
  
  # Set system-specific paths based on OS
  case "$OS_TYPE" in
    Darwin)
      debug "Setting up paths for macOS"
      SYS_VOLUMES_DATA_PATH="${SYS_VOLUMES_DATA_PATH:-/System/Volumes/Data}"
      SYS_PRIVATE_PATH="${SYS_PRIVATE_PATH:-/private}"
      SYS_PRIVATE_VAR_PATH="${SYS_PRIVATE_VAR_PATH:-/private/var}"
      SYS_DATA_PRIVATE_PATH="${SYS_DATA_PRIVATE_PATH:-/System/Volumes/Data/private}"
      SYS_DATA_PRIVATE_VAR_PATH="${SYS_DATA_PRIVATE_VAR_PATH:-/System/Volumes/Data/private/var}"
      SYS_VAR_DB_PATH="${SYS_VAR_DB_PATH:-/System/Volumes/Data/private/var/db}"
      SYS_VAR_FOLDERS_PATH="${SYS_VAR_FOLDERS_PATH:-/private/var/folders}"
      SYS_VAR_VM_PATH="${SYS_VAR_VM_PATH:-/System/Volumes/Data/private/var/vm}"
      SYS_LIBRARY_PATH="${SYS_LIBRARY_PATH:-/System/Library}"
      APP_SUPPORT_PATH="${APP_SUPPORT_PATH:-/Library/Application Support/Apple}"
      LIBRARY_CACHE_PATH="${LIBRARY_CACHE_PATH:-/Library/Caches}"
      LIBRARY_LOGS_PATH="${LIBRARY_LOGS_PATH:-/Library/Logs}"
      
      # Check for Homebrew paths
      if [ -d "/opt/homebrew/bin" ]; then
        HOMEBREW_PREFIX="/opt/homebrew"  # Apple Silicon
      elif [ -d "/usr/local/bin" ]; then
        HOMEBREW_PREFIX="/usr/local"     # Intel Mac
      fi
      
      # Set ClamAV paths based on Homebrew location
      if [ -n "${HOMEBREW_PREFIX:-}" ]; then
        DEFAULT_CLAMAV_DB_DIR="${DEFAULT_CLAMAV_DB_DIR:-$HOMEBREW_PREFIX/var/lib/clamav}"
        DEFAULT_CLAMAV_BIN_DIR="${DEFAULT_CLAMAV_BIN_DIR:-$HOMEBREW_PREFIX/bin}"
      else
        DEFAULT_CLAMAV_DB_DIR="${DEFAULT_CLAMAV_DB_DIR:-/opt/homebrew/var/lib/clamav}"
        DEFAULT_CLAMAV_BIN_DIR="${DEFAULT_CLAMAV_BIN_DIR:-/opt/homebrew/bin}"
      fi
      ;;
      
    Linux)
      debug "Setting up paths for Linux"
      SYS_VOLUMES_DATA_PATH="${SYS_VOLUMES_DATA_PATH:-}"
      SYS_PRIVATE_PATH="${SYS_PRIVATE_PATH:-/private}"
      SYS_PRIVATE_VAR_PATH="${SYS_PRIVATE_VAR_PATH:-/var}"
      SYS_DATA_PRIVATE_PATH="${SYS_DATA_PRIVATE_PATH:-/private}"
      SYS_DATA_PRIVATE_VAR_PATH="${SYS_DATA_PRIVATE_VAR_PATH:-/var}"
      SYS_VAR_DB_PATH="${SYS_VAR_DB_PATH:-/var/db}"
      SYS_VAR_FOLDERS_PATH="${SYS_VAR_FOLDERS_PATH:-/var/folders}"
      SYS_VAR_VM_PATH="${SYS_VAR_VM_PATH:-/var/vm}"
      SYS_LIBRARY_PATH="${SYS_LIBRARY_PATH:-/usr/lib}"
      APP_SUPPORT_PATH="${APP_SUPPORT_PATH:-/usr/share/applications}"
      LIBRARY_CACHE_PATH="${LIBRARY_CACHE_PATH:-/var/cache}"
      LIBRARY_LOGS_PATH="${LIBRARY_LOGS_PATH:-/var/log}"
      
      # Set ClamAV specific paths for Linux
      DEFAULT_CLAMAV_DB_DIR="${DEFAULT_CLAMAV_DB_DIR:-/var/lib/clamav}"
      DEFAULT_CLAMAV_BIN_DIR="${DEFAULT_CLAMAV_BIN_DIR:-/usr/bin}"
      ;;
      
    *)
      echo "Warning: Unsupported OS type: $OS_TYPE. Using Linux-like paths." >&2
      # Use Linux-like paths as fallback
      SYS_VOLUMES_DATA_PATH="${SYS_VOLUMES_DATA_PATH:-}"
      SYS_PRIVATE_PATH="${SYS_PRIVATE_PATH:-/private}"
      SYS_PRIVATE_VAR_PATH="${SYS_PRIVATE_VAR_PATH:-/var}"
      SYS_DATA_PRIVATE_PATH="${SYS_DATA_PRIVATE_PATH:-/private}"
      SYS_DATA_PRIVATE_VAR_PATH="${SYS_DATA_PRIVATE_VAR_PATH:-/var}"
      SYS_VAR_DB_PATH="${SYS_VAR_DB_PATH:-/var/db}"
      SYS_VAR_FOLDERS_PATH="${SYS_VAR_FOLDERS_PATH:-/var/folders}"
      SYS_VAR_VM_PATH="${SYS_VAR_VM_PATH:-/var/vm}"
      SYS_LIBRARY_PATH="${SYS_LIBRARY_PATH:-/usr/lib}"
      APP_SUPPORT_PATH="${APP_SUPPORT_PATH:-/usr/share/applications}"
      LIBRARY_CACHE_PATH="${LIBRARY_CACHE_PATH:-/var/cache}"
      LIBRARY_LOGS_PATH="${LIBRARY_LOGS_PATH:-/var/log}"
      
      # Set ClamAV specific paths
      DEFAULT_CLAMAV_DB_DIR="${DEFAULT_CLAMAV_DB_DIR:-/var/lib/clamav}"
      DEFAULT_CLAMAV_BIN_DIR="${DEFAULT_CLAMAV_BIN_DIR:-/usr/bin}"
      ;;
  esac
  
  # Determine best temporary directory
  if [ -n "${TMPDIR:-}" ] && [ -d "${TMPDIR}" ] && [ -w "${TMPDIR}" ]; then
    SYS_TMP_PATH="${TMPDIR}"
  elif [ -d "/tmp" ] && [ -w "/tmp" ]; then
    SYS_TMP_PATH="/tmp"
  elif [ -d "$HOME/tmp" ] && [ -w "$HOME/tmp" ]; then
    SYS_TMP_PATH="$HOME/tmp"
  else
    # Create a temp directory as last resort
    SYS_TMP_PATH="${SECURITY_DIR}/tmp"
    mkdir -p "$SYS_TMP_PATH" 2>/dev/null || {
      echo "Error: Could not create or find a writable temporary directory" >&2
      exit 1
    }
  fi
  
  # Find ClamAV database location
  find_clamav_database
  
  debug "OS detection and system path setup completed"
}

# Find ClamAV database location from common locations
# Usage: find_clamav_database
find_clamav_database() {
  debug "Searching for ClamAV database..."
  
  # Define search locations based on OS
  local db_locations=()
  
  if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS locations
    db_locations=(
      "$DEFAULT_CLAMAV_DB_DIR"
      "/opt/homebrew/var/lib/clamav"
      "/usr/local/var/lib/clamav"
      "/var/lib/clamav"
      "${HOME}/.clamav"
    )
  else
    # Linux/Unix locations
    db_locations=(
      "$DEFAULT_CLAMAV_DB_DIR"
      "/var/lib/clamav"
      "/usr/local/share/clamav"
      "/usr/share/clamav"
      "${HOME}/.clamav"
    )
  fi
  
  # Find the first existing database directory
  CLAMAV_DB_DIR=${CLAMAV_DB_DIR:-""}
  if [ -z "$CLAMAV_DB_DIR" ]; then
    for db_path in "${db_locations[@]}"; do
      if [ -d "$db_path" ]; then
        CLAMAV_DB_DIR="$db_path"
        debug "Found ClamAV database directory: $CLAMAV_DB_DIR"
        break
      fi
    done
    
    # If no existing directory is found, use the default location
    if [ -z "$CLAMAV_DB_DIR" ]; then
      CLAMAV_DB_DIR="$DEFAULT_CLAMAV_DB_DIR"
      debug "Using default ClamAV database directory: $CLAMAV_DB_DIR"
    fi
  fi
  
  # Export database path for scripts
  export CLAMAV_DB_DIR
}

#----------- Path Validation -----------#

# Create required directory if it doesn't exist
# Usage: ensure_dir_exists path
ensure_dir_exists() {
  local path="$1"
  
  if [ ! -d "$path" ]; then
    debug "Creating directory: $path"
    mkdir -p "$path" 2>/dev/null || {
      echo "Error: Failed to create directory: $path" >&2
      return 1
    }
    
    # Set secure permissions for sensitive directories
    if [[ "$path" == *"quarantine"* || "$path" == *"Security"* ]]; then
      chmod 700 "$path" 2>/dev/null || {
        echo "Warning: Failed to set secure permissions on $path" >&2
        return 0  # Continue despite permission setting failure
      }
    fi
  fi
  
  # Verify the directory is writable
  if [ ! -w "$path" ]; then
    echo "Error: Directory is not writable: $path" >&2
    return 1
  fi
  
  return 0
}

# Validate system path
# Usage: validate_system_path path [type] [skip_check]
# type can be "dir" or "file", skip_check is optional boolean
validate_system_path() {
  local path="$1"
  local path_type="${2:-dir}"
  local skip_check="${3:-false}"
  
  # Skip validation if requested
  if [ "$skip_check" = "true" ]; then
    return 0
  fi
  
  # For directories, check if they exist
  if [ "$path_type" = "dir" ]; then
    if [ ! -d "$path" ] && [ ! -L "$path" ]; then
      debug "System directory path does not exist: $path"
      # No need to create system paths, just warn
      return 1
    fi
  elif [ "$path_type" = "file" ]; then
    if [ ! -f "$path" ] && [ ! -L "$path" ]; then
      debug "System file path does not exist: $path"
      return 1
    fi
  fi
  
  return 0
}

# Check if there's enough disk space for scanning and quarantine
# Usage: check_disk_space [directory]
check_disk_space() {
  local dir_to_check="${1:-$SECURITY_DIR}"
  debug "Checking available disk space in $dir_to_check..."
  
  # Ensure the directory exists or can be created
  if ! ensure_dir_exists "$dir_to_check"; then
    echo "Error: Cannot create directory for disk space check: $dir_to_check" >&2
    return 1
  fi
  
  # Get available space in MB
  local available_space
  available_space=$(df -m "$dir_to_check" 2>/dev/null | awk 'NR==2 {print $4}')
  
  # Verify df command succeeded
  if [ -z "$available_space" ]; then
    echo "Error: Failed to determine available disk space for $dir_to_check" >&2
    return 1
  fi
  
  # Verify we have enough space for operations
  if [ "$available_space" -lt "$MIN_FREE_SPACE" ]; then
    local available_gb=$(echo "scale=1; $available_space/1024" | bc 2>/dev/null || echo "$available_space")
    local required_gb=$(echo "scale=1; $MIN_FREE_SPACE/1024" | bc 2>/dev/null || echo "$MIN_FREE_SPACE")
    
    echo "Error: Insufficient disk space. Required: ${required_gb}GB, Available: ${available_gb}GB" >&2
    return 1
  fi
  
  debug "Sufficient disk space available: ${available_space}MB"
  return 0
}

# Verify file permissions and accessibility 
# Usage: verify_file_access file [required_permission]
verify_file_access() {
  local file="$1"
  local permission="${2:-r}"  # Default to check read permission
  
  # Check if file exists
  if [ ! -e "$file" ]; then
    debug "File does not exist: $file"
    return 1
  fi
  
  # Check required permission
  case "$permission" in
    r) # Read permission
      if [ ! -r "$file" ]; then
        debug "File is not readable: $file"
        return 1
      fi
      ;;
    w) # Write permission
      if [ ! -w "$file" ]; then
        debug "File is not writable: $file"
        return 1
      fi
      ;;
    x) # Execute permission
      if [ ! -x "$file" ]; then
        debug "File is not executable: $file"
        return 1
      fi
      ;;
    *) # Invalid permission type
      debug "Invalid permission type: $permission"
      return 1
      ;;
  esac
  
  return 0
}

#----------- Logging Functions -----------#

# Initialize logging
# Usage: init_logging
init_logging() {
  debug "Initializing logging system..."
  
  # Ensure log directory exists
  if ! ensure_dir_exists "$LOG_DIR"; then
    echo "Error: Failed to create log directory: $LOG_DIR" >&2
    # Fallback to ./clammy.log in the current directory
    LOGFILE="./clammy.log"
  fi
  
  # Initialize the global log file
  if [ ! -f "$LOGFILE" ]; then
    touch "$LOGFILE" 2>/dev/null || {
      echo "Error: Failed to create log file: $LOGFILE" >&2
      # Create a fallback log file in the current directory
      LOGFILE="./clammy.log"
      touch "$LOGFILE" 2>/dev/null || {
        echo "Error: Failed to create fallback log file. Continuing without logging." >&2
        return 1
      }
    }
  elif [ ! -w "$LOGFILE" ]; then
    echo "Error: Log file is not writable: $LOGFILE" >&2
    return 1
  fi
  
  # Set flag that log system is initialized
  LOG_SYSTEM_INITIALIZED="true"
  
  # Write initial log entry
  log "=== Clammy Scanner started at $(date) ==="
  log "Logging initialized: $LOGFILE"
  
  debug "Logging system initialized"
  return 0
}

# Log message to file and optionally to console
# Usage: log "message" ["level"]
log() {
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  local level="${2:-INFO}"
  local message="$1"
  
  # Make sure log directory exists
  if [ ! -d "$(dirname "${LOGFILE}")" ]; then
    mkdir -p "$(dirname "${LOGFILE}")" 2>/dev/null || { 
      echo "Error: Failed to create log directory at $(dirname "${LOGFILE}")" >&2
      return 1
    }
  fi
  
  # Write to log file (without color codes)
  echo "[$timestamp] [$level] $message" >> "${LOGFILE}" 2>/dev/null || {
    echo "Error: Failed to write to log file ${LOGFILE}" >&2
    return 1
  }
  
  # Echo to terminal with emoji and color if not in quiet mode
  if [ "${QUIET_MODE:-false}" != "true" ]; then
    case "$level" in
      ERROR)
        printf "\033[1;31m❌ ERROR: %s\033[0m\n" "$message" >&2
        ;;
      WARNING)
        printf "\033[1;33m⚠️ WARNING: %s\033[0m\n" "$message" >&2
        ;;
      SUCCESS)
        printf "\033[1;32m✅ SUCCESS: %s\033[0m\n" "$message" >&2
        ;;
      QUARANTINE)
        printf "\033[1;35m🔒 QUARANTINE: %s\033[0m\n" "$message" >&2
        ;;
      SCAN)
        printf "\033[1;34m🔍 SCAN: %s\033[0m\n" "$message" >&2
        ;;
      *)
        # Only show INFO messages in verbose mode
        [ "${VERBOSE:-false}" = "true" ] && printf "\033[0;36mℹ️ INFO: %s\033[0m\n" "$message" >&2
        ;;
    esac
  fi
  
  return 0
}

# Debug function for verbose output
# Usage: debug "message"
debug() {
  # Use direct echo if called before log system is initialized
  if [ -z "${LOG_SYSTEM_INITIALIZED:-}" ]; then
    if [ "${DEBUG:-false}" = "true" ]; then
      local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
      printf "[%s] [DEBUG] %s\n" "$timestamp" "$1" >&2
    fi
    return 0
  fi
  
  # Standard debug with log file once initialized
  if [ "${DEBUG:-false}" = "true" ]; then
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    printf "[%s] [DEBUG] %s\n" "$timestamp" "$1" >&2
    log_file_only "$1" "DEBUG"
  fi
  return 0
}

# Log message to logfile only (no stdout)
# Usage: log_file_only "message" ["level"]
log_file_only() {
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  local msg="$1"
  local level="${2:-INFO}"
  
  # Create log directory if it doesn't exist yet
  if [ ! -d "$(dirname "${LOGFILE}")" ]; then
    mkdir -p "$(dirname "${LOGFILE}")" 2>/dev/null || { 
      printf "Error: Failed to create log directory %s\n" "$(dirname "${LOGFILE}")" >&2
      return 1
    }
  fi
  
  # Only write to log file, not to console
  printf "[%s] [%s] %s\n" "${timestamp}" "${level}" "$msg" >> "${LOGFILE}" 2>/dev/null || {
    printf "Error: Failed to write to log file %s\n" "${LOGFILE}" >&2
    return 1
  }
  
  # Force write to disk in critical sections only
  if [ "$level" = "ERROR" ] || [ "$level" = "CRITICAL" ]; then
    sync
  fi
  
  return 0
}

# Check if a command exists
# Usage: command_exists "command_name"
# Returns: 0 if command exists, 1 if not
command_exists() {
  if [ -z "$1" ]; then
    log "No command specified to check" "ERROR"
    return 1
  fi
  command -v "$1" >/dev/null 2>&1
}

# Check for required dependencies
# Usage: check_dependencies
# Returns: 0 if all required dependencies are found, 1 otherwise
check_dependencies() {
  log "Checking dependencies for virus scanning..." "SCAN"
  local missing_deps=0
  local missing_list=""
  
  # Define required and optional dependencies
  local required_deps=("clamscan" "freshclam")
  local optional_deps=("osascript" "jq" "bc")
  
  # Check required dependencies first
  for cmd in "${required_deps[@]}"; do
    if ! command_exists "$cmd"; then
      log "Required command '$cmd' not found" "ERROR"
      missing_deps=1
      missing_list="${missing_list} $cmd"
    else
      debug "Found required dependency: $cmd"
    fi
  done
  
  # Check optional dependencies
  for cmd in "${optional_deps[@]}"; do
    if ! command_exists "$cmd"; then
      log "Optional command '$cmd' not found. Some features may be limited." "WARNING"
    else
      debug "Found optional dependency: $cmd"
    fi
  done
  
  # Report missing dependencies
  if [ $missing_deps -eq 1 ]; then
    log "Missing required dependencies: ${missing_list}" "ERROR"
    echo "Please install the missing dependencies: ${missing_list}" >&2
    echo "On macOS, you can use: brew install ${missing_list}" >&2
    echo "On Linux, you can use: sudo apt-get install ${missing_list} (Debian/Ubuntu)" >&2
    echo "                     or: sudo yum install ${missing_list} (CentOS/RHEL)" >&2
    return 1
  fi
  
  log "All required dependencies found" "SUCCESS"
  return 0
}

# Setup the environment for the scanner
# Usage: setup_environment
setup_environment() {
  debug "Setting up scanner environment..."
  
  # Load configuration
  load_config
  
  # Setup system paths
  detect_os_paths
  
  # Initialize logging
  init_logging
  
  # Create required directories
  ensure_dir_exists "$SECURITY_DIR" || return 1
  ensure_dir_exists "$LOG_DIR" || return 1
  ensure_dir_exists "$QUARANTINE_DIR" || return 1
  
  # Check dependencies
  check_dependencies || return 1
  
  # Check disk space
  check_disk_space || return 1
  
  log "Environment setup completed successfully" "SUCCESS"
  return 0
}

# Automatically setup the environment when core.sh is loaded
setup_environment

