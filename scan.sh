#!/bin/bash
#================================================================
# 🔍 Clammy Scanner Scan Module
#================================================================
# Scanning-related functions for Clammy Scanner
#================================================================

# Source the core library for shared functionality if not already loaded
if [ -z "${CORE_LOADED:-}" ]; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "$SCRIPT_DIR/lib/core.sh" || {
    echo "Error: Failed to load core library from scan.sh. Exiting."
    exit 1
  }
fi

# Source utilities module if not already loaded
if [ -z "${UTILS_LOADED:-}" ]; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "$SCRIPT_DIR/lib/utils.sh" || {
    echo "Error: Failed to load utils library from scan.sh. Exiting."
    exit 1
  }
fi

# Update virus definitions
# Usage: update_virus_definitions
update_virus_definitions() {
  log "Updating virus definitions..." "SCAN"
  printf "  🔄 Updating ClamAV virus definitions..."
  
  # Run freshclam to update definitions
  if freshclam --quiet; then
    printf " \033[1;32m✓\033[0m\n"
    log "Virus definitions updated successfully" "SUCCESS"
  else
    printf " \033[1;33m⚠️\033[0m\n"
    log "Error updating virus definitions, continuing with existing definitions" "WARNING"
    printf "  \033[1;33m⚠️ Using existing virus definitions. Consider running 'freshclam' manually.\033[0m\n"
  fi
}

# Run the actual ClamAV scan
# Usage: run_scan
# Returns: Scan status code (0: no virus, 1: viruses found, 2: errors)
run_scan() {
  log "Starting ClamAV scan..." "SCAN"
  echo "========================================"
  echo "Starting ClamAV scan on ${#SCAN_TARGETS[@]} targets"
  echo "- Excluded patterns: ${#EXCLUSION_PATTERNS[@]} patterns defined"
  echo "- Maximum file size to scan: ${MAX_FILE_SIZE}MB"
  echo "- Quarantine directory: ${QUARANTINE_DIR}"
  echo "========================================"
  
  # Create exclusion file for clamscan
  EXCLUDE_FILE=$(create_exclude_file)
  if [ ! -f "$EXCLUDE_FILE" ]; then
    log "Error: Failed to create exclusion file!" "ERROR"
    exit $EXIT_SCAN_ERROR
  fi
  
  # Create progress tracking file
  PROGRESS_FILE=$(mktemp -t "clamav-progress.XXXXXX")
  if [ ! -f "$PROGRESS_FILE" ]; then
    log "Warning: Failed to create progress file. Progress display will be disabled." "WARNING"
  else
    chmod 644 "$PROGRESS_FILE" # Make sure it's readable
    echo "Initializing scan..." > "$PROGRESS_FILE"
  fi
  
  # Create a temporary file for scan output
  SCAN_OUTPUT_FILE=$(mktemp -t "clamav-scan-output.XXXXXX")
  if [ ! -f "$SCAN_OUTPUT_FILE" ]; then
    log "Error: Failed to create temporary file for scan output" "ERROR"
    exit $EXIT_SCAN_ERROR
  fi
  
  # Start progress display in background if verbose mode is not enabled
  if [ "$VERBOSE" != "true" ] && [ -n "$PROGRESS_FILE" ]; then
    display_progress "$PROGRESS_FILE" &
    PROGRESS_PID=$!
    # Store PID and make it available to trap
    echo "$PROGRESS_PID" > "${PROGRESS_FILE}.pid" 2>/dev/null || true
    debug "Started progress display with PID: $PROGRESS_PID"
  fi
  
  # Define clamscan options
  CLAMSCAN_OPTIONS=(
    --recursive                 # Scan directories recursively
    --infected                  # Only print infected files
    --stdout                    # Force output to stdout
    "--max-filesize=${MAX_FILE_SIZE}"  # Skip files larger than this size (MB)
    "--max-scansize=${MAX_FILE_SIZE}"  # Maximum amount of data to scan from a file
  )
  
  # Create a temporary file to collect all exclusion patterns
  SYSTEM_EXCLUDE_FILE=$(mktemp -t "clamav-system-exclude.XXXXXX")
  if [ ! -f "$SYSTEM_EXCLUDE_FILE" ]; then
    log "Warning: Failed to create system exclusion file" "WARNING"
  else
    # Add standard system directories to exclude
    {
      echo "/proc"
      echo "/sys"
      echo "/dev"
      echo "/var/vm"
      
      # Add VM paths if they exist
      [ -n "${SYS_VAR_VM_PATH:-}" ] && [ -d "${SYS_VAR_VM_PATH}" ] && echo "${SYS_VAR_VM_PATH}"
      
      # Add quarantine directory
      [ -n "${QUARANTINE_DIR:-}" ] && [ -d "${QUARANTINE_DIR}" ] && echo "${QUARANTINE_DIR}"
      
      # Add temp directories
      echo "/tmp"
      [ -n "${TMPDIR:-}" ] && echo "${TMPDIR}"
    } > "$SYSTEM_EXCLUDE_FILE"
    
    # Add system exclusion file to options
    CLAMSCAN_OPTIONS+=("--exclude-dir=@${SYSTEM_EXCLUDE_FILE}")
  fi
  
  # Add pattern exclusion file if available
  if [ -f "$EXCLUDE_FILE" ]; then
    CLAMSCAN_OPTIONS+=("--exclude-dir=@${EXCLUDE_FILE}")
  fi
  
  # Add quarantine option if enabled
  if [ "$QUARANTINE_ENABLED" = "true" ]; then
    # Create temporary quarantine directory if needed
    TEMP_QUARANTINE_DIR="$(dirname "${QUARANTINE_DIR}")/tmp"
    mkdir -p "$TEMP_QUARANTINE_DIR" 2>/dev/null || {
      log "Error: Failed to create temporary quarantine directory: $TEMP_QUARANTINE_DIR" "ERROR"
      exit $EXIT_QUARANTINE_ERROR
    }
    CLAMSCAN_OPTIONS+=("--move=${TEMP_QUARANTINE_DIR}")
  fi
  
  # Display scan command in verbose mode
  if [ "$VERBOSE" = "true" ]; then
    debug "Running: clamscan ${CLAMSCAN_OPTIONS[*]} ${SCAN_TARGETS[*]}"
  fi
  
  # Clear the screen for better visibility
  clear 2>/dev/null || true
  
  # Display scan banner
  echo "*******************************************" >&2
  echo "*        STARTING CLAMAV VIRUS SCAN       *" >&2
  echo "*******************************************" >&2
  echo "" >&2
  
  # Update progress file
  if [ -f "$PROGRESS_FILE" ]; then
    echo "Starting scan at $(date +%H:%M:%S)" > "$PROGRESS_FILE"
  fi
  
  # Run the scan
  echo "Running ClamAV scan... This may take some time."
  echo "Press Ctrl+C to abort"
  echo ""
  
  # Execute clamscan with proper redirection
  if [ "$VERBOSE" = "true" ]; then
    # In verbose mode, show output in real-time and save to file
    clamscan "${CLAMSCAN_OPTIONS[@]}" "${SCAN_TARGETS[@]}" 2>&1 | tee "$SCAN_OUTPUT_FILE"
  else
    # In normal mode, just save to file
    clamscan "${CLAMSCAN_OPTIONS[@]}" "${SCAN_TARGETS[@]}" > "$SCAN_OUTPUT_FILE" 2>&1
  fi
  SCAN_STATUS=${PIPESTATUS[0]:-$?}
  SCAN_END_TIME=$(date +%s)
  
  # Update progress file
  if [ -f "$PROGRESS_FILE" ]; then
    echo "Scan completed, processing results..." > "$PROGRESS_FILE"
  fi
  
  # Kill progress display if it was started
  if [ -n "$PROGRESS_PID" ] && kill -0 "$PROGRESS_PID" 2>/dev/null; then
    debug "Stopping progress display (PID: $PROGRESS_PID)"
    kill "$PROGRESS_PID" 2>/dev/null || true
    wait "$PROGRESS_PID" 2>/dev/null || true
  fi
  
  log "clamscan completed with exit code: $SCAN_STATUS" "INFO"
  return $SCAN_STATUS
}

# Process scan results
# Usage: process_scan_results scan_status scan_output_file
# Returns: 0 on success, 1 if viruses found, 2 on error
process_scan_results() {
  local scan_status=$1
  local scan_output_file=$2
  
  # Calculate scan duration
  local scan_duration=$((SCAN_END_TIME - SCAN_START_TIME))
  local duration_formatted=$(format_duration $SCAN_START_TIME $SCAN_END_TIME)
  
  debug "Processing scan results (status: $scan_status, duration: $duration_formatted)"
  
  # Extract scan statistics with improved parsing
  local scanned_files=0
  local infected_files=0
  
  if [ -f "$scan_output_file" ]; then
    # Parse the summary section more reliably using awk
    local summary
    summary=$(awk '/----------- SCAN SUMMARY -----------/,/^$/' "$scan_output_file")
    
    if [ -n "$summary" ]; then
      scanned_files=$(echo "$summary" | awk '/^Scanned files:/ {print $3}')
      infected_files=$(echo "$summary" | awk '/^Infected files:/ {print $3}')
      debug "Parsed summary - Scanned: $scanned_files, Infected: $infected_files"
    else
      log "Warning: Could not find scan summary in output" "WARNING"
    fi
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
    echo "Found ${infected_files} infected files."
    
    # Organize quarantined files if quarantine module is loaded and enabled
    if [ "$QUARANTINE_ENABLED" = "true" ]; then
      if [ -n "${QUARANTINE_LOADED:-}" ] && type process_quarantined_files >/dev/null 2>&1; then
        process_quarantined_files
      else
        log "Quarantine module not loaded, skipping quarantine processing" "WARNING"
      fi
    fi
  fi
  
  # Generate report if report module is loaded
  if [ -n "${REPORT_LOADED:-}" ] && type generate_scan_report >/dev/null 2>&1; then
    generate_scan_report "$scan_status" "$scanned_files" "$infected_files" "$duration_formatted" "$scan_output_file"
  else
    # Basic summary if report module is not available
    echo "Scan completed with status $scan_status"
    echo "Files scanned: $scanned_files"
    echo "Infected files: $infected_files"
    echo "Duration: $duration_formatted"
  fi
  
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
  
  return 0
}

#----------- Main Execution Block -----------#

# Only run the main block if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Initialize variables
  UPDATE_DEFINITIONS=true
  VERBOSE_SCAN=false
  SHOW_HELP=false
  SCAN_TARGETS=()

  # Source report module for HTML report generation
  if [ -z "${REPORT_LOADED:-}" ]; then
    # Try multiple locations
    if [ -f "$SCRIPT_DIR/lib/report.sh" ]; then
      debug "Loading report module from $SCRIPT_DIR/lib/report.sh"
      source "$SCRIPT_DIR/lib/report.sh" || {
        log "Warning: Failed to load report module from $SCRIPT_DIR/lib/report.sh" "WARNING"
      }
    elif [ -f "$CLAMAV_TAP_ROOT/lib/report.sh" ]; then
      debug "Loading report module from $CLAMAV_TAP_ROOT/lib/report.sh"
      source "$CLAMAV_TAP_ROOT/lib/report.sh" || {
        log "Warning: Failed to load report module from $CLAMAV_TAP_ROOT/lib/report.sh" "WARNING"
      }
    elif [ -f "./lib/report.sh" ]; then
      debug "Loading report module from ./lib/report.sh"
      source "./lib/report.sh" || {
        log "Warning: Failed to load report module from ./lib/report.sh" "WARNING"
      }
    else
      log "Warning: Report module not found. HTML reports will not be generated." "WARNING"
      # Set flag to indicate HTML reports are disabled
      GENERATE_HTML_REPORT=false
    fi
  fi

  # Source quarantine module for infected file handling
  if [ -z "${QUARANTINE_LOADED:-}" ]; then
    # Try multiple locations
    if [ -f "$SCRIPT_DIR/lib/quarantine.sh" ]; then
      debug "Loading quarantine module from $SCRIPT_DIR/lib/quarantine.sh"
      source "$SCRIPT_DIR/lib/quarantine.sh" || {
        log "Warning: Failed to load quarantine module from $SCRIPT_DIR/lib/quarantine.sh" "WARNING"
      }
    elif [ -f "$CLAMAV_TAP_ROOT/lib/quarantine.sh" ]; then
      debug "Loading quarantine module from $CLAMAV_TAP_ROOT/lib/quarantine.sh"
      source "$CLAMAV_TAP_ROOT/lib/quarantine.sh" || {
        log "Warning: Failed to load quarantine module from $CLAMAV_TAP_ROOT/lib/quarantine.sh" "WARNING"
      }
    elif [ -f "./lib/quarantine.sh" ]; then
      debug "Loading quarantine module from ./lib/quarantine.sh"
      source "./lib/quarantine.sh" || {
        log "Warning: Failed to load quarantine module from ./lib/quarantine.sh" "WARNING"
      }
    else
      log "Warning: Quarantine module not found. Quarantine features will be limited." "WARNING"
    fi
  fi

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        SHOW_HELP=true
        shift
        ;;
      --verbose|-v)
        VERBOSE=true
        VERBOSE_SCAN=true
        shift
        ;;
      --no-update|-n)
        UPDATE_DEFINITIONS=false
        shift
        ;;
      --quarantine|-q)
        QUARANTINE_ENABLED=true
        shift
        ;;
      --no-quarantine)
        QUARANTINE_ENABLED=false
        shift
        ;;
      --html-report)
        GENERATE_HTML_REPORT=true
        shift
        ;;
      --no-html-report)
        GENERATE_HTML_REPORT=false
        shift
        ;;
      -*)
        log "Unknown option: $1" "ERROR"
        SHOW_HELP=true
        shift
        ;;
      *)
        SCAN_TARGETS+=("$1")
        shift
        ;;
    esac
  done

  # Show help if requested or no targets specified
  if [ "$SHOW_HELP" = "true" ]; then
    echo "Usage: $0 [options] [target_directories]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -v, --verbose       Enable verbose output"
    echo "  -n, --no-update     Skip virus definition updates"
    echo "  -q, --quarantine    Enable quarantine of infected files"
    echo "  --no-quarantine     Disable quarantine (report only)"
    echo "  --html-report       Generate HTML report"
    echo "  --no-html-report    Disable HTML report generation"
    echo ""
    echo "If no target directories are specified, the default target will be used."
    exit 0
  fi

  # Set default scan targets if none provided
  if [ ${#SCAN_TARGETS[@]} -eq 0 ]; then
    SCAN_TARGETS=("${DEFAULT_SCAN_TARGETS[@]}")
    log "No scan targets specified, using default: ${SCAN_TARGETS[*]}" "INFO"
  fi

  # Record scan start time
  SCAN_START_TIME=$(date +%s)

  # Update virus definitions if enabled
  if [ "$UPDATE_DEFINITIONS" = "true" ]; then
    update_virus_definitions
  else
    log "Skipping virus definition updates as requested" "INFO"
  fi

  # Run the scan
  run_scan
  SCAN_STATUS=$?

  # Process scan results
  process_scan_results "$SCAN_STATUS" "$SCAN_OUTPUT_FILE"

  # Clean up temporary files
  # Clean up temporary files
  if [ -f "$EXCLUDE_FILE" ]; then
    rm -f "$EXCLUDE_FILE" 2>/dev/null || true
  fi
  if [ -f "$SYSTEM_EXCLUDE_FILE" ]; then
    rm -f "$SYSTEM_EXCLUDE_FILE" 2>/dev/null || true
  fi
  if [ -f "$PROGRESS_FILE" ]; then
    rm -f "$PROGRESS_FILE" 2>/dev/null || true
    rm -f "${PROGRESS_FILE}.pid" 2>/dev/null || true
  fi
  if [ -f "$SCAN_OUTPUT_FILE" ]; then
    if [ "$DEBUG" != "true" ]; then
      rm -f "$SCAN_OUTPUT_FILE" 2>/dev/null || true
    else
      log "Debug mode: preserving scan output at $SCAN_OUTPUT_FILE" "DEBUG"
    fi
  fi
  # Exit with appropriate status code
  log "Exiting with status code: $EXIT_CODE" "DEBUG"
  exit $EXIT_CODE
fi

# Export module marker
SCAN_LOADED=true
