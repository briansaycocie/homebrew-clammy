#!/bin/bash
#================================================================
# 🔒 Clammy Quarantine Management System
#================================================================
# Advanced quarantine features for ClamAV with rotation, retention
# policies, and malware classification
#================================================================

# Exit on error, undefined variables, and handle pipes properly
set -euo pipefail

# Source the core library for shared functionality if not already loaded
if [ -z "${CORE_LOADED:-}" ]; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "$SCRIPT_DIR/core.sh" || {
    echo "Error: Failed to load core library from quarantine_enhanced.sh. Exiting." >&2
    exit 1
  }
fi

# Source utilities module if not already loaded
if [ -z "${UTILS_LOADED:-}" ]; then
  source "$SCRIPT_DIR/utils.sh" || {
    echo "Error: Failed to load utils library from quarantine_enhanced.sh. Exiting." >&2
    exit 1
  }
fi

# Global variables for quarantine system
QUARANTINE_DB="${SECURITY_DIR}/quarantine_db.sqlite"
QUARANTINE_INDEX="${SECURITY_DIR}/quarantine_index.json"
QUARANTINE_LOCK="${SECURITY_DIR}/quarantine.lock"
QUARANTINE_METADATA_DIR="${SECURITY_DIR}/metadata"

# Initialize the enhanced quarantine system
# Usage: setup_enhanced_quarantine
setup_enhanced_quarantine() {
  log "Setting up enhanced quarantine system..." "INFO"
  
  # Skip if quarantine is disabled
  if [ "${QUARANTINE_ENABLED:-false}" != "true" ]; then
    log "Quarantine disabled by configuration" "INFO"
    return 0
  fi
  
  # Create necessary directories
  for dir in \
    "$QUARANTINE_DIR" \
    "${QUARANTINE_DIR}/tmp" \
    "$QUARANTINE_METADATA_DIR" \
    "${SECURITY_DIR}/logs"; do
    if ! ensure_dir_exists "$dir"; then
      log "Failed to create quarantine directory: $dir" "ERROR"
      return 1
    fi
    
    # Set secure permissions (owner only)
    chmod 700 "$dir" 2>/dev/null || log "Failed to set secure permissions on $dir" "WARNING"
  done
  
  # Initialize quarantine database if needed
  initialize_quarantine_db
  
  # Create current rotation directory
  create_rotation_directory
  
  log "Enhanced quarantine system setup completed" "SUCCESS"
  return 0
}

# Initialize the quarantine database
# Usage: initialize_quarantine_db
initialize_quarantine_db() {
  # Check if we have sqlite3 available
  if ! command -v sqlite3 >/dev/null 2>&1; then
    log "SQLite3 not available, using file-based index instead" "WARNING"
    initialize_quarantine_index
    return 0
  fi
  
  # Check if database needs to be created
  if [ ! -f "$QUARANTINE_DB" ]; then
    log "Creating new quarantine database at $QUARANTINE_DB" "INFO"
    
    # Create directory if needed
    local db_dir=$(dirname "$QUARANTINE_DB")
    if [ ! -d "$db_dir" ]; then
      mkdir -p "$db_dir" || {
        log "Failed to create database directory: $db_dir" "ERROR"
        return 1
      }
    fi
    
    # Create database schema
    sqlite3 "$QUARANTINE_DB" <<EOF
CREATE TABLE quarantine_files (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  original_path TEXT NOT NULL,
  quarantine_path TEXT NOT NULL,
  detection_name TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  scan_id TEXT NOT NULL,
  risk_level TEXT NOT NULL,
  retention_days INTEGER NOT NULL,
  expiry_date INTEGER NOT NULL,
  file_hash TEXT,
  file_size INTEGER,
  file_type TEXT,
  archived INTEGER DEFAULT 0,
  status TEXT DEFAULT 'active'
);

CREATE TABLE quarantine_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp INTEGER NOT NULL,
  file_id INTEGER,
  event_type TEXT NOT NULL,
  details TEXT,
  FOREIGN KEY(file_id) REFERENCES quarantine_files(id)
);

CREATE INDEX idx_quarantine_files_expiry ON quarantine_files(expiry_date);
CREATE INDEX idx_quarantine_files_status ON quarantine_files(status);
CREATE INDEX idx_quarantine_files_risk ON quarantine_files(risk_level);
PRAGMA journal_mode=WAL;
EOF
    
    if [ $? -ne 0 ]; then
      log "Failed to create quarantine database schema" "ERROR"
      return 1
    fi
    
    # Set secure permissions
    chmod 600 "$QUARANTINE_DB" 2>/dev/null || log "Failed to set secure permissions on database" "WARNING"
    
    log "Quarantine database initialized" "SUCCESS"
  else
    # Verify database is valid
    if ! sqlite3 "$QUARANTINE_DB" "SELECT count(*) FROM sqlite_master;" >/dev/null 2>&1; then
      log "Existing quarantine database is corrupted, creating backup and new database" "WARNING"
      mv "$QUARANTINE_DB" "${QUARANTINE_DB}.bak.$(date +%s)" 2>/dev/null
      initialize_quarantine_db
      return $?
    fi
  fi
  
  return 0
}

# Initialize JSON-based quarantine index (fallback when SQLite isn't available)
# Usage: initialize_quarantine_index
initialize_quarantine_index() {
  if [ ! -f "$QUARANTINE_INDEX" ]; then
    log "Creating new quarantine index file at $QUARANTINE_INDEX" "INFO"
    
    # Create directory if needed
    local index_dir=$(dirname "$QUARANTINE_INDEX")
    if [ ! -d "$index_dir" ]; then
      mkdir -p "$index_dir" || {
        log "Failed to create index directory: $index_dir" "ERROR"
        return 1
      }
    }
    
    # Create empty index
    echo '{
  "quarantine_files": [],
  "metadata": {
    "created": "'$(date +%s)'",
    "version": "1.0"
  }
}' > "$QUARANTINE_INDEX" || {
      log "Failed to create quarantine index file" "ERROR"
      return 1
    }
    
    # Set secure permissions
    chmod 600 "$QUARANTINE_INDEX" 2>/dev/null || log "Failed to set secure permissions on index file" "WARNING"
    
    log "Quarantine index initialized" "SUCCESS"
  fi
  
  return 0
}

# Create a rotation directory for the current period
# Usage: create_rotation_directory
create_rotation_directory() {
  # Format: YYYY-MM-DD
  local current_date
  current_date=$(date "+%Y-%m-%d")
  
  # Create directory
  CURRENT_QUARANTINE_DIR="${QUARANTINE_DIR}/${current_date}"
  CURRENT_METADATA_DIR="${QUARANTINE_METADATA_DIR}/${current_date}"
  
  for dir in "$CURRENT_QUARANTINE_DIR" "$CURRENT_METADATA_DIR"; do
    if ! ensure_dir_exists "$dir"; then
      log "Failed to create rotation directory: $dir" "ERROR"
      return 1
    fi
    
    # Set secure permissions
    chmod 700 "$dir" 2>/dev/null || log "Failed to set secure permissions on $dir" "WARNING"
  done
  
  debug "Created rotation directories for $current_date"
  return 0
}

#----------- Malware Classification System -----------#

# Enhanced malware classification with detailed categories
# Usage: classify_malware detection_name [file_path] [file_type]
# Returns: "risk_level:retention_days:category"
classify_malware() {
  local detection_name="$1"
  local file_path="${2:-}"
  local file_type="${3:-}"
  
  # Default classification (medium risk, 90 days retention)
  local risk_level="medium"
  local retention_days=90
  local category="malware"
  
  # Convert detection_name to lowercase for easier matching
  local detection_lower="${detection_name,,}"
  
  # Check for high-risk malware types
  if [[ "$detection_lower" =~ (trojan|backdoor|rootkit|banker|keylogger|ransomware) ]]; then
    risk_level="high"
    retention_days=365
    
    # Further categorize high-risk threats
    if [[ "$detection_lower" =~ ransomware ]]; then
      category="ransomware"
    elif [[ "$detection_lower" =~ (trojan|banker) ]]; then
      category="trojan"
    elif [[ "$detection_lower" =~ backdoor ]]; then
      category="backdoor"
    elif [[ "$detection_lower" =~ rootkit ]]; then
      category="rootkit"
    elif [[ "$detection_lower" =~ keylogger ]]; then
      category="spyware"
    fi
  # Check for critical-risk advanced threats
  elif [[ "$detection_lower" =~ (apt|targeted|zero[-_]day|exploit) ]]; then
    risk_level="critical"
    retention_days=730  # 2 years
    category="advanced_threat"
  # Check for low-risk threats
  elif [[ "$detection_lower" =~ (adware|pua|potentially|unwanted|suspicious|heuristic) ]]; then
    risk_level="low"
    retention_days=30
    
    # Further categorize low-risk threats
    if [[ "$detection_lower" =~ adware ]]; then
      category="adware"
    elif [[ "$detection_lower" =~ (pua|potentially|unwanted) ]]; then
      category="pua"
    elif [[ "$detection_lower" =~ (suspicious|heuristic) ]]; then
      category="suspicious"
    fi
  fi
  
  # Further adjust based on file type if available
  if [ -n "$file_type" ]; then
    if [[ "$file_type" == *"executable"* || "$file_type" == *"application"* ]]; then
      # Executables are higher risk
      if [ "$risk_level" = "low" ]; then
        risk_level="medium"
        retention_days=90
      elif [ "$risk_level" = "medium" ]; then
        retention_days=180
      fi
    elif [[ "$file_type" == *"script"* || "$file_type" == *"javascript"* || "$file_type" == *"shell"* ]]; then
      # Scripts are also higher risk
      if [ "$risk_level" = "low" ]; then
        risk_level="medium"
        retention_days=60
      fi
    fi
  fi
  
  debug "Classified \"$detection_name\" as $risk_level risk ($category), retention: $retention_days days"
  echo "${risk_level}:${retention_days}:${category}"
}

# Calculate expiry timestamp for a quarantined file
# Usage: calculate_expiry_timestamp retention_days
calculate_expiry_timestamp() {
  local retention_days="$1"
  local current_ts
  current_ts=$(date +%s)
  
  # Check for special retention values
  if [ "$retention_days" -le 0 ]; then
    # Keep indefinitely (use far future date)
    echo "9999999999"
  else
    # Calculate expiry date (current time + retention in seconds)
    echo $((current_ts + (retention_days * 86400)))
  fi
}

#----------- Quarantine File Processing -----------#

# Process files moved to quarantine by ClamAV
# Usage: process_quarantined_files
# Returns: 0 on success, non-zero on error
process_quarantined_files() {
  log "Processing quarantined files..." "QUARANTINE"
  
  # Skip if quarantine is disabled
  if [ "${QUARANTINE_ENABLED:-false}" != "true" ]; then
    log "Quarantine processing skipped (disabled in configuration)" "INFO"
    return 0
  fi
  
  # Ensure quarantine directories exist
  setup_enhanced_quarantine || return 1
  
  # Get temporary quarantine directory
  local temp_dir="${QUARANTINE_DIR}/tmp"
  
  # Check if there are files to process
  local file_count
  file_count=$(find "$temp_dir" -type f 2>/dev/null | wc -l)
  file_count=$((file_count + 0))  # Convert to number, removing whitespace
  
  if [ "$file_count" -eq 0 ]; then
    log "No files found in temporary quarantine directory" "INFO"
    return 0
  fi
  
  log "Found $file_count file(s) to quarantine" "QUARANTINE"
  
  # Create current rotation directory if not exists
  create_rotation_directory || return 1
  
  # Process each quarantined file
  local processed=0
  local failed=0
  
  find "$temp_dir" -type f -print0 2>/dev/null | while IFS= read -r -d $'\0' file; do
    local filename=$(basename "$file")
    local timestamp=$(date +%s)
    local target="${CURRENT_QUARANTINE_DIR}/${filename}_${timestamp}"
    
    if mv "$file" "$target" 2>/dev/null; then
      # Set secure permissions
      chmod 600 "$target" 2>/dev/null || log "Failed to set permissions on quarantined file" "WARNING"
      
      # Extract detection name from scan output if available
      local detection_name="Unknown"
      if [ -f "${SCAN_OUTPUT_FILE:-}" ]; then
        detection_name=$(grep -E ": .+FOUND$" "${SCAN_OUTPUT_FILE}" | grep -F "$filename" | 
                        sed -E 's/^.*: (.*) FOUND$/\1/' | head -1 || echo "Unknown")
      fi
      
      # Get file info
      local file_size
      local file_type
      local file_hash
      
      file_size=$(stat -f%z "$target" 2>/dev/null || stat -c%s "$target" 2>/dev/null || echo "0")
      file_type=$(file -b --mime-type "$target" 2>/dev/null || echo "application/octet-stream")
      
      # Calculate checksum
      if command -v shasum >/dev/null 2>&1; then
        file_hash=$(shasum -a 256 "$target" 2>/dev/null | cut -d' ' -f1)
      elif command -v sha256sum >/dev/null 2>&1; then
        file_hash=$(sha256sum "$target" 2>/dev/null | cut -d' ' -f1)
      else
        file_hash="unknown"
      fi
      
      # Classify malware and get retention policy
      local classification
      classification=$(classify_malware "$detection_name" "$file" "$file_type")
      
      local risk_level="${classification%%:*}"
      classification="${classification#*:}"
      local retention_days="${classification%%:*}"
      local category="${classification#*:}"
      
      # Calculate expiry date
      local expiry
      expiry=$(calculate_expiry_timestamp "$retention_days")
      
      # Create metadata for the quarantined file
      local metadata_file="${CURRENT_METADATA_DIR}/${filename}_${timestamp}.json"
      
      cat > "$metadata_file" <<EOF || {
        log "Failed to create metadata file: $metadata_file" "ERROR"
        failed=$((failed + 1))
        continue
      }
{
  "original_path": "$file",
  "quarantine_path": "$target",
  "detection_name": "$detection_name",
  "quarantine_date": "$timestamp",
  "scan_id": "${SCAN_ID:-unknown}",
  "risk_assessment": {
    "level": "$risk_level",
    "category": "$category",
    "retention_days": $retention_days,
    "expiry_date": $expiry
  },
  "file_info": {
    "size": "$file_size",
    "type": "$file_type",
    "sha256": "$file_hash"
  }
}
EOF
      
      # Set secure permissions on metadata
      chmod 600 "$metadata_file" 2>/dev/null || log "Failed to set permissions on metadata file" "WARNING"
      
      # Add to quarantine database/index
      if command -v sqlite3 >/dev/null 2>&1; then
        # Use SQLite database
        sqlite3 "$QUARANTINE_DB" <<EOF || {
          log "Failed to add quarantine record to database" "ERROR"
          failed=$((failed + 1))
          continue
        }
INSERT INTO quarantine_files (
  original_path,
  quarantine_path,
  detection_name,
  timestamp,
  scan_id,
  risk_level,
  retention_days,
  expiry_date,
  file_hash,
  file_size,
  file_type
) VALUES (
  '$file',
  '$target',
  '$detection_name',
  $timestamp,
  '${SCAN_ID:-unknown}',
  '$risk_level',
  $retention_days,
  $expiry,
  '$file_hash',
  $file_size,
  '$file_type'
);

INSERT INTO quarantine_events (
  timestamp,
  file_id,
  event_type,
  details
) VALUES (
  $timestamp,
  last_insert_rowid(),
  'quarantined',
  'File quarantined during scan'
);
EOF
      else
        # Use JSON index file as fallback
        update_quarantine_index "$file" "$target" "$detection_name" "$timestamp" \
          "$risk_level" "$retention_days" "$expiry" "$file_hash" "$file_size" "$file_type"
      fi
      
      processed=$((processed + 1))
      log "Quarantined: $filename (${risk_level} risk)" "QUARANTINE"
    else
      log "Failed to quarantine: $filename" "ERROR"
      failed=$((failed + 1))
    fi
  done
  
  # Clean up empty directories
  find "$temp_dir" -type d -empty -delete 2>/dev/null
  
  # Report results
  if [ $processed -gt 0 ]; then
    log "Successfully quarantined $processed file(s)" "SUCCESS"
  fi
  if [ $failed -gt 0 ]; then
    log "Failed to quarantine $failed file(s)" "WARNING"
  fi
  
  # Run cleanup of expired files if configured
  if [ "${AUTO_CLEANUP_ENABLED:-true}" = "true" ]; then
    cleanup_expired_quarantine
  fi
  
  return $(( failed > 0 ? 1 : 0 ))
}

# Update the JSON quarantine index file (fallback for systems without SQLite)
# Usage: update_quarantine_index original_path quarantine_path detection_name timestamp risk_level retention_days expiry hash size type
update_quarantine_index() {
  local original_path="$1"
  local quarantine_path="$2"
  local detection_name="$3"
  local timestamp="$4"
  local risk_level="$5"
  local retention_days="$6"
  local expiry="$7"
  local file_hash="$8"
  local file_size="$9"
  local file_type="${10}"
  
  # Acquire a lock for index modification
  local lock_fd=9
  local lock_acquired=false
  
  # Try to acquire lock with timeout
  exec {lock_fd}>>"$QUARANTINE_LOCK"
  flock -w 10 $lock_fd || {
    log "Failed to acquire lock for quarantine index update" "ERROR"
    return 1
  }
  lock_acquired=true
  
  # Create temporary file for atomic update
  local temp_index
  temp_index=$(mktemp -t "quarantine-index.XXXXXX")
  
  # Read current index and prepare for update
  if [ -s "$QUARANTINE_INDEX" ] && [ -r "$QUARANTINE_INDEX" ]; then
    # Check if index is valid JSON
    if grep -q '"quarantine_files"' "$QUARANTINE_INDEX"; then
      # Remove closing bracket to append new entry
      sed -e '$ s/^}//' "$QUARANTINE_INDEX" > "$temp_index"
      
      # Check if we need a comma
      if grep -q '"quarantine_files": \[\]' "$temp_index"; then
        # Empty array, rewrite with opening
        sed -i.bak 's/"quarantine_files": \[\]/"quarantine_files": [/' "$temp_index" || true
      else
        # Add comma if array already has items
        echo "," >> "$temp_index"
      fi
    else
      # Create new index structure
      echo '{
  "quarantine_files": [' > "$temp_index"
    fi
  else
    # Initialize new index
    echo '{
  "quarantine_files": [' > "$temp_index"
  fi
  
  # Add new entry
  cat >> "$temp_index" <<EOF
    {
      "id": "$(uuidgen 2>/dev/null || echo "id_${timestamp}_$$")",
      "original_path": "$original_path",
      "quarantine_path": "$quarantine_path",
      "detection_name": "$detection_name",
      "timestamp": $timestamp,
      "scan_id": "${SCAN_ID:-unknown}",
      "risk_level": "$risk_level",
      "retention_days": $retention_days,
      "expiry_date": $expiry,
      "status": "active",
      "file_info": {
        "sha256": "$file_hash",
        "size": $file_size,
        "type": "$file_type"
      }
    }
  ]
}
EOF
  
  # Atomically replace index file
  mv "$temp_index" "$QUARANTINE_INDEX" || {
    log "Failed to update quarantine index" "ERROR"
    rm -f "$temp_index"
    # Release lock
    [ "$lock_acquired" = true ] && exec {lock_fd}>&-
    return 1
  }
  
  # Release lock
  [ "$lock_acquired" = true ] && exec {lock_fd}>&-
  
  return 0
}

#----------- Quarantine Rotation and Cleanup -----------#

# Rotate quarantine directories and enforce retention policy
# Usage: rotate_quarantine
rotate_quarantine() {
  log "Rotating quarantine directories..." "INFO"
  
  # Skip if quarantine is disabled
  if [ "${QUARANTINE_ENABLED:-false}" != "true" ]; then
    log "Quarantine rotation skipped (disabled in configuration)" "INFO"
    return 0
  }
  
  # Create new rotation directory
  create_rotation_directory || return 1
  
  # Enforce size limit if configured
  if [ -n "${QUARANTINE_MAX_SIZE:-}" ] && [ "$QUARANTINE_MAX_SIZE" -gt 0 ]; then
    enforce_quarantine_size_limit
  fi
  
  # Clean up expired files
  cleanup_expired_quarantine
  
  log "Quarantine rotation completed" "SUCCESS"
  return 0
}

# Enforce size limit on quarantine directory
# Usage: enforce_quarantine_size_limit
enforce_quarantine_size_limit() {
  local max_size_mb=${QUARANTINE_MAX_SIZE}
  log "Enforcing quarantine size limit of ${max_size_mb}MB..." "INFO"
  
  # Get current size in MB
  local current_size_kb=$(du -sk "$QUARANTINE_DIR" 2>/dev/null | cut -f1)
  local current_size_mb=$((current_size_kb / 1024))
  
  if [ "$current_size_mb" -gt "$max_size_mb" ]; then
    log "Quarantine exceeds size limit: ${current_size_mb}MB / ${max_size_mb}MB" "WARNING"
    
    # Calculate how much to remove
    local excess_mb=$((current_size_mb - max_size_mb))
    local target_removal_kb=$((excess_mb * 1024 + 1024))  # Add buffer
    
    log "Need to remove approximately ${excess_mb}MB" "INFO"
    
    if command -v sqlite3 >/dev/null 2>&1; then
      # Use SQLite to find oldest files
      local files_to_remove
      files_to_remove=$(sqlite3 "$QUARANTINE_DB" "
        SELECT quarantine_path 
        FROM quarantine_files 
        WHERE status = 'active'
          AND risk_level != 'critical'  -- Don't auto-remove critical files
        ORDER BY timestamp ASC;
      ")
      
      local removed_kb=0
      local removed_count=0
      
      echo "$files_to_remove" | while IFS= read -r file; do
        if [ "$removed_kb" -ge "$target_removal_kb" ]; then
          break
        fi
        
        if [ -f "$file" ]; then
          local file_size_kb=$(du -sk "$file" 2>/dev/null | cut -f1)
          
          if rm -f "$file" 2>/dev/null; then
            sqlite3 "$QUARANTINE_DB" "
              UPDATE quarantine_files 
              SET status = 'removed', archived = 1 
              WHERE quarantine_path = '$file';
              
              INSERT INTO quarantine_events (
                timestamp, 
                file_id,
                event_type,
                details
              ) SELECT 
                $(date +%s),
                id,
                'removed',
                'File removed due to size limit enforcement'
              FROM quarantine_files
              WHERE quarantine_path = '$file';
            "
            removed_kb=$((removed_kb + file_size_kb))
            removed_count=$((removed_count + 1))
          fi
        fi
        
        if [ $((removed_count % 10)) -eq 0 ]; then
          log "Removed $removed_count files (${removed_kb}KB) so far..." "INFO"
        fi
      done
      
      log "Removed $removed_count files ($(( removed_kb / 1024 ))MB) to enforce size limit" "SUCCESS"
    else
      # Use find to select oldest files when SQLite is not available
      log "SQLite not available, using file timestamps for size enforcement" "WARNING"
      
      local removed_kb=0
      local removed_count=0
      
      # Find oldest files first
      find "$QUARANTINE_DIR" -type f -name "*.json" -prune -o -type f -print0 | 
      xargs -0 ls -tr 2>/dev/null | 
      while read -r file; do
        if [ "$removed_kb" -ge "$target_removal_kb" ]; then
          break
        fi
        
        if [ -f "$file" ]; then
          local file_size_kb=$(du -sk "$file" 2>/dev/null | cut -f1)
          
          if rm -f "$file" 2>/dev/null; then
            # Also remove corresponding metadata if we can find it
            local base_name=$(basename "$file")
            find "$QUARANTINE_METADATA_DIR" -name "${base_name}*.json" -delete 2>/dev/null || true
            
            removed_kb=$((removed_kb + file_size_kb))
            removed_count=$((removed_count + 1))
          fi
        fi
      done
      
      log "Removed $removed_count files ($(( removed_kb / 1024 ))MB) to enforce size limit" "SUCCESS"
    fi
  else
    log "Quarantine size within limits: ${current_size_mb}MB / ${max_size_mb}MB" "INFO"
  fi
}

# Clean up expired quarantined files
# Usage: cleanup_expired_quarantine
cleanup_expired_quarantine() {
  log "Checking for expired quarantined files..." "INFO"
  
  local current_time
  current_time=$(date +%s)
  local removed=0
  local errors=0
  
  if command -v sqlite3 >/dev/null 2>&1; then
    # Use SQLite database for cleanup
    local expired_files
    expired_files=$(sqlite3 "$QUARANTINE_DB" "
      SELECT quarantine_path 
      FROM quarantine_files 
      WHERE expiry_date <= $current_time 
        AND status = 'active'
        AND archived = 0;
    ")
    
    if [ -n "$expired_files" ]; then
      echo "$expired_files" | while IFS= read -r file; do
        if [ -f "$file" ]; then
          if rm -f "$file" 2>/dev/null; then
            sqlite3 "$QUARANTINE_DB" "
              UPDATE quarantine_files 
              SET status = 'expired', archived = 1 
              WHERE quarantine_path = '$file';
              
              INSERT INTO quarantine_events (
                timestamp, 
                file_id,
                event_type,
                details
              ) SELECT 
                $current_time,
                id,
                'expired',
                'File removed due to expiration'
              FROM quarantine_files
              WHERE quarantine_path = '$file';
            "
            removed=$((removed + 1))
            debug "Removed expired file: $file"
          else
            errors=$((errors + 1))
            log "Failed to remove expired file: $file" "ERROR"
          fi
        fi
      done
    fi
  else
    # Use JSON index for cleanup when SQLite is not available
    if [ -f "$QUARANTINE_INDEX" ]; then
      # Acquire lock
      local lock_fd=9
      exec {lock_fd}>>"$QUARANTINE_LOCK"
      flock -w 10 $lock_fd || {
        log "Failed to acquire lock for quarantine cleanup" "ERROR"
        return 1
      }
      
      local temp_index
      temp_index=$(mktemp -t "quarantine-index.XXXXXX")
      
      # Extract non-expired files to new index
      # Extract non-expired files to new index
      jq --arg now "$current_time" '
        .quarantine_files = [
          .quarantine_files[] | 
          if (.expiry_date | tonumber) <= ($now | tonumber) then
            .status = "expired"
          else
            .
          end
        ]
      ' "$QUARANTINE_INDEX" > "$temp_index" 2>/dev/null
      
      # Process expired files from the index
      jq -r --arg now "$current_time" '
        .quarantine_files[] | 
        select((.expiry_date | tonumber) <= ($now | tonumber) and .status == "active") |
        .quarantine_path
      ' "$QUARANTINE_INDEX" 2>/dev/null | while IFS= read -r file; do
        if [ -f "$file" ]; then
          if rm -f "$file" 2>/dev/null; then
            removed=$((removed + 1))
            debug "Removed expired file: $file"
            
            # Remove corresponding metadata file if it exists
            local base_name=$(basename "$file")
            find "$QUARANTINE_METADATA_DIR" -name "${base_name}*.json" -delete 2>/dev/null || true
          else
            errors=$((errors + 1))
            log "Failed to remove expired file: $file" "ERROR"
          fi
        fi
      done
      
      # Update index file atomically
      mv "$temp_index" "$QUARANTINE_INDEX" || {
        log "Failed to update quarantine index during cleanup" "ERROR"
        rm -f "$temp_index"
        exec {lock_fd}>&-  # Release lock
        return 1
      }
      
      # Release lock
      exec {lock_fd}>&-
    fi
  fi
  
  # Report cleanup results
  if [ $removed -gt 0 ]; then
    log "Removed $removed expired file(s)" "SUCCESS"
  fi
  if [ $errors -gt 0 ]; then
    log "Failed to remove $errors expired file(s)" "WARNING"
  fi
  
  return $(( errors > 0 ? 1 : 0 ))
}

# Clean up old rotation logs
# Usage: cleanup_rotation_logs [days_to_keep]
cleanup_rotation_logs() {
  local days_to_keep=${1:-30}  # Default: keep 30 days of logs
  log "Cleaning up rotation logs older than $days_to_keep days..." "INFO"
  
  local removed=0
  local errors=0
  
  # Find and remove old log files
  find "${SECURITY_DIR}/logs" -type f -name "quarantine-*.log" -mtime "+${days_to_keep}" -print0 2>/dev/null | 
  while IFS= read -r -d $'\0' log_file; do
    if rm -f "$log_file" 2>/dev/null; then
      removed=$((removed + 1))
      debug "Removed old log file: $log_file"
    else
      errors=$((errors + 1))
      log "Failed to remove old log file: $log_file" "ERROR"
    fi
  done
  
  # Find and remove old rotation directories if empty
  find "$QUARANTINE_DIR" -type d -not -path "$QUARANTINE_DIR" -mtime "+${days_to_keep}" -print0 2>/dev/null |
  while IFS= read -r -d $'\0' dir; do
    # Only remove if directory is empty
    if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
      if rmdir "$dir" 2>/dev/null; then
        debug "Removed empty quarantine directory: $dir"
      fi
    fi
  done
  
  if [ $removed -gt 0 ]; then
    log "Removed $removed old log file(s)" "SUCCESS"
  fi
  
  return $(( errors > 0 ? 1 : 0 ))
}

#----------- Quarantine Reporting -----------#

# Generate a quarantine status report
# Usage: report_quarantine_status [--format=text|json]
report_quarantine_status() {
  local format="text"
  
  # Parse arguments
  while [ $# -gt 0 ]; do
    case "$1" in
      --format=*)
        format="${1#*=}"
        shift
        ;;
      *)
        shift
        ;;
    esac
  done
  
  local current_time
  current_time=$(date +%s)
  
  if [ "$format" = "json" ]; then
    # Generate JSON report
    if command -v sqlite3 >/dev/null 2>&1; then
      sqlite3 -json "$QUARANTINE_DB" "
        SELECT 
          COUNT(*) as total_files,
          SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as active_files,
          SUM(CASE WHEN status = 'expired' THEN 1 ELSE 0 END) as expired_files,
          SUM(file_size) / 1024 / 1024 as total_size_mb,
          COUNT(DISTINCT risk_level) as risk_levels,
          GROUP_CONCAT(DISTINCT risk_level) as risk_level_list
        FROM quarantine_files;
        
        SELECT 
          risk_level,
          COUNT(*) as count,
          SUM(file_size) / 1024 / 1024 as size_mb
        FROM quarantine_files
        WHERE status = 'active'
        GROUP BY risk_level
        ORDER BY count DESC;
        
        SELECT 
          quarantine_path,
          detection_name,
          risk_level,
          datetime(expiry_date, 'unixepoch') as expires
        FROM quarantine_files
        WHERE status = 'active'
          AND expiry_date > $current_time
          AND expiry_date <= ($current_time + 604800)
        ORDER BY expiry_date ASC;
      "
    else
      # Generate JSON report from index file
      if [ -f "$QUARANTINE_INDEX" ]; then
        # Generate summary statistics
        jq --arg now "$current_time" '{
          summary: {
            total_files: .quarantine_files | length,
            active_files: [.quarantine_files[] | select(.status == "active")] | length,
            expired_files: [.quarantine_files[] | select(.status != "active")] | length
          },
          by_risk: [
            .quarantine_files | 
            group_by(.risk_level) | 
            map({
              risk_level: .[0].risk_level, 
              count: length,
              files: map(select(.status == "active"))
            })
          ],
          expiring_soon: [
            .quarantine_files[] | 
            select(
              .status == "active" and
              (.expiry_date | tonumber) > ($now | tonumber) and
              (.expiry_date | tonumber) <= (($now | tonumber) + 604800)
            ) | {
              path: .quarantine_path,
              detection: .detection_name,
              expires: .expiry_date
            }
          ]
        }' "$QUARANTINE_INDEX" 2>/dev/null || echo "{}"
      else
        echo "{}"
      fi
    fi
  else
    # Generate text report
    echo "=== Quarantine Status Report ==="
    echo "Generated: $(date)"
    echo ""
    
    if command -v sqlite3 >/dev/null 2>&1; then
      echo "=== Summary ==="
      sqlite3 "$QUARANTINE_DB" "
        SELECT 
          COUNT(*) || ' total files',
          SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) || ' active files',
          SUM(CASE WHEN status = 'expired' THEN 1 ELSE 0 END) || ' expired files',
          ROUND(SUM(file_size) / 1024.0 / 1024.0, 2) || ' MB total size'
        FROM quarantine_files;
      "
      
      echo ""
      echo "=== Files by Risk Level ==="
      sqlite3 "$QUARANTINE_DB" "
        SELECT 
          risk_level || ': ' || 
          COUNT(*) || ' files (' || 
          ROUND(SUM(file_size) / 1024.0 / 1024.0, 1) || ' MB)'
        FROM quarantine_files
        WHERE status = 'active'
        GROUP BY risk_level
        ORDER BY COUNT(*) DESC;
      "
      
      echo ""
      echo "=== Expiring Soon (Next 7 Days) ==="
      sqlite3 "$QUARANTINE_DB" "
        SELECT 
          '- ' || substr(quarantine_path, -30) || 
          ' (' || detection_name || ')' ||
          ' expires ' || datetime(expiry_date, 'unixepoch')
        FROM quarantine_files
        WHERE status = 'active'
          AND expiry_date > $current_time
          AND expiry_date <= ($current_time + 604800)
        ORDER BY expiry_date ASC
        LIMIT 10;
      "
      
      echo ""
      echo "=== Recent Activity ==="
      sqlite3 "$QUARANTINE_DB" "
        SELECT 
          datetime(e.timestamp, 'unixepoch') || ' - ' ||
          e.event_type || ': ' || 
          COALESCE(substr(f.quarantine_path, -30), 'unknown')
        FROM quarantine_events e
        LEFT JOIN quarantine_files f ON e.file_id = f.id
        WHERE e.timestamp > ($current_time - 86400)
        ORDER BY e.timestamp DESC
        LIMIT 10;
      "
    else
      # Basic report from file system
      echo "=== Summary ==="
      local total_files
      total_files=$(find "$QUARANTINE_DIR" -type f -not -name "*.json" 2>/dev/null | wc -l)
      local total_size
      total_size=$(du -sh "$QUARANTINE_DIR" 2>/dev/null | cut -f1)
      echo "Total files: $total_files"
      echo "Total size: $total_size"
      
      echo ""
      echo "=== Storage Usage ==="
      du -sh "$QUARANTINE_DIR"/* 2>/dev/null | sort -hr
      
      if [ -f "$QUARANTINE_INDEX" ]; then
        echo ""
        echo "=== Risk Levels ==="
        jq -r '.quarantine_files | group_by(.risk_level) | map({level: .[0].risk_level, count: length}) | .[] | "\(.level): \(.count) files"' "$QUARANTINE_INDEX" 2>/dev/null
      fi
    fi
    
    echo ""
    echo "=== Quarantine Directory Structure ==="
    find "$QUARANTINE_DIR" -type d -mindepth 1 -maxdepth 1 | sort | while read -r dir; do
      local dir_count=$(find "$dir" -type f -not -name "*.json" 2>/dev/null | wc -l)
      local dir_name=$(basename "$dir")
      echo "- $dir_name: $dir_count files"
    done
  fi
}

# Restore a file from quarantine
# Usage: restore_from_quarantine file_path [destination_dir]
restore_from_quarantine() {
  local file_path="$1"
  local destination="${2:-./restored_files}"
  
  if [ ! -f "$file_path" ]; then
    log "File not found in quarantine: $file_path" "ERROR"
    return 1
  fi
  
  # Create destination directory if it doesn't exist
  if [ ! -d "$destination" ]; then
    mkdir -p "$destination" || {
      log "Failed to create destination directory: $destination" "ERROR"
      return 1
    }
  fi
  
  # Get file information
  local file_name=$(basename "$file_path")
  local metadata_file=""
  
  # Find corresponding metadata file
  if [ -f "${file_path}.meta.json" ]; then
    metadata_file="${file_path}.meta.json"
  else
    # Try to find metadata file in metadata directory
    local base_name="${file_name%_*}"  # Remove timestamp suffix
    metadata_file=$(find "$QUARANTINE_METADATA_DIR" -name "${base_name}*.json" 2>/dev/null | head -1)
  fi
  
  # Get original name if possible
  local original_name="$file_name"
  if [ -n "$metadata_file" ] && [ -f "$metadata_file" ]; then
    local original_path
    original_path=$(grep -o '"original_path": "[^"]*"' "$metadata_file" | cut -d'"' -f4)
    if [ -n "$original_path" ]; then
      original_name=$(basename "$original_path")
    fi
  fi
  
  # Add prefix to indicate it was restored from quarantine
  local dest_file="${destination}/RESTORED_${original_name}"
  
  # Copy the file (don't move it from quarantine)
  if cp "$file_path" "$dest_file"; then
    chmod 600 "$dest_file" || true  # Make restored file secure
    log "Restored file to: $dest_file" "SUCCESS"
    
    # Record the event in the database
    if command -v sqlite3 >/dev/null 2>&1; then
      sqlite3 "$QUARANTINE_DB" "
        INSERT INTO quarantine_events (
          timestamp,
          file_id,
          event_type,
          details
        ) SELECT 
          $(date +%s),
          id,
          'restored',
          'File restored to $dest_file'
        FROM quarantine_files
        WHERE quarantine_path = '$file_path';
      " 2>/dev/null
    fi
    
    return 0
  else
    log "Failed to restore file: $file_path" "ERROR"
    return 1
  fi
}

# Export module marker
QUARANTINE_ENHANCED_LOADED=true
