#!/bin/bash
#================================================================
# 🔍 Clammy Consolidated Scan Implementation
#================================================================
# Enhanced scanning functionality with improved error handling,
# path management, and state tracking
#================================================================

# Exit on error, undefined variables, and handle pipes properly
set -euo pipefail

# Source the core library for shared functionality if not already loaded
if [ -z "${CORE_LOADED:-}" ]; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "$SCRIPT_DIR/core.sh" || {
    echo "Error: Failed to load core library from scan_consolidated.sh. Exiting." >&2
    exit 1
  }
fi

# Source utilities module if not already loaded
if [ -z "${UTILS_LOADED:-}" ]; then
  source "$SCRIPT_DIR/utils.sh" || {
    echo "Error: Failed to load utils library from scan_consolidated.sh. Exiting." >&2
    exit 1
  }
fi

# Source quarantine module if not already loaded
if [ -z "${QUARANTINE_LOADED:-}" ]; then
  source "$SCRIPT_DIR/quarantine.sh" 2>/dev/null || {
    debug "Quarantine module not available, quarantine functionality will be limited"
  }
fi

# Global variables for scan state tracking
SCAN_ID=""
SCAN_START_TIME=0
SCAN_END_TIME=0
SCAN_STATUS=0
TEMP_FILES=()
PROGRESS_PID=""
SCAN_STATE_FILE="${SECURITY_DIR:-${HOME}/Security}/scan_state.json"

#----------- Cleanup Functions -----------#

# Cleanup function to handle all temporary resources
# This ensures resources are freed even if the script terminates unexpectedly
cleanup() {
  local exit_code=$?
  debug "Running cleanup handler (exit code: $exit_code)"
  
  # Kill progress display if running
  if [ -n "${PROGRESS_PID:-}" ] && kill -0 "$PROGRESS_PID" 2>/dev/null; then
    debug "Stopping progress display (PID: $PROGRESS_PID)"
    kill "$PROGRESS_PID" 2>/dev/null || true
    wait "$PROGRESS_PID" 2>/dev/null || true
  fi
  
  # Remove temporary files
  for temp_file in "${TEMP_FILES[@]:-}"; do
    if [ -f "$temp_file" ]; then
      debug "Removing temporary file: $temp_file"
      rm -f "$temp_file" 2>/dev/null || debug "Failed to remove temp file: $temp_file"
    fi
  done
  
  # Update scan state to reflect completion
  if [ -n "${SCAN_ID:-}" ]; then
    update_scan_state "completed" "$exit_code"
  fi
  
  # Final logging
  if [ $exit_code -eq 0 ]; then
    debug "Cleanup completed successfully"
  else
    debug "Cleanup completed with exit code: $exit_code"
  fi
}

# Register cleanup handler for script exit
trap cleanup EXIT

#----------- Scan State Tracking -----------#

# Initialize a new scan session with unique ID and timestamps
# Usage: init_scan [--resume id]
init_scan() {
  local resume_id=""
  
  # Parse arguments
  while [ $# -gt 0 ]; do
    case "$1" in
      --resume)
        resume_id="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done
  
  if [ -n "$resume_id" ]; then
    # Resuming an existing scan
    SCAN_ID="$resume_id"
    log "Resuming scan: $SCAN_ID" "INFO"
    
    # Load previous scan state if available
    if [ -f "$SCAN_STATE_FILE" ]; then
      local prev_state
      prev_state=$(grep -A5 "\"scan_id\": \"$SCAN_ID\"" "$SCAN_STATE_FILE" 2>/dev/null)
      if [ -n "$prev_state" ]; then
        debug "Found previous state for scan: $SCAN_ID"
      else
        log "No state found for scan ID: $SCAN_ID" "WARNING"
      fi
    fi
  else
    # Generate new scan ID using timestamp and random component
    SCAN_ID="scan_$(date +%Y%m%d_%H%M%S)_$$"
    log "Initialized new scan: $SCAN_ID" "INFO"
  fi
  
  # Record scan start time
  SCAN_START_TIME=$(date +%s)
  
  # Initialize scan state
  update_scan_state "initialized"
  
  return 0
}

# Update the scan state in the state tracking file
# Usage: update_scan_state state [status]
update_scan_state() {
  local state="$1"
  local status="${2:-0}"
  local timestamp=$(date +%s)
  
  # Ensure state tracking directory exists
  local state_dir=$(dirname "$SCAN_STATE_FILE")
  if [ ! -d "$state_dir" ]; then
    mkdir -p "$state_dir" 2>/dev/null || {
      debug "Failed to create state directory: $state_dir"
      return 1
    }
  fi
  
  # Create state entry in JSON format
  local state_entry
  state_entry=$(cat <<EOF
{
  "scan_id": "$SCAN_ID",
  "state": "$state",
  "status": $status,
  "timestamp": $timestamp,
  "targets": "${SCAN_TARGETS[*]:-}"
}
EOF
)
  
  # Append to state file with header if needed
  if [ ! -f "$SCAN_STATE_FILE" ]; then
    echo '[' > "$SCAN_STATE_FILE" || return 1
    echo "$state_entry" >> "$SCAN_STATE_FILE" || return 1
    echo ']' >> "$SCAN_STATE_FILE" || return 1
  else
    # Insert new state entry properly
    local file_size=$(stat -f%z "$SCAN_STATE_FILE" 2>/dev/null || stat -c%s "$SCAN_STATE_FILE")
    if [ "$file_size" -lt 10 ]; then
      # Initialize file if empty or corrupted
      echo '[' > "$SCAN_STATE_FILE" || return 1
      echo "$state_entry" >> "$SCAN_STATE_FILE" || return 1
      echo ']' >> "$SCAN_STATE_FILE" || return 1
    else
      # Update existing state file
      sed -i.bak -e '$d' "$SCAN_STATE_FILE" 2>/dev/null || {
        sed -i -e '$d' "$SCAN_STATE_FILE" 2>/dev/null || return 1
      }
      echo ",$state_entry" >> "$SCAN_STATE_FILE" || return 1
      echo ']' >> "$SCAN_STATE_FILE" || return 1
    fi
  fi
  
  debug "Updated scan state: $state (status: $status)"
  return 0
}

#----------- Scan Functions -----------#

# Update virus definitions before scanning
# Usage: update_virus_definitions
update_virus_definitions() {
  log "Updating virus definitions..." "SCAN"
  printf "  🔄 Updating ClamAV virus definitions..."
  
  # Ensure database directory exists and is writable
  if [ ! -d "$CLAMAV_DB_DIR" ]; then
    mkdir -p "$CLAMAV_DB_DIR" 2>/dev/null || {
      printf " \033[1;31m✗\033[0m\n"
      log "Error: ClamAV database directory does not exist and cannot be created: $CLAMAV_DB_DIR" "ERROR"
      return 1
    }
  elif [ ! -w "$CLAMAV_DB_DIR" ]; then
    printf " \033[1;31m✗\033[0m\n"
    log "Error: ClamAV database directory is not writable: $CLAMAV_DB_DIR" "ERROR"
    return 1
  fi
  
  # Run freshclam with timeout to prevent hanging
  if command -v timeout >/dev/null 2>&1; then
    if timeout 300 freshclam --quiet; then
      printf " \033[1;32m✓\033[0m\n"
      log "Virus definitions updated successfully" "SUCCESS"
    else
      local status=$?
      if [ $status -eq 124 ]; then
        printf " \033[1;33m⚠️\033[0m\n"
        log "Timeout while updating virus definitions" "WARNING"
      else
        printf " \033[1;33m⚠️\033[0m\n"
        log "Error updating virus definitions (status: $status)" "WARNING"
      fi
      printf "  \033[1;33m⚠️ Using existing virus definitions. Consider running 'freshclam' manually.\033[0m\n"
    fi
  else
    # Run without timeout if timeout command not available
    if freshclam --quiet; then
      printf " \033[1;32m✓\033[0m\n"
      log "Virus definitions updated successfully" "SUCCESS"
    else
      printf " \033[1;33m⚠️\033[0m\n"
      log "Error updating virus definitions, continuing with existing definitions" "WARNING"
      printf "  \033[1;33m⚠️ Using existing virus definitions. Consider running 'freshclam' manually.\033[0m\n"
    fi
  fi
  
  return 0
}

# Create file with exclusion patterns for clamscan
# Usage: create_exclude_file
# Returns: Path to the exclusion file
create_exclude_file() {
  local exclude_file
  exclude_file=$(mktemp -t "clamav-exclude.XXXXXX")
  TEMP_FILES+=("$exclude_file")
  
  debug "Creating exclusion file: $exclude_file"
  
  # Add default patterns
  for pattern in "${EXCLUSION_PATTERNS[@]}"; do
    echo "$pattern" >> "$exclude_file"
  done
  
  # Add system-specific exclusions
  if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS-specific exclusions
    cat >> "$exclude_file" <<EOF
/System/Volumes/Data/private/var/vm/
/private/var/vm/
/private/var/db/uuidtext/
/Library/Caches/
/System/Library/Caches/
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

# Validate and prepare scan targets with proper path handling
# Usage: prepare_scan_targets target1 [target2...]
# Returns: 0 on success, non-zero on error
prepare_scan_targets() {
  debug "Preparing scan targets"
  
  # Reset scan targets array
  SCAN_TARGETS=()
  
  # Process each target
  for target in "$@"; do
    # Use readlink to follow symlinks and get canonical path
    local real_path
    real_path=$(readlink -f "$target" 2>/dev/null || echo "$target")
    
    # Skip non-existent targets
    if [ ! -e "$real_path" ]; then
      log "Warning: Target does not exist: $target" "WARNING"
      continue
    fi
    
    # Handle paths with spaces and special characters
    if [[ "$real_path" == *[[:space:]]* || "$real_path" == *['\"'\$\(\)\[\]\{\}\;\<\>\&\|\#\*\?\!\^]* ]]; then
      debug "Target path contains special characters: $real_path"
      # Properly quote the path
      real_path="${real_path//\"/\\\"}"
    fi
    
    # Handle paths specifically for macOS /tmp (which is symlinked to /private/tmp)
    if [ "$OS_TYPE" = "Darwin" ] && [[ "$real_path" == "/tmp/"* ]]; then
      real_path="/private${real_path}"
      debug "Converted tmp path for macOS: $real_path"
    fi
    
    # Add to targets array
    SCAN_TARGETS+=("$real_path")
    debug "Added target: $real_path"
  done
  
  # Verify we have at least one valid target
  if [ ${#SCAN_TARGETS[@]} -eq 0 ]; then
    log "Error: No valid scan targets found" "ERROR"
    return 1
  fi
  
  log "Prepared ${#SCAN_TARGETS[@]} scan targets" "INFO"
  return 0
}

# Display scan progress in a background process
# Usage: display_progress progress_file
display_progress() {
  local progress_file="$1"
  local prev_content=""
  local dots=0
  
  # Ensure the terminal supports cursor movement
  if ! tput cuu1 >/dev/null 2>&1; then
    # Simple non-animated display for limited terminals
    tail -f "$progress_file" 2>/dev/null &
    return
  fi
  
  while true; do
    # Read current progress
    if [ -f "$progress_file" ]; then
      local content
      content=$(cat "$progress_file" 2>/dev/null || echo "Scanning...")
      
      # Only update display if content changed
      if [ "$content" != "$prev_content" ]; then
        tput sc # Save cursor position
        tput civis # Hide cursor
        tput cuu1 2>/dev/null || true # Move up one line if possible
        tput el # Clear the line
        dots=$(( (dots + 1) % 4 ))
        local dot_str=$(printf "%*s" $dots | tr ' ' '.')
        printf "  🔍 %s%s\r" "$content" "$dot_str"
        tput rc # Restore cursor position
        tput cnorm # Show cursor
        prev_content="$content"
      fi
    fi
    
    sleep 0.2
  done
}

# Run the ClamAV scan with the configured options
# Usage: run_scan
# Returns: Scan exit code (0: no threats, 1: threats found, 2: error)
run_scan() {
  log "Starting ClamAV scan..." "SCAN"
  echo "========================================"
  echo "Starting ClamAV scan on ${#SCAN_TARGETS[@]} targets"
  echo "- Excluded patterns: ${#EXCLUSION_PATTERNS[@]} patterns defined"
  echo "- Maximum file size to scan: ${MAX_FILE_SIZE}MB"
  if [ "$QUARANTINE_ENABLED" = "true" ]; then
    echo "- Quarantine: Enabled (${QUARANTINE_DIR})"
  else
    echo "- Quarantine: Disabled"
  fi
  echo "========================================"
  
  # Create exclusion file for clamscan
  EXCLUDE_FILE=$(create_exclude_file)
  if [ ! -f "$EXCLUDE_FILE" ]; then
    log "Error: Failed to create exclusion file!" "ERROR"
    return $EXIT_SCAN_ERROR
  fi
  
  # Create progress tracking file
  PROGRESS_FILE=$(mktemp -t "clamav-progress.XXXXXX")
  TEMP_FILES+=("$PROGRESS_FILE")
  
  if [ ! -f "$PROGRESS_FILE" ]; then
    log "Warning: Failed to create progress file. Progress display will be disabled." "WARNING"
  else
    chmod 644 "$PROGRESS_FILE" || true
    echo "Initializing scan..." > "$PROGRESS_FILE"
  fi
  
  # Create scan output file
  SCAN_OUTPUT_FILE=$(mktemp -t "clamav-scan-output.XXXXXX")
  TEMP_FILES+=("$SCAN_OUTPUT_FILE")
  
  if [ ! -f "$SCAN_OUTPUT_FILE" ]; then
    log "Error: Failed to create scan output file" "ERROR"
    return $EXIT_SCAN_ERROR
  fi
  
  # Start progress display in background if not in verbose mode
  if [ "${VERBOSE:-false}" != "true" ] && [ -n "$PROGRESS_FILE" ]; then
    display_progress "$PROGRESS_FILE" &
    PROGRESS_PID=$!
    echo "$PROGRESS_PID" > "${PROGRESS_FILE}.pid"
    debug "Started progress display with PID: $PROGRESS_PID"
  fi
  
  # Setup clamscan options
  local -a scan_options=(
    --recursive                 # Scan directories recursively
    --infected                  # Only print infected files
    --stdout                    # Force output to stdout
    "--exclude-dir=${SYS_DEV_PATH:-/dev}"       # Don't scan device files
    "--exclude-dir=${SYS_PROC_PATH:-/proc}"     # Don't scan proc
    "--exclude-dir=/sys"                        # Don't scan sysfs
    "--exclude-dir=${SYS_VAR_VM_PATH:-/var/vm}" # Don't scan VM files
    "--max-filesize=${MAX_FILE_SIZE}"           # Skip large files
    "--max-scansize=${MAX_FILE_SIZE}"           # Maximum scan size
    "--exclude-dir=${QUARANTINE_DIR}"           # Don't scan quarantine
  )
  
  # Add exclusion file if available
  if [ -f "$EXCLUDE_FILE" ]; then
    scan_options+=("--exclude-dir=@${EXCLUDE_FILE}")
  fi
  
  # Add quarantine options if enabled
  if [ "$QUARANTINE_ENABLED" = "true" ]; then
    # Create temporary quarantine directory if needed
    TEMP_QUARANTINE_DIR="${QUARANTINE_DIR}/tmp"
    if [ ! -d "$TEMP_QUARANTINE_DIR" ]; then
      mkdir -p "$TEMP_QUARANTINE_DIR" 2>/dev/null || {
        log "Error: Failed to create temporary quarantine directory: $TEMP_QUARANTINE_DIR" "ERROR"
        return $EXIT_QUARANTINE_ERROR
      }
    fi
    scan_options+=("--move=${TEMP_QUARANTINE_DIR}")
  fi
  
  # Show scan command in verbose mode
  if [ "${VERBOSE:-false}" = "true" ]; then
    debug "Running: clamscan ${scan_options[*]} ${SCAN_TARGETS[*]}"
  fi
  
  # Clear screen for better visibility
  clear 2>/dev/null || true
  
  # Display scan banner
  echo "*******************************************"
  echo "*        STARTING CLAMAV VIRUS SCAN       *"
  echo "*******************************************"
  echo ""
  
  # Update progress
  if [ -f "$PROGRESS_FILE" ]; then
    echo "Starting scan at $(date +%H:%M:%S)" > "$PROGRESS_FILE"
  fi
  
  # Check for parallel scanning capability
  local can_parallel=false
  local parallel_jobs=1
  
  if command -v parallel >/dev/null 2>&1 && [ "${PARALLEL_SCAN:-false}" = "true" ]; then
    can_parallel=true
    # Determine optimal number of jobs based on CPU count
    local cpu_count
    cpu_count=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo "1")
    parallel_jobs=$((cpu_count - 1))
    [ "$parallel_jobs" -lt 1 ] && parallel_jobs=1
    log "Parallel scanning enabled with $parallel_jobs jobs" "INFO"
  fi
  
  # Execute the scan
  echo "Running ClamAV scan... This may take some time."
  echo "Press Ctrl+C to abort"
  echo ""
  
  local scan_status=0
  update_scan_state "scanning"
  
  if [ "$can_parallel" = "true" ] && [ ${#SCAN_TARGETS[@]} -gt 1 ]; then
    # Parallel scanning for multiple targets
    log "Using parallel scanning with $parallel_jobs threads" "INFO"
    
    if [ -f "$PROGRESS_FILE" ]; then
      echo "Using parallel scanning with $parallel_jobs threads" > "$PROGRESS_FILE"
    fi
    
    # Export functions and variables for GNU parallel
    export -f log debug
    
    # Create a temporary directory for scan chunks
    local chunk_dir=$(mktemp -d -t "clamav-chunks.XXXXXX")
    TEMP_FILES+=("$chunk_dir")
    
    # Process targets in parallel
    printf "%s\n" "${SCAN_TARGETS[@]}" | \
      parallel --will-cite -j "$parallel_jobs" \
        "clamscan ${scan_options[*]} {} >> \"$SCAN_OUTPUT_FILE\" 2>&1 || echo \"Error scanning {}: \$?\" >> \"$SCAN_OUTPUT_FILE\""
    scan_status=$?
  else
    # Sequential scanning
    if [ "${VERBOSE:-false}" = "true" ]; then
      # Show output in real-time for verbose mode
      clamscan "${scan_options[@]}" "${SCAN_TARGETS[@]}" 2>&1 | tee "$SCAN_OUTPUT_FILE"
      scan_status=${PIPESTATUS[0]}
    else
      # Regular output to file
      clamscan "${scan_options[@]}" "${SCAN_TARGETS[@]}" > "$SCAN_OUTPUT_FILE" 2>&1
      scan_status=$?
    fi
  fi
  
  # Record scan end time
  SCAN_END_TIME=$(date +%s)
  
  # Update progress file
  if [ -f "$PROGRESS_FILE" ]; then
    echo "Scan completed, processing results..." > "$PROGRESS_FILE"
  fi
  
  # Kill progress display if it was started
  if [ -n "$PROGRESS_PID" ] && kill -0 "$PROGRESS_PID" 2>/dev/null; then
    kill "$PROGRESS_PID" 2>/dev/null || true
    wait "$PROGRESS_PID" 2>/dev/null || true
  fi
  
  # Log completion
  log "clamscan completed with exit code: $scan_status" "INFO"
  
  # Update scan state
  update_scan_state "scanned" "$scan_status"
  
  return $scan_status
}

# Process scan results and generate summary
# Usage: process_scan_results scan_status
process_scan_results() {
  local scan_status=$1
  
  log "Processing scan results (status: $scan_status)" "INFO"
  
  # Calculate scan duration
  local duration=$((SCAN_END_TIME - SCAN_START_TIME))
  local duration_formatted=$(format_duration "$SCAN_START_TIME" "$SCAN_END_TIME")
  
  # Parse scan output for statistics
  local scanned_files=0
  local infected_files=0
  
  if [ -f "$SCAN_OUTPUT_FILE" ]; then
    # Extract summary section
    local summary
    summary=$(awk '/----------- SCAN SUMMARY -----------/,/^$/' "$SCAN_OUTPUT_FILE")
    
    if [ -n "$summary" ]; then
      # Parse statistics
      scanned_files=$(echo "$summary" | awk '/^Scanned files:/ {print $3}')
      infected_files=$(echo "$summary" | awk '/^Infected files:/ {print $3}')
      
      debug "Parsed summary - Scanned: $scanned_files, Infected: $infected_files"
    else
      log "Warning: Could not find scan summary in output" "WARNING"
    fi
  else
    log "Warning: Scan output file not found" "WARNING"
  fi
  
  # Ensure we have valid numeric values
  if ! [[ "$scanned_files" =~ ^[0-9]+$ ]]; then
    scanned_files=0
    debug "WARNING: Failed to parse scanned files count from output"
  fi
  
  if ! [[ "$infected_files" =~ ^[0-9]+$ ]]; then
    infected_files=0
    debug "WARNING: Failed to parse infected files count from output"
  fi
  
  # Process infected files if any were found
  if [ "${infected_files:-0}" -gt 0 ]; then
    log "Found ${infected_files} infected files." "SCAN"
    echo "⚠️ Found ${infected_files} infected files."
    
    # Extract the list of infected files from scan output
    local infected_list
    infected_list=$(grep -E ": .+FOUND$" "$SCAN_OUTPUT_FILE" || echo "No details available")
    debug "Infected files: $infected_list"
    
    # Organize quarantined files if quarantine is enabled
    if [ "$QUARANTINE_ENABLED" = "true" ]; then
      if [ -n "${QUARANTINE_LOADED:-}" ] && type process_quarantined_files >/dev/null 2>&1; then
        log "Processing quarantined files..." "QUARANTINE"
        process_quarantined_files || log "Failed to process quarantined files" "ERROR"
      else
        log "Quarantine module not loaded, skipping quarantine processing" "WARNING"
      fi
    fi
  else
    log "No infected files found." "SUCCESS"
    echo "✅ No infected files found."
  fi
  
  # Generate report if report module is loaded
  if [ -n "${REPORT_LOADED:-}" ] && type generate_scan_report >/dev/null 2>&1; then
    generate_scan_report "$scan_status" "$scanned_files" "$infected_files" "$duration_formatted" "$SCAN_OUTPUT_FILE"
  else
    # Basic summary if report module is not available
    echo ""
    echo "=========== SCAN SUMMARY ==========="
    echo "📊 Scan completed with status: $(get_status_description $scan_status)"
    echo "📁 Files scanned: $scanned_files"
    echo "🔍 Infected files: $infected_files"
    echo "⏱️ Duration: $duration_formatted"
    echo "===================================="
  fi
  
  # Update final state
  update_scan_state "processed" "$scan_status"
  
  # Set exit code based on scan status with proper interpretation
  case "$scan_status" in
    0)  # No viruses found
        EXIT_CODE=$EXIT_SUCCESS
        debug "Scan completed successfully - no infections found"
        ;;
    1)  # Viruses found and handled
        EXIT_CODE=$EXIT_SCAN_INFECTED
        debug "Scan completed - infections found and handled"
        ;;
    2)  # Error during scanning
        EXIT_CODE=$EXIT_SCAN_ERROR
        debug "Scan encountered errors"
        ;;
    *)  # Unknown status
        EXIT_CODE=$EXIT_SCAN_ERROR
        debug "Scan completed with unknown status: $scan_status"
        ;;
  esac
  
  return $EXIT_CODE
}

# Get a human-readable description of scan status code
# Usage: get_status_description status_code
get_status_description() {
  local status="$1"
  case "$status" in
    0)  echo "No threats found" ;;
    1)  echo "Threats found" ;;
    2)  echo "Error occurred during scan" ;;
    *)  echo "Unknown status ($status)" ;;
  esac
}

# Format scan duration in a human-readable format
# Usage: format_duration start_time end_time
format_duration() {
  local start_time="$1"
  local end_time="$2"
  local seconds duration
  
  if [ -z "$end_time" ]; then
    # Single argument mode (total seconds)
    seconds="$start_time"
  else
    # Two argument mode (start and end timestamps)
    seconds=$(( end_time - start_time ))
  fi
  
  # Format duration
  if [ "$seconds" -lt 60 ]; then
    duration="${seconds}s"
  elif [ "$seconds" -lt 3600 ]; then
    local minutes=$(( seconds / 60 ))
    local remaining_seconds=$(( seconds % 60 ))
    duration="${minutes}m ${remaining_seconds}s"
  else
    local hours=$(( seconds / 3600 ))
    local remaining=$(( seconds % 3600 ))
    local minutes=$(( remaining / 60 ))
    local remaining_seconds=$(( remaining % 60 ))
    duration="${hours}h ${minutes}m ${remaining_seconds}s"
  fi
  
  echo "$duration"
}

# Export module marker
SCAN_CONSOLIDATED_LOADED=true

