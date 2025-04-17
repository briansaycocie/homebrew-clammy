#!/bin/bash
#================================================================
# 🛣️ Clammy Path Management System
#================================================================
# Secure and configurable path handling for Clammy
#================================================================

# Exit on error, undefined variables, and handle pipes properly
set -euo pipefail

# Source the core library for shared functionality if not already loaded
if [ -z "${CORE_LOADED:-}" ]; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "$SCRIPT_DIR/core.sh" || {
    echo "Error: Failed to load core library from paths.sh. Exiting." >&2
    exit 1
  }
fi

# Global variables for path management
PATHS_CONFIG_FILE="${SECURITY_DIR}/clamav.paths"
PATHS_OVERRIDE_FILE="${HOME}/.config/clamav-scan/paths.conf"
SYSTEM_PATHS_FILE="/etc/clamav-scan/paths.conf"
PATHS_CACHE_FILE="${SECURITY_DIR}/paths_cache.json"

# Define default path patterns to avoid - these are security-sensitive
# or potentially problematic paths that should never be scanned
DEFAULT_UNSAFE_PATHS=(
  "/dev/*"
  "/proc/*"
  "/sys/*"
  "/var/run/*"
  "/var/lock/*"
  "*/lost+found/*"
  "/private/var/vm/*"
  "/System/Volumes/VM/*"
  "/private/var/db/diagnostics/*"
  "${QUARANTINE_DIR}/*"
)

# Default OS-specific paths
if [ "$(uname)" = "Darwin" ]; then
  # macOS-specific paths
  SYSTEM_PATHS=(
    "/System"
    "/Library"
    "/Applications"
    "/Users"
    "/opt"
    "/private"
  )
  
  SYSTEM_UNSAFE_PATHS=(
    "/System/Volumes/Data/private/var/vm/*"
    "/System/Volumes/Data/private/var/tmp/*"
    "/System/Volumes/Data/System/Library/Caches/*"
    "/Library/Caches/*"
    "/Users/*/Library/Caches/*"
  )
else
  # Linux-specific paths
  SYSTEM_PATHS=(
    "/bin"
    "/sbin"
    "/usr"
    "/opt"
    "/home"
    "/etc"
    "/var"
    "/lib"
    "/lib64"
  )
  
  SYSTEM_UNSAFE_PATHS=(
    "/var/cache/*"
    "/var/tmp/*"
    "/var/log/*"
    "/var/lock/*"
    "/tmp/*"
  )
fi

# Initialize the path management system
# Usage: init_path_management
init_path_management() {
  log "Initializing path management system..." "INFO"
  
  # Ensure configuration directory exists
  local config_dir="${HOME}/.config/clamav-scan"
  ensure_dir_exists "$config_dir" || log "Failed to create config directory, using defaults" "WARNING"
  
  # Load path configurations
  load_path_configurations
  
  # Initialize path cache
  init_path_cache
  
  log "Path management system initialized" "SUCCESS"
  return 0
}

# Load path configurations from all sources
# Usage: load_path_configurations
load_path_configurations() {
  debug "Loading path configurations..."
  
  # Reset path arrays
  CONFIGURED_PATHS=()
  UNSAFE_PATHS=("${DEFAULT_UNSAFE_PATHS[@]}")
  PATH_OVERRIDES=()
  
  # Add system-specific unsafe paths
  UNSAFE_PATHS+=("${SYSTEM_UNSAFE_PATHS[@]}")
  
  # Load system-wide configuration if it exists
  if [ -f "$SYSTEM_PATHS_FILE" ]; then
    debug "Loading system paths configuration: $SYSTEM_PATHS_FILE"
    load_paths_from_file "$SYSTEM_PATHS_FILE"
  fi
  
  # Load default paths configuration if it exists
  if [ -f "$PATHS_CONFIG_FILE" ]; then
    debug "Loading default paths configuration: $PATHS_CONFIG_FILE"
    load_paths_from_file "$PATHS_CONFIG_FILE"
  else
    # Create default configuration if it doesn't exist
    create_default_paths_config
  fi
  
  # Load user overrides if they exist
  if [ -f "$PATHS_OVERRIDE_FILE" ]; then
    debug "Loading user path overrides: $PATHS_OVERRIDE_FILE"
    load_paths_from_file "$PATHS_OVERRIDE_FILE"
  fi
  
  # Apply environment variable overrides
  apply_path_environment_overrides
  
  debug "Path configurations loaded - ${#CONFIGURED_PATHS[@]} paths configured, ${#UNSAFE_PATHS[@]} unsafe paths"
  return 0
}

# Load paths from a configuration file
# Usage: load_paths_from_file config_file
load_paths_from_file() {
  local config_file="$1"
  
  if [ ! -f "$config_file" ]; then
    debug "Path configuration file not found: $config_file"
    return 1
  fi
  
  # Parse configuration file
  while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# || -z "$line" ]] && continue
    
    # Process configuration directives
    if [[ "$line" =~ ^path[[:space:]]*=[[:space:]]*(.+) ]]; then
      local path="${BASH_REMATCH[1]}"
      path=$(eval echo "$path") # Expand variables like $HOME
      CONFIGURED_PATHS+=("$path")
    elif [[ "$line" =~ ^unsafe[[:space:]]*=[[:space:]]*(.+) ]]; then
      local unsafe_path="${BASH_REMATCH[1]}"
      unsafe_path=$(eval echo "$unsafe_path") # Expand variables
      UNSAFE_PATHS+=("$unsafe_path")
    elif [[ "$line" =~ ^override[[:space:]]*=[[:space:]]*(.+) ]]; then
      local override="${BASH_REMATCH[1]}"
      PATH_OVERRIDES+=("$override")
    elif [[ "$line" =~ ^exclude[[:space:]]*=[[:space:]]*(.+) ]]; then
      local exclude_pattern="${BASH_REMATCH[1]}"
      EXCLUSION_PATTERNS+=("$exclude_pattern")
    fi
  done < "$config_file"
  
  return 0
}

# Create default paths configuration
# Usage: create_default_paths_config
create_default_paths_config() {
  debug "Creating default paths configuration"
  
  # Ensure directory exists
  local config_dir=$(dirname "$PATHS_CONFIG_FILE")
  if ! ensure_dir_exists "$config_dir"; then
    log "Failed to create paths configuration directory" "ERROR"
    return 1
  fi
  
  # Create the configuration file
  cat > "$PATHS_CONFIG_FILE" <<EOF || return 1
#================================================================
# ClamAV Scanner Paths Configuration
#================================================================
# This file configures paths for the ClamAV scanner to use.
#
# Format:
#   path = /path/to/scan         Define a path to be scanned
#   unsafe = /path/to/avoid      Define a path to never scan
#   override = source:target     Define a path override
#   exclude = pattern            Define an exclusion pattern
#================================================================

# Default scan paths
path = \$HOME

# Unsafe paths (never scanned)
unsafe = /dev/*
unsafe = /proc/*
unsafe = /sys/*
unsafe = */lost+found/*
unsafe = /private/var/vm/*
unsafe = /var/tmp/*

# Path overrides
override = /tmp:/private/tmp

# Exclusion patterns
exclude = \.git/
exclude = node_modules/
exclude = \.DS_Store
exclude = \.localized
exclude = *.iso
exclude = *.dmg
exclude = *.sparseimage
exclude = *.img
EOF
  
  # Set secure permissions
  chmod 644 "$PATHS_CONFIG_FILE" || true
  
  # Load the newly created configuration
  CONFIGURED_PATHS=("$HOME")
  
  log "Created default paths configuration at $PATHS_CONFIG_FILE" "INFO"
  return 0
}

# Apply environment variable overrides for paths
# Usage: apply_path_environment_overrides
apply_path_environment_overrides() {
  debug "Applying environment variable path overrides"
  
  # Add paths from environment variable if defined
  if [ -n "${CLAMAV_SCAN_PATHS:-}" ]; then
    IFS=: read -ra env_paths <<< "$CLAMAV_SCAN_PATHS"
    for path in "${env_paths[@]}"; do
      path=$(eval echo "$path") # Expand variables
      CONFIGURED_PATHS+=("$path")
      debug "Added path from environment: $path"
    done
  fi
  
  # Add unsafe paths from environment variable if defined
  if [ -n "${CLAMAV_UNSAFE_PATHS:-}" ]; then
    IFS=: read -ra env_unsafe_paths <<< "$CLAMAV_UNSAFE_PATHS"
    for path in "${env_unsafe_paths[@]}"; do
      path=$(eval echo "$path") # Expand variables
      UNSAFE_PATHS+=("$path")
      debug "Added unsafe path from environment: $path"
    done
  fi
  
  # Add path overrides from environment variable if defined
  if [ -n "${CLAMAV_PATH_OVERRIDES:-}" ]; then
    IFS=: read -ra env_overrides <<< "$CLAMAV_PATH_OVERRIDES"
    for override in "${env_overrides[@]}"; do
      PATH_OVERRIDES+=("$override")
      debug "Added path override from environment: $override"
    done
  fi
}

# Initialize path cache for faster path validation
# Usage: init_path_cache
init_path_cache() {
  # Only create cache if we have many paths to validate
  if [ ${#UNSAFE_PATHS[@]} -gt 10 ]; then
    debug "Initializing path cache"
    
    # Create cache directory if needed
    local cache_dir=$(dirname "$PATHS_CACHE_FILE")
    if ! ensure_dir_exists "$cache_dir"; then
      log "Failed to create paths cache directory" "WARNING"
      return 1
    fi
    
    # Build cache with normalized paths
    local cache_content="{"
    cache_content+='"unsafe_paths":['
    
    local first=true
    for path in "${UNSAFE_PATHS[@]}"; do
      if [ "$first" = true ]; then
        first=false
      else
        cache_content+=","
      fi
      # Normalize and escape the path for JSON
      local norm_path=$(normalize_path "$path")
      norm_path=${norm_path//\\/\\\\}
      norm_path=${norm_path//\"/\\\"}
      cache_content+="\"$norm_path\""
    done
    
    cache_content+='],'
    cache_content+='"overrides":{'
    
    first=true
    for override in "${PATH_OVERRIDES[@]}"; do
      if [[ "$override" == *:* ]]; then
        local src="${override%%:*}"
        local dst="${override#*:}"
        
        if [ "$first" = true ]; then
          first=false
        else
          cache_content+=","
        fi
        
        # Normalize and escape paths for JSON
        src=$(normalize_path "$src")
        src=${src//\\/\\\\}
        src=${src//\"/\\\"}
        
        dst=$(normalize_path "$dst")
        dst=${dst//\\/\\\\}
        dst=${dst//\"/\\\"}
        
        cache_content+="\"$src\":\"$dst\""
      fi
    done
    
    cache_content+='}'
    cache_content+='}'
    
    # Write cache file
    echo "$cache_content" > "$PATHS_CACHE_FILE" || {
      log "Failed to write paths cache file" "WARNING"
      return 1
    }
    
    chmod 644 "$PATHS_CACHE_FILE" || true
  fi
  
  return 0
}

#----------- Path Resolution and Validation -----------#

# Securely resolve a path, following symlinks but avoiding symlink attacks
# Usage: resolve_path path
# Returns: Resolved path or empty string if invalid
resolve_path() {
  local path="$1"
  
  # Expand any environment variables
  path=$(eval echo "$path")
  
  # Apply path overrides if matching
  local original_path="$path"
  for override in "${PATH_OVERRIDES[@]}"; do
    if [[ "$override" == *:* ]]; then
      local src="${override%%:*}"
      local dst="${override#*:}"
      
      # Check if path starts with the source pattern
      if [[ "$path" == "$src" || "$path" == "$src"/* ]]; then
        # Apply override
        path="${dst}${path#$src}"
        debug "Applied path override: $original_path -> $path"
        break
      fi
    fi
  done
  
  # For macOS, handle /tmp special case
  if [ "$(uname)" = "Darwin" ] && [[ "$path" == "/tmp" || "$path" == "/tmp/"* ]]; then
    path="/private$path"
    debug "Converted tmp path for macOS: $path"
  fi
  
  # First check if path exists
  if [ ! -e "$path" ]; then
    debug "Path does not exist: $path"
    echo ""
    return 1
  fi
  
  # Use readlink to securely resolve the path
  local resolved_path
  if command -v realpath >/dev/null 2>&1; then
    # Use realpath if available (most secure)
    resolved_path=$(realpath -q "$path" 2>/dev/null)
  elif command -v readlink >/dev/null 2>&1; then
    # Use readlink -f as fallback
    resolved_path=$(readlink -f "$path" 2>/dev/null)
  else
    # Fallback implementation for basic systems
    resolved_path=$(cd "$(dirname "$path")" && pwd -P)/$(basename "$path")
  fi
  
  # Validate resolved path
  if [ -z "$resolved_path" ]; then
    debug "Failed to resolve path: $path"
    echo ""
    return 1
  fi
  
  echo "$resolved_path"
  return 0
}

# Normalize a path to canonical form without resolving symlinks
# This is useful for pattern matching
# Usage: normalize_path path
# Returns: Normalized path string
normalize_path() {
  local path="$1"
  
  # Expand any environment variables
  path=$(eval echo "$path")
  
  # Remove duplicate slashes
  path=$(echo "$path" | sed 's|//|/|g')
  
  # Remove trailing slash unless it's the root
  if [ "$path" != "/" ]; then
    path=${path%/}
  fi
  
  echo "$path"
}

# Sanitize a path for use in shell commands
# Usage: sanitize_path path
# Returns: Sanitized path string
sanitize_path() {
  local path="$1"
  
  # Escape special characters
  path="${path//\\/\\\\}"  # Escape backslashes first
  path="${path//\"/\\\"}"  # Escape quotes
  path="${path//\$/\\\$}"  # Escape dollar signs
  path="${path//\`/\\\`}"  # Escape backticks
  path="${path//\!/\\\!}"  # Escape exclamation marks
  path="${path//\[/\\\[}"  # Escape square brackets
  path="${path//\]/\\\]}"
  path="${path//\{/\\\{}"  # Escape curly braces
  path="${path//\}/\\\}}"
  path="${path//\*/\\\*}"  # Escape wildcards
  path="${path//\?/\\\?}"
  path="${path//\(/\\\(}"  # Escape parentheses
  path="${path//\)/\\\)}"
  path="${path//\>/\\\>}"  # Escape angle brackets
  path="${path//\</\\\<}"
  path="${path//\|/\\\|}"  # Escape pipe
  path="${path//\&/\\\&}"  # Escape ampersand
  path="${path//\;/\\\;}"  # Escape semicolon
  path="${path//\ /\\\ }"  # Escape spaces
  
  echo "$path"
}

# Check if a path matches any unsafe patterns
# Usage: is_unsafe_path path
# Returns: 0 if unsafe, 1 if safe
is_unsafe_path() {
  local path="$1"
  
  # Normalize the path for comparison
  path=$(normalize_path "$path")
  
  # Check against unsafe patterns
  for unsafe in "${UNSAFE_PATHS[@]}"; do
    local pattern=$(normalize_path "$unsafe")
    
    # Convert glob pattern to regex
    pattern="${pattern//./\\.}"   # Escape dots
    pattern="${pattern//\*/.*}"   # Convert * to .*
    pattern="${pattern//\?/.}"    # Convert ? to .
    pattern="^${pattern}$"
    
    if [[ "$path" =~ $pattern ]]; then
      debug "Path matches unsafe pattern: $path ~ $unsafe"
      return 0
    fi
  done
  
  return 1
}

# Validate a path for scanning
# Usage: validate_scan_path path
# Returns: 0 if valid, non-zero otherwise
validate_scan_path() {
  local path="$1"
  
  # Skip empty paths
  if [ -z "$path" ]; then
    debug "Empty path provided"
    return 1
  }
  
  # Resolve the path securely
  local resolved_path
  resolved_path=$(resolve_path "$path") || {
    debug "Failed to resolve path: $path"
    return 1
  }
  
  # Check if path exists
  if [ ! -e "$resolved_path" ]; then
    debug "Path does not exist: $resolved_path"
    return 1
  }
  
  # Check if path is readable
  if [ ! -r "$resolved_path" ]; then
    debug "Path is not readable: $resolved_path"
    return 1
  }
  
  # Check if path is unsafe
  if is_unsafe_path "$resolved_path"; then
    debug "Path is marked as unsafe: $resolved_path"
    return 1
  }
  
  # For directories, check if we can traverse
  if [ -d "$resolved_path" ] && [ ! -x "$resolved_path" ]; then
    debug "Directory is not traversable: $resolved_path"
    return 1
  }
  
  return 0
}

# Process a pattern to make it compatible with clamscan
# Usage: format_pattern_for_clamscan pattern
# Returns: Formatted pattern string
format_pattern_for_clamscan() {
  local pattern="$1"
  
  # Remove any quotes around the pattern
  pattern="${pattern#\"}"
  pattern="${pattern%\"}"
  
  # Convert path-based patterns to use forward slashes
  pattern="${pattern//\\/\/}"
  
  # Remove duplicate slashes
  pattern=$(echo "$pattern" | sed 's|//|/|g')
  
  echo "$pattern"
}

# Get a list of valid scan paths after applying all rules and filters
# Usage: get_scan_paths [path...]
# Returns: List of valid scan paths
get_scan_paths() {
  local -a paths=("$@")
  local -a valid_paths=()
  
  # If no paths provided, use configured paths
  if [ ${#paths[@]} -eq 0 ]; then
    paths=("${CONFIGURED_PATHS[@]}")
  fi
  
  # Process each path
  for path in "${paths[@]}"; do
    # Skip empty paths
    [ -z "$path" ] && continue
    
    # Resolve and validate the path
    local resolved_path
    resolved_path=$(resolve_path "$path") || continue
    
    if validate_scan_path "$resolved_path"; then
      valid_paths+=("$resolved_path")
      debug "Added valid scan path: $resolved_path"
    else
      log "Skipping invalid path: $path" "WARNING"
    fi
  done
  
  # Ensure we have at least one valid path
  if [ ${#valid_paths[@]} -eq 0 ]; then
    log "No valid scan paths found" "ERROR"
    return 1
  fi
  
  # Print valid paths one per line
  printf "%s\n" "${valid_paths[@]}"
  return 0
}

# Check if a path is excluded by patterns
# Usage: is_excluded_path path
# Returns: 0 if excluded, 1 if not
is_excluded_path() {
  local path="$1"
  
  # Normalize the path for comparison
  path=$(normalize_path "$path")
  
  # Check against exclusion patterns
  for pattern in "${EXCLUSION_PATTERNS[@]}"; do
    # Convert pattern to shell glob if it's not already
    if [[ "$pattern" != *[\*\?\[\]]* ]]; then
      pattern="*${pattern}*"
    fi
    
    if [[ "$path" == $pattern ]]; then
      debug "Path matches exclusion pattern: $path ~ $pattern"
      return 0
    fi
  done
  
  return 1
}

# Generate exclusion file for clamscan from patterns
# Usage: generate_exclusion_file
# Returns: Path to the generated exclusion file
generate_exclusion_file() {
  local exclude_file
  exclude_file=$(mktemp -t "clamav-exclude.XXXXXX")
  
  debug "Creating exclusion file: $exclude_file"
  
  # Add patterns from configuration
  for pattern in "${EXCLUSION_PATTERNS[@]}"; do
    local formatted_pattern=$(format_pattern_for_clamscan "$pattern")
    echo "$formatted_pattern" >> "$exclude_file"
  done
  
  # Add unsafe paths
  for path in "${UNSAFE_PATHS[@]}"; do
    local formatted_path=$(format_pattern_for_clamscan "$path")
    echo "$formatted_path" >> "$exclude_file"
  done
  
  # Add system-specific exclusions
  if [ "$(uname)" = "Darwin" ]; then
    # macOS-specific exclusions
    cat >> "$exclude_file" <<EOF
/System/Volumes/Data/private/var/vm/
/private/var/vm/
/private/var/db/uuidtext/
/System/Library/Caches/
/Library/Caches/
/Users/*/Library/Caches/
EOF
  else
    # Linux-specific exclusions
    cat >> "$exclude_file" <<EOF
/proc/
/sys/
/dev/
/var/cache/
/var/log/
/var/lock/
/var/tmp/
/run/
EOF
  fi
  
  echo "$exclude_file"
}

# Generate path lists for scanner configuration
# Usage: generate_path_lists
# Outputs: Sets global variables with path lists
generate_path_lists() {
  debug "Generating path lists for scanner..."
  
  # Create arrays for scanner configuration
  SCAN_PATHS=()      # Paths to scan
  EXCLUDE_PATHS=()   # Paths to exclude
  PROTECT_PATHS=()   # Paths to protect from modification
  
  # Get valid scan paths
  while IFS= read -r path; do
    SCAN_PATHS+=("$path")
  done < <(get_scan_paths)
  
  # Build exclude paths list
  for path in "${UNSAFE_PATHS[@]}"; do
    path=$(normalize_path "$path")
    EXCLUDE_PATHS+=("$path")
  done
  
  # Add exclusion patterns
  for pattern in "${EXCLUSION_PATTERNS[@]}"; do
    EXCLUDE_PATHS+=("$pattern")
  done
  
  # Build protect paths list (system directories)
  for path in "${SYSTEM_PATHS[@]}"; do
    if [ -d "$path" ]; then
      PROTECT_PATHS+=("$path")
    fi
  done
  
  debug "Generated path lists - Scan: ${#SCAN_PATHS[@]}, Exclude: ${#EXCLUDE_PATHS[@]}, Protect: ${#PROTECT_PATHS[@]}"
  return 0
}

# Get available scan targets for the current user
# Usage: get_available_scan_targets
# Returns: List of recommended scan targets
get_available_scan_targets() {
  debug "Finding available scan targets..."
  local -a targets=()
  
  # Always include user's home directory if accessible
  if [ -r "$HOME" ]; then
    targets+=("$HOME")
  fi
  
  # Add standard locations based on OS
  if [ "$(uname)" = "Darwin" ]; then
    # macOS locations
    local mac_locations=(
      "/Applications"
      "$HOME/Applications"
      "$HOME/Downloads"
      "$HOME/Documents"
      "$HOME/Desktop"
    )
    
    for loc in "${mac_locations[@]}"; do
      if [ -r "$loc" ]; then
        targets+=("$loc")
      fi
    done
  else
    # Linux locations
    local linux_locations=(
      "$HOME/Downloads"
      "$HOME/Documents"
      "$HOME/Desktop"
      "/usr/local"
      "/opt"
    )
    
    for loc in "${linux_locations[@]}"; do
      if [ -r "$loc" ]; then
        targets+=("$loc")
      fi
    done
  fi
  
  # Print targets one per line
  printf "%s\n" "${targets[@]}"
  return 0
}

# Export functions and variables
export PATHS_LOADED=true
export -f resolve_path normalize_path sanitize_path
export -f is_unsafe_path validate_scan_path is_excluded_path
export -f get_scan_paths generate_path_lists get_available_scan_targets
