#!/bin/bash
#================================================================
# 📊 Clammy Report Module
#================================================================
# Reporting functions for Clammy
#================================================================

# Source the core library for shared functionality if not already loaded
if [ -z "${CORE_LOADED:-}" ]; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "$SCRIPT_DIR/core.sh" || {
    echo "Error: Failed to load core library from report.sh. Exiting."
    exit 1
  }
fi

# Source utilities module if not already loaded
if [ -z "${UTILS_LOADED:-}" ]; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "$SCRIPT_DIR/utils.sh" || {
    echo "Error: Failed to load utils library from report.sh. Exiting."
    exit 1
  }
fi

# Generate a detailed scan report
# Usage: generate_scan_report status scanned_files infected_files duration scan_output_file
# Returns: 0 on success, 1 on failure
generate_scan_report() {
  local status=$1
  local scanned_files=$2
  local infected_files=$3
  local duration=$4
  local scan_output_file=$5
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  local report_file="${LOG_DIR}/scan_report_$(date +%Y%m%d_%H%M%S).txt"
  
  log "Generating scan report: $report_file" "INFO"
  
  # Create the report file with enhanced formatting
  {
    echo "                 CLAMMY SCAN REPORT"
    echo "                 CLAMAV SCAN REPORT"
    echo "========================================================"
    echo "Report Generated: $timestamp"
    echo "Scan ID: $SCAN_ID"
    echo ""
    echo "SCAN INFORMATION"
    echo "----------------"
    printf "%-25s: %s\n" "Start time" "$(date -r $SCAN_START_TIME "+%Y-%m-%d %H:%M:%S")"
    printf "%-25s: %s\n" "End time" "$(date -r $SCAN_END_TIME "+%Y-%m-%d %H:%M:%S")"
    printf "%-25s: %s\n" "Duration" "$duration"
    printf "%-25s: %s\n" "Executed by" "$(whoami)@$(hostname)"
    echo ""
    echo "SCAN TARGETS"
    echo "------------"
    for target in "${SCAN_TARGETS[@]}"; do
      printf "• %s\n" "$target"
    done
    echo ""
    echo "SCAN RESULTS"
    echo "------------"
    printf "%-25s: %s\n" "Files scanned" "$scanned_files"
    printf "%-25s: %s\n" "Infected files" "$infected_files"
    printf "%-25s: %s\n" "Exit code" "$status"
    
    # Add scan rate calculation if we have valid numbers
    if [ "$scanned_files" -gt 0 ] && [ "$duration" -gt 0 ]; then
      local scan_rate=$(( scanned_files / $(echo $duration | grep -o '[0-9]*$') ))
      printf "%-25s: %s files/second\n" "Scan rate" "$scan_rate"
    fi
    
    # Status indicator with proper interpretation of exit codes
    case "$status" in
      0) printf "%-25s: ✅ No infections found\n" "Status" ;;
      1) printf "%-25s: ⚠️ Infections found and quarantined\n" "Status" ;;
      2) printf "%-25s: ❌ Scan errors occurred\n" "Status" ;;
      *) printf "%-25s: ℹ️ Unknown status code\n" "Status" ;;
    esac
    
    echo ""
    echo "SYSTEM INFORMATION"
    echo "-----------------"
    printf "%-25s: %s\n" "Hostname" "$(hostname 2>/dev/null || echo 'unknown')"
    printf "%-25s: %s\n" "Operating system" "$(uname -a 2>/dev/null || echo 'unknown')"
    printf "%-25s: %s\n" "ClamAV version" "$(clamscan --version 2>/dev/null | head -n 1 || echo 'unknown')"
    echo ""
    
    # Show infection details if any
    if [ "$infected_files" -gt 0 ] && [ -f "$scan_output_file" ]; then
      echo "INFECTED FILES"
      echo "---------------"
      echo "The following files were found to be infected:"
      echo ""
      
      # Extract and display infected files with their detections
      grep -E ": .+FOUND$" "$scan_output_file" | while read -r line; do
        local file_path=$(echo "$line" | sed -E 's/^(.*): .* FOUND$/\1/')
        local virus_name=$(echo "$line" | sed -E 's/^.*: (.*) FOUND$/\1/')
        printf "• %s\n  └─ %s\n" "$file_path" "$virus_name"
      done
      
      echo ""
      echo "QUARANTINE INFORMATION"
      echo "----------------------"
      printf "%-25s: %s\n" "Quarantine enabled" "$QUARANTINE_ENABLED"
      printf "%-25s: %s\n" "Quarantine location" "${QUARANTINE_CURRENT_DIR:-$QUARANTINE_DIR}"
      printf "%-25s: %s\n" "Retention policy" "${QUARANTINE_RETENTION_POLICY:-time-based}"
      printf "%-25s: %s days\n" "Retention period" "${QUARANTINE_MAX_AGE:-90}"
    fi
    
    # Include scan summary if available
    if [ -f "$scan_output_file" ]; then
      echo ""
      echo "SCAN SUMMARY"
      echo "-----------"
      sed -n '/----------- SCAN SUMMARY -----------/,$p' "$scan_output_file"
    fi
    
    echo "========================================================"
    echo "End of Report"
    echo "========================================================"
  } > "$report_file" 2>/dev/null || {
    log "Failed to write scan report to $report_file" "ERROR"
    return 1
  }
  
  # Set permissions on the report file
  chmod 644 "$report_file" 2>/dev/null || log "Failed to set permissions on report file" "WARNING"
  
  # Generate HTML report if enabled
  if [ "${GENERATE_HTML_REPORT:-true}" = "true" ]; then
    generate_html_report "$report_file"
  fi
  
  log "Scan report generated: $report_file" "SUCCESS"
  echo "Scan report generated: $report_file"
  
  return 0
}

# Generate HTML report if enabled
# Usage: generate_html_report text_report_file
# Returns: 0 on success, 1 on failure
generate_html_report() {
  local text_report="$1"
  local html_report="${text_report%.txt}.html"
  
  log "Generating HTML report from $text_report" "INFO"
  
  # Create the HTML report with enhanced styling and layout
  {
    cat << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ClamAV Scan Report</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f8f8f8;
        }
        h1, h2, h3 {
            color: #2c3e50;
        }
        h1 {
            text-align: center;
            border-bottom: 2px solid #3498db;
            padding-bottom: 10px;
            margin-bottom: 30px;
        }
        .section {
            background: white;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section-title {
            background: #3498db;
            color: white;
            padding: 10px 15px;
            border-radius: 5px;
            margin-top: 0;
            font-size: 1.2em;
        }
        pre {
            background-color: #f5f5f5;
            padding: 10px;
            border-radius: 5px;
            white-space: pre-wrap;
            overflow-x: auto;
        }
        .status-clean {
            color: #27ae60;
            font-weight: bold;
        }
        .status-infected {
            color: #e74c3c;
            font-weight: bold;
        }
        .status-error {
            color: #f39c12;
            font-weight: bold;
        }
        .footer {
            text-align: center;
            font-size: 0.9em;
            color: #7f8c8d;
            margin-top: 30px;
        }
        @media print {
            body {
                background: white;
            }
            .section {
                box-shadow: none;
                border: 1px solid #ddd;
            }
        }
    </style>
</head>
<body>
    <h1>Clammy Virus Scan Report</h1>
    <div class="section">
        <h2 class="section-title">Scan Report</h2>
        <pre>
$(cat "$text_report" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')
        </pre>
    </div>
    <div class="footer">
        <p>Generated by Clammy Scanner on $(date)</p>
    </div>
</body>
</html>
EOF
  } > "$html_report" 2>/dev/null || {
    log "Failed to write HTML report to $html_report" "ERROR"
    return 1
  }
  
  # Set permissions
  chmod 644 "$html_report" 2>/dev/null || log "Failed to set permissions on HTML report" "WARNING"
  
  log "HTML report generated: $html_report" "SUCCESS"
  echo "HTML report generated: $html_report"
  
  # Try to open in browser if configured and possible
  if [ "${OPEN_REPORT_AUTOMATICALLY:-false}" = "true" ] && command_exists "open"; then
    open "$html_report" 2>/dev/null && log "Opened HTML report in browser" "INFO"
  fi
  
  return 0
}

# Display the final summary for the scan
# Usage: print_final_summary status duration scanned_files infected_files
# Returns: 0 always
print_final_summary() {
  local status_code="$1"
  local duration="$2"
  local scanned_files="$3"
  local infected_files="$4"
  
  # Format summary header
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "                  SCAN SUMMARY REPORT                       "
  echo "════════════════════════════════════════════════════════════"
  echo ""
  
  # Format status line with color and quarantine info
  case "$status_code" in
    0) printf "\033[1;32m✅ CLEAN SCAN: No infections detected in %s files\033[0m\n" "$scanned_files" ;;
    1) 
      if [ "$QUARANTINE_ENABLED" = "true" ]; then
        printf "\033[1;33m⚠️ INFECTIONS FOUND: %d infected files quarantined\033[0m\n" "$infected_files"
      else
        printf "\033[1;31m⚠️ INFECTIONS FOUND: %d infected files detected (QUARANTINE DISABLED)\033[0m\n" "$infected_files"
        printf "\033[1;31m   WARNING: Infected files remain in their original locations!\033[0m\n"
      fi
      ;;
    2) printf "\033[1;31m❌ SCAN ERROR: Problems encountered during scan\033[0m\n" ;;
    *) printf "\033[1;36mℹ️ UNKNOWN STATUS: Scan completed with code %d\033[0m\n" "$status_code" ;;
  esac
  
  printf "\033[1;36m%-20s\033[0m : %s\n" "Duration" "$duration"
  printf "\033[1;36m%-20s\033[0m : %s\n" "Files scanned" "$scanned_files"
  printf "\033[1;36m%-20s\033[0m : %s\n" "Infected files" "$infected_files"
  
  if [ "$infected_files" -gt 0 ]; then
    printf "\033[1;36m%-20s\033[0m : %s\n" "Quarantine location" "${QUARANTINE_CURRENT_DIR:-$QUARANTINE_DIR}"
    printf "\033[1;36m%-20s\033[0m : %s\n" "Report location" "${LOG_DIR}/scan_report_*.txt"
  fi
  
  echo ""
  printf "\033[1;36m%-20s\033[0m : %s\n" "Log file" "$LOGFILE"
  
  # Add advice based on status
  echo ""
  case "$status_code" in
    0) 
      echo "🔍 RECOMMENDATION: Schedule regular scans to ensure continued protection."
      ;;
    1) 
      echo "🔍 RECOMMENDATION: Review quarantined files in the generated report."
      echo "   Consider checking other devices on your network that may be infected."
      ;;
    2) 
      echo "🔍 RECOMMENDATION: Check the log file for details about scan errors."
      echo "   Try running the scan again with fewer targets or excluding problem areas."
      ;;
  esac
  
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo ""
  
  return 0
}

# Export module marker
REPORT_LOADED=true
