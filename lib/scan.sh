#!/bin/bash
#================================================================
# 🔍 Clammy Scan Module
#================================================================
# Scanning-related functions for Clammy
#================================================================

# Source the core library for shared functionality if not already loaded
if [ -z "${CORE_LOADED:-}" ]; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "$SCRIPT_DIR/core.sh" || {
    echo "Error: Failed to load core library from scan.sh. Exiting."
    exit 1
  }
fi

# Source utilities module if not already loaded
if [ -z "${UTILS_LOADED:-}" ]; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "$SCRIPT_DIR/utils.sh" || {
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

  # Create scan output directory
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local scan_dir="${LOG_DIR}/scan_${timestamp}"
  mkdir -p "$scan_dir" || {
    log "Failed to create scan directory: $scan_dir" "ERROR"
    return $EXIT_SCAN_ERROR
  }

  # Validate targets and resolve real paths
  local resolved_targets=()
  for target in "${SCAN_TARGETS[@]}"; do
    if [ -e "$target" ]; then
      local real_path
      if [[ "$target" == "/tmp/"* ]]; then
        real_path="/private$target"
      else
        real_path="$target"
      fi
      echo "  ✓ Target exists: $target"
      log "Target validated: $target -> $real_path" "INFO"
      resolved_targets+=("$real_path")
    else
      echo "  ✗ Target not found: $target"
      log "Target not found: $target" "ERROR"
      return $EXIT_SCAN_ERROR
    fi
  done

  # Set up scan output files
  SCAN_OUTPUT_FILE="${scan_dir}/scan_output.txt"
  log "Will save scan output to: $SCAN_OUTPUT_FILE" "DEBUG"

  # Run test clamscan first
  echo "Running preliminary scan..."
  local test_output="${scan_dir}/test_output.txt"
  if ! clamscan --stdout "${resolved_targets[@]}" > "$test_output" 2>&1; then
    local test_status=$?
    if [ "$test_status" -eq 1 ]; then
      log "Preliminary scan identified virus" "INFO"
      log "Test output: $(cat "$test_output")" "DEBUG"
    else
      log "Preliminary scan failed: $(cat "$test_output")" "ERROR"
      return $test_status
    fi
  fi

  # Run the main scan
  echo "Running ClamAV scan... This may take some time."
  echo "Press Ctrl+C to abort"
  echo ""

  # Execute clamscan and capture output
  log "Starting scan with targets: ${resolved_targets[*]}" "INFO"
  clamscan --verbose --stdout "${resolved_targets[@]}" > "$SCAN_OUTPUT_FILE" 2>&1
  SCAN_STATUS=$?

  # Log scan completion
  log "Scan completed with status: $SCAN_STATUS" "INFO"
  if [ -f "$SCAN_OUTPUT_FILE" ]; then
    log "Scan output: $(cat "$SCAN_OUTPUT_FILE")" "DEBUG"
  else
    log "No scan output file found" "ERROR"
  fi

  SCAN_END_TIME=$(date +%s)

  # Process scan status
  case "$SCAN_STATUS" in
    0) log "Scan completed successfully - no infections found" "SUCCESS" ;;
    1) log "Scan completed - infections found" "WARNING" ;;
    2) log "Scan failed with errors" "ERROR" ;;
    *) log "Scan completed with unknown status: $SCAN_STATUS" "ERROR" ;;
  esac

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
  
  log "Processing scan results (status: $scan_status, duration: $duration_formatted)" "INFO"
  
  # Extract scan statistics
  local scanned_files=0
  local infected_files=0
  
  if [ -f "$scan_output_file" ]; then
    log "Processing scan output from: $scan_output_file" "DEBUG"
    
    # Extract summary statistics
    local summary
    summary=$(sed -n '/----------- SCAN SUMMARY -----------/,$p' "$scan_output_file")
    
    if [ -n "$summary" ]; then
      log "Found scan summary section" "DEBUG"
      log "Summary: $summary" "DEBUG"
      
      scanned_files=$(echo "$summary" | grep "Scanned files:" | awk '{print $3}')
      infected_files=$(echo "$summary" | grep "Infected files:" | awk '{print $3}')
      
      log "Parsed summary - Scanned: $scanned_files, Infected: $infected_files" "DEBUG"
    else
      log "No summary section found in output" "WARNING"
      log "Full output: $(cat "$scan_output_file")" "DEBUG"
    fi
  else
    log "Scan output file not found: $scan_output_file" "ERROR"
  fi
  
  # Verify numeric values
  if ! [[ "$scanned_files" =~ ^[0-9]+$ ]]; then
    scanned_files=0
    log "Invalid scanned files count, using 0" "WARNING"
  fi
  
  if ! [[ "$infected_files" =~ ^[0-9]+$ ]]; then
    infected_files=0
    log "Invalid infected files count, using 0" "WARNING"
  fi
  
  # Generate report
  if [ -n "${REPORT_LOADED:-}" ] && type generate_scan_report >/dev/null 2>&1; then
    generate_scan_report "$scan_status" "$scanned_files" "$infected_files" "$duration_formatted" "$scan_output_file"
  else
    # Basic summary without report module
    case "$scan_status" in
      0) echo "✅ No infections found" ;;
      1) echo "⚠️ Found $infected_files infection(s)" ;;
      2) echo "❌ Scan error" ;;
      *) echo "❓ Unknown status: $scan_status" ;;
    esac
    echo "Files scanned: $scanned_files"
    echo "Duration: $duration_formatted"
  fi
  
  # Set exit code based on scan status
  case "$scan_status" in
    0)  EXIT_CODE=$EXIT_SUCCESS ;;
    1)  EXIT_CODE=$EXIT_SCAN_INFECTED ;;
    *)  EXIT_CODE=$EXIT_SCAN_ERROR ;;
  esac
  
  return 0
}

# Export module marker
SCAN_LOADED=true
