# Wayland profile - Wayland compositor and related tools
# This profile contains Wayland-specific applications and utilities

{ pkgs, lib, ... }:
{
  services.swaync = {
    enable = true;
    package = pkgs.unstable.swaynotificationcenter;
  };

  services.gpg-agent = {
    enable = true;
    enableBashIntegration = true;
    pinentry.package = pkgs.pinentry-all;
    defaultCacheTtl = 3600;
  };

  services.wl-clip-persist = {
    enable = true;
    clipboardType = "regular";
  };

  services.cliphist = {
    enable = true;
    allowImages = true;
  };

  # Auto-inhibit idle/lock when a fullscreen video is playing (detected via
  # PipeWire). Replaces sway's per-app `inhibit_idle fullscreen` rules.
  systemd.user.services.wayland-pipewire-idle-inhibit = {
    Unit = {
      Description = "Inhibit idle while fullscreen media is playing";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = "${pkgs.wayland-pipewire-idle-inhibit}/bin/wayland-pipewire-idle-inhibit";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.packages = with pkgs.unstable; [
    # Core Wayland infrastructure
    pipewire # Audio server
    wireplumber # PipeWire session manager

    # Wayland compositor tools
    waybar # Status bar
    swaybg # Static wallpaper for Wayland (used by both sway and niri)
    # fuzzel is configured via programs.fuzzel (programs/fuzzel/default.nix)
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
    wl-screenrec # Hardware-encoded screen recorder (dma-buf, faster than wf-recorder)

    # Display management
    wdisplays # Display configuration
    brightnessctl # Brightness control
    # wlsunset provided by services.wlsunset (bolt-with-de/home.nix); adding it
    # here too pulled in a second derivation and broke buildEnv with a
    # conflicting-subpath error.
    wl-gammactl # Gamma correction

    # Clipboard utilities (wl-clipboard pulled in by services.cliphist)
    wl-clipboard # Wayland clipboard utilities

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
  ];
}
