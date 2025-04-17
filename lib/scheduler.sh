#!/bin/bash
#================================================================
# 🕒 Clammy Scheduler
#================================================================
# Scheduling and automation support for Clammy
#================================================================

# Exit on error, undefined variables, and handle pipes properly
set -euo pipefail

# Source the core library for shared functionality if not already loaded
if [ -z "${CORE_LOADED:-}" ]; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "$SCRIPT_DIR/core.sh" || {
    echo "Error: Failed to load core library from scheduler.sh. Exiting." >&2
    exit 1
  }
fi

# Source platform module if not already loaded
if [ -z "${PLATFORM_LOADED:-}" ]; then
  source "$SCRIPT_DIR/platform.sh" || {
    echo "Error: Failed to load platform library from scheduler.sh. Exiting." >&2
    exit 1
  }
fi

# Global variables for scheduler
SCHEDULER_CONFIG_DIR="${HOME}/.config/clammy/schedules"
SCHEDULER_PROFILES_DIR="${SCHEDULER_CONFIG_DIR}/profiles"
SCHEDULER_STATE_FILE="${SECURITY_DIR}/scheduler_state.json"
SCHEDULER_LOG_FILE="${LOG_DIR}/scheduler.log"

#----------- Scheduler Initialization -----------#

# Initialize the scheduler system
# Usage: init_scheduler
init_scheduler() {
  log "Initializing scheduler system..." "INFO"
  
  # Create necessary directories
  ensure_dir_exists "$SCHEDULER_CONFIG_DIR" || return 1
  ensure_dir_exists "$SCHEDULER_PROFILES_DIR" || return 1
  
  # Initialize state file if needed
  if [ ! -f "$SCHEDULER_STATE_FILE" ]; then
    echo '{
  "schedules": [],
  "last_run": {},
  "next_run": {}
}' > "$SCHEDULER_STATE_FILE" || {
      local plist_file="$HOME/Library/LaunchAgents/com.clammy.${schedule_id}.plist"
      return 1
    }
    chmod 600 "$SCHEDULER_STATE_FILE" || true
  fi
  
  # Create default scan profiles if they don't exist
  create_default_scan_profiles
  
  log "Scheduler system initialized" "SUCCESS"
  return 0
}

# Create default scan profiles
# Usage: create_default_scan_profiles
create_default_scan_profiles() {
  # Quick scan profile
  if [ ! -f "${SCHEDULER_PROFILES_DIR}/quick_scan.conf" ]; then
    cat > "${SCHEDULER_PROFILES_DIR}/quick_scan.conf" <<EOF
# Quick Scan Profile
# Scans common infection points and recently modified files

name = Quick Scan
description = Fast scan of common infection points and recent downloads
targets = [
  "\$HOME/Downloads",
  "\$HOME/Desktop",
  "\$HOME/Documents"
]
options = [
  "--detect-pua=yes",
  "--max-filesize=100M",
  "--max-scansize=100M"
]
exclude_patterns = [
  "*.iso",
  "*.dmg",
  "node_modules",
  ".git"
]
EOF
  fi

  # Full scan profile
  if [ ! -f "${SCHEDULER_PROFILES_DIR}/full_scan.conf" ]; then
    cat > "${SCHEDULER_PROFILES_DIR}/full_scan.conf" <<EOF
# Full Scan Profile
# Comprehensive system scan

name = Full System Scan
description = Complete scan of all accessible files
targets = [
  "\$HOME"
]
options = [
  "--detect-pua=yes",
  "--scan-archive=yes",
  "--max-filesize=500M",
  "--max-scansize=500M"
]
exclude_patterns = [
  "*.iso",
  "*.dmg",
  "*.vdi",
  "*.vmdk",
  "node_modules",
  ".git",
  "Library/Caches",
  "Library/Application Support/Steam"
]
EOF
  fi

  # Custom scan profile template
  if [ ! -f "${SCHEDULER_PROFILES_DIR}/custom_scan_template.conf" ]; then
    cat > "${SCHEDULER_PROFILES_DIR}/custom_scan_template.conf" <<EOF
# Custom Scan Profile Template
# Customize this template for your specific needs

name = Custom Scan
description = User-defined scan configuration
targets = [
  # Add your scan targets here
  #"\$HOME/path/to/scan"
]
options = [
  "--detect-pua=yes",
  "--max-filesize=100M",
  "--max-scansize=100M"
]
exclude_patterns = [
  # Add your exclusion patterns here
  #"*.extension",
  #"pattern/*"
]
EOF
  fi
}

#----------- Scheduler Management -----------#

# Add a new scheduled scan
# Usage: add_scheduled_scan profile schedule [name] [description]
# Example: add_scheduled_scan quick_scan "0 3 * * *" "Nightly Quick Scan" "Runs every night at 3 AM"
add_scheduled_scan() {
  local profile="$1"
  local schedule="$2"
  local name="${3:-Scheduled Scan}"
  local description="${4:-Automated scan using $profile profile}"
  
  # Validate profile exists
  local profile_file="${SCHEDULER_PROFILES_DIR}/${profile}.conf"
  if [ ! -f "$profile_file" ]; then
    log "Profile not found: $profile" "ERROR"
    echo "Available profiles:"
    list_scan_profiles
    return 1
  fi
  
  # Validate cron schedule format
  if ! verify_cron_format "$schedule"; then
    log "Invalid schedule format: $schedule" "ERROR"
    echo "Schedule must be in cron format: minute hour day-of-month month day-of-week"
    echo "Example: \"0 3 * * *\" for daily at 3:00 AM"
    return 1
  }
  
  # Generate unique ID for the schedule
  local schedule_id="scan_$(date +%s)_$$"
  
  # Create schedule configuration
  local schedule_file="${SCHEDULER_CONFIG_DIR}/${schedule_id}.conf"
  cat > "$schedule_file" <<EOF
# Scheduled Scan Configuration
name = $name
description = $description
profile = $profile
schedule = $schedule
enabled = true
notify = true
quarantine = true
last_modified = $(date +%s)
EOF
  
  # Add to scheduler state
  if command -v jq >/dev/null 2>&1; then
    local temp_state
    temp_state=$(mktemp)
    jq --arg id "$schedule_id" --arg next "$(get_next_run_time "$schedule")" '
      .schedules += [$id] |
      .next_run[$id] = $next
    ' "$SCHEDULER_STATE_FILE" > "$temp_state" && mv "$temp_state" "$SCHEDULER_STATE_FILE"
  else
    # Fallback if jq not available
    log "jq not available, state tracking limited" "WARNING"
  fi
  
  # Add to system scheduler
  case "$PLATFORM_OS" in
    Darwin)
      # Create launchd plist
      create_launchd_schedule "$schedule_id" "$schedule" "$profile"
      ;;
    Linux)
      # Create crontab entry
      create_crontab_schedule "$schedule_id" "$schedule" "$profile"
      ;;
    *)
      local plist_file="$HOME/Library/LaunchAgents/com.clammy.${schedule_id}.plist"
      return 1
      ;;
  esac
  
  log "Added scheduled scan: $name ($schedule_id)" "SUCCESS"
  echo "Schedule ID: $schedule_id"
  echo "Name: $name"
  echo "Profile: $profile"
  echo "Schedule: $schedule"
  return 0
}

# Remove a scheduled scan
# Usage: remove_scheduled_scan schedule_id
remove_scheduled_scan() {
  local schedule_id="$1"
  local schedule_file="${SCHEDULER_CONFIG_DIR}/${schedule_id}.conf"
  
  if [ ! -f "$schedule_file" ]; then
    log "Schedule not found: $schedule_id" "ERROR"
    return 1
  fi
  
  # Remove from system scheduler
  case "$PLATFORM_OS" in
    Darwin)
      # Remove launchd job
      local plist_file="$HOME/Library/LaunchAgents/com.clammy.${schedule_id}.plist"
      if [ -f "$plist_file" ]; then
        launchctl unload "$plist_file" 2>/dev/null || true
        rm -f "$plist_file"
      fi
      ;;
    Linux)
      # Remove from crontab
      if command -v crontab >/dev/null 2>&1; then
        (crontab -l 2>/dev/null | grep -v "clammy.*${schedule_id}" | crontab -) || true
      fi
      ;;
  esac
  
  # Remove schedule file
  rm -f "$schedule_file"
  
  # Update scheduler state
  if command -v jq >/dev/null 2>&1; then
    local temp_state
    temp_state=$(mktemp)
    jq --arg id "$schedule_id" '
      .schedules = (.schedules | map(select(. != $id))) |
      del(.last_run[$id]) |
      del(.next_run[$id])
    ' "$SCHEDULER_STATE_FILE" > "$temp_state" && mv "$temp_state" "$SCHEDULER_STATE_FILE"
  fi
  
  log "Removed scheduled scan: $schedule_id" "SUCCESS"
  return 0
}

# List all scheduled scans
# Usage: list_scheduled_scans
list_scheduled_scans() {
  echo "Scheduled Scans:"
  echo "================"
  
  # Check if any schedules exist
  local schedule_files
  schedule_files=$(find "$SCHEDULER_CONFIG_DIR" -maxdepth 1 -name "*.conf" 2>/dev/null || echo "")
  
  if [ -z "$schedule_files" ]; then
    echo "No scheduled scans configured."
    return 0
  fi
  
  # Get current time
  local current_time
  current_time=$(date +%s)
  
  # Process each schedule file
  find "$SCHEDULER_CONFIG_DIR" -maxdepth 1 -name "*.conf" | while read -r config_file; do
    local id
    id=$(basename "$config_file" .conf)
    
    # Skip if it's a profile directory
    [ "$id" = "profiles" ] && continue
    
    local name
    local schedule
    local profile
    local enabled
    local next_run
    
    name=$(grep '^name = ' "$config_file" | cut -d'=' -f2- | sed 's/^ *//')
    schedule=$(grep '^schedule = ' "$config_file" | cut -d'=' -f2- | sed 's/^ *//')
    profile=$(grep '^profile = ' "$config_file" | cut -d'=' -f2- | sed 's/^ *//')
    enabled=$(grep '^enabled = ' "$config_file" | cut -d'=' -f2- | sed 's/^ *//')
    
    # Get next run time
    if command -v jq >/dev/null 2>&1 && [ -f "$SCHEDULER_STATE_FILE" ]; then
      next_run=$(jq -r --arg id "$id" '.next_run[$id] // empty' "$SCHEDULER_STATE_FILE" 2>/dev/null || echo "")
    else
      next_run=$(get_next_run_time "$schedule")
    fi
    
    # Format next run time
    if [ -n "$next_run" ]; then
      next_run_fmt=$(date -r "$next_run" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -d "@$next_run" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Unknown")
    else
      next_run_fmt="Unknown"
    fi
    
    echo "ID: $id"
    echo "Name: $name"
    echo "Profile: $profile"
    echo "Schedule: $schedule"
    echo "Enabled: $enabled"
    echo "Next Run: $next_run_fmt"
    echo "----------------------------------------"
  done
}

# Enable or disable a scheduled scan
# Usage: toggle_scheduled_scan schedule_id [enable|disable]
toggle_scheduled_scan() {
  local schedule_id="$1"
  local action="${2:-toggle}"
  local schedule_file="${SCHEDULER_CONFIG_DIR}/${schedule_id}.conf"
  
  if [ ! -f "$schedule_file" ]; then
    log "Schedule not found: $schedule_id" "ERROR"
    return 1
  fi
  
  local current_state
  current_state=$(grep '^enabled = ' "$schedule_file" | cut -d'=' -f2- | sed 's/^ *//')
  
  local new_state
  case "$action" in
    enable)
      new_state="true"
      ;;
    disable)
      new_state="false"
      ;;
    toggle)
      if [ "$current_state" = "true" ]; then
        new_state="false"
      else
        new_state="true"
      fi
      ;;
    *)
      log "Invalid action: $action" "ERROR"
      echo "Valid actions: enable, disable, toggle"
      return 1
      ;;
  esac
  
  # Update configuration file
  sed -i.bak "s/^enabled = .*/enabled = $new_state/" "$schedule_file" && rm -f "${schedule_file}.bak"
  
  # Apply changes to system scheduler
  case "$PLATFORM_OS" in
    Darwin)
      local plist_file="$HOME/Library/LaunchAgents/com.clammy.${schedule_id}.plist"
      if [ -f "$plist_file" ]; then
        if [ "$new_state" = "true" ]; then
          launchctl load "$plist_file" 2>/dev/null || true
        else
          launchctl unload "$plist_file" 2>/dev/null || true
        fi
      fi
      ;;
    Linux)
      # For Linux, we need to recreate the crontab entry
      local schedule
      local profile
      schedule=$(grep '^schedule = ' "$schedule_file" | cut -d'=' -f2- | sed 's/^ *//')
      profile=$(grep '^profile = ' "$schedule_file" | cut -d'=' -f2- | sed 's/^ *//')
      
      # If new state is enabled, add the entry; otherwise remove it
      if [ "$new_state" = "true" ]; then
        create_crontab_schedule "$schedule_id" "$schedule" "$profile"
      else
        (crontab -l 2>/dev/null | grep -v "clammy.*${schedule_id}" | crontab -) || true
      fi
      ;;
  esac
  
  log "Schedule $schedule_id ${new_state}d" "SUCCESS"
  return 0
}

# List available scan profiles
# Usage: list_scan_profiles
list_scan_profiles() {
  echo "Available Scan Profiles:"
  echo "======================="
  
  find "$SCHEDULER_PROFILES_DIR" -name "*.conf" | while read -r profile_file; do
    local profile_name
    local profile_description
    local profile_id
    
    profile_id=$(basename "$profile_file" .conf)
    profile_name=$(grep '^name = ' "$profile_file" | cut -d'=' -f2- | sed 's/^ *//')
    profile_description=$(grep '^description = ' "$profile_file" | cut -d'=' -f2- | sed 's/^ *//')
    
    if [[ "$profile_id" != *"template"* ]]; then  # Skip template files in regular listing
      echo "ID: $profile_id"
      echo "Name: ${profile_name:-Unknown}"
      echo "Description: ${profile_description:-No description available}"
      echo "------------------------------------------"
    fi
  done
  
  return 0
}

# Create a launchd schedule entry
# Usage: create_launchd_schedule schedule_id cron_schedule profile
create_launchd_schedule() {
  local schedule_id="$1"
  local cron_schedule="$2"
  local profile="$3"
  
  # Convert cron schedule to launchd schedule
  local minute hour dom month dow
  read -r minute hour dom month dow <<< "$cron_schedule"
  
  # Create plist file
  local plist_dir="$HOME/Library/LaunchAgents"
  local plist_file="$plist_dir/com.clammy.$schedule_id.plist"
  
  # Ensure directory exists
  mkdir -p "$plist_dir" 2>/dev/null || {
    log "Failed to create LaunchAgents directory" "ERROR"
    return 1
  }
  
  # Create the plist
  cat > "$plist_file" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.clammy.$schedule_id</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(which bash)</string>
        <string>-c</string>
        <string>$SCRIPT_DIR/../scan.sh --profile $profile</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
EOF
  
  # Add schedule components
  [ "$minute" != "*" ] && echo "        <key>Minute</key>\n        <integer>$minute</integer>" >> "$plist_file"
  [ "$hour" != "*" ] && echo "        <key>Hour</key>\n        <integer>$hour</integer>" >> "$plist_file"
  [ "$dom" != "*" ] && echo "        <key>Day</key>\n        <integer>$dom</integer>" >> "$plist_file"
  [ "$month" != "*" ] && echo "        <key>Month</key>\n        <integer>$month</integer>" >> "$plist_file"
  [ "$dow" != "*" ] && echo "        <key>Weekday</key>\n        <integer>$dow</integer>" >> "$plist_file"
  
  # Complete the plist
  cat >> "$plist_file" <<EOF
    </dict>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/schedule_$schedule_id.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/schedule_$schedule_id.err</string>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF
  
  # Load the plist
  launchctl load "$plist_file" 2>/dev/null || {
    log "Failed to load launchd job: $schedule_id" "WARNING"
  }
  
  log "Created launchd schedule: $schedule_id" "SUCCESS"
  return 0
}

# Create a crontab schedule entry
# Usage: create_crontab_schedule schedule_id cron_schedule profile
create_crontab_schedule() {
  local schedule_id="$1"
  local cron_schedule="$2"
  local profile="$3"
  
  if ! command -v crontab >/dev/null 2>&1; then
    log "crontab command not found, cannot schedule" "ERROR"
    return 1
  }
  
  # Create the crontab entry
  local crontab_entry="$cron_schedule $SCRIPT_DIR/../scan.sh --profile $profile --log-to-file $LOG_DIR/schedule_$schedule_id.log # clammy:$schedule_id"
  
  # Add to crontab
  (crontab -l 2>/dev/null || echo "") | grep -v "clammy:$schedule_id" | { cat; echo "$crontab_entry"; } | crontab -
  
  log "Created crontab schedule: $schedule_id" "SUCCESS"
  return 0
}

# Verify cron schedule format
# Usage: verify_cron_format "schedule"
# Returns: 0 if valid, 1 if invalid
verify_cron_format() {
  local schedule="$1"
  local parts
  
  # Simple validation - check for 5 parts
  IFS=' ' read -ra parts <<< "$schedule"
  if [ ${#parts[@]} -ne 5 ]; then
    return 1
  }
  
  # TODO: Add more detailed validation if needed
  
  return 0
}

# Get next run time for a cron schedule
# Usage: get_next_run_time "schedule"
get_next_run_time() {
  local schedule="$1"
  local next_run
  
  # Different approaches based on available tools
  if command -v next-cron-time >/dev/null 2>&1; then
    next_run=$(next-cron-time "$schedule" 2>/dev/null)
  elif command -v ncron >/dev/null 2>&1; then
    next_run=$(ncron "$schedule" 2>/dev/null)
  else
    # Simple approximation - just return now + 1 day
    next_run=$(($(date +%s) + 86400))
  }
  
  echo "$next_run"
}

# Export module marker
SCHEDULER_LOADED=true
