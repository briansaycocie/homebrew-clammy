# Glossary of Terms

## A

### Antivirus
Software designed to detect, prevent, and remove malicious software (malware).

### Automatic Quarantine
The scanner's feature that automatically isolates infected files in a secure location to prevent them from causing harm.

### Archive Scanning
The ability to scan inside compressed files (ZIP, RAR, etc.) for potential threats.

## B

### Bytecode Signatures
Advanced virus signatures that use compiled code to detect complex malware patterns.

### Batch Scanning
Processing multiple files or directories in a single scan operation.

## C

### ClamAV
The open-source antivirus engine that powers this enhanced scanner.

### ClamAV-TAP
Clammy with additional features like automatic quarantine, scheduling, and advanced scanning capabilities.

### Cron Schedule
A time-based job scheduler used on Unix-like operating systems to automate scanning tasks.

### CVD (ClamAV Virus Database)
The main virus definition file format used by ClamAV.

### Command Line Interface (CLI)
Text-based interface for controlling the scanner through terminal commands.

## D

### Database
Collection of virus definitions used to identify malware.

### Detection Rate
The percentage of known malware that the scanner can successfully identify.

### Deep Scan
A thorough scanning mode that checks all file contents and embedded objects.

### Daemon
A background process that runs continuously, such as `clamd`.

## E

### Exclusion Pattern
A rule that tells the scanner which files or directories to skip during scanning.

### Exit Code
A number returned by the scanner indicating the scan result (0: clean, 1: infected, 2: error).

## F

### False Positive
When the scanner incorrectly identifies a clean file as malware.

### Freshclam
The ClamAV database update tool that keeps virus definitions current.

### Full Scan
A comprehensive scan of all specified locations, typically including the entire home directory.

## H

### Heuristic Detection
Advanced scanning that looks for malware-like behavior rather than exact signatures.

### Hash-based Detection
Using cryptographic checksums to identify known malicious files.

## I

### Incremental Scanning
Scanning only files that have changed since the last scan.

### Infection
A file or system compromised by malware.

### Include Pattern
A rule specifying which file types or locations should be scanned.

## L

### Launchd
macOS service management framework used for scheduling scans.

### Light Scan
A scanning mode optimized for performance with slightly reduced thoroughness.

### Log Rotation
Automatic archiving of old log files to prevent disk space issues.

## M

### Malware
Malicious software, including viruses, trojans, and other threats.

### Memory-Mapped Scanning
A performance optimization technique for scanning large files.

### Metadata
Additional information about quarantined files, such as original location, detection name, and timestamp.

## P

### Parallel Scanning
Using multiple processor cores to scan different files simultaneously.

### Profile
A saved configuration for scanning with specific settings and targets.

### PUA (Potentially Unwanted Application)
Software that isn't strictly malware but might be unwanted or harmful.

## Q

### Quarantine
A secure, isolated storage location for infected files.

### Quick Scan
A fast scan of commonly infected locations.

## R

### Real-time Protection
Continuous monitoring of file system activities for immediate threat detection.

### Recursive Scanning
Scanning directories and all their subdirectories.

### Retention Policy
Rules determining how long quarantined files are kept.

### Risk Assessment
Classification of threats based on their potential impact and severity.

## S

### Scan Profile
A saved set of scanning preferences and targets.

### Signature
A pattern used to identify specific malware.

### Scheduled Scan
An automatically executed scan that runs at specified times.

### System Integration
Features that connect the scanner with operating system functionality.

## T

### Threat Classification
Categorization of detected malware by risk level and type.

### Thorough Scan
The most comprehensive scanning mode that checks everything.

## U

### Update
The process of downloading new virus definitions.

### UUID (Universally Unique Identifier)
A unique identifier assigned to quarantined files and scan sessions.

## V

### Virus Definition
A pattern file used to identify specific malware.

### Verbose Mode
Detailed output showing all scanner activities.

## Terms by Category

### Scanning Modes
- **Quick Scan**: Fast scan of common infection points
- **Full Scan**: Comprehensive system scan 
- **Deep Scan**: Thorough scan including archives and embedded files
- **Light Scan**: Resource-efficient scan with reduced depth
- **Incremental Scan**: Only scanning files modified since last scan
- **Parallel Scan**: Utilizing multiple CPU cores for faster scanning

### Security Terms
- **Malware**: Malicious software designed to harm systems
- **Virus**: Self-replicating malicious code
- **Trojan**: Malware disguised as legitimate software
- **Ransomware**: Malware that encrypts files and demands payment
- **Adware**: Software that displays unwanted advertisements
- **PUA**: Potentially Unwanted Application

### Performance Terms
- **Memory-Mapped Scanning**: Using memory mapping for faster file access
- **Parallel Processing**: Using multiple CPU cores simultaneously
- **Batch Operation**: Processing multiple files at once
- **Resource Usage**: CPU, memory, and disk utilization during scanning
- **CPU Limit**: Maximum processor usage allowed for scanning
- **Memory Limit**: Maximum RAM usage allowed for scanning

### Configuration Terms
- **Profile**: Saved set of scan settings
- **Exclusion Pattern**: Files or directories to skip
- **Retention Policy**: Rules for keeping quarantined files
- **Schedule**: Time-based automation settings
- **Integration**: Connection with OS features
- **Override**: Custom settings that replace defaults

### File Operations
- **Archive Scanning**: Checking inside compressed files
- **Recursive Scanning**: Including all subdirectories
- **File Monitoring**: Watching for changes
- **Real-time Protection**: Immediate scanning when files change
- **Log Rotation**: Managing log file growth
- **Quarantine Storage**: Secure isolation of infected files

### System Integration
- **Context Menu**: Right-click scan option
- **File System Monitor**: Background file activity watcher
- **Automatic Updates**: Self-updating definitions
- **Service Integration**: Running as a system service
- **Desktop Notifications**: Alerts about scan results
- **System Tray Icon**: Quick access to scanner functions

## Common Abbreviations

| Abbreviation | Meaning |
|-------------|----------|
| AV | Antivirus |
| PUA | Potentially Unwanted Application |
| CVD | ClamAV Virus Database |
| CLD | Daily/Local Database Update |
| FP | False Positive |
| CPU | Central Processing Unit |
| RAM | Random Access Memory |
| I/O | Input/Output |
| FS | File System |
| RT | Real-Time |
| TAP | Clammy (ClamAV-TAP) |

## Status Codes

| Code | Meaning | Description |
|------|---------|-------------|
| 0 | Clean | No threats found |
| 1 | Infected | Threats detected and handled |
| 2 | Error | Scan failed or had errors |
| 3 | System Error | Operating system or permission error |
| 4 | Database Error | Virus database issue |
| 50+ | Custom Status | Application-specific status codes |

## Risk Levels

| Level | Description | Retention |
|-------|-------------|-----------|
| Low | Minor threats like adware | 30 days |
| Medium | Common malware | 90 days |
| High | Serious threats like trojans | 180 days |
| Critical | Severe threats like ransomware | Indefinite |

## File Categories

| Category | Description | Default Action |
|----------|-------------|----------------|
| Executable | Program files (.exe, .app) | Deep scan |
| Document | Office files, PDFs | Standard scan |
| Archive | Compressed files | Optional scan |
| System | OS files | Protected scan |
| Media | Images, videos | Quick scan |
| Network | Remote/shared files | Careful scan |

## Platform-Specific Terms

### macOS
- **XProtect**: Apple's built-in malware detection system
- **Gatekeeper**: macOS security feature that verifies downloaded applications
- **Quarantine Attribute**: macOS metadata tag applied to downloaded files
- **Launch Agent**: User-level scheduled tasks on macOS
- **Launch Daemon**: System-level scheduled tasks on macOS

### Linux
- **Fanotify**: Linux kernel subsystem for file access monitoring
- **Inotify**: Linux kernel subsystem for file system event monitoring
- **systemd**: System and service manager for Linux
- **crontab**: Configuration table for scheduled tasks
- **AppArmor/SELinux**: Linux security modules

