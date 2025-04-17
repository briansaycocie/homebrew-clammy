#!/bin/bash
#================================================================
# 🔒 Clammy Quarantine Module
#================================================================
# Quarantine-related functions for Clammy
#================================================================

# Source the core library for shared functionality if not already loaded
if [ -z "${CORE_LOADED:-}" ]; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "$SCRIPT_DIR/core.sh" || {
    echo "Error: Failed to load core library from quarantine.sh. Exiting."
    exit 1
  }
fi

# Source utilities module if not already loaded
if [ -z "${UTILS_LOADED:-}" ]; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "$SCRIPT_DIR/utils.sh" || {
    echo "Error: Failed to load utils library from quarantine.sh. Exiting."
    exit 1
  }
fi

# Initialize quarantine environment
# Usage: setup_quarantine
# Returns: 0 on success, 1 on failure
setup_quarantine() {
  log "Setting up quarantine environment" "INFO"
  
  # Skip if quarantine is disabled
  if [ "${QUARANTINE_ENABLED:-false}" != "true" ]; then
    log "Quarantine is disabled - skipping setup" "INFO"
    return 0
  fi
  
  # Make sure the basic quarantine directory exists
  if [ ! -d "$QUARANTINE_DIR" ]; then
    mkdir -p "$QUARANTINE_DIR" 2>/dev/null || {
      log "Failed to create quarantine directory: $QUARANTINE_DIR" "ERROR"
      return 1
    }
    chmod 700 "$QUARANTINE_DIR" 2>/dev/null
  fi
  
  # Create the temporary quarantine directory
  TEMP_QUARANTINE_DIR="${QUARANTINE_DIR}/tmp"
  if [ ! -d "$TEMP_QUARANTINE_DIR" ]; then
    mkdir -p "$TEMP_QUARANTINE_DIR" 2>/dev/null || {
      log "Failed to create temporary quarantine directory: $TEMP_QUARANTINE_DIR" "ERROR"
      return 1
    }
    chmod 700 "$TEMP_QUARANTINE_DIR" 2>/dev/null
  fi
  
  # Create the quarantine metadata directory
  QUARANTINE_METADATA_DIR="${SECURITY_DIR}/quarantine-metadata"
  if [ ! -d "$QUARANTINE_METADATA_DIR" ]; then
    mkdir -p "$QUARANTINE_METADATA_DIR" 2>/dev/null || {
      log "Failed to create quarantine metadata directory: $QUARANTINE_METADATA_DIR" "ERROR"
      return 1
    }
    chmod 700 "$QUARANTINE_METADATA_DIR" 2>/dev/null
  fi
  
  # Create year-month folders for organization
  YEAR_MONTH=$(date "+%Y-%m")
  QUARANTINE_CURRENT_DIR="${QUARANTINE_DIR}/${YEAR_MONTH}"
  METADATA_CURRENT_DIR="${QUARANTINE_METADATA_DIR}/${YEAR_MONTH}"
  
  if [ ! -d "$QUARANTINE_CURRENT_DIR" ]; then
    mkdir -p "$QUARANTINE_CURRENT_DIR" 2>/dev/null || {
      log "Failed to create current quarantine directory: $QUARANTINE_CURRENT_DIR" "ERROR"
      return 1
    }
    chmod 700 "$QUARANTINE_CURRENT_DIR" 2>/dev/null
  fi
  
  if [ ! -d "$METADATA_CURRENT_DIR" ]; then
    mkdir -p "$METADATA_CURRENT_DIR" 2>/dev/null || {
      log "Failed to create current metadata directory: $METADATA_CURRENT_DIR" "ERROR"
      return 1
    }
    chmod 700 "$METADATA_CURRENT_DIR" 2>/dev/null
  fi
  
  log "Quarantine environment setup completed" "SUCCESS"
  return 0
}

# Process quarantined files by moving them from temporary to permanent storage
# Usage: process_quarantined_files
# Returns: 0 on success, 1 on failure
process_quarantined_files() {
  log "Processing quarantined files" "INFO"
  
  # Skip if quarantine is disabled
  if [ "${QUARANTINE_ENABLED:-false}" != "true" ]; then
    log "Quarantine is disabled - skipping processing" "INFO"
    return 0
  fi
  
  # Make sure temporary quarantine directory exists
  if [ ! -d "$TEMP_QUARANTINE_DIR" ]; then
    log "Temporary quarantine directory not found: $TEMP_QUARANTINE_DIR" "ERROR"
    return 1
  fi
  
  # Count quarantined files
  local file_count=$(find "$TEMP_QUARANTINE_DIR" -type f 2>/dev/null | wc -l)
  file_count=$(echo "$file_count" | tr -d '[:space:]')
  
  if [ "$file_count" -eq 0 ]; then
    log "No files found in temporary quarantine directory" "INFO"
    return 0
  fi
  
  log "Found $file_count infected files to process" "INFO"
  
  # Make sure the target directories exist
  setup_quarantine
  
  # Process each file in the temporary quarantine directory
  find "$TEMP_QUARANTINE_DIR" -type f 2>/dev/null | while read -r file; do
    local basename=$(basename "$file")
    local timestamp=$(date "+%Y%m%d%H%M%S")
    local target_file="${QUARANTINE_CURRENT_DIR}/${basename}.${timestamp}"
    
    # Move file to permanent quarantine
    if mv "$file" "$target_file" 2>/dev/null; then
      log "Moved $basename to permanent quarantine" "SUCCESS"
      chmod 600 "$target_file" 2>/dev/null
      
      # Create metadata for the quarantined file
      create_metadata_file "$basename" "$target_file"
    else
      log "Failed to move $basename to permanent quarantine" "ERROR"
    fi
  done
  
  # Clean up temporary quarantine directory
  cleanup_quarantine_temp
  
  log "Completed processing quarantined files" "SUCCESS"
  return 0
}

# Create a simple metadata file for a quarantined file
# Usage: create_metadata_file original_name quarantined_path
# Returns: 0 on success, 1 on failure
create_metadata_file() {
  local original_name="$1"
  local quarantined_path="$2"
  
  # Create metadata file name
  local metadata_file="${METADATA_CURRENT_DIR}/$(basename "$quarantined_path").meta"
  
  # Get file information
  local detect_date=$(date "+%Y-%m-%d %H:%M:%S")
  local file_size=$(stat -f%z "$quarantined_path" 2>/dev/null || 
                    stat -c%s "$quarantined_path" 2>/dev/null || 
                    echo "unknown")
                   
  # Create simple metadata file
  {
    echo "File: $original_name"
    echo "Date: $detect_date"
    echo "Size: $file_size bytes"
    echo "Location: $quarantined_path"
    echo "ScanID: ${SCAN_ID:-unknown}"
  } > "$metadata_file" 2>/dev/null || {
    log "Failed to create metadata file: $metadata_file" "ERROR"
    return 1
  }
  
  # Set secure permissions
  chmod 600 "$metadata_file" 2>/dev/null
  
  log "Created metadata for quarantined file: $original_name" "INFO"
  return 0
}

# Clean up temporary quarantine directory
# Usage: cleanup_quarantine_temp
# Returns: 0 on success
cleanup_quarantine_temp() {
  # Remove empty directories
  if [ -d "$TEMP_QUARANTINE_DIR" ]; then
    find "$TEMP_QUARANTINE_DIR" -type d -empty -delete 2>/dev/null
    log "Cleaned up temporary quarantine directory" "DEBUG"
  fi
  return 0
}

# Export module marker
QUARANTINE_LOADED=true
