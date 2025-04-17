#!/bin/bash
#================================================================
# 🔧 Clammy Utilities Module
#================================================================
# General utility functions for Clammy
#================================================================

# Source the core library for shared functionality if not already loaded
if [ -z "${CORE_LOADED:-}" ]; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "$SCRIPT_DIR/core.sh" || {
    echo "Error: Failed to load core library from utils.sh. Exiting."
    exit 1
  }
fi

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

# Format duration for readable output
# Usage: format_duration start_time [end_time]
format_duration() {
  local start_time=$1
  local end_time=${2:-$(date +%s)}
  local duration=$((end_time - start_time))
  
  # Format the duration as hours, minutes, seconds
  local hours=$((duration / 3600))
  local minutes=$(( (duration % 3600) / 60 ))
  local seconds=$((duration % 60))
  
  # Format with appropriate units
  if [ $hours -gt 0 ]; then
    printf '%dh:%02dm:%02ds' $hours $minutes $seconds
  elif [ $minutes -gt 0 ]; then
    printf '%dm:%02ds' $minutes $seconds
  else
    printf '%ds' $seconds
  fi
}

# Display progress for the scanning process
# Usage: display_progress progress_file
display_progress() {
  local progress_file="$1"
  local spin='-\|/'
  local i=0
  
  # Function to clear progress line
  clear_progress_line() {
    printf "\r%-80s\r" " " >&2
  }
  
  echo "Progress display started" >&2
  
  while [ -f "$progress_file" ]; do
    i=$(( (i+1) % 4 ))
    local msg=$(cat "$progress_file" 2>/dev/null || echo "Scanning...")
    printf "\r[%c] %s " "${spin:$i:1}" "$msg" >&2
    sleep 0.5
  done
  
  # Clear the line when we're done
  clear_progress_line
  
  # Final message
  {
    printf "\033[1;32mProgress display completed.\033[0m\n" > /dev/tty 2>/dev/null || 
    printf "\033[1;32mProgress display completed.\033[0m\n" >&2
  }
}

# Create exclude file for clamscan with patterns to skip
# Usage: create_exclude_file
# Returns: Path to created exclude file
create_exclude_file() {
  local exclude_file
  
  # Create temporary file with a descriptive prefix
  exclude_file=$(mktemp -t "clammy-exclude.XXXXXX") || {
    log "Failed to create temporary exclusion file" "ERROR"
    return 1
  }
  
  debug "Created exclusion file: $exclude_file"
  
  # Combine default exclusions with user-specified ones
  local all_exclusions=("${EXCLUSION_PATTERNS[@]}")
  
  # Add user-specified exclusions
  if [ ${#USER_EXCLUSIONS[@]} -gt 0 ]; then
    all_exclusions+=("${USER_EXCLUSIONS[@]}")
  fi
  
  # Write each pattern on a separate line
  local valid_patterns=0
  local invalid_patterns=0
  
  for pattern in "${all_exclusions[@]}"; do
    # Skip empty patterns
    if [ -z "$pattern" ]; then
      invalid_patterns=$((invalid_patterns + 1))
      continue
    fi
    
    echo "$pattern" >> "$exclude_file" || {
      log "Failed to write pattern '$pattern' to exclusion file" "WARNING"
      invalid_patterns=$((invalid_patterns + 1))
    }
    valid_patterns=$((valid_patterns + 1))
  done
  
  # Report pattern statistics
  debug "Exclusion patterns: $valid_patterns valid, $invalid_patterns invalid"
  
  # Verify file was created successfully
  if [ ! -f "$exclude_file" ]; then
    log "Failed to create exclusion file" "ERROR"
    return 1
  fi
  
  echo "$exclude_file"
}

# Export module marker
UTILS_LOADED=true

