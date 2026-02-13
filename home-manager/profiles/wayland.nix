# Wayland profile - Wayland compositor and related tools  
# This profile contains Wayland-specific applications and utilities

{ inputs, pkgs, ... }: 
let
  # Import unstable packages for latest Wayland tools
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    overlays = [];
  };
in {
  home.packages = [
    # Core Wayland infrastructure
    unstable.pipewire            # Audio server
    unstable.wireplumber         # PipeWire session manager
    
    # Wayland compositor tools
    unstable.waybar              # Status bar
    unstable.wofi                # Application launcher
    unstable.mako                # Notification daemon
    unstable.swaylock-fancy      # Screen locker
    unstable.wlogout             # Logout menu
    
    # Screenshot and screen sharing
    unstable.grim                # Screenshot tool
    unstable.slurp               # Screen region selector
    
    # Display management
    unstable.wdisplays           # Display configuration
    unstable.brightnessctl       # Brightness control
    unstable.wlsunset            # Blue light filter
    unstable.wl-gammactl         # Gamma correction
    
    # Clipboard and utilities
    unstable.wl-clipboard        # Wayland clipboard utilities
    
    # Desktop portals for app integration
    unstable.xdg-desktop-portal
    unstable.xdg-desktop-portal-gtk
    unstable.xdg-desktop-portal-wlr

    # Media and image viewing
    pkgs.imv                     # Wayland-native image viewer
    
    # Terminal and session
    pkgs.kdePackages.konsole     # Terminal emulator
    
    # Audio control
    pkgs.pamixer                 # PulseAudio/PipeWire mixer
    pkgs.pavucontrol             # Audio control GUI
    pkgs.playerctl               # Media player control
    
    # System integration
    pkgs.networkmanagerapplet    # Network management
    pkgs.pinentry-all            # GPG password entry
  ];
}