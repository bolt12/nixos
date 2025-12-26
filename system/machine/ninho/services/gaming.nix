{ config, lib, pkgs, inputs, ... }:

# ============================================================================
# Game Streaming Configuration (Headless with HDMI Dummy Plug)
# ============================================================================
# Enables Steam game streaming from headless NixOS server using:
# - HDMI dummy plug (already connected to GPU)
# - Steam with headless configuration
# - Sunshine (GameStream server) for streaming to Steam Deck & other devices
#
# Hardware requirement: HDMI dummy plug connected to GPU ✓
#
# Client setup:
#   - Steam Deck: Install Moonlight app from Discover store
#   - Other devices: Install Moonlight client (moonlight-stream.org)
#   - First time: Browse to http://ninho-ip:47990 to pair devices
#   - Connect to: ninho server IP, Sunshine will handle the rest
# ============================================================================

{
  # ==========================================================================
  # X11 DISPLAY SERVER & DISPLAY MANAGER
  # ==========================================================================
  # The HDMI dummy plug makes the GPU initialize properly

  # Configure LightDM to auto-login bolt user for headless game streaming
  services.xserver.displayManager.lightdm.enable = true;

  services.displayManager.autoLogin = {
    enable = true;
    user = "bolt";
  };

  # Set display resolution early (runs when X server starts, before session)
  services.xserver.displayManager.setupCommands = ''
    ${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-0 --mode 1920x1080 --rate 60 --scale 1x1 --panning 1920x1080 || \
    ${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-0 --mode 1920x1080 --rate 60 || \
    true
  '';

  # Start a minimal desktop session (required for Sunshine)
  services.xserver.desktopManager.xfce = {
    enable = true;
    enableScreensaver = false;
  };
  services.displayManager.defaultSession = "xfce";

  # Allow local connections to X server without authentication
  # This is needed for Sunshine to access the display
  # Also disable compositor (prevents black screen in games) and ensure proper resolution
  services.xserver.displayManager.sessionCommands = ''
    ${pkgs.xorg.xhost}/bin/xhost +local:

    # Disable XFCE compositor to fix game streaming black screen issues
    ${pkgs.xfce.xfconf}/bin/xfconf-query -c xfwm4 -p /general/use_compositing -s false || true

    # Ensure resolution is properly set (fixes black screen after game intros)
    ${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-0 --mode 1920x1080 --rate 60 --scale 1x1 --panning 1920x1080 || true
  '';

  # ==========================================================================
  # STEAM CONFIGURATION
  # ==========================================================================

  # Enable Steam with optimizations for game streaming
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;  # Opens Steam Remote Play ports
    dedicatedServer.openFirewall = true;  # Opens Source dedicated server ports

    # Additional libraries for better compatibility
    package = pkgs.steam.override {
      extraPkgs = pkgs: with pkgs; [
        xorg.libXcursor
        xorg.libXi
        xorg.libXinerama
        xorg.libXScrnSaver
        libpng
        libpulseaudio
        libvorbis
        stdenv.cc.cc.lib
        libkrb5
        keyutils
      ];
    };
  };

  # ==========================================================================
  # SUNSHINE STREAMING SERVER
  # ==========================================================================
  # Sunshine is an open-source GameStream server
  # Works perfectly with Moonlight clients (better than Steam Link for headless)

  # Disable the stable service
  disabledModules = [ "${inputs.nixpkgs}/nixos/modules/services/networking/sunshine.nix" ];
  # Get the unstable service version
  imports = [
    "${inputs.nixpkgs-unstable}/nixos/modules/services/networking/sunshine.nix"
  ];

  services.sunshine = {
    enable = true;
    autoStart = true;
    openFirewall = true;  # Automatically opens required ports
    package = pkgs.sunshine.override { cudaSupport = true; };

    # Enable hardware capabilities for best performance
    capSysAdmin = true;
  };

  # ==========================================================================
  # AUDIO SUPPORT (PipeWire)
  # ==========================================================================
  # Required for game audio streaming

  # Use PipeWire (modern audio server)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # ==========================================================================
  # FIREWALL CONFIGURATION
  # ==========================================================================

  networking.firewall = {
    allowedTCPPorts = [
      # Sunshine Web UI and streaming
      47984  # HTTPS Web UI
      47989  # HTTP Web UI
      47990  # RTSP/Configuration
      48010  # Video stream

      # Steam Remote Play (backup option)
      27036
      27037
    ];

    allowedUDPPorts = [
      # Sunshine streaming (video/audio/control)
      47998
      47999
      48000
      48002
      48010

      # Steam Remote Play (backup option)
      27031
      27036
    ];
  };

  # ==========================================================================
  # SYSTEM PACKAGES
  # ==========================================================================

  environment.systemPackages = with pkgs; [
    # Display tools (for troubleshooting)
    xorg.xrandr
    xorg.xdpyinfo

    # Streaming
    sunshine

    # Steam
    steam
    steamcmd  # CLI for debugging

    # Performance monitoring
    iftop  # Network bandwidth monitor
  ];

  # ==========================================================================
  # INPUT DEVICES (uinput for virtual controllers/keyboard/mouse)
  # ==========================================================================
  # Load uinput kernel module and set permissions
  boot.kernelModules = [ "uinput" ];

  # Create udev rules for input devices and NVIDIA capabilities
  services.udev.extraRules = ''
    # Allow input group access to /dev/uinput for virtual devices
    KERNEL=="uinput", SUBSYSTEM=="misc", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"

    # Allow video group access to NVIDIA capability devices (required for NVENC/NVDEC)
    SUBSYSTEM=="nvidia-caps", MODE="0666"
  '';

  # ==========================================================================
  # USER GROUPS
  # ==========================================================================
  # Add users to input/render groups for controller and GPU access

  users.users.bolt.extraGroups = [ "input" "render" ];
  users.users.pollard.extraGroups = [ "input" "render" ];

  # ==========================================================================
  # USER LINGERING & NVIDIA PERMISSIONS
  # ==========================================================================
  # Enable lingering so user services (like Sunshine) start at boot
  # without requiring an active login session
  # Also ensure NVIDIA capabilities devices have correct permissions (for NVENC/NVDEC)

  systemd.tmpfiles.rules = [
    # User lingering
    "f /var/lib/systemd/linger/bolt - - - -"
    "f /var/lib/systemd/linger/pollard - - - -"

    # NVIDIA capabilities permissions (required for hardware encoding)
    "z /dev/nvidia-caps/nvidia-cap1 0666 - - - -"
    "z /dev/nvidia-caps/nvidia-cap2 0666 - - - -"
  ];
}
