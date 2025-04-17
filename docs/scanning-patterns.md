# Scanning Patterns

This guide provides recommended scanning patterns for different environments and use cases with Clammy.

## Understanding Scanning Patterns

A scanning pattern is a set of directories to scan, options to use, and frequency to run scans that is optimized for a particular environment or threat model. Different environments have different security requirements and performance constraints.

## Home User Patterns

### Basic Home User

**Threat Profile:** Occasional downloads, browsing, email
**System Impact Priority:** Minimize disruption to daily activities

#### Recommended Pattern:

```bash
# Daily quick scan of high-risk areas
clamav-scan --quick ~/Downloads ~/Desktop ~/Documents/attachments

# Weekly more thorough scan
clamav-scan --count ~/Documents ~/Downloads ~/Desktop ~/.mail

# Monthly full scan
clamav-scan --count --scan-archives ~/
```

**Configuration Focus:**
- Enable email/notifications for positive detections
- Moderate quarantine retention (90 days)
- Skip large backup files and media

### Power User / Developer

**Threat Profile:** Frequent downloads, testing software, code repositories
**System Impact Priority:** Balance between security and performance

#### Recommended Pattern:

```bash
# Daily scan of high-risk areas
clamav-scan --quick ~/Downloads ~/Desktop

# Additional scan for developers
clamav-scan --exclude="node_modules/*" --exclude=".git/*" --exclude="*.o" --exclude="*.class" ~/Projects

# Weekly more thorough scan
clamav-scan --count --exclude="*.iso" --exclude="*.vmdk" ~/

# Scan after connecting external media or downloading suspicious files
clamav-scan --verbose /Volumes/ExternalDrive
```

**Configuration Focus:**
- Extensive exclusion patterns for development files
- Higher max file size limits for development environments
- Quick scan mode for frequent checks

## Business Environment Patterns

### Office Workstation

**Threat Profile:** Email attachments, office documents, web downloads
**System Impact Priority:** Minimize impact during work hours

#### Recommended Pattern:

```bash
# Daily quick scan of high-risk areas
clamav-scan --quick --log-to-syslog ~/Downloads ~/Desktop ~/Documents

# Weekend full scan
clamav-scan --count --scan-archives --log-to-syslog /
```

**Configuration Focus:**
- Integration with centralized logging
- Strict quarantine policies
- Email notifications to IT security team

### File Server

**Threat Profile:** Document storage, file sharing, potential spreading point
**System Impact Priority:** Minimize impact on file access performance

#### Recommended Pattern:

```bash
# Nightly scan of recently modified files
find /shared -type f -mtime -1 -print0 | xargs -0 clamav-scan --quiet

# Weekend full scan with low priority
clamav-scan --count --scan-archives --scan-priority=19 --io-priority=7 /shared
```

**Configuration Focus:**
- CPU/IO priority settings to minimize impact
- Comprehensive logging for audit trails
- Integration with file access monitoring

### Web Server

**Threat Profile:** Web shells, malicious uploads, compromise attempts
**System Impact Priority:** Minimize impact on web application performance

#### Recommended Pattern:

```bash
# Hourly scan of upload directories
clamav-scan --quick /var/www/uploads /tmp

# Daily scan of web directories
clamav-scan --exclude="*.jpg" --exclude="*.png" --exclude="*.css" --exclude="*.js" /var/www

# Weekly full scan
clamav-scan --count --scan-priority=19 /var/www /tmp
```

**Configuration Focus:**
- Focus on PHP/ASP/JSP files and executable content
- Immediate alerts for detections
- Integration with web application firewall logs

## Specialized Environment Patterns

### High-Security System

**Threat Profile:** Targeted attacks, sensitive data, compliance requirements
**System Impact Priority:** Security over performance

#### Recommended Pattern:

```bash
# Frequent scans of critical areas
clamav-scan --verbose --quarantine /etc /bin /sbin /usr/bin /usr/sbin

# Daily full scan
clamav-scan --count --quarantine --scan-archives /

# Real-time monitoring with inotify (Linux)
# Set up separate file monitoring script using inotify tools
```

**Configuration Focus:**
- Maximum scan coverage, minimal exclusions
- Extended logging and reporting
- Long quarantine retention periods
- Additional heuristic scans

### Low-Resource System

**Threat Profile:** Basic malware protection
**System Impact Priority:** Minimal resource usage

#### Recommended Pattern:

```bash
# Weekly scan of important areas only
clamav-scan --quick --max-file-size=50 ~/Downloads ~/Documents

# Monthly limited system scan
clamav-scan --quick --max-file-size=50 --scan-priority=19 /
```

**Configuration Focus:**
- Limited scan scope
- Smaller file size limits
- Reduced disk I/O impact
- Minimal logging

### Air-Gapped System

**Threat Profile:** Malware from external media and files
**System Impact Priority:** Thorough scanning of all incoming content

#### Recommended Pattern:

```bash
# Scan all media before connecting
clamav-scan --verbose --quarantine /media/external

# Scan all files before importing
mkdir ~/incoming_files
# (copy files to incoming_files)
clamav-scan --verbose --quarantine ~/incoming_files

# Move files only after clean scan
if [ $? -eq 0 ]; then
  mv ~/incoming_files/* ~/approved_files/
fi
```

**Configuration Focus:**
- Thorough scanning of all external content
- Strict quarantine policies
- Detailed logging for audit purposes

## Optimization Techniques

### For Large File Systems

When scanning large file systems, consider these optimizations:

1. **Incremental Scanning**:
   ```bash
   # Create a list of files modified in the last day
   find /path -type f -mtime -1 > /tmp/recent_files.txt
   
   # Scan only those files
   clamav-scan --file-list=/tmp/recent_files.txt
   ```

2. **Partitioned Scanning**:
   ```bash
   # Split a large scan into smaller chunks
   clamav-scan /path/partition1
   clamav-scan /path/partition2
   # ... and so on
   ```

### For Limited Resources

When operating on systems with limited resources:

1. **Prioritize Critical Areas**:
   ```bash
   # Focus on high-risk locations only
   clamav-scan --quick /etc /bin /usr/bin ~/Downloads
   ```

2. **Limit File Sizes**:
   ```bash
   # Only scan smaller files
   clamav-scan --max-file-size=50 /path
   ```

3. **Use Process Priorities**:
   ```bash
   # Run with low CPU and I/O priority
   clamav-scan --scan-priority=19 --io-priority=7 /path
   ```

### For Regular Maintenance

For ongoing protection with minimal overhead:

1. **Tiered Scanning Schedule**:
   ```bash
   # Daily quick scans of high-risk areas
   clamav-scan --quick ~/Downloads
   
   # Weekly thorough scans of user files
   clamav-scan ~/
   
   # Monthly full system scans
   clamav-scan /
   ```

2. **Event-Based Scanning**:
   ```bash
   # Scan after downloading files (integrate with browser)
   clamav-scan --quick ~/Downloads/recent-download.zip
   
   # Scan after mounting external media
   clamav-scan --quick /Volumes/ExternalDrive
   ```

## Custom Scanning Patterns

You can create your own custom scanning patterns based on your specific needs:

1. **Identify High-Risk Areas**:
   - Download directories
   - External media mount points
   - Email attachment storage
   - Web upload directories
   - Executable file locations

2. **Determine Resource Constraints**:
   - CPU availability
   - Memory limitations
   - Disk I/O capacity
   - Time windows for scanning

3. **Create Appropriate Exclusions**:
   - Large files unlikely to contain malware
   - Trusted file types
   - System files verified by other means
   - Performance-critical areas

4. **Set Up a Layered Approach**:
   - Frequent quick scans of high-risk areas
   - Regular standard scans of user files
   - Occasional comprehensive scans of all content

## Integration with Security Tools

For enhanced protection, integrate your scanning patterns with other security tools:

1. **Firewall Integration**:
   ```bash
   # Scan files downloaded through monitored traffic
   clamav-scan --quarantine /path/to/firewall/quarantine
   ```

2. **Intrusion Detection**:
   ```bash
   # Scan directories flagged by IDS
   clamav-scan --verbose --quarantine /path/flagged/by/ids
   ```

3. **File Integrity Monitoring**:
   ```bash
   # Scan files that changed unexpectedly
   clamav-scan --verbose $(aide --check | grep -o '/path/to/changed/file')
   ```

## Performance Benchmarks

These benchmarks can help you estimate scan times based on filesystem size and content:

| Filesystem Type | Size | File Count | Scan Type | Approx. Time* | Resource Usage |
|-----------------|------|------------|-----------|---------------|----------------|
| Home directory | 50GB | 100,000 | Standard | 10-20 min | Medium |
| Home directory | 50GB | 100,000 | Quick | 3-5 min | Low |
| Web server | 10GB | 50,000 | Standard | 5-10 min | Medium |
| File server | 500GB | 1,000,000 | Standard | 2-5 hours | High |
| File server | 500GB | 1,000,000 | Quick | 30-60 min | Medium |

*Times are approximate and will vary based on hardware, file types, and system load.

## Next Steps

After implementing appropriate scanning patterns for your environment, you may want to:

- Set up [scheduled scans](scheduling-examples.md) based on your chosen patterns
- Configure [custom exclusions](configuration.md) to optimize performance
- Establish a [quarantine policy](quarantine-guide.md) aligned with your security needs
