# Desktop profile - GUI applications and desktop environment tools
# This profile contains applications specific to desktop/laptop usage

{ pkgs, ... }:
{
  # Secret store for both desktop sessions (niri + Sway). Lives here rather
  # than in the Sway module so the daily-driver niri session gets it too.
  services.gnome-keyring.enable = true;

  home.packages = with pkgs; [
    # Web browsers and communication
    chromium # Primary web browser
    google-chrome # Secondary browser for compatibility
    discord # Gaming/community communication
    slack # Work communication
    thunderbird # Email client

    # Media and entertainment
    spotify # Music streaming
    vlc # Video player
    mpv # Lightweight video player
    obs-studio # Streaming/recording
    obs-studio-plugins.wlrobs # Wayland OBS plugin

    # Office and productivity
    libreoffice # Office suite (also handles PDFs)

    # File management and archiving
    thunar # File manager
    xarchiver # Archive manager

    # Graphics and design
    silicon # Beautiful code screenshots

    # Games and entertainment
    steam # Gaming platform
    moonlight-qt # Game streaming platform

    # Desktop theming and appearance
    lxappearance # Theme configuration
    numix-cursor-theme # Cursor theme
    numix-icon-theme-circle # Icon theme
    gsettings-desktop-schemas # Theme schemas
    gtk3 # GTK3 library
    gtk-engine-murrine # Theme engine
    gtk_engines # Additional theme engines

    # Desktop integration
    lxmenu-data # Desktop menu integration

    # GNOME applications and utilities
    gnome-calendar # Calendar application
    gnome-control-center # System settings
    gnome-power-manager # Power management
    gnome-weather # Weather application
    zenity # Display dialogs from shell scripts
  ];
}
