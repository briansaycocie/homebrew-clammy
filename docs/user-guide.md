# User Guide

This guide covers the basic and advanced usage of Clammy.

## Basic Usage

Clammy can be used with simple commands for most common scanning needs.

### Running a Basic Scan

To scan your home directory with default settings:

```bash
clamav-scan
```

### Scanning Specific Locations

You can specify one or more directories or files to scan:

```bash
clamav-scan ~/Documents ~/Downloads

# You can also scan specific files
clamav-scan ~/Downloads/suspicious-file.zip
```

### Viewing Help and Version Information

```bash
# Display help
clamav-scan --help

# Display version information
clamav-scan --version
```

## Command-Line Options

Clammy supports a variety of command-line options for customizing scans:

### Output Control Options

| Option | Description |
|--------|-------------|
| `-v, --verbose` | Enable verbose output with detailed information |
| `-q, --quiet` | Minimal output, only display errors and infected files |
| `--summary-only` | Only display the summary after scanning, not individual file results |

### Scan Behavior Options

| Option | Description |
|--------|-------------|
| `--quick` | Skip non-essential operations for faster scanning |
| `-c, --count` | Count files before scanning to provide progress percentage (may be slow) |
| `--no-quarantine` | Do not quarantine infected files, only report them |
| `--max-size=SIZE` | Set maximum file size to scan in MB (default: 500MB) |

### File Selection Options

| Option | Description |
|--------|-------------|
| `--exclude=PATTERN` | Add exclusion pattern (can be used multiple times) |
| `--include=PATTERN` | Only include files matching pattern (can be used multiple times) |
| `--recursive=DEPTH` | Set maximum recursion depth (default: unlimited) |

## Examples of Common Usage Patterns

### Quick Security Check

For a fast security check of recently downloaded files:

```bash
clamav-scan --quick ~/Downloads
```

### Thorough System Scan

For a comprehensive system scan with detailed output:

```bash
clamav-scan --verbose --count /
```

### Scan with Custom Exclusions

To skip certain file types or directories:

```bash
clamav-scan --exclude="*.iso" --exclude="*.zip" --exclude="/path/to/exclude" ~/Documents
```

### Scan without Quarantine

To only detect but not quarantine infected files:

```bash
clamav-scan --no-quarantine ~/Downloads
```

### Scan Large Files

To include larger files than the default limit:

```bash
clamav-scan --max-size=1000 /path/with/large/files
```

## Understanding Scan Results

Clammy provides comprehensive information about the scan process and results:

### Scan Summary

At the end of every scan, a summary is displayed showing:

- Number of files scanned
- Number of infected files found
- Scan duration
- Database information

Example:

```
----------- SCAN SUMMARY -----------
Files scanned: 13624
Files infected: 1
Time: 35.621 sec (0 m 35 s)
Database version: 26842 (2025-04-17)
```

### Return Codes

The scanner returns different exit codes based on the scan outcome:

| Exit Code | Description |
|-----------|-------------|
| 0 | No threats detected |
| 1 | Infected files found and quarantined |
| 2 | Error occurred during scanning |
| 10 | Required dependencies not found |
| 20 | Insufficient disk space for scan |
| 40 | Error processing quarantined files |

These return codes can be useful for scripting and automation.

## Next Steps

Now that you understand how to use Clammy, you may want to:

- Learn how to [configure the scanner](configuration.md) for your specific needs
- Set up [scheduled scans](scheduling-examples.md) for ongoing protection
- Understand the [quarantine system](quarantine-guide.md) for handling infected files
