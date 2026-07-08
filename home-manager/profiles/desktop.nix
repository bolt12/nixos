# Desktop profile - GUI applications and desktop environment tools
# This profile contains applications specific to desktop/laptop usage

{ pkgs, ... }:
let
  # Steam is an X11 app, so under niri it renders through xwayland-satellite.
  # On the fractionally-scaled (1.2) BlitzWolf ultrawide, xwayland-satellite's
  # single-scale pointer mapping drifts from the drawn geometry, and the offset
  # grows toward the right edge, so buttons on the right of the Steam window (and
  # of Remote Play streams) become unclickable. gamescope is a nested compositor
  # with its own integer-scaled surface and input handling, so the X11 clients
  # live inside its X server, insulated from xwayland-satellite, and the offset
  # disappears.
  #
  # Call the bare `gamescope` on PATH: the system `programs.gamescope` wrapper
  # (system/machine/x1-g8/default.nix) carries CAP_SYS_NICE for realtime
  # scheduling, which `${pkgs.gamescope}/bin/gamescope` would skip.
  #
  # -W/-H set the internal render resolution (gamescope defaults to 1280x720
  # otherwise); they target the docked ultrawide, and downscale to the laptop
  # panel when undocked. -e enables Steam integration (overlay + controller).
  steam-gamescope = pkgs.writeShellScriptBin "steam-gamescope" ''
    exec gamescope -W 3440 -H 1440 -r 60 -f -e -- ${pkgs.steam}/bin/steam "$@"
  '';
in
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
    steam-gamescope # Steam wrapped in gamescope (fixes XWayland click offset on the 1.2 ultrawide)
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

  # Launcher entry (shows in the dms launcher) for the gamescope-wrapped Steam.
  # The plain "Steam" entry from pkgs.steam stays available for the scale-1.0
  # outputs where the XWayland offset does not occur.
  xdg.desktopEntries.steam-gamescope = {
    name = "Steam (gamescope)";
    comment = "Steam inside gamescope; fixes the XWayland click offset on the fractionally-scaled ultrawide";
    exec = "steam-gamescope";
    icon = "steam";
    terminal = false;
    categories = [ "Game" ];
  };
}
