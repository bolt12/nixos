# Desktop profile - GUI applications and desktop environment tools
# This profile contains applications specific to desktop/laptop usage

{ pkgs, ... }: {
  home.packages = with pkgs; [
    # Web browsers and communication
    chromium                     # Primary web browser
    google-chrome                # Secondary browser for compatibility
    discord                      # Gaming/community communication
    slack                        # Work communication
    thunderbird                  # Email client

    # Media and entertainment
    spotify                      # Music streaming
    vlc                          # Video player
    mpv                          # Lightweight video player
    obs-studio                   # Streaming/recording
    obs-studio-plugins.wlrobs    # Wayland OBS plugin
    simplescreenrecorder         # Screen recording

    # Office and productivity
    libreoffice                  # Office suite (also handles PDFs)

    # File management and archiving
    xfce.thunar                  # File manager
    xarchiver                    # Archive manager

    # Graphics and design
    silicon                      # Beautiful code screenshots

    # Games and entertainment
    steam                        # Gaming platform

    # Desktop theming and appearance
    lxappearance                 # Theme configuration
    numix-cursor-theme           # Cursor theme
    numix-icon-theme-circle      # Icon theme
    gsettings-desktop-schemas    # Theme schemas
    gtk3                         # GTK3 library
    gtk-engine-murrine           # Theme engine
    gtk_engines                  # Additional theme engines

    # Desktop integration
    lxmenu-data                  # Desktop menu integration
    greetd.gtkgreet              # Login greeter
    xsettingsd                   # X11 settings daemon

    # GNOME applications and utilities
    gnome-calendar               # Calendar application
    gnome-control-center         # System settings
    gnome-power-manager          # Power management
    gnome-weather                # Weather application
    zenity                       # Display dialogs from shell scripts

    # Font packages - system-wide typography configuration
    dejavu_fonts                 # Standard fonts
    emojione                     # Emoji support
    font-awesome                 # Icon font
    hack-font                    # Monospace programming font
    inconsolata                  # Monospace font
    liberation_ttf               # Microsoft font alternatives
    material-icons               # Material Design icons
    nerd-fonts.fira-code         # Programming font with ligatures
    nerd-fonts.jetbrains-mono    # JetBrains programming font
    noto-fonts                   # Google Noto fonts
    noto-fonts-cjk-sans          # CJK language support
    noto-fonts-extra             # Additional Noto fonts
    open-dyslexic                # Dyslexia-friendly font
    open-sans                    # Clean sans-serif font
    siji                         # Icon font for status bars
    terminus_font                # Bitmap terminal font
    ubuntu_font_family           # Ubuntu font family
    unifont                      # Unicode font
    xits-math                    # Mathematical typesetting
  ];
}
