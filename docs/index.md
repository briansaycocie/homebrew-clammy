# Clammy Documentation

## 📚 Documentation Index

### Getting Started
- [Main Documentation](README.md) - Complete guide to Clammy
- [Quick Reference](quick-reference.md) - Essential commands and options
- [Installation Guide](README.md#installation) - Installation instructions for all platforms

### Core Features
1. **Scanning**
   - [Scanning Patterns Guide](scanning-patterns.md) - Common scanning scenarios and patterns
   - [Basic Usage](README.md#basic-usage) - Essential scanning operations
   - [Advanced Features](README.md#advanced-features) - Advanced scanning capabilities

2. **Scheduling**
   - [Scheduling Examples](scheduling-examples.md) - Common scheduling patterns and examples
   - [Schedule Management](README.md#scheduling-scans) - Managing automated scans

3. **Quarantine**
   - [Quarantine Guide](quarantine-guide.md) - Managing infected files
   - [Risk Assessment](quarantine-guide.md#understanding-quarantine-classification) - Understanding threat classification

### Configuration and Customization
- [Configuration Guide](README.md#configuration) - Configuring the scanner
- [Custom Profiles](scanning-patterns.md#custom-scanning-tips) - Creating custom scan profiles
- [Path Management](README.md#path-management) - Managing scan paths and exclusions

### Platform-Specific Guides
- [macOS Notes](README.md#macos-notes) - macOS-specific features and considerations
- [Linux Notes](README.md#linux-notes) - Linux-specific features and considerations

### Troubleshooting and Support
- [Troubleshooting Guide](README.md#troubleshooting) - Common issues and solutions
- [Getting Help](README.md#getting-help) - How to get assistance

## 🚀 Quick Start

If you're new to Clammy, here's how to get started:

1. **Installation**
   ```bash
   # On macOS
   brew install clamav
   git clone https://github.com/briansaycocie/clammy.git
   cd clamav-tap
   ./install.sh
   ```

2. **First Scan**
   ```bash
   # Run a quick scan
   clamav-scan --quick
   ```

3. **Setup Automation**
   ```bash
   # Set up daily scans
   clamav-scan --schedule add quick_scan "0 3 * * *" "Daily Quick Scan"
   ```

## 📋 Common Tasks

### Essential Commands
```bash
# Update virus definitions
clamav-scan --update

# Quick scan of common locations
clamav-scan --quick

# Scan specific directory
clamav-scan --scan ~/Documents

# Check quarantine
clamav-scan --quarantine list
```

### Common Configurations
```bash
# Edit configuration
clamav-scan --config edit

# Create custom scan profile
clamav-scan --profile create my_scan "My Custom Scan" \
  --targets "~/Documents,~/Downloads" \
  --exclude "*.iso,node_modules"
```

## 🔄 Version Information

- Current Version: 1.0.0
- Supported ClamAV Versions: 0.103.0+
- Required OS: macOS 10.14+ or Linux
- Last Updated: 2025-04-17

## 📱 Stay Updated

- [GitHub Repository](https://github.com/briansaycocie/clamav-tap)
- [Report Issues](https://github.com/briansaycocie/clamav-tap/issues)
- [Release Notes](https://github.com/briansaycocie/clamav-tap/releases)

## 💡 Tips and Best Practices

1. **Regular Updates**
   - Keep virus definitions updated daily
   - Check for scanner updates weekly

2. **Efficient Scanning**
   - Use quick scans for daily checks
   - Schedule full scans for off-hours
   - Configure appropriate exclusions

3. **Security Best Practices**
   - Review quarantine regularly
   - Keep logs for at least 30 days
   - Configure notifications for threats

## 🤝 Contributing

We welcome contributions! See our [Contributing Guide](https://github.com/briansaycocie/clamav-tap/CONTRIBUTING.md) for details on:
- Submitting issues
- Requesting features
- Creating pull requests
- Development guidelines

## 📃 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

