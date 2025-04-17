#!/bin/bash
#================================================================
# 🧪 Clammy Test Suite
#================================================================
# Comprehensive tests to verify scanner functionality
#================================================================

set -euo pipefail

# Source the core library
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/core.sh" || {
    echo "Error: Failed to load core library" >&2
    exit 1
}

# Test files directory
TEST_DIR="${SCRIPT_DIR}/testfiles"
EICAR_FILE="${TEST_DIR}/eicar.txt"
TEST_RESULTS="${TEST_DIR}/results"

#----------- Test Setup -----------#

setup_test_environment() {
    log "Setting up test environment..." "INFO"
    
    # Create test directories
    mkdir -p "$TEST_DIR" "$TEST_RESULTS"
    
    # Create EICAR test file (standard antivirus test file)
    echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "$EICAR_FILE"
    
    # Create test file structure
    create_test_files
    
    # Check if ClamAV is installed
    if ! command -v clamscan >/dev/null 2>&1; then
        log "ClamAV not installed! Tests cannot continue." "ERROR"
        return 1
    fi
    
    # Check if our scanner is installed
    if ! command -v clamav-scan >/dev/null 2>&1; then
        log "clamav-scan not found in PATH! Tests cannot continue." "ERROR"
        return 1
    }
    
    return 0
}

create_test_files() {
    # Create various test files and directories
    mkdir -p "${TEST_DIR}/documents" "${TEST_DIR}/archives" "${TEST_DIR}/nested"
    
    # Create test documents
    echo "Test document content" > "${TEST_DIR}/documents/test.txt"
    echo "PDF content" > "${TEST_DIR}/documents/test.pdf"
    
    # Create test archive
    if command -v zip >/dev/null 2>&1; then
        (cd "${TEST_DIR}/archives" && zip test.zip ../documents/* 2>/dev/null)
    else
        log "zip command not found, skipping archive test file creation" "WARNING"
        # Create a simple tar file as fallback
        if command -v tar >/dev/null 2>&1; then
            tar -cf "${TEST_DIR}/archives/test.tar" "${TEST_DIR}/documents" 2>/dev/null
        fi
    fi
    
    # Create nested structure for recursive scanning tests
    mkdir -p "${TEST_DIR}/nested/level1/level2/level3"
    touch "${TEST_DIR}/nested/level1/file1.txt"
    touch "${TEST_DIR}/nested/level1/level2/file2.txt"
    touch "${TEST_DIR}/nested/level1/level2/level3/file3.txt"
    
    # Create a file with a space in the name to test path handling
    echo "Test with spaces" > "${TEST_DIR}/documents/test file with spaces.txt"
    
    return 0
}

cleanup_test_environment() {
    log "Cleaning up test environment..." "INFO"
    
    # Remove test files
    rm -rf "$TEST_DIR"
    
    return 0
}

#----------- Test Cases -----------#

# Test basic scanning functionality
test_basic_scan() {
    log "Testing basic scan functionality..." "TEST"
    
    # Test quick scan
    if ! clamav-scan --quick --quiet; then
        log "Quick scan test failed" "ERROR"
        return 1
    fi
    
    # Test specific directory scan
    if ! clamav-scan --scan "$TEST_DIR/documents" --quiet; then
        log "Directory scan test failed" "ERROR"
        return 1
    fi
    
    # Test recursive scanning
    if ! clamav-scan --scan "$TEST_DIR/nested" --quiet; then
        log "Recursive scan test failed" "ERROR"
        return 1
    fi
    
    # Test path with spaces
    if ! clamav-scan --scan "${TEST_DIR}/documents/test file with spaces.txt" --quiet; then
        log "Path with spaces test failed" "ERROR"
        return 1
    fi
    
    log "Basic scan tests passed" "SUCCESS"
    return 0
}

# Test malware detection
test_malware_detection() {
    log "Testing malware detection..." "TEST"
    
    # Scan EICAR test file (should detect as malware)
    if clamav-scan --scan "$EICAR_FILE" --quiet --no-quarantine; then
        log "EICAR detection test failed - malware not detected" "ERROR"
        return 1
    fi
    
    # Verify the exit code is 1 (infected)
    if [ $? -ne 1 ]; then
        log "EICAR detection test failed - wrong exit code" "ERROR"
        return 1
    fi
    
    # Test false positive prevention (should not detect clean files)
    if ! clamav-scan --scan "${TEST_DIR}/documents/test.txt" --quiet; then
        log "False positive test failed - clean file detected as malware" "ERROR"
        return 1
    fi
    
    log "Malware detection test passed" "SUCCESS"
    return 0
}

# Test quarantine functionality
test_quarantine() {
    log "Testing quarantine functionality..." "TEST"
    
    # First ensure EICAR file exists
    if [ ! -f "$EICAR_FILE" ]; then
        # Recreate EICAR file if it was removed by previous tests
        echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "$EICAR_FILE"
    fi
    
    # Enable quarantine and scan EICAR file
    clamav-scan --scan "$EICAR_FILE" --quiet
    
    # Wait a moment for quarantine to complete
    sleep 2
    
    # Check if file was quarantined (should no longer exist at original location)
    if [ -f "$EICAR_FILE" ]; then
        log "Quarantine test failed - infected file not quarantined" "ERROR"
        return 1
    fi
    
    # Check quarantine list
    if ! clamav-scan --quarantine list | grep -q "EICAR"; then
        log "Quarantine test failed - file not in quarantine list" "ERROR"
        return 1
    fi
    
    # Test restoring a file
    local quarantine_id=$(clamav-scan --quarantine list | grep "EICAR" | head -1 | cut -d' ' -f1)
    if [ -n "$quarantine_id" ]; then
        # Restore to test directory
        if ! clamav-scan --quarantine restore "$quarantine_id" "$TEST_DIR"; then
            log "Quarantine restore test failed" "ERROR"
            return 1
        fi
        
        # Verify file was restored
        if ! ls "$TEST_DIR"/RESTORED_* | grep -q "EICAR"; then
            log "Quarantine restore verification failed" "ERROR"
            return 1
        fi
    else
        log "Quarantine ID not found" "ERROR"
        return 1
    fi
    
    log "Quarantine tests passed" "SUCCESS"
    return 0
}

# Test scheduling functionality
test_scheduling() {
    log "Testing scheduling functionality..." "TEST"
    
    # Add test schedule
    if ! clamav-scan --schedule add quick_scan "0 3 * * *" "Test Schedule"; then
        log "Schedule creation test failed" "ERROR"
        return 1
    fi
    
    # Verify schedule exists
    if ! clamav-scan --schedule list | grep -q "Test Schedule"; then
        log "Schedule verification test failed" "ERROR"
        return 1
    fi
    
    # Get the schedule ID
    local schedule_id=$(clamav-scan --schedule list | grep "Test Schedule" | head -1 | awk '{print $2}')
    
    # Test disabling a schedule
    if ! clamav-scan --schedule disable "$schedule_id"; then
        log "Schedule disable test failed" "ERROR"
        return 1
    fi
    
    # Test enabling a schedule
    if ! clamav-scan --schedule enable "$schedule_id"; then
        log "Schedule enable test failed" "ERROR"
        return 1
    fi
    
    # Remove test schedule
    if ! clamav-scan --schedule remove "$schedule_id"; then
        log "Schedule removal test failed" "ERROR"
        return 1
    fi
    
    log "Scheduling tests passed" "SUCCESS"
    return 0
}

# Test configuration management
test_configuration() {
    log "Testing configuration functionality..." "TEST"
    
    # Backup current config
    local config_file="$HOME/.config/clamav-scan/config.conf"
    if [ -f "$config_file" ]; then
        cp "$config_file" "${config_file}.test-backup" 2>/dev/null || true
    fi
    
    # Test config modification
    if ! clamav-scan --config set "quarantine_enabled=true"; then
        log "Configuration modification test failed" "ERROR"
        
        # Restore backup
        if [ -f "${config_file}.test-backup" ]; then
            mv "${config_file}.test-backup" "$config_file" 2>/dev/null || true
        fi
        
        return 1
    fi
    
    # Verify config change
    if ! clamav-scan --config get "quarantine_enabled" | grep -q "true"; then
        log "Configuration verification test failed" "ERROR"
        
        # Restore backup
        if [ -f "${config_file}.test-backup" ]; then
            mv "${config_file}.test-backup" "$config_file" 2>/dev/null || true
        fi
        
        return 1
    fi
    
    # Restore config
    if [ -f "${config_file}.test-backup" ]; then
        mv "${config_file}.test-backup" "$config_file" 2>/dev/null || true
    fi
    
    log "Configuration tests passed" "SUCCESS"
    return 0
}

# Test path handling
test_path_handling() {
    log "Testing path handling..." "TEST"
    
    # Test path with spaces
    if ! clamav-scan --scan "${TEST_DIR}/documents/test file with spaces.txt" --quiet; then
        log "Path with spaces test failed" "ERROR"
        return 1
    fi
    
    # Test path exclusion
    if ! clamav-scan --scan "$TEST_DIR" --exclude "archives" --quiet; then
        log "Path exclusion test failed" "ERROR"
        return 1
    fi
    
    # Test path inclusion
    if ! clamav-scan --scan "$TEST_DIR" --include "*.txt" --quiet; then
        log "Path inclusion test failed" "ERROR"
        return 1
    }
    
    # Test path override (if supported)
    if command -v clamav-scan --paths add-override >/dev/null 2>&1; then
        local orig_path="${TEST_DIR}/documents"
        local override_path="${TEST_DIR}/docs_override"
        
        # Create override directory
        mkdir -p "$override_path"
        
        # Add override
        if ! clamav-scan --paths add-override "${orig_path}:${override_path}"; then
            log "Path override test failed" "ERROR"
            return 1
        fi
        
        # Remove override when done
        clamav-scan --paths remove-override "${orig_path}" || true
    fi
    
    log "Path handling tests passed" "SUCCESS"
    return 0
}

# Test performance features
test_performance() {
    log "Testing performance features..." "TEST"
    
    # Test parallel scanning (if supported)
    if clamav-scan --help | grep -q "\-\-parallel"; then
        if ! clamav-scan --scan "$TEST_DIR" --parallel 2 --quiet; then
            log "Parallel scanning test failed" "ERROR"
            return 1
        fi
    else
        log "Parallel scanning not supported, skipping test" "WARNING"
    fi
    
    # Test memory-mapped scanning (if supported)
    if clamav-scan --help | grep -q "\-\-memory-map"; then
        if ! clamav-scan --scan "$TEST_DIR" --memory-map --quiet; then
            log "Memory-mapped scanning test failed" "ERROR"
            return 1
        fi
    else
        log "Memory-mapped scanning not supported, skipping test" "WARNING"
    fi
    
    # Test light mode scanning
    if clamav-scan --help | grep -q "\-\-light"; then
        if ! clamav-scan --scan "$TEST_DIR" --light --quiet; then
            log "Light mode scanning test failed" "ERROR"
            return 1
        fi
    else
        log "Light mode not supported, skipping test" "WARNING"
    fi
    
    log "Performance tests passed" "SUCCESS"
    return 0
}

# Test database management
test_database() {
    log "Testing database management..." "TEST"
    
    # Test database info retrieval
    if ! clamav-scan --db-info; then
        log "Database info test failed" "ERROR"
        return 1
    fi
    
    # Test database update (skip if not connected to internet)
    if ping -c 1 database.clamav.net >/dev/null 2>&1; then
        if ! clamav-scan --update-db; then
            log "Database update test failed" "ERROR"
            return 1
        fi
    else
        log "No internet connection, skipping database update test" "WARNING"
    fi
    
    log "Database tests passed" "SUCCESS"
    return 0
}

#----------- Test Runner -----------#

run_tests() {
    local failed=0
    local skipped=0
    local passed=0
    
    # Setup test environment
    setup_test_environment || {
        log "Test environment setup failed" "ERROR"
        return 1
    }
    
    # Run test cases
    echo "Running ClamAV Scanner Test Suite"
    echo "================================"
    echo "Date: $(date)"
    echo "System: $(uname -a)"
    echo "ClamAV Version: $(clamscan --version 2>/dev/null | head -1)"
    echo ""
    echo "Running tests..."
    echo ""
    
    # Define all tests
    local tests=(
        "test_basic_scan:Basic Scanning"
        "test_malware_detection:Malware Detection"
        "test_quarantine:Quarantine System"
        "test_scheduling:Scheduling"
        "test_configuration:Configuration"
        "test_path_handling:Path Handling"
        "test_performance:Performance Features"
        "test_database:Database Management"
    )
    
    # Run each test
    for test_entry in "${tests[@]}"; do
        IFS=: read -r test_func test_name <<< "$

