class Clammy < Formula
  desc "Enhanced virus scanning and quarantine solution built on ClamAV"
  homepage "https://github.com/briansaycocie/clammy"
  url "https://github.com/briansaycocie/clammy/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "389835032b3518ad82a41c3e9c24bbce589b5bd28d57674144fddf9052f20666"
  license "MIT"
  head "https://github.com/briansaycocie/clammy.git", branch: "main"

  depends_on "clamav"
  depends_on "jq" => :recommended
  depends_on "bash" # Require bash 4+

  def install
    # Add requirement for fileutils
    require "fileutils"
    
    # Create directories first
    libexec.mkpath
    bin.mkpath
    (prefix/"config").mkpath
    doc.mkpath
    (prefix/"share/clammy").mkpath
    
    # Install lib files with preserved permissions
    Dir["lib/*"].each do |file|
      if File.directory?(file)
        FileUtils.cp_r file, libexec, preserve: true
      else
        if File.executable?(file)
          FileUtils.install file, libexec, mode: 0755
        else
          FileUtils.install file, libexec, mode: 0644
        end
      end
    end
    # Manually install the main executable to ensure proper permissions
    FileUtils.cp "scan.sh", "#{bin}/clammy"
    FileUtils.chmod 0755, "#{bin}/clammy"
    
    # Install bin directory items with executable permissions
    if Dir.exist?("bin")
      Dir["bin/*"].each do |f|
        if File.directory?(f)
          FileUtils.cp_r f, bin, preserve: true
        else
          FileUtils.install f, bin, mode: 0755
        end
      end
    end
    
    # Install configuration files with read permissions
    if Dir.exist?("config")
      Dir["config/*"].each do |f|
        if File.directory?(f)
          FileUtils.cp_r f, "#{prefix}/config/", preserve: true
        else
          FileUtils.install f, "#{prefix}/config/", mode: 0644
        end
      end
    end
    
    # Install documentation with read permissions
    if Dir.exist?("docs")
      Dir["docs/*"].each do |f|
        if File.directory?(f)
          FileUtils.cp_r f, doc, preserve: true
        else
          FileUtils.install f, doc, mode: 0644
        end
      end
    end
    
    # Create example configuration file
    (prefix/"share/clammy/clammy.conf.example").write <<~EOS
      # Clammy Configuration File
      
      # Security directories
      SECURITY_DIR="${HOME}/Security"
      LOG_DIR="${SECURITY_DIR}/logs"
      QUARANTINE_DIR="${SECURITY_DIR}/quarantine"
      LOGFILE="${LOG_DIR}/clammy.log"
      
      # Scan settings
      MAX_FILE_SIZE=500
      MIN_FREE_SPACE=1024
      QUARANTINE_ENABLED=true
      GENERATE_HTML_REPORT=true
      OPEN_REPORT_AUTOMATICALLY=false
    EOS
  end
  def post_install
    ohai "Setting up Clammy"
    
    # Add requirement for fileutils for consistent file operations
    require "fileutils"
    
    # Define all required user directories
    security_dir = "#{ENV["HOME"]}/Security"
    log_dir = "#{security_dir}/logs"
    quarantine_dir = "#{security_dir}/quarantine"
    reports_dir = "#{security_dir}/reports"
    user_config_dir = "#{ENV["HOME"]}/.config/clammy"
    logfile = "#{log_dir}/clammy.log"
    user_config = "#{user_config_dir}/clammy.conf"
    log_rotation_file = "#{user_config_dir}/logrotate.conf"
    
    # Use ohai for better reporting
    ohai "Clammy Post-Installation Setup"
    
    begin
      # Verify dependencies and versions
      ohai "Verifying dependencies"
      
      # Check ClamAV installation and version
      clamscan_version = `clamscan --version 2>/dev/null`.strip
      if clamscan_version.empty?
        opoo "ClamAV not found. Please install ClamAV: brew install clamav"
      else
        ohai "✓ ClamAV detected: #{clamscan_version}"
      end
      
      # Check if jq is installed (recommended dependency)
      jq_version = `jq --version 2>/dev/null`.strip
      if jq_version.empty?
        opoo "jq not found. Some features may be limited. Install with: brew install jq"
      else
        ohai "✓ jq detected: #{jq_version}"
      end
      
      # Create and verify all required directories
      ohai "Setting up directory structure"
      [security_dir, log_dir, quarantine_dir, reports_dir, user_config_dir].each do |dir|
        # Create directory if it doesn't exist
        unless File.directory?(dir)
          system "mkdir", "-p", dir
          ohai "Created directory: #{dir}"
        end
        
        # Verify and fix permissions
        current_perms = File.stat(dir).mode & 0777
        if current_perms != 0700
          system "chmod", "700", dir
          ohai "Fixed permissions for: #{dir} (from #{current_perms.to_s(8)} to 700)"
        else
          ohai "✓ Verified permissions (700) for: #{dir}"
        end
      end
      
      # Create a placeholder empty log file if it doesn't exist
      unless File.exist?(logfile)
        system "touch", logfile
        system "chmod", "600", logfile
        ohai "Created log file: #{logfile}"
      else
        # Verify and fix log file permissions
        current_perms = File.stat(logfile).mode & 0777
        if current_perms != 0600
          system "chmod", "600", logfile
          ohai "Fixed permissions for log file (from #{current_perms.to_s(8)} to 600)"
        else
          ohai "✓ Verified log file permissions (600)"
        end
      end
      
      # Copy example config if none exists
      if !File.exist?(user_config)
        system "cp", "#{prefix}/share/clammy/clammy.conf.example", user_config
        system "chmod", "600", user_config
        ohai "Created configuration file: #{user_config}"
      else
        # Verify and fix config file permissions
        current_perms = File.stat(user_config).mode & 0777
        if current_perms != 0600
          system "chmod", "600", user_config
          ohai "Fixed permissions for config file (from #{current_perms.to_s(8)} to 600)"
        else
          ohai "✓ Verified config file permissions (600)"
        end
      end
      
      # Set up log rotation configuration
      unless File.exist?(log_rotation_file)
        File.open(log_rotation_file, "w") do |file|
          file.write <<~EOS
            # Clammy log rotation configuration
            # This file configures automatic cleanup of old logs
            
            # Maximum size of log file before rotation (in MB)
            MAX_LOG_SIZE=10
            
            # Number of log files to keep
            MAX_LOG_FILES=5
            
            # Days to keep logs before deletion (0 = keep forever)
            MAX_LOG_DAYS=30
          EOS
        end
        system "chmod", "600", log_rotation_file
        ohai "Created log rotation configuration: #{log_rotation_file}"
      end
      
      # Verify ClamAV virus database exists and is accessible
      ohai "Checking ClamAV virus database"
      clamav_db_dir = "/opt/homebrew/var/lib/clamav" # Homebrew default location
      clamav_db_file = "#{clamav_db_dir}/main.cvd"
      
      if File.exist?(clamav_db_file)
        db_status = `clamav-config --version 2>/dev/null`.strip
        ohai "✓ ClamAV database detected: #{db_status}"
      else
        opoo "ClamAV virus database not found at #{clamav_db_file}"
        opoo "Please update virus definitions by running: freshclam"
      end
      
      # Create a simple script to periodically clean up old logs
      cleanup_script = "#{user_config_dir}/clammy-cleanup.sh"
      begin
        File.open(cleanup_script, "w") do |file|
          file.write <<~EOS
            #!/bin/bash
            # Cleanup script for Clammy logs
            
            CONFIG_FILE="${HOME}/.config/clammy/logrotate.conf"
            LOG_DIR="${HOME}/Security/logs"
            
            if [ -f "$CONFIG_FILE" ]; then
              source "$CONFIG_FILE"
            else
              MAX_LOG_SIZE=10
              MAX_LOG_FILES=5
              MAX_LOG_DAYS=30
            fi
            
            # Remove old log files based on date
            if [ "$MAX_LOG_DAYS" -gt 0 ]; then
              find "$LOG_DIR" -name "clammy*.log" -type f -mtime +$MAX_LOG_DAYS -delete
            fi
            
            # Rotate current log if too large
            CURRENT_LOG="$LOG_DIR/clammy.log"
            if [ -f "$CURRENT_LOG" ]; then
              SIZE=$(du -m "$CURRENT_LOG" | cut -f1)
              if [ "$SIZE" -ge "$MAX_LOG_SIZE" ]; then
                TIMESTAMP=$(date +"%Y%m%d%H%M%S")
                mv "$CURRENT_LOG" "${CURRENT_LOG}.${TIMESTAMP}"
                touch "$CURRENT_LOG"
                chmod 600 "$CURRENT_LOG"
              fi
            fi
            
            # Keep only the most recent logs
            ls -t "${LOG_DIR}/clammy.log."* 2>/dev/null | tail -n +$((MAX_LOG_FILES+1)) | xargs rm -f 2>/dev/null
          EOS
        end
        FileUtils.chmod 0755, cleanup_script
        # Create a symlink to the bin directory if possible
        begin
          FileUtils.ln_sf cleanup_script, "#{bin}/clammy-cleanup"
          FileUtils.chmod 0755, "#{bin}/clammy-cleanup"
          ohai "Created log cleanup script and linked it to: #{bin}/clammy-cleanup"
        rescue => e
          ohai "Created log cleanup script at: #{cleanup_script}"
          ohai "You can manually copy it to a location in your PATH if desired"
        end
      rescue => e
        opoo "Error creating cleanup script: #{e.message}"
      end
      ohai "Created log cleanup script: #{cleanup_script}"
      
      # Ensure proper ownership (especially important if installed with sudo)
      if Process.uid == 0 && ENV["SUDO_USER"]
        # Get the real user's UID and GID when installed with sudo
        user = ENV["SUDO_USER"]
        uid = `id -u #{user}`.chomp.to_i
        gid = `id -g #{user}`.chomp.to_i
        
        ohai "Setting correct ownership for user: #{user}"
        
        # Change ownership of all created directories and files
        [security_dir, log_dir, quarantine_dir, reports_dir, user_config_dir].each do |dir|
          if File.exist?(dir)
            system "chown", "-R", "#{uid}:#{gid}", dir
            ohai "✓ Set ownership for directory: #{dir}"
          end
        end
        
        # Set ownership for individual files
        [user_config, logfile, log_rotation_file].each do |file|
          if File.exist?(file)
            system "chown", "#{uid}:#{gid}", file
            ohai "✓ Set ownership for file: #{file}"
          end
        end
        
        # Set ownership for cleanup script
        system "chown", "#{uid}:#{gid}", cleanup_script if File.exist?(cleanup_script)
      end
      
      # Add a suggestion to set up a scheduled task for log cleanup
      ohai "Setup complete! Consider setting up automatic log cleanup:"
      ohai "  To run cleanup daily: crontab -e"
      ohai "  Then add: 0 0 * * * #{user_config_dir}/clammy-cleanup.sh"
      
    rescue => e
      opoo "Error during post-install: #{e.message}"
      opoo "You may need to manually set up the following directories:"
      opoo "  #{security_dir}"
      opoo "  #{log_dir}"
      opoo "  #{quarantine_dir}"
      opoo "  #{reports_dir}"
      opoo "  #{user_config_dir}"
      opoo "And verify permissions (directories should be 700, files 600)"
    end
  end

  def caveats
    <<~EOS
      Clammy has been installed!
      
      To ensure proper functionality:
      
      1. Update virus definitions:
         $ freshclam
      
      2. Run your first scan:
         $ clammy --verbose
      
      3. Configure Clammy (optional):
         $ nano ~/.config/clammy/clammy.conf
      
      4. Set up scheduled scans (optional):
         $ clammy --schedule add quick_scan "0 3 * * *" "Daily Quick Scan"
      
      Documentation has been installed to:
        #{doc}
    EOS
  end

  test do
    system "#{bin}/clammy", "--version"
    system "#{bin}/clammy", "--help"
    
    # Create a test file
    (testpath/"test.txt").write("This is a test file.")
    
    # Run a basic scan on the test file
    output = shell_output("#{bin}/clammy --quick #{testpath}/test.txt 2>&1")
    assert_match "Files scanned:", output
  end
end

