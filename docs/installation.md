# Installation Guide

This guide will walk you through the process of installing and setting up Clammy on your system.

## Prerequisites

Before installing Clammy, ensure you have the following requirements:

1. **ClamAV** - The base ClamAV antivirus engine must be installed on your system
2. **Bash 4.0+** - The enhanced scanner requires Bash 4.0 or newer
3. **SQLite3** (optional) - For enhanced quarantine features
4. **jq** (optional) - For advanced JSON processing

## Installing Dependencies

### macOS

The recommended way to install dependencies on macOS is using Homebrew:

```bash
# Install Homebrew if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install ClamAV and other dependencies
brew install clamav sqlite jq

# Initialize ClamAV database
sudo mkdir -p /opt/homebrew/var/lib/clamav
sudo freshclam
```

### Linux (Debian/Ubuntu)

```bash
# Update package list
sudo apt update

# Install ClamAV and dependencies
sudo apt install clamav clamav-daemon sqlite3 jq

# Update virus definitions
sudo freshclam
```

### Linux (RHEL/CentOS/Fedora)

```bash
# Install ClamAV and dependencies
sudo dnf install clamav clamav-update sqlite jq

# Update virus definitions
sudo freshclam
```

## Installing Clammy

### Option 1: Using Homebrew (Recommended for macOS)

Clammy is available as a Homebrew tap:

```bash
# Add the tap
brew tap briansaycocie/clammy

# Install the enhanced scanner
brew install clammy
```

### Option 2: Manual Installation

1. Download the latest release:

```bash
git clone https://github.com/briansaycocie/clammy.git
cd clammy
```

2. Install the scanner:

```bash
# Make the install script executable
chmod +x install.sh

# Run the installer
./install.sh
```

3. Add to your PATH (if not automatically added):

```bash
echo 'export PATH="$PATH:/usr/local/opt/clammy/bin"' >> ~/.zshrc
source ~/.zshrc
```

## Post-Installation Setup

After installation, it's recommended to perform the following setup steps:

1. **Update Virus Definitions**:
   ```bash
   freshclam
   ```

2. **Initial Configuration**:
   ```bash
   # Create a custom configuration file (optional)
   mkdir -p ~/.config
   cp /usr/local/etc/clamav-scan.conf.example ~/.config/clamav-scan.conf
   
   # Edit the configuration file with your preferred settings
   nano ~/.config/clamav-scan.conf
   ```

3. **Verify Installation**:
   ```bash
   # Check version
   clamav-scan --version
   
   # Test with a simple scan
   clamav-scan --verbose ~/Downloads
   ```

## Upgrading

### Upgrading via Homebrew

```bash
brew update
brew upgrade clammy
```

### Upgrading Manual Installation

```bash
cd /path/to/clammy
git pull
./install.sh
```

## Next Steps

Now that you have installed Clammy, you can:

- Review the [Configuration Guide](configuration.md) to customize settings
- Set up [Scheduled Scans](scheduling-examples.md) for automated protection
- Explore the [Quarantine System](quarantine-guide.md) for managing infected files

If you encounter any issues during installation, please refer to the [Troubleshooting FAQ](troubleshooting-faq.md).
