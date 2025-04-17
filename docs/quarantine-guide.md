# Quarantine Guide

Clammy includes a sophisticated quarantine system for safely handling infected files. This guide explains how the quarantine system works and how to manage quarantined files.

## Overview of the Enhanced Quarantine System

The enhanced quarantine system provides several advanced features:

- **Risk-Based Classification** - Categorizes threats by risk level
- **Retention Policies** - Configurable retention periods based on threat severity
- **Metadata Preservation** - Maintains detailed information about quarantined files
- **SQLite Database** - Efficient storage and retrieval of quarantine records
- **Rotation System** - Organizes quarantined files by date

## How Quarantine Works

When the scanner detects an infected file, the following process occurs:

1. **Detection** - ClamAV identifies a file as infected
2. **Classification** - The file is classified by risk level and threat type
3. **Quarantine** - The file is moved to a secure quarantine location
4. **Metadata** - Detailed information about the file is recorded
5. **Database Entry** - A record is added to the quarantine database

## Quarantine Directory Structure

The quarantine system organizes files in the following structure:

```
$HOME/Security/
├── quarantine/
│   ├── tmp/                   # Temporary holding for newly detected files
│   ├── 2025-04-16/            # Quarantine directory for specific date
│   │   ├── file1_1681654321   # Quarantined file with timestamp
│   │   └── file2_1681654789   # Another quarantined file
│   └── 2025-04-17/            # Another date directory
├── metadata/                  # Metadata about quarantined files
│   ├── 2025-04-16/
│   │   ├── file1_1681654321.json
│   │   └── file2_1681654789.json
│   └── 2025-04-17/
└── quarantine_db.sqlite       # SQLite database (if available)
```

## Risk Classification System

The quarantine system classifies threats into risk levels:

| Risk Level | Description | Default Retention | Examples |
|------------|-------------|-------------------|----------|
| `low` | Low-risk threats like adware | 30 days | Adware, PUAs, cookies |
| `medium` | Standard malware | 90 days | Common viruses, worms |
| `high` | Serious threats | 365 days | Trojans, backdoors, rootkits |
| `critical` | Advanced threats | 730 days | APTs, zero-day exploits |

## Quarantine Management Commands

### Viewing Quarantined Files

To view a list of quarantined files:

```bash
# Generate a quarantine report
clamav-scan --quarantine-report

# Generate a JSON report
clamav-scan --quarantine-report --format=json
```

### Restoring Files from Quarantine

To restore a file from quarantine:

```bash
# Restore a specific file
clamav-scan --restore-file=/path/to/quarantine/file_1681654321

# Restore to a specific location
clamav-scan --restore-file=/path/to/quarantine/file_1681654321 --restore-to=/path/to/destination
```

**Warning**: Restoring files from quarantine can reintroduce malware to your system. Only restore files if you are confident they are safe.

### Cleaning the Quarantine

To manually clean expired quarantined files:

```bash
# Clean expired files
clamav-scan --clean-quarantine

# Force clean all files older than a specified number of days
clamav-scan --clean-quarantine --force --older-than=30
```

## Quarantine Configuration Options

The quarantine system can be configured through several options in your configuration file:

```properties
# Enable or disable quarantine
QUARANTINE_ENABLED="true"

# Directory for quarantined files
QUARANTINE_DIR="${HOME}/Security/quarantine"

# Maximum size of quarantine directory in MB (0 = unlimited)
QUARANTINE_MAX_SIZE="1000"

# Whether to automatically clean up expired quarantined files
AUTO_CLEANUP_ENABLED="true"

# Default retention periods (in days) for different risk levels
LOW_RISK_RETENTION="30"
MEDIUM_RISK_RETENTION="90"
HIGH_RISK_RETENTION="365"
CRITICAL_RISK_RETENTION="730"

# Whether to maintain detailed metadata
DETAILED_METADATA="true"
```

## Quarantine Database

If SQLite is available on your system, the quarantine system will use a database to efficiently manage quarantined files. The database schema includes:

- `quarantine_files` table - Records of quarantined files
- `quarantine_events` table - Events related to quarantined files (detection, restoration, expiry)

You can query this database directly for advanced reporting:

```bash
# Example: List all high-risk quarantined files
sqlite3 ~/Security/quarantine_db.sqlite "SELECT detection_name, original_path, datetime(timestamp, 'unixepoch') FROM quarantine_files WHERE risk_level = 'high' ORDER BY timestamp DESC;"
```

## Quarantine Metadata

For each quarantined file, detailed metadata is preserved in JSON format:

```json
{
  "original_path": "/path/to/original/file",
  "quarantine_path": "/path/to/quarantine/file_1681654321",
  "detection_name": "Trojan.Malware-123",
  "quarantine_date": "1681654321",
  "scan_id": "CLAMSCAN-202504161234-1234",
  "risk_assessment": {
    "level": "high",
    "category": "trojan",
    "retention_days": 365,
    "expiry_date": 1713190321
  },
  "file_info": {
    "size": "1024000",
    "type": "application/x-executable",
    "sha256": "a1b2c3d4e5f6..."
  }
}
```

This metadata is valuable for security analysis and can help identify patterns in malware infections.

## Automatic Quarantine Maintenance

The quarantine system includes automatic maintenance features:

1. **Expiry Enforcement** - Removes files that have exceeded their retention period
2. **Size Limitation** - Enforces the maximum quarantine directory size
3. **Rotation** - Creates date-based directories for better organization

These maintenance tasks run automatically after each scan if enabled in your configuration.

## Best Practices for Quarantine Management

1. **Regular Cleanup** - Run `--clean-quarantine` periodically to ensure the quarantine doesn't grow too large
2. **Review Reports** - Check quarantine reports regularly to monitor threats on your system
3. **Backup Metadata** - Consider backing up the metadata directory and database for security analysis
4. **Adjust Retention** - Configure retention periods based on your security needs and storage constraints

## Quarantine Security Considerations

The quarantine system implements several security measures:

- Files are stored with restricted permissions (600)
- Directories have restricted access (700)
- SQLite database is protected with appropriate permissions
- Files are renamed with timestamps to prevent conflicts

However, remember that quarantined files still contain malicious code. Handle the quarantine directory with appropriate caution.

## Troubleshooting Quarantine Issues

If you encounter issues with the quarantine system:

1. **Check Permissions** - Ensure the quarantine directory has appropriate permissions
2. **Verify Disk Space** - Make sure you have sufficient disk space for quarantine operations
3. **Check SQLite** - If using SQLite, verify it's installed and functioning correctly
4. **Review Logs** - Check the log file for error messages related to quarantine

For more help with troubleshooting, see the [Troubleshooting FAQ](troubleshooting-faq.md).

## Next Steps

After understanding the quarantine system, you may want to:

- Configure [custom retention policies](configuration.md) for your environment
- Set up [regular reporting](scheduling-examples.md) of quarantine status
- Learn about [scanning patterns](scanning-patterns.md) to minimize infections
