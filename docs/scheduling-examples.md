# Scheduling Examples

This guide provides examples of how to schedule regular scans with Clammy for continuous protection.

## Why Schedule Scans

Regular scanning is essential for ongoing protection against malware. Scheduling scans allows you to:

- Detect threats automatically without manual intervention
- Run scans during low-usage periods to minimize impact
- Maintain consistent security practices
- Receive regular status reports about your system's security

## Scheduling on macOS

### Using launchd (Recommended)

macOS uses `launchd` for scheduling recurring tasks. Here's how to set up a scheduled scan:

1. Create a launch agent file in `~/Library/LaunchAgents/com.user.clamav-scan.plist`:

```xml
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
        <string>--quarantine</string>
        <string>~/Documents</string>
        <string>~/Downloads</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>~/Library/Logs/clamav-scan.log</string>
    <key>StandardErrorPath</key>
    <string>~/Library/Logs/clamav-scan-error.log</string>
</dict>
</plist>
```

This example schedules a scan every day at 2:00 AM.

2. Load the launch agent:

```bash
launchctl load ~/Library/LaunchAgents/com.user.clamav-scan.plist
```

3. To unload the scheduled task:

```bash
launchctl unload ~/Library/LaunchAgents/com.user.clamav-scan.plist
```

### Weekly Scan with Email Report

Here's an example for a weekly scan with email reporting:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.clamav-scan-weekly</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/clamav-scan</string>
        <string>--email-report</string>
        <string>--quarantine</string>
        <string>--scan-archives</string>
        <string>/</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>0</integer>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>EnvironmentVariables</key>
    <dict>
        <key>EMAIL_RECIPIENTS</key>
        <string>your.email@example.com</string>
    </dict>
</dict>
</plist>
```

This schedules a comprehensive system scan every Sunday at 3:00 AM.

## Scheduling on Linux

### Using Cron (Recommended)

Linux systems typically use `cron` for scheduling tasks:

1. Edit your crontab:

```bash
crontab -e
```

2. Add an entry for regular scanning:

```
# Run daily scan at 3:00 AM
0 3 * * * /usr/local/bin/clamav-scan --quiet --quarantine ~/Documents ~/Downloads

# Run weekly full scan on Sunday at 4:00 AM
0 4 * * 0 /usr/local/bin/clamav-scan --email-report --quarantine /
```

### Using Systemd Timers

For modern Linux distributions using systemd, you can create a timer:

1. Create a service file `/etc/systemd/system/clamav-scan.service`:

```ini
[Unit]
Description=Clammy Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/clamav-scan --quarantine --quiet /home
User=yourusername
IOSchedulingClass=idle
CPUSchedulingPolicy=idle
Nice=19

[Install]
WantedBy=multi-user.target
```

2. Create a timer file `/etc/systemd/system/clamav-scan.timer`:

```ini
[Unit]
Description=Run Clammy daily

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true
RandomizedDelaySec=900

[Install]
WantedBy=timers.target
```

3. Enable and start the timer:

```bash
sudo systemctl enable clamav-scan.timer
sudo systemctl start clamav-scan.timer
```

4. Check timer status:

```bash
sudo systemctl list-timers clamav-scan.timer
```

## Advanced Scheduling Examples

### Tiered Scanning Schedule

For comprehensive protection, consider implementing a tiered scheduling approach:

1. **Daily Quick Scan** - Scan high-risk areas:

```bash
# Daily quick scan at 1:00 AM
0 1 * * * /usr/local/bin/clamav-scan --quick --quarantine ~/Downloads /tmp
```

2. **Weekly Standard Scan** - More thorough scan of user directories:

```bash
# Weekly standard scan on Wednesdays at 2:00 AM
0 2 * * 3 /usr/local/bin/clamav-scan --quarantine ~/Documents ~/Downloads ~/Desktop
```

3. **Monthly Full Scan** - Comprehensive system scan:

```bash
# Monthly full scan on the 1st at 3:00 AM
0 3 1 * * /usr/local/bin/clamav-scan --quarantine --count --scan-archives /
```

### Usage-Based Scheduling

You can trigger scans based on system activity with more advanced scripting:

```bash
#!/bin/bash
# Save as /usr/local/bin/smart-scan.sh

# Check if system is idle
CPU_IDLE=$(top -b -n 1 | grep "Cpu(s)" | awk '{print $8}' | cut -d. -f1)
LOAD=$(uptime | awk '{print $(NF-2)}' | sed 's/,//')

if [ "$CPU_IDLE" -gt 90 ] && [ "$(echo "$LOAD < 1.0" | bc)" -eq 1 ]; then
    /usr/local/bin/clamav-scan --quarantine ~/Documents
fi
```

Then schedule this script to run frequently:

```
# Run check every hour to see if system is idle enough for a scan
0 * * * * /usr/local/bin/smart-scan.sh
```

## Scan on External Drive Connection

### macOS Solution

Create a launch agent that watches for external drive connections:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.clamav-scan-external</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>for d in /Volumes/*; do if [ "$d" != "/Volumes/Macintosh HD" ]; then /usr/local/bin/clamav-scan --quick "$d"; fi; done</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>/Volumes</string>
    </array>
</dict>
</plist>
```

### Linux Solution

Create a udev rule to trigger a scan when a drive is connected:

1. Create the script `/usr/local/bin/scan-drive.sh`:

```bash
#!/bin/bash
# This script is triggered by udev when a drive is connected

if [ -n "$1" ] && [ -d "$1" ]; then
    logger "Clammy: Scanning newly connected drive at $1"
    /usr/local/bin/clamav-scan --quick "$1"
fi
```

2. Make it executable:

```bash
sudo chmod +x /usr/local/bin/scan-drive.sh
```

3. Create a udev rule `/etc/udev/rules.d/99-clamscan.rules`:

```
ACTION=="add", SUBSYSTEMS=="usb", SUBSYSTEM=="block", ENV{ID_FS_USAGE}=="filesystem", RUN+="/usr/local/bin/scan-drive.sh /media/%k"
```

4. Reload udev rules:

```bash
sudo udevadm control --reload-rules
```

## Handling Scan Results

When scheduling scans, consider how to handle the results:

### Email Notifications

Configure email notifications in your configuration file:

```properties
EMAIL_NOTIFICATIONS="true"
EMAIL_RECIPIENTS="your.email@example.com admin@example.com"
EMAIL_ONLY_ON_INFECTED="true"
```

### Logging to Syslog

Add logging options to your scheduled scans:

```bash
/usr/local/bin/clamav-scan --log-to-syslog --quarantine
```

### Integration with Monitoring Systems

For enterprise environments, have the scan output report to monitoring systems:

```bash
/usr/local/bin/clamav-scan --json-output --quarantine | curl -s -X POST -H "Content-Type: application/json" -d @- https://monitoring.example.com/api/security-scans
```

## Recommended Scheduling Practices

1. **Run during off-hours** - Schedule intensive scans for times when the system is least likely to be in use
2. **Use low priority** - Set the CPU and I/O priorities to minimize impact on system performance
3. **Stagger scans** - If managing multiple systems, stagger scan times to distribute load
4. **Layer your approach** - Combine quick daily scans with thorough weekly or monthly scans
5. **Verify scan completion** - Check logs regularly to ensure scheduled scans are completing successfully

## Troubleshooting Scheduled Scans

If your scheduled scans aren't running as expected:

1. **Check permissions** - Ensure the scheduler has permissions to run the scanner
2. **Verify paths** - Make sure all paths in the scheduled command are absolute
3. **Review logs** - Check system logs and scanner logs for errors
4. **Test manually** - Run the exact command from the scheduler manually to verify it works
5. **Check scheduling service** - Verify that launchd/cron/systemd is running properly

## Next Steps

Now that you have scheduled scanning set up, you might want to:

- Configure [custom notifications](configuration.md) for scan results
- Set up a [reporting dashboard](quarantine-guide.md#viewing-quarantined-files) for scan findings
- Implement [retention policies](quarantine-guide.md) for quarantined files
