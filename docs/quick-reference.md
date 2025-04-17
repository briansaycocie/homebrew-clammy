# Quick Reference

This quick reference guide provides a handy summary of the most common commands, options, and configurations for Clammy.

## Common Commands

| Command | Description |
|---------|-------------|
| `clamav-scan` | Run a default scan on your home directory |
| `clamav-scan [directory]` | Scan a specific directory |
| `clamav-scan --help` | Display help information |
| `clamav-scan --version` | Show version information |

## Essential Options

### Scan Control

| Option | Description |
|--------|-------------|
| `--quick` | Skip non-essential operations for faster scanning |
| `--verbose` or `-v` | Show detailed scan information |
| `--quiet` or `-q` | Minimize output, show only errors and detections |
| `--count` or `-c` | Count files before scanning for progress percentage |

### File Selection

| Option | Description |
|--------|-------------|
| `--exclude=PATTERN` | Exclude files matching pattern (can use multiple times) |
| `--max-size=SIZE` | Set maximum file size to scan in MB (default: 500) |
| `--scan-archives` | Scan inside archive files (on by default) |
| `--no-scan-archives` | Skip scanning inside archive files |

### Quarantine Options

| Option | Description |
|--------|-------------|
| `--no-quarantine` | Do not quarantine infected files |
| `--quarantine-report` | Show report of quarantined files |
| `--restore-file=PATH` | Restore a file from quarantine |
| `--clean-quarantine` | Clean expired quarantined files |

### Output Options

| Option | Description |
|--------|-------------|
| `--summary-only` | Only show summary after scan completion |
| `--json-output` | Output results in JSON format |
| `--log-to-syslog` | Send scan results to syslog |
| `--email-report` | Send scan report via email |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | No infections found |
| 1 | Infections found and quarantined |
| 2 | Error during scanning |
| 10 | Required dependencies not found |
| 20 | Insufficient disk space |
| 40 | Error processing quarantined files |

## Configuration Quick Reference

### Common Configuration Settings

```properties
# Paths
SECURITY_DIR="${HOME}/Security"
LOG_DIR="${SECURITY_DIR}/logs"
QUARANTINE_DIR="${SECURITY_DIR}/quarantine"

# Scan behavior
MAX_FILE_SIZE="500"
SCAN_RECURSIVE="true"
SCAN_ARCHIVES="true"

# Exclusions
EXCLUSION_PATTERNS=("*.iso" "*.vmdk" "node_modules/*" ".git/*")

# Quarantine settings
QUARANTINE_ENABLED="true"
AUTO_CLEANUP_ENABLED="true"

# Notifications
NOTIFICATIONS_ENABLED="true"
EMAIL_NOTIFICATIONS="false"
```

### Configuration File Locations (in order of precedence)

1. Command-line arguments (highest precedence)
2. Local configuration: `./clamav-scan.conf`
3. User configuration: `$HOME/.config/clamav-scan.conf`
4. System configuration: `/etc/clamav-scan.conf`
5. Default configuration (lowest precedence)

## Common Scanning Examples

### Basic Scanning

```bash
# Scan home directory
clamav-scan

# Scan specific directories
clamav-scan ~/Downloads ~/Documents

# Quick scan of Downloads folder
clamav-scan --quick ~/Downloads

# Verbose scan with progress percentage
clamav-scan --verbose --count ~/Documents
```

### Advanced Scanning

```bash
# Scan with customized exclusions
clamav-scan --exclude="*.iso" --exclude="*.zip" --exclude="node_modules/*" ~/Projects

# Scan large files (up to 1GB)
clamav-scan --max-size=1000 /path/with/large/files

# Scan without quarantining
clamav-scan --no-quarantine ~/Downloads

# Scan and send email report
clamav-scan --email-report ~/Documents
```

### Quarantine Management

```bash
# Generate quarantine report
clamav-scan --quarantine-report

# Clean expired quarantined files
clamav-scan --clean-quarantine

# Restore file from quarantine
clamav-scan --restore-file=/path/to/quarantine/file_1681654321

# Restore to specific location
clamav-scan --restore-file=/path/to/quarantine/file_1681654321 --restore-to=~/restored_files
```

## Scheduling Quick Reference

### macOS (launchd)

```xml
<!-- Save as ~/Library/LaunchAgents/com.user.clamav-scan.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.clamav-scan</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/clamav-scan</string>
        <string>--quiet</string>
        <string>~/Downloads</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
```

Load with: `launchctl load ~/Library/LaunchAgents/com.user.clamav-scan.plist`

### Linux (cron)

```bash
# Edit crontab with: crontab -e

# Daily scan at 2:00 AM
0 2 * * * /usr/local/bin/clamav-scan --quiet ~/Downloads

# Weekly full scan on Sunday at 3:00 AM
0 3 * * 0 /usr/local/bin/clamav-scan --quarantine ~/
```

## Common File Exclusion Patterns

```properties
# Development files
EXCLUSION_PATTERNS=("node_modules/*" ".git/*" "*.o" "*.class" "target/*" "build/*")

# Media and archives
EXCLUSION_PATTERNS=("*.iso" "*.zip" "*.tar.gz" "*.mp4" "*.mkv" "*.jpg" "*.png")

# System and cache files
EXCLUSION_PATTERNS=("/var/cache/*" "/tmp/*" "*.log" ".DS_Store")
```

## Recommended Scanning Patterns

### Daily Quick Scan

```bash
clamav-scan --quick ~/Downloads ~/Desktop ~/Documents/attachments
```

### Weekly Standard Scan

```bash
clamav-scan --exclude="*.iso" --exclude="*.vmdk" ~/
```

### Monthly Full Scan

```bash
clamav-scan --count --scan-archives /
```

## Troubleshooting Quick Tips

- Scan not starting: Check ClamAV installation with `which clamscan`
- Database issues: Update definitions with `freshclam`
- Scan too slow: Use `--quick` and appropriate exclusions
- Permission issues: Run with sudo for system directories
- Quarantine errors: Check directory permissions and space

For more detailed troubleshooting help, see the [Troubleshooting FAQ](troubleshooting-faq.md).
