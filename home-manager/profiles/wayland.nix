# Wayland profile - Wayland compositor and related tools  
# This profile contains Wayland-specific applications and utilities

{ pkgs, ... }:
{
  home.packages = with pkgs.unstable; [
    # Core Wayland infrastructure
    pipewire                     # Audio server
    wireplumber                  # PipeWire session manager

    # Wayland compositor tools
    waybar                       # Status bar
    wofi                         # Application launcher
    mako                         # Notification daemon
    swaylock-fancy               # Screen locker
    wlogout                      # Logout menu

    # Screenshot and screen sharing
    grim                         # Screenshot tool
    slurp                        # Screen region selector

    # Display management
    wdisplays                    # Display configuration
    brightnessctl                # Brightness control
    wlsunset                     # Blue light filter
    wl-gammactl                  # Gamma correction

    # Clipboard and utilities
    wl-clipboard                 # Wayland clipboard utilities

    # Desktop portals for app integration
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr

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