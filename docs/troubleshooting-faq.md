# Troubleshooting FAQ

This guide addresses common issues you might encounter when using Clammy and provides solutions to resolve them.

## Installation Issues

### Q: ClamAV database cannot be found

**Problem:** The scanner reports that it cannot find the ClamAV database files.

**Solution:**
1. Verify that ClamAV is properly installed:
   ```bash
   which clamscan
   which freshclam
   ```

2. Update the virus definitions manually:
   ```bash
   freshclam
   ```

3. Check if the database directory exists and has the right permissions:
   ```bash
   # For macOS with Homebrew
   ls -la /opt/homebrew/var/lib/clamav
   
   # For Linux
   ls -la /var/lib/clamav
   ```

4. If the database directory is in a non-standard location, specify it in your configuration:
   ```properties
   # In ~/.config/clamav-scan.conf
   CLAMAV_DB_DIR="/path/to/clamav/database"
   ```

### Q: Missing dependencies error

**Problem:** The scanner exits with code 10 (Missing dependencies).

**Solution:**
1. Install the required dependencies:
   ```bash
   # For macOS
   brew install clamav sqlite jq
   
   # For Debian/Ubuntu
   sudo apt install clamav clamav-daemon sqlite3 jq
   
   # For RHEL/CentOS/Fedora
   sudo dnf install clamav clamav-update sqlite jq
   ```

2. Verify that all binaries are in your PATH:
   ```bash
   which clamscan
   which freshclam
   which sqlite3  # Optional but recommended
   which jq       # Optional but recommended
   ```

## Scanning Issues

### Q: Scan is extremely slow

**Problem:** Scanning takes much longer than expected.

**Solution:**
1. Use the quick scan option for faster results:
   ```bash
   clamav-scan --quick /path/to/scan
   ```

2. Limit the maximum file size to scan:
   ```bash
   clamav-scan --max-size=100 /path/to/scan
   ```

3. Add exclusions for large files or directories that don't need scanning:
   ```bash
   clamav-scan --exclude="*.iso" --exclude="*.vmdk" --exclude="/path/to/large/files/*" /path/to/scan
   ```

4. Use focused scanning patterns on high-risk areas:
   ```bash
   clamav-scan ~/Downloads ~/Documents/attachments
   ```

5. Check if your system has sufficient resources (CPU, memory, disk I/O).

### Q: "ERROR: Can't open file or directory"

**Problem:** The scanner cannot access certain files or directories.

**Solution:**
1. Check file permissions:
   ```bash
   ls -la /path/to/problem/file
   ```

2. Run the scanner with elevated privileges for system directories:
   ```bash
   sudo clamav-scan /system/directory
   ```

3. Check for file locks or if files are in use by other applications.

4. Verify that symbolic links are configured to be followed if needed:
   ```bash
   clamav-scan --follow-symlinks /path/with/symlinks
   ```

### Q: Scan terminates unexpectedly

**Problem:** The scanner stops before completing without a clear error message.

**Solution:**
1. Check system logs for errors:
   ```bash
   # For macOS
   log show --predicate 'processImagePath contains "clamav"' --last 1h
   
   # For Linux
   journalctl -u clamav
   ```

2. Run with verbose output to get more information:
   ```bash
   clamav-scan --verbose /path/to/scan
   ```

3. Check for resource constraints (disk space, memory):
   ```bash
   df -h
   free -m
   ```

4. Try scanning a smaller subset of files to isolate the problem.

## Quarantine Issues

### Q: Files cannot be quarantined

**Problem:** The scanner reports that it cannot quarantine infected files.

**Solution:**
1. Check quarantine directory permissions:
   ```bash
   ls -la ~/Security/quarantine
   ```

2. Ensure the directory exists and is writable:
   ```bash
   mkdir -p ~/Security/quarantine
   chmod 700 ~/Security/quarantine
   ```

3. Check disk space:
   ```bash
   df -h ~/Security
   ```

4. Verify quarantine is enabled in your configuration:
   ```properties
   # In ~/.config/clamav-scan.conf
   QUARANTINE_ENABLED="true"
   ```

### Q: Cannot access quarantined files

**Problem:** You need to access quarantined files but cannot find or restore them.

**Solution:**
1. Generate a quarantine report to locate files:
   ```bash
   clamav-scan --quarantine-report
   ```

2. Use the restore command with the full path:
   ```bash
   clamav-scan --restore-file=/path/to/quarantine/file_1681654321
   ```

3. Check quarantine directory structure:
   ```bash
   find ~/Security/quarantine -type f
   ```

4. Look up the file in the quarantine database:
   ```bash
   sqlite3 ~/Security/quarantine_db.sqlite "SELECT * FROM quarantine_files WHERE detection_name LIKE '%keyword%';"
   ```

### Q: Quarantine database errors

**Problem:** Errors related to the SQLite quarantine database.

**Solution:**
1. Check if SQLite is installed:
   ```bash
   which sqlite3
   ```

2. Verify database permissions:
   ```bash
   ls -la ~/Security/quarantine_db.sqlite
   ```

3. Check for database corruption and rebuild if necessary:
   ```bash
   # Backup current database
   cp ~/Security/quarantine_db.sqlite ~/Security/quarantine_db.sqlite.bak
   
   # Remove corrupted database (the scanner will recreate it)
   rm ~/Security/quarantine_db.sqlite
   
   # Run a scan to initialize a new database
   clamav-scan --quick ~/Downloads
   ```

## Configuration Issues

### Q: Custom configuration not applied

**Problem:** Your custom configuration settings don't seem to be taking effect.

**Solution:**
1. Verify the configuration file location:
   ```bash
   ls -la ~/.config/clamav-scan.conf
   ```

2. Check syntax in your configuration file:
   ```bash
   cat ~/.config/clamav-scan.conf
   ```

3. Run the scanner with verbose output to see which configuration is being loaded:
   ```bash
   clamav-scan --verbose
   ```

4. Make sure variable names are correct and values are properly quoted.

### Q: Exclusions not working

**Problem:** Files or directories you've excluded are still being scanned.

**Solution:**
1. Check the syntax of your exclusion patterns:
   ```properties
   # In ~/.config/clamav-scan.conf
   EXCLUSION_PATTERNS=("*.iso" "*.vmdk" "/path/to/exclude/*")
   ```

2. Use absolute paths for directory exclusions.

3. If using command-line exclusions, ensure they're properly formatted:
   ```bash
   clamav-scan --exclude="*.iso" --exclude="/path/to/exclude" /path/to/scan
   ```

4. Run with verbose output to see if exclusions are being recognized:
   ```bash
   clamav-scan --verbose --exclude="*.iso" /path/to/scan
   ```

## Notification and Reporting Issues

### Q: Email notifications not being sent

**Problem:** Email alerts for scan results aren't being delivered.

**Solution:**
1. Verify email configuration:
   ```properties
   # In ~/.config/clamav-scan.conf
   EMAIL_NOTIFICATIONS="true"
   EMAIL_RECIPIENTS="your.email@example.com"
   ```

2. Check if mail services are available on your system:
   ```bash
   which mail
   which sendmail
   ```

3. Test email delivery manually:
   ```bash
   echo "Test" | mail -s "ClamAV Test" your.email@example.com
   ```

4. Configure an SMTP server if needed:
   ```properties
   # In ~/.config/clamav-scan.conf
   SMTP_SERVER="smtp.example.com"
   SMTP_PORT="587"
   SMTP_USER="username"
   SMTP_PASSWORD="password"
   ```

### Q: Desktop notifications not appearing

**Problem:** System notifications don't appear after scans.

**Solution:**
1. Ensure notifications are enabled:
   ```properties
   # In ~/.config/clamav-scan.conf
   NOTIFICATIONS_ENABLED="true"
   ```

2. Check if required tools are available:
   ```bash
   # For macOS
   which osascript
   
   # For Linux with GNOME
   which notify-send
   ```

3. Test notifications manually:
   ```bash
   # For macOS
   osascript -e 'display notification "Test notification" with title "ClamAV Test"'
   
   # For Linux with GNOME
   notify-send "ClamAV Test" "Test notification"
   ```

4. Check system notification settings to ensure they're not blocked.

## Scheduled Scanning Issues

### Q: Scheduled scans not running

**Problem:** Automated scans set up with cron, launchd, or systemd aren't executing.

**Solution:**
1. Check scheduler logs:
   ```bash
   # For macOS
   log show --predicate 'processImagePath contains "launchd"' --last 6h
   
   # For Linux (cron)
   grep CRON /var/log/syslog
   
   # For Linux (systemd)
   journalctl -u clamav-scan.timer
   ```

2. Verify scheduler configuration:
   ```bash
   # For macOS
   launchctl list | grep clamav
   
   # For Linux (cron)
   crontab -l
   
   # For Linux (systemd)
   systemctl status clamav-scan.timer
   ```

3. Ensure the scanner executable path is correct and absolute.

4. Check file permissions on scheduler configuration files.

5. Run the command manually to verify it works.

### Q: Scheduled scan hanging

**Problem:** Scheduled scans start but never complete.

**Solution:**
1. Add timeouts to scheduled commands:
   ```bash
   # For Linux (cron)
   0 2 * * * timeout 4h /usr/local/bin/clamav-scan /path/to/scan
   ```

2. Use the quick scan option for scheduled scans:
   ```bash
   /usr/local/bin/clamav-scan --quick /path/to/scan
   ```

3. Check for resource bottlenecks during scheduled scan times.

4. Review scanner logs for repeated patterns or stuck operations.

## Performance Optimization

### Q: High CPU usage during scans

**Problem:** Scans are consuming too much CPU and impacting system performance.

**Solution:**
1. Set a lower CPU priority:
   ```bash
   clamav-scan --scan-priority=15 /path/to/scan
   ```

2. Limit the scanner to specific CPU cores (Linux only):
   ```bash
   taskset -c 0,1 clamav-scan /path/to/scan
   ```

3. Schedule scans during low-usage periods.

4. Break large scans into smaller, focused scans:
   ```bash
   clamav-scan ~/Downloads
   clamav-scan ~/Documents
   # Instead of:
   # clamav-scan ~
   ```

### Q: High memory usage

**Problem:** Scanner is using too much memory.

**Solution:**
1. Limit the maximum file size to scan:
   ```bash
   clamav-scan --max-size=100 /path/to/scan
   ```

2. Disable archive scanning for systems with limited memory:
   ```bash
   clamav-scan --no-scan-archives /path/to/scan
   ```

3. Split large scans into smaller batches.

4. Increase system swap if possible.

## Miscellaneous Issues

### Q: Enhanced features not available

**Problem:** Advanced features like risk-based quarantine or detailed reporting aren't working.

**Solution:**
1. Check for optional dependencies:
   ```bash
   which sqlite3
   which jq
   ```

2. Install missing components:
   ```bash
   # For macOS
   brew install sqlite jq
   
   # For Debian/Ubuntu
   sudo apt install sqlite3 jq
   ```

3. Verify that enhanced features are enabled in your configuration.

### Q: Version compatibility issues

**Problem:** The scanner reports compatibility issues with ClamAV versions.

**Solution:**
1. Check your ClamAV version:
   ```bash
   clamscan --version
   ```

2. Update to the latest ClamAV:
   ```bash
   # For macOS
   brew upgrade clamav
   
   # For Debian/Ubuntu
   sudo apt update
   sudo apt upgrade clamav
   ```

3. Check for enhanced scanner updates:
   ```bash
   # For Homebrew tap
   brew update
   brew upgrade clammy
   ```

## Getting More Help

If you've tried the solutions above and still have issues:

1. Check the full logs for detailed error information:
   ```bash
   cat ~/Security/logs/clamav-scan.log
   ```

2. Enable debug logging for more detailed information:
   ```bash
   DEBUG=true clamav-scan --verbose /path/to/scan
   ```

3. Test with minimal configuration to isolate the issue:
   ```bash
   # Rename your config temporarily
   mv ~/.config/clamav-scan.conf ~/.config/clamav-scan.conf.bak
   
   # Run with minimal settings
   clamav-scan --verbose /small/test/directory
   ```

4. Check for related issues in the ClamAV documentation or forums.

5. Report the issue with detailed information about your system, configuration, and errors encountered.
