# Wayland profile - Wayland compositor and related tools
# This profile contains Wayland-specific applications and utilities

{ pkgs, ... }:
{
  home.packages = with pkgs.unstable; [
    # Core Wayland infrastructure
    pipewire # Audio server
    wireplumber # PipeWire session manager

    # Wayland compositor tools
    waybar # Status bar
    fuzzel # Application launcher (replaces wofi)
    swaynotificationcenter # Notification center (replaces mako)
    swaylock-effects # Screen locker with blur/clock (replaces swaylock-fancy)
    wlogout # Logout menu

    # Window management
    autotiling # Auto-alternate h/v splits
    swayr # MRU window switcher (Alt-Tab)

    # Screenshot and screen sharing
    grim # Screenshot tool
    slurp # Screen region selector
    satty # Screenshot annotation tool
    pkgs.tesseract # OCR (screenshot text extraction)

    # Display management
    wdisplays # Display configuration
    kanshi # Automatic display profile switching
    brightnessctl # Brightness control
    wlsunset # Blue light filter
    wl-gammactl # Gamma correction

    # Clipboard and utilities
    wl-clipboard # Wayland clipboard utilities
    cliphist # Clipboard history manager

    # Desktop portals for app integration
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr

    # Media and image viewing
    pkgs.imv # Wayland-native image viewer

    # Terminal and session
    pkgs.kdePackages.konsole # Terminal emulator

    # Audio control
    pkgs.pamixer # PulseAudio/PipeWire mixer
    pkgs.pwvucontrol # PipeWire volume control (replaces pavucontrol)
    pkgs.playerctl # Media player control

    # System integration
    pkgs.networkmanagerapplet # Network management
    pkgs.pinentry-all # GPG password entry
  ];
}
