# Clammy

## Overview

Clammy is a comprehensive antivirus scanning solution for macOS and Linux systems that extends ClamAV's capabilities with advanced features:

- **Smart Scanning** - Optimized scan performance with intelligent file filtering
- **Enhanced Quarantine** - Sophisticated quarantine system with risk assessment
- **Detailed Reporting** - Comprehensive scan reports and notifications
- **Flexible Configuration** - Multiple configuration layers for customization
- **Scheduled Scanning** - Built-in scheduling capabilities

## Key Features

- 🔍 **Advanced Scanning**
  - Optimized file filtering and exclusions
  - Smart file size limits to improve performance
  - Progress indicators and time estimates

- 🔒 **Enhanced Quarantine**
  - Risk-based classification of infected files
  - Retention policies based on threat level
  - Metadata preservation for security analysis
  - SQLite database for efficient quarantine management

- 📊 **Comprehensive Reporting**
  - Detailed scan reports with file statistics
  - Machine-readable outputs (JSON, CSV)
  - System notifications for critical findings
  - Email reporting capabilities

- ⚙️ **Flexible Configuration**
  - Layered configuration system (system-wide, user, local)
  - Extensive command-line options
  - Default settings optimized for typical environments

## Quick Start

```bash
# Run a basic scan on your home directory
clammy

# Scan multiple locations with verbose output
clammy --verbose ~/Documents /Volumes/External

# Quick scan with minimal operations
clammy --quick ~/Downloads

# Scan with custom exclusions
clammy --exclude="*.iso" --exclude="*.zip" ~/Downloads
```

## Documentation

- [Installation Guide](installation.md)
- [User Guide](user-guide.md)
- [Configuration Guide](configuration.md)
- [Quarantine Guide](quarantine-guide.md)
- [Scheduling Examples](scheduling-examples.md)
- [Scanning Patterns](scanning-patterns.md)
- [Troubleshooting FAQ](troubleshooting-faq.md)
- [Quick Reference](quick-reference.md)
- [Glossary](glossary.md)

## Requirements

- ClamAV (clamscan, freshclam)
- Bash 4.0+ (default on macOS and most Linux distributions)
- Optional: SQLite3 (for enhanced quarantine features)
- Optional: jq (for advanced JSON processing)

## License

Copyright (c) 2025. All rights reserved.

## Acknowledgements

This tool extends the capabilities of the excellent ClamAV antivirus scanner. Special thanks to the ClamAV team for their ongoing work on this essential security tool.
