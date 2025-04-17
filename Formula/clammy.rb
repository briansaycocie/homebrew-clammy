class Clammy < Formula
  desc "Enhanced virus scanning and quarantine solution built on ClamAV"
  homepage "https://github.com/briansaycocie/homebrew-clammy"
  url "https://github.com/briansaycocie/homebrew-clammy/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "2a59c05a95e6507eb39beb3c787931798acc1e1463e24055073b236dd714b690"
  license "MIT"
  head "https://github.com/briansaycocie/homebrew-clammy.git", branch: "main"

  depends_on "clamav"
  depends_on "jq" => :recommended
  depends_on "bash" # Require bash 4+

  def install
    # Ensure lib directory exists
    libexec.install Dir["lib/*"]
    
    # Install configuration
    (prefix/"config").install Dir["config/*"]
    
    # Install main script and set executable bit
    bin.install "scan.sh" => "clammy"
    chmod 0755, bin/"clammy"
    
    # Install bin directory items
    bin.install Dir["bin/*"]
    
    # Link executables
    bin.each_child do |f|
      chmod 0755, f if f.file?
    end
    
    # Install documentation
    doc.install Dir["docs/*"]
    
    # Create default directories
    (prefix/"share/clammy").mkpath
    
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
    # Create required directories in user's home
    security_dir = "#{ENV["HOME"]}/Security"
    log_dir = "#{security_dir}/logs"
    quarantine_dir = "#{security_dir}/quarantine"
    
    system "mkdir", "-p", security_dir
    system "mkdir", "-p", log_dir
    system "mkdir", "-p", quarantine_dir
    
    # Set permissions
    system "chmod", "700", security_dir
    system "chmod", "700", log_dir
    system "chmod", "700", quarantine_dir
    
    # Create user config directory
    user_config_dir = "#{ENV["HOME"]}/.config/clammy"
    system "mkdir", "-p", user_config_dir
    
    # Copy example config if none exists
    user_config = "#{user_config_dir}/clammy.conf"
    system "cp", "#{prefix}/share/clammy/clammy.conf.example", user_config unless File.exist?(user_config)
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

