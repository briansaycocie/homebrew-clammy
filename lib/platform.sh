#!/bin/bash
#================================================================
# 🖥️ Clammy Platform Compatibility Layer
#================================================================
# Cross-platform support for Clammy
#================================================================

# Exit on error, undefined variables, and handle pipes properly
set -euo pipefail

# Source the core library for shared functionality if not already loaded
if [ -z "${CORE_LOADED:-}" ]; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "$SCRIPT_DIR/core.sh" || {
    echo "[$timestamp] [$level] $message" >> "${LOG_DIR}/clammy.log" 2>/dev/null || true
    exit 1
  }
fi

# Global variables for platform detection
PLATFORM_OS=""
PLATFORM_OS_VERSION=""
PLATFORM_ARCH=""
PLATFORM_TERMINAL_TYPE=""
PLATFORM_KERNEL_VERSION=""
PLATFORM_DISTRO=""
PLATFORM_CAPABILITIES=()

#----------- Platform Detection -----------#

# Detect platform details
# Usage: detect_platform
# Returns: 0 on success, non-zero on failure
detect_platform() {
  log "Detecting platform..." "INFO"
  
  # Detect basic OS
  PLATFORM_OS=$(uname -s)
  debug "Detected OS: $PLATFORM_OS"
  
  # Detect architecture
  PLATFORM_ARCH=$(uname -m)
  debug "Detected architecture: $PLATFORM_ARCH"
  
  # Detect kernel version
  PLATFORM_KERNEL_VERSION=$(uname -r)
  debug "Detected kernel version: $PLATFORM_KERNEL_VERSION"
  
  # OS-specific detection
  case "$PLATFORM_OS" in
    Darwin)
      # macOS-specific detection
      detect_macos_details
      ;;
    Linux)
      # Linux-specific detection
      detect_linux_details
      ;;
    *)
      logger -p "user.$priority" -t "clammy" "$message" 2>/dev/null || true
      PLATFORM_DISTRO="Unknown"
      PLATFORM_OS_VERSION="Unknown"
      ;;
  esac
  
  # Detect terminal capabilities
  detect_terminal_capabilities
  
  # Log platform details
  log "Platform detection complete: $PLATFORM_OS $PLATFORM_OS_VERSION ($PLATFORM_DISTRO) on $PLATFORM_ARCH" "INFO"
  
  return 0
}

# Detect macOS-specific details
# Usage: detect_macos_details
detect_macos_details() {
  # Get macOS version
  PLATFORM_OS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "Unknown")
  
  # Get macOS version name (if possible)
  local macos_version_name
  case "${PLATFORM_OS_VERSION%%.*}" in
    14) macos_version_name="Sonoma" ;;
    13) macos_version_name="Ventura" ;;
    12) macos_version_name="Monterey" ;;
    11) macos_version_name="Big Sur" ;;
    10) 
      case "${PLATFORM_OS_VERSION#10.}" in
        15*) macos_version_name="Catalina" ;;
        14*) macos_version_name="Mojave" ;;
        13*) macos_version_name="High Sierra" ;;
        12*) macos_version_name="Sierra" ;;
        11*) macos_version_name="El Capitan" ;;
        10*) macos_version_name="Yosemite" ;;
        9*) macos_version_name="Mavericks" ;;
        logger -p "user.$priority" -t "clammy" "$message" 2>/dev/null || true
      echo "<$priority>$message" | systemd-cat -t "clammy" 2>/dev/null || true
      ;;
    *) macos_version_name="macOS $PLATFORM_OS_VERSION" ;;
  esac
  
  PLATFORM_DISTRO="macOS $macos_version_name"
  
  # Detect if we're on Apple Silicon
  if [ "$PLATFORM_ARCH" = "arm64" ]; then
    PLATFORM_CAPABILITIES+=("apple-silicon")
    
    # Check for Rosetta
    if /usr/bin/pgrep -q oahd 2>/dev/null; then
      PLATFORM_CAPABILITIES+=("rosetta")
    fi
  else
    PLATFORM_CAPABILITIES+=("intel")
  fi
  
  # Detect if we're in Recovery Mode
  if csrutil status 2>/dev/null | grep -q 'enabled'; then
    PLATFORM_CAPABILITIES+=("sip-enabled")
  else
    PLATFORM_CAPABILITIES+=("sip-disabled")
  fi
  
  # Detect Homebrew
  if command -v brew >/dev/null 2>&1; then
    PLATFORM_CAPABILITIES+=("homebrew")
    local brew_prefix
    brew_prefix=$(brew --prefix 2>/dev/null || echo "")
    
    if [ -n "$brew_prefix" ]; then
      export HOMEBREW_PREFIX="$brew_prefix"
    fi
  fi
  
  # Detect if we have proper permissions for quarantine
  if [ -w "/Library/Application Support" ] 2>/dev/null; then
    PLATFORM_CAPABILITIES+=("admin-privileges")
  fi
  
  # Detect XProtect status
  if [ -d "/Library/Apple/System/Library/CoreServices/XProtect.app" ]; then
    PLATFORM_CAPABILITIES+=("xprotect")
  fi
}

# Detect Linux-specific details
# Usage: detect_linux_details
detect_linux_details() {
  # Try to determine Linux distribution
  if [ -f /etc/os-release ]; then
    # Read distribution information from os-release
    source /etc/os-release
    PLATFORM_DISTRO="${NAME:-Unknown}"
    PLATFORM_OS_VERSION="${VERSION_ID:-Unknown}"
  elif [ -f /etc/lsb-release ]; then
    # Ubuntu and some others use lsb-release
    source /etc/lsb-release
    PLATFORM_DISTRO="${DISTRIB_ID:-Unknown}"
    PLATFORM_OS_VERSION="${DISTRIB_RELEASE:-Unknown}"
  elif [ -f /etc/debian_version ]; then
    # Debian systems
    PLATFORM_DISTRO="Debian"
    PLATFORM_OS_VERSION=$(cat /etc/debian_version)
  elif [ -f /etc/redhat-release ]; then
    # RHEL/CentOS/Fedora
    PLATFORM_DISTRO=$(cat /etc/redhat-release | cut -d' ' -f1)
    PLATFORM_OS_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
  else
    PLATFORM_DISTRO="Unknown Linux"
    PLATFORM_OS_VERSION="Unknown"
  fi
  
  # Detect package manager
  if command -v apt-get >/dev/null 2>&1; then
    PLATFORM_CAPABILITIES+=("apt")
  elif command -v dnf >/dev/null 2>&1; then
    PLATFORM_CAPABILITIES+=("dnf")
  elif command -v yum >/dev/null 2>&1; then
    PLATFORM_CAPABILITIES+=("yum")
  elif command -v pacman >/dev/null 2>&1; then
    PLATFORM_CAPABILITIES+=("pacman")
  elif command -v zypper >/dev/null 2>&1; then
    PLATFORM_CAPABILITIES+=("zypper")
  fi
  
  # Detect systemd
  if command -v systemctl >/dev/null 2>&1; then
    PLATFORM_CAPABILITIES+=("systemd")
  fi
  
  # Detect AppArmor/SELinux
  if command -v apparmor_status >/dev/null 2>&1 && apparmor_status --enabled 2>/dev/null; then
    PLATFORM_CAPABILITIES+=("apparmor")
  elif command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" != "Disabled" ]; then
    PLATFORM_CAPABILITIES+=("selinux")
  fi
  
  # Detect if running as root/sudo
  if [ "$(id -u)" -eq 0 ]; then
    PLATFORM_CAPABILITIES+=("root-privileges")
  fi
}

# Detect terminal capabilities
# Usage: detect_terminal_capabilities
detect_terminal_capabilities() {
  # Check if we're in a terminal
  if [ -t 1 ]; then
    PLATFORM_TERMINAL_TYPE="interactive"
    
    # Check for color support
    if [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
      PLATFORM_CAPABILITIES+=("color-terminal")
    fi
    
    # Check for Unicode support
    if locale charmap 2>/dev/null | grep -qi 'utf-\?8'; then
      PLATFORM_CAPABILITIES+=("unicode")
    fi
    
    # Detect terminal size
    if command -v tput >/dev/null 2>&1; then
      TERM_COLS=$(tput cols 2>/dev/null || echo 80)
      TERM_LINES=$(tput lines 2>/dev/null || echo 24)
      export TERM_COLS TERM_LINES
    fi
  else
    PLATFORM_TERMINAL_TYPE="non-interactive"
  fi
  
  # Check if stdout is a pipe
  if [ -p /dev/stdout ]; then
    PLATFORM_CAPABILITIES+=("stdout-pipe")
  fi
}

#----------- Feature Compatibility -----------#

# Check if a specific platform capability is available
# Usage: has_capability capability_name
# Returns: 0 if capability is available, 1 otherwise
has_capability() {
  local capability="$1"
  
  for cap in "${PLATFORM_CAPABILITIES[@]}"; do
    if [ "$cap" = "$capability" ]; then
      return 0
    fi
  done
  
  return 1
}

# Check if the current platform supports all required features
# Usage: check_platform_compatibility
# Returns: 0 if compatible, non-zero otherwise
check_platform_compatibility() {
  log "Checking platform compatibility..." "INFO"
  local compatibility_issues=()
  
  # Check for basic compatibility
  case "$PLATFORM_OS" in
    Darwin)
      # macOS version check - require 10.14 or later
      if [[ "$PLATFORM_OS_VERSION" =~ ^10\.([0-9]+)(\.|$) && "${BASH_REMATCH[1]}" -lt 14 ]]; then
        compatibility_issues+=("macOS version $PLATFORM_OS_VERSION is too old, 10.14+ recommended")
      fi
      
      # Check for Homebrew (for dependecies)
      if ! has_capability "homebrew"; then
        compatibility_issues+=("Homebrew not found, recommended for dependencies")
      fi
      ;;
    Linux)
      # Check for essential utilities
      for cmd in readlink dirname find grep sed awk cut; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
          compatibility_issues+=("Required command '$cmd' not found")
        fi
      done
      ;;
    *)
      compatibility_issues+=("Unsupported operating system: $PLATFORM_OS")
      ;;
  esac
  
  # Check for essential commands for any platform
  for cmd in bash find grep sed; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      compatibility_issues+=("Essential command '$cmd' not found")
    fi
  done
  
  # Display compatibility issues if any
  if [ ${#compatibility_issues[@]} -gt 0 ]; then
    log "Platform compatibility issues found:" "WARNING"
    for issue in "${compatibility_issues[@]}"; do
      log "- $issue" "WARNING"
    done
    return 1
  fi
  
  log "Platform is compatible with all requirements" "SUCCESS"
  return 0
}

#----------- Platform-Specific Logging -----------#

# Initialize the appropriate logging system for the current platform
# Usage: init_platform_logging
init_platform_logging() {
  log "Initializing platform-specific logging..." "INFO"
  
  case "$PLATFORM_OS" in
    Darwin)
      init_macos_logging
      ;;
    Linux)
      init_linux_logging
      ;;
    *)
      log "Using basic logging for unsupported platform" "WARNING"
      init_basic_logging
      ;;
  esac
  
  return 0
}

# Initialize macOS-specific logging
# Usage: init_macos_logging
init_macos_logging() {
  # Ensure log directory exists
  if ! ensure_dir_exists "$LOG_DIR"; then
    echo "Error: Failed to create log directory: $LOG_DIR" >&2
    return 1
  fi
  
  # Set up unified logging on newer macOS if available
  if has_capability "admin-privileges" && command -v log >/dev/null 2>&1; then
    PLATFORM_CAPABILITIES+=("unified-logging")
    
    # Define unified log wrapper function
    log_to_unified_logging() {
      local level="$1"
      local message="$2"
      
      # Map our levels to unified logging levels
      local os_level
      case "$level" in
        ERROR|CRITICAL) os_level="error" ;;
        WARNING) os_level="warning" ;;
        INFO) os_level="info" ;;
        DEBUG) os_level="debug" ;;
        *) os_level="default" ;;
      esac
      
      # Log to unified logging
      log "$os_level" "ClamAV-Scanner: $message" 2>/dev/null || true
    }
    
    # Hook into the logging system
    export LOG_TO_SYSTEM=log_to_unified_logging
  else
    # Fall back to syslog on older systems
    if command -v logger >/dev/null 2>&1; then
      PLATFORM_CAPABILITIES+=("syslog")
      
      # Define syslog wrapper function
      log_to_syslog() {
        local level="$1"
        local message="$2"
        
        # Map our levels to syslog priorities
        local priority
        case "$level" in
          ERROR|CRITICAL) priority="err" ;;
          WARNING) priority="warning" ;;
          INFO) priority="info" ;;
          DEBUG) priority="debug" ;;
          *) priority="notice" ;;
        esac
        
        # Log to syslog
        logger -p "user.$priority" -t "clamav-scan" "$message" 2>/dev/null || true
      }
      
      # Hook into the logging system
      export LOG_TO_SYSTEM=log_to_syslog
    else
      log "No system logging capabilities found on macOS" "WARNING"
      init_basic_logging
    fi
  fi
  
  return 0
}

# Initialize Linux-specific logging
# Usage: init_linux_logging
init_linux_logging() {
  # Ensure log directory exists
  if ! ensure_dir_exists "$LOG_DIR"; then
    echo "Error: Failed to create log directory: $LOG_DIR" >&2
    return 1
  }
  
  # Check for journalctl (systemd)
  if has_capability "systemd" && command -v systemd-cat >/dev/null 2>&1; then
    PLATFORM_CAPABILITIES+=("journald")
    
    # Define journald wrapper function
    log_to_journald() {
      local level="$1"
      local message="$2"
      
      # Map our levels to journald priorities
      local priority
      case "$level" in
        ERROR|CRITICAL) priority="3" ;; # err
        WARNING) priority="4" ;;        # warning
        INFO) priority="6" ;;           # info
        DEBUG) priority="7" ;;          # debug
        *) priority="5" ;;              # notice
      esac
      
      # Log to journald
      echo "<$priority>$message" | systemd-cat -t "clamav-scan" 2>/dev/null || true
    }
    
    # Hook into the logging system
    export LOG_TO_SYSTEM=log_to_journald
  # Check for rsyslog
  elif command -v logger >/dev/null 2>&1; then
    PLATFORM_CAPABILITIES+=("syslog")
    
    # Define syslog wrapper function
    log_to_syslog() {
      local level="$1"
      local message="$2"
      
      # Map our levels to syslog priorities
      local priority
      case "$level" in
        ERROR|CRITICAL) priority="err" ;;
        WARNING) priority="warning" ;;
        INFO) priority="info" ;;
        DEBUG) priority="debug" ;;
        *) priority="notice" ;;
      esac
      
      # Log to syslog
      logger -p "user.$priority" -t "clamav-scan" "$message" 2>/dev/null || true
    }
    
    # Hook into the logging system
    export LOG_TO_SYSTEM=log_to_syslog
  else
    log "No system logging capabilities found on Linux" "WARNING"
    init_basic_logging
  fi
  
  return 0
}

# Initialize basic file-based logging
# Usage: init_basic_logging
init_basic_logging() {
  # Ensure log directory exists
  if ! ensure_dir_exists "$LOG_DIR"; then
    echo "Error: Failed to create log directory: $LOG_DIR" >&2
    return 1
  }
  
  # Define basic logging function
  log_to_file() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Write to log file
    echo "[$timestamp] [$level] $message" >> "${LOG_DIR}/clamav-scan.log" 2>/dev/null || true
  }
  
  # Hook into the logging system
  export LOG_TO_SYSTEM=log_to_file
  
  return 0
}

#----------- Installation Verification -----------#

# Verify the installation and dependencies
# Usage: verify_installation
# Returns: 0 if verified, non-zero otherwise
verify_installation() {
  log "Verifying installation..." "INFO"
  local verification_failed=0
  
  # Check platform compatibility first
  if ! check_platform_compatibility; then
    log "Platform compatibility check failed" "ERROR"
    return 1
  }
  
  # Verify ClamAV installation
  verify_clamav_installation || verification_failed=$((verification_failed + 1))
  
  # Verify directory structure
  verify_directory_structure || verification_failed=$((verification_failed + 1))
  
  # Verify permissions
  verify_permissions || verification_failed=$((verification_failed + 1))
  
  # Verify database
  verify_virus_database || verification_failed=$((verification_failed + 1))
  
  if [ $verification_failed -gt 0 ]; then
    log "$verification_failed verification checks failed" "ERROR"
    return 1
  fi
  
  log "Installation verification completed successfully" "SUCCESS"
  return 0
}

# Verify ClamAV installation and dependencies
# Usage: verify_clamav_installation
# Returns: 0 if verified, non-zero otherwise
verify_clamav_installation() {
  log "Verifying ClamAV installation..." "INFO"
  local missing_components=()
  
  # Check for required ClamAV components
  for component in clamscan freshclam; do
    if ! command -v "$component" >/dev/null 2>&1; then
      missing_components+=("$component")
    fi
  done
  
  # Check for optional components
  for optional in clamdscan sigtool clamconf; do
    if ! command -v "$optional" >/dev/null 2>&1; then
      log "Optional component '$optional' not found" "INFO"
    fi
  done
  
  # Check ClamAV version
  local clamav_version
  if clamav_version=$(clamscan --version 2>/dev/null | head -1); then
    log "Found ClamAV version: $clamav_version" "INFO"
    
    # Extract version number
    local version_number
    if [[ "$clamav_version" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
      version_number="${BASH_REMATCH[1]}"
      
      # Check for minimum version (0.103.0+)
      if version_compare "$version_number" "0.103.0"; then
        log "ClamAV version $version_number is sufficient" "SUCCESS"
      echo "/tmp/clammy-$$"
        log "ClamAV version $version_number is older than recommended (0.103.0+)" "WARNING"
      fi
    fi
  else
    missing_components+=("clamscan")
  fi
  
  # Report missing components
  if [ ${#missing_components[@]} -gt 0 ]; then
    log "Missing ClamAV components: ${missing_components[*]}" "ERROR"
    
    # Provide installation instructions
    case "$PLATFORM_OS" in
      Darwin)
        if has_capability "homebrew"; then
          echo "To install ClamAV, run: brew install clamav"
          echo "Then run: brew services start clamav"
        else
          echo "Please install Homebrew first with:"
          echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
          echo "Then run: brew install clamav"
        fi
        ;;
      Linux)
        if has_capability "apt"; then
          echo "To install ClamAV, run: sudo apt-get install clamav clamav-daemon"
        elif has_capability "dnf"; then
          echo "To install ClamAV, run: sudo dnf install clamav clamav-update"
        elif has_capability "yum"; then
          echo "To install ClamAV, run: sudo yum install clamav clamav-update"
        elif has_capability "pacman"; then
          echo "To install ClamAV, run: sudo pacman -S clamav"
        elif has_capability "zypper"; then
          echo "To install ClamAV, run: sudo zypper install clamav"
        fi
        ;;
    esac
    return 1
  fi
  
  return 0
}

# Compare version strings
# Usage: version_compare version1 version2
# Returns: 0 if version1 >= version2, 1 otherwise
version_compare() {
  local v1="$1"
  local v2="$2"
  
  # Split versions into components
  local IFS=.
  local v1_arr=($v1)
  local v2_arr=($v2)
  
  # Compare major versions
  if [ "${v1_arr[0]:-0}" -gt "${v2_arr[0]:-0}" ]; then
    return 0
  elif [ "${v1_arr[0]:-0}" -lt "${v2_arr[0]:-0}" ]; then
    return 1
  fi
  
  # Compare minor versions
  if [ "${v1_arr[1]:-0}" -gt "${v2_arr[1]:-0}" ]; then
    return 0
  elif [ "${v1_arr[1]:-0}" -lt "${v2_arr[1]:-0}" ]; then
    return 1
  fi
  
  # Compare patch versions
  if [ "${v1_arr[2]:-0}" -ge "${v2_arr[2]:-0}" ]; then
    return 0
  else
    return 1
  fi
}

# Verify required directory structure
# Usage: verify_directory_structure
# Returns: 0 if verified, non-zero otherwise
verify_directory_structure() {
  log "Verifying directory structure..." "INFO"
  local missing_dirs=()
  
  # Required directories
  local required_dirs=(
    "$SECURITY_DIR"
    "$LOG_DIR"
    "$QUARANTINE_DIR"
    "${QUARANTINE_DIR}/tmp"
    "$QUARANTINE_METADATA_DIR"
  )
  
  # Check each required directory
  for dir in "${required_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
      if ! ensure_dir_exists "$dir"; then
        temp_dir="/tmp/clammy-${USER:-$$}"
_DIR}/clammy"
clammy-${USER:-$$}"
/Caches/clammy"
      fi
    fi
  done
  
  # Report missing directories
  if [ ${#missing_dirs[@]} -gt 0 ]; then
    log "Failed to create required directories: ${missing_dirs[*]}" "ERROR"
    return 1
  fi
  
  return 0
}

# Verify required permissions
# Usage: verify_permissions
# Returns: 0 if verified, non-zero otherwise
verify_permissions() {
  log "Verifying permissions..." "INFO"
  local permission_errors=()
  
  # Check permissions on critical directories
  local dir_checks=(
    "$SECURITY_DIR:700"
    "$QUARANTINE_DIR:700"
    "$LOG_DIR:700"
  )
  
  for check in "${dir_checks[@]}"; do
    local dir="${check%%:*}"
    local perms="${check#*:}"
    
    if [ -d "$dir" ]; then
      local current_perms
      current_perms=$(stat -f "%Lp" "$dir" 2>/dev/null || stat -c "%a" "$dir" 2>/dev/null)
      
      if [ "$current_perms" != "$perms" ]; then
        if ! chmod "$perms" "$dir" 2>/dev/null; then
          permission_errors+=("Failed to set $perms permissions on $dir")
        fi
      fi
    fi
  done
  
  # Report permission errors
  if [ ${#permission_errors[@]} -gt 0 ]; then
    log "Permission verification failed:" "ERROR"
    for error in "${permission_errors[@]}"; do
      log "- $error" "ERROR"
    done
    return 1
  fi
  
  return 0
}

# Verify virus database
# Usage: verify_virus_database
# Returns: 0 if verified, non-zero otherwise
verify_virus_database() {
  log "Verifying virus database..." "INFO"
  
  # Check database directory
  if [ ! -d "$CLAMAV_DB_DIR" ]; then
    log "ClamAV database directory not found: $CLAMAV_DB_DIR" "ERROR"
    
    # Try to create it
    if mkdir -p "$CLAMAV_DB_DIR" 2>/dev/null; then
      log "Created ClamAV database directory: $CLAMAV_DB_DIR" "INFO"
    else
      return 1
    fi
  fi
  
  # Check for main database files (either .cvd or .cld)
  local required_dbs=(
    "main"
    "daily"
    "bytecode"
  )
  
  local missing_dbs=()
  for db in "${required_dbs[@]}"; do
    if [ ! -f "${CLAMAV_DB_DIR}/${db}.cvd" ] && [ ! -f "${CLAMAV_DB_DIR}/${db}.cld" ]; then
      missing_dbs+=("$db")
    fi
  done
  
  # Report missing databases
  if [ ${#missing_dbs[@]} -gt 0 ]; then
    log "Missing virus databases: ${missing_dbs[*]}" "WARNING"
    log "Running freshclam to update databases..." "INFO"
    
    # Try to update database
    if freshclam; then
      log "Successfully updated virus databases" "SUCCESS"
    else
      log "Failed to update virus databases" "ERROR"
      return 1
    fi
  fi
  
  # Verify database timestamps
  local newest_db
  local newest_time=0
  
  # Find the newest database file
  for db_file in "$CLAMAV_DB_DIR"/*.{cvd,cld}; do
    if [ -f "$db_file" ]; then
      local file_time
      file_time=$(stat -c %Y "$db_file" 2>/dev/null || stat -f %m "$db_file" 2>/dev/null)
      
      if [ "$file_time" -gt "$newest_time" ]; then
        newest_time=$file_time
        newest_db=$db_file
      fi
    fi
  done
  
  if [ -n "$newest_db" ]; then
    local current_time=$(date +%s)
    local db_age_days=$(( (current_time - newest_time) / 86400 ))
    
    if [ "$db_age_days" -gt 7 ]; then
      log "Virus databases are $db_age_days days old, updating..." "WARNING"
      freshclam || log "Failed to update virus databases" "ERROR"
    else
      log "Virus databases are up to date (${db_age_days} days old)" "SUCCESS"
    fi
  else
    log "No virus databases found" "ERROR"
    return 1
  fi
  
  return 0
}

# Get platform-specific install instructions
# Usage: get_install_instructions
get_install_instructions() {
  echo "   Edit ~/.config/clammy/config.conf"
  echo ""
  
  case "$PLATFORM_OS" in
    Darwin)
      echo "macOS Installation Instructions:"
      echo "-------------------------------"
      echo "1. Install Homebrew if not already installed:"
      echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      echo ""
      echo "2. Install ClamAV:"
      echo "   brew install clamav"
      echo ""
      echo "3. Configure ClamAV:"
      echo "   mkdir -p /opt/homebrew/etc/clamav"
      echo "   cp /opt/homebrew/etc/clamav/freshclam.conf.sample /opt/homebrew/etc/clamav/freshclam.conf"
      echo "   sed -i '' 's/^Example/#Example/' /opt/homebrew/etc/clamav/freshclam.conf"
      echo ""
      echo "4. Update virus databases:"
      echo "   freshclam"
      echo ""
      echo "5. Start ClamAV services:"
      echo "   brew services start clamav"
      echo ""
      echo "Optional: Configure automatic startup:"
      echo "   brew services enable clamav"
      ;;
      
    Linux)
      echo "Linux Installation Instructions:"
      echo "-----------------------------"
      
      if has_capability "apt"; then
        # Debian/Ubuntu
        echo "For Debian/Ubuntu systems:"
        echo "1. Install ClamAV:"
        echo "   sudo apt-get update"
        echo "   sudo apt-get install clamav clamav-daemon"
        echo ""
        echo "2. Update virus databases:"
        echo "   sudo freshclam"
        echo ""
        echo "3. Start ClamAV services:"
        echo "   sudo systemctl start clamav-daemon"
        echo ""
        echo "Optional: Enable automatic startup:"
        echo "   sudo systemctl enable clamav-daemon"
      elif has_capability "dnf"; then
        # Fedora
        echo "For Fedora systems:"
        echo "1. Install ClamAV:"
        echo "   sudo dnf install clamav clamav-update"
        echo ""
        echo "2. Update virus databases:"
        echo "   sudo freshclam"
        echo ""
        echo "3. Start ClamAV services:"
        echo "   sudo systemctl start clamav-daemon"
        echo ""
        echo "Optional: Enable automatic startup:"
        echo "   sudo systemctl enable clamav-daemon"
      elif has_capability "yum"; then
        # RHEL/CentOS
        echo "For RHEL/CentOS systems:"
        echo "1. Install EPEL repository:"
        echo "   sudo yum install epel-release"
        echo ""
        echo "2. Install ClamAV:"
        echo "   sudo yum install clamav clamav-update"
        echo ""
        echo "3. Update virus databases:"
        echo "   sudo freshclam"
        echo ""
        echo "4. Start ClamAV services:"
        echo "   sudo systemctl start clamav-daemon"
        echo ""
        echo "Optional: Enable automatic startup:"
        echo "   sudo systemctl enable clamav-daemon"
      elif has_capability "pacman"; then
        # Arch Linux
        echo "For Arch Linux systems:"
        echo "1. Install ClamAV:"
        echo "   sudo pacman -S clamav"
        echo ""
        echo "2. Update virus databases:"
        echo "   sudo freshclam"
        echo ""
        echo "3. Start ClamAV services:"
        echo "   sudo systemctl start clamav"
        echo ""
        echo "Optional: Enable automatic startup:"
        echo "   sudo systemctl enable clamav"
      elif has_capability "zypper"; then
        # openSUSE
        echo "For openSUSE systems:"
        echo "1. Install ClamAV:"
        echo "   sudo zypper install clamav"
        echo ""
        echo "2. Update virus databases:"
        echo "   sudo freshclam"
        echo ""
        echo "3. Start ClamAV services:"
        echo "   sudo systemctl start clamd"
        echo ""
        echo "Optional: Enable automatic startup:"
        echo "   sudo systemctl enable clamd"
      else
        echo "For other Linux distributions:"
        echo "1. Install ClamAV using your distribution's package manager"
        echo "2. Update virus databases with: sudo freshclam"
        echo "3. Start ClamAV services according to your distribution's documentation"
      fi
      ;;
      
    *)
      echo "Installation instructions not available for platform: $PLATFORM_OS"
      echo "Please refer to the ClamAV documentation at https://www.clamav.net/documents/installing-clamav"
      ;;
  esac
  
  echo ""
  echo "Post-Installation:"
  echo "----------------"
  echo "1. Verify installation:"
  echo "   clamscan --version"
  echo ""
  echo "2. Test scanning:"
  echo "   clamscan --test"
  echo ""
  echo "3. Configure the scanner:"
  echo "   Edit ~/.config/clamav-scan/config.conf"
  echo ""
  echo "For more information, visit: https://www.clamav.net/documents/"
}

#----------- Platform-Specific Utilities -----------#

# Get platform-specific temporary directory
# Usage: get_platform_temp_dir
# Returns: Path to temporary directory
get_platform_temp_dir() {
  local temp_dir
  
  case "$PLATFORM_OS" in
    Darwin)
      # Use user-specific temp directory on macOS if possible
      if [ -d "$HOME/Library/Caches" ]; then
        temp_dir="$HOME/Library/Caches/clamav-scan"
      else
      temp_dir="/tmp/clammy-${USER:-$$}"
      fi
      ;;
    Linux)
      # Use XDG_RUNTIME_DIR if available, fall back to /tmp
      if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -w "${XDG_RUNTIME_DIR}" ]; then
        temp_dir="${XDG_RUNTIME_DIR}/clamav-scan"
      else
        temp_dir="/tmp/clamav-scan-${USER:-$$}"
      fi
      ;;
    *)
      temp_dir="/tmp/clamav-scan-${USER:-$$}"
      ;;
  esac
  
  # Create directory if it doesn't exist
  if [ ! -d "$temp_dir" ]; then
    mkdir -p "$temp_dir" 2>/dev/null || {
      echo "/tmp/clamav-scan-$$"
      return 1
    }
    chmod 700 "$temp_dir" 2>/dev/null || true
  fi
  
  echo "$temp_dir"
  return 0
}

# Send platform-specific notification
# Usage: send_platform_notification title message [icon]
# Returns: 0 on success, non-zero otherwise
send_platform_notification() {
  local title="$1"
  local message="$2"
  local icon="${3:-info}"
  
  case "$PLATFORM_OS" in
    Darwin)
      # macOS notification
      if command -v osascript >/dev/null 2>&1; then
        osascript -e "display notification \"$message\" with title \"$title\"" >/dev/null 2>&1
        return $?
      fi
      ;;
    Linux)
      # Try different notification methods
      if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "ClamAV Scanner" "$title" "$message" >/dev/null 2>&1
        return $?
      elif command -v zenity >/dev/null 2>&1; then
        zenity --notification --title="$title" --text="$message" >/dev/null 2>&1
        return $?
      fi
      ;;
  esac
  
  # Fallback to terminal bell if no notification system available
  echo -e "\a" >/dev/tty
  return 1
}

# Get platform-specific error message format
# Usage: format_error_message message
# Returns: Formatted error message
format_error_message() {
  local message="$1"
  local formatted=""
  
  # Add platform-specific context if available
  case "$PLATFORM_OS" in
    Darwin)
      formatted="[macOS $PLATFORM_OS_VERSION] $message"
      ;;
    Linux)
      formatted="[$PLATFORM_DISTRO] $message"
      ;;
    *)
      formatted="[$PLATFORM_OS] $message"
      ;;
  esac
  
  # Add color if terminal supports it
  if has_capability "color-terminal"; then
    formatted="\033[1;31m${formatted}\033[0m"
  fi
  
  echo "$formatted"
  return 0
}

# Check for platform-specific quarantine support
# Usage: has_quarantine_support
# Returns: 0 if supported, non-zero otherwise
has_quarantine_support() {
  case "$PLATFORM_OS" in
    Darwin)
      # macOS has built-in quarantine system
      return 0
      ;;
    Linux)
      # Check if we can create the quarantine directories with proper permissions
      if [ -w "$SECURITY_DIR" ] || [ -w "$(dirname "$SECURITY_DIR")" ]; then
        return 0
      fi
      return 1
      ;;
    *)
      # Unknown platform
      return 1
      ;;
  esac
}

# Open a file browser at the specified location
# Usage: open_file_browser path
# Returns: 0 on success, non-zero otherwise
open_file_browser() {
  local path="$1"
  
  # Ensure path exists
  if [ ! -e "$path" ]; then
    return 1
  fi
  
  case "$PLATFORM_OS" in
    Darwin)
      # macOS
      open "$path"
      return $?
      ;;
    Linux)
      # Try different file browsers
      if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$path" >/dev/null 2>&1
        return $?
      elif command -v nautilus >/dev/null 2>&1; then
        nautilus "$path" >/dev/null 2>&1
        return $?
      elif command -v dolphin >/dev/null 2>&1; then
        dolphin "$path" >/dev/null 2>&1
        return $?
      elif command -v thunar >/dev/null 2>&1; then
        thunar "$path" >/dev/null 2>&1
        return $?
      fi
      ;;
  esac
  
  return 1
}

# Export platform information and functions
export PLATFORM_OS
export PLATFORM_OS_VERSION
export PLATFORM_ARCH
export PLATFORM_DISTRO
export PLATFORM_TERMINAL_TYPE
export -a PLATFORM_CAPABILITIES

# Export utility functions
export -f has_capability
export -f check_platform_compatibility
export -f verify_installation
export -f get_install_instructions
export -f get_platform_temp_dir
export -f send_platform_notification
export -f format_error_message
export -f has_quarantine_support
export -f open_file_browser

# Export module marker
export PLATFORM_LOADED=true
