# System tools profile - Core utilities and system administration tools
# This profile contains essential command-line tools and system utilities

{ pkgs, ... }: {
  home.packages = with pkgs; [
    # Core shell utilities
    bash                         # Bash shell
    gawk                         # Text processing
    bc                           # Calculator
    
    # File and directory operations
    fd                           # Modern find replacement
    ripgrep                      # Fast grep replacement
    fzf                          # Fuzzy finder
    dust                         # Modern du replacement
    eza                          # Modern ls replacement
    ncdu                         # Disk usage analyzer (kept alongside dust)
    
    # System information and monitoring
    fastfetch                    # System information display
    lsof                         # List open files
    lm_sensors                   # Hardware sensors
    mission-center               # Hardware monitoring GUI
    psensor                      # Hardware monitoring
    
    # Network tools
    dig                          # DNS lookup
    nmap                         # Network scanner
    
    # Archive and compression
    zip                          # Zip compression
    unzip                        # Zip extraction
    
    # Process management
    killall                      # Kill processes by name
    
    # Hardware and system integration
    blueman                      # Bluetooth management
    alsa-utils                   # Audio utilities
    
    # Clipboard and X11 utilities
    xclip                        # Clipboard tool
    xorg.xmodmap                 # Keyboard mapping
    
    # System libraries and frameworks
    glib                         # Core library
    zlib                         # Compression library
    
    # Package and system utilities
    nix-bash-completions         # Bash completions for Nix
    
    # Misc utilities
    wget                         # Web downloader
    sof-firmware                 # Audio firmware
  ];
}