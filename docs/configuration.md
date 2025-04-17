# 🔧## 🔄 Configuration System

## ⚙️ Core Configuration Options

### 🗂️ Path Configuration

| Option | Description | Default | Scanner uses a layered configuration system that searches for configuration files in multiple locations with the following precedence (highest to lowest):

1. Command-line arguments (highest precedence)
2. Local configuration file (`./clamav-scan.conf` in the current directory)
3. User configuration file (`$HOME/.config/clamav-scan.conf`)
4. System-wide configuration file (`/etc/clamav-scan.conf`)
5. Default configuration file (lowest precedence)

This approach allows for flexible configuration at different levels of your system.

## 📝 Configuration File Formatn Guide

This guide explains how to configure Clammy to suit your specific needs and environment.

## 🔄 Configuration System

Clammy uses a layered configuration system that searches for configuration files in multiple locations with the following precedence (highest to lowest):

1. Command-line arguments (highest precedence)
2. Local configuration file (`./clamav-scan.conf` in the current directory)
3. User configuration file (`$HOME/.config/clamav-scan.conf`)
4. System-wide configuration file (`/etc/clamav-scan.conf`)
5. Default configuration file (lowest precedence)

This approach allows for flexible configuration at different levels of your system.

## 📝 Configuration File Format

Configuration files use a simple key-value format:

```properties
# This is a comment
KEY="value"

# Boolean values (true/false)
FEATURE_ENABLED="true"

# Numeric values
MAX_FILE_SIZE="500"

# Array values (space-separated)
EXCLUSION_PATTERNS=("*.iso" "*.zip" "/tmp/*")
```

## ⚙️ Core Configuration Options

### Path Configuration

| Option | Description | Default |
|--------|-------------|---------|
| `SECURITY_DIR` | Base directory for security operations | `$HOME/Security` |
| `LOG_DIR` | Directory for log files | `$SECURITY_DIR/logs` |
| `QUARANTINE_DIR` | Directory for quarantined files | `$SECURITY_DIR/quarantine` |
| `LOGFILE` | Path to the main log file | `$LOG_DIR/clamav-scan.log` |
| `DEFAULT_SCAN_TARGETS` | Default directories to scan if none specified | `("$HOME")` |

### 🔍 Scanning Options

| Option | Description | Default |
|--------|-------------|---------|
| `SCAN_RECURSIVE` | Whether to scan directories recursively | `"true"` |
| `MAX_FILE_SIZE` | Maximum file size to scan in MB | `"500"` |
| `MAX_SCAN_SIZE` | Maximum amount of data to scan from a file in MB | `"100"` |
| `MAX_FILES` | Maximum number of files to scan (0 = unlimited) | `"0"` |
| `SCAN_ARCHIVES` | Whether to scan inside archive files | `"true"` |
| `SCAN_MAIL` | Whether to scan mail files | `"true"` |
| `SCAN_PDF` | Whether to scan PDF files | `"true"` |
| `SCAN_HTML` | Whether to scan HTML files | `"true"` |
| `SCAN_OLE2` | Whether to scan OLE2 containers (MS Office) | `"true"` |
| `SCAN_PE` | Whether to scan portable executables | `"true"` |
| `SCAN_ELF` | Whether to scan ELF files | `"true"` |
| `SCAN_ALGORITHMS` | Scan using specified algorithms | `"all"` |
| `MAX_RECURSION` | Maximum archive recursion level | `"16"` |
| `MAX_FILES_IN_ARCHIVE` | Maximum files in archives to scan | `"10000"` |
| `FOLLOW_SYMLINKS` | Whether to follow symbolic links | `"false"` |
| `CROSS_FS` | Whether to cross filesystem boundaries | `"false"` |

### 🔒 Quarantine Options

| Option | Description | Default |
|--------|-------------|---------|
| `QUARANTINE_ENABLED` | Whether to quarantine infected files | `"true"` |
| `REMOVE_INFECTED` | Whether to delete infected files after quarantine | `"false"` |
| `QUARANTINE_MAX_SIZE` | Maximum size of quarantine directory in MB (0 = unlimited) | `"1000"` |
| `AUTO_CLEANUP_ENABLED` | Whether to automatically clean up expired quarantined files | `"true"` |
| `DEFAULT_RETENTION_DAYS` | Default number of days to keep quarantined files | `"90"` |

### 🔔 Notification Options

| Option | Description | Default |
|--------|-------------|---------|
| `NOTIFICATIONS_ENABLED` | Whether to send system notifications | `"true"` |
| `NOTIFY_CLEAN` | Whether to notify on clean scan completion | `"false"` |
| `NOTIFY_INFECTED` | Whether to notify on infected files detection | `"true"` |
| `NOTIFY_ERROR` | Whether to notify on scan errors | `"true"` |
| `EMAIL_NOTIFICATIONS` | Whether to send email notifications | `"false"` |
| `EMAIL_RECIPIENTS` | Email addresses to receive notifications (space-separated) | `""` |
| `EMAIL_ONLY_ON_INFECTED` | Whether to send emails only when infections are found | `"true"` |

### ⚡ Performance Options

| Option | Description | Default |
|--------|-------------|---------|
| `SCAN_THREADS` | Number of parallel scanning threads (0 = auto) | `"0"` |
| `SCAN_PRIORITY` | Process priority for the scanner (0-19, higher = lower priority) | `"10"` |
| `IO_PRIORITY` | I/O priority for the scanner (0-7, higher = lower priority) | `"4"` |
| `COUNT_FILES` | Whether to count files before scanning for progress indication | `"false"` |

## 🚫 Exclusion Patterns

You can configure file and directory exclusions to skip certain files during scanning:

```properties
# File patterns to exclude (wildcards supported)
EXCLUSION_PATTERNS=("*.iso" "*.zip" "*.tar.gz" "node_modules/*" ".git/*")

# Paths to exclude (absolute paths)
EXCLUDED_PATHS=("/tmp" "/var/cache" "/var/log")
```

Exclusion patterns support:
- Wildcards: `*` (matches any sequence), `?` (matches any single character)
- Path anchors: `/` (directory separator), `^` (beginning of path), `$` (end of path)

Examples:
- `*.iso` - Excludes all ISO files
- `/var/log/*` - Excludes all files in /var/log
- `node_modules/*` - Excludes Node.js modules directories
- `^/home/user/large_file.dat$` - Excludes a specific file

## 🗃️ Database Configuration

| Option | Description | Default |
|--------|-------------|---------|
| `CLAMAV_DB_DIR` | Directory containing ClamAV databases | (auto-detected) |
| `UPDATE_DB_BEFORE_SCAN` | Whether to update virus definitions before scanning | `"true"` |
| `DB_UPDATE_INTERVAL` | Minimum hours between database updates | `"24"` |

## 📋 Sample Configuration File

Here's a sample configuration file with common customizations:

```properties
# Clammy Configuration

# Paths
SECURITY_DIR="$HOME/Security"
LOG_DIR="$SECURITY_DIR/logs"
QUARANTINE_DIR="$SECURITY_DIR/quarantine"
LOGFILE="$LOG_DIR/clamav-scan.log"

# Default scan locations
DEFAULT_SCAN_TARGETS=("$HOME/Downloads" "$HOME/Documents")

# Scan options
MAX_FILE_SIZE="1000"
SCAN_RECURSIVE="true"
SCAN_ARCHIVES="true"
EXCLUSION_PATTERNS=("*.iso" "*.vmdk" "*.vdi" "node_modules/*" ".git/*")
EXCLUDED_PATHS=("/tmp" "/var/cache")

# Performance options
SCAN_THREADS="4"
COUNT_FILES="true"

# Quarantine options
QUARANTINE_ENABLED="true"
REMOVE_INFECTED="false"
QUARANTINE_MAX_SIZE="2000"
DEFAULT_RETENTION_DAYS="90"

# Notification options
NOTIFICATIONS_ENABLED="true"
NOTIFY_CLEAN="false"
NOTIFY_INFECTED="true"
EMAIL_NOTIFICATIONS="false"
```

## 🛠️ Creating a Custom Configuration

To create a custom configuration:

1. Create a configuration file:
   ```bash
   # Create user configuration
   mkdir -p ~/.config
   touch ~/.config/clamav-scan.conf
   ```

2. Edit the file with your preferred settings:
   ```bash
   nano ~/.config/clamav-scan.conf
   ```

3. Add your custom settings following the format above.

## 🌐 Environment Variables

The scanner also respects certain environment variables that can override configuration settings:

```bash
# Example of setting options via environment variables
export CLAMAV_SCAN_VERBOSE="true"
export CLAMAV_MAX_FILE_SIZE="2000"
export CLAMAV_EXCLUSIONS="*.iso,*.zip"

# Then run the scanner
clamav-scan
```

## ✅ Verifying Your Configuration

To verify that your configuration is being correctly loaded:

```bash
clamav-scan --verbose
```

The verbose output will show the configuration values being used, including where they were loaded from.

## 👉 Next Steps

After configuring Clammy, you may want to:

- Set up [scheduled scans](scheduling-examples.md) based on your configuration
- Learn about [scanning patterns](scanning-patterns.md) for different environments
- Configure the [quarantine system](quarantine-guide.md) for handling infected files
