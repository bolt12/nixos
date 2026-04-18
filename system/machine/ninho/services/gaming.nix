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

let
  # Register the ultrawide modeline (HDMI dummy plug EDID doesn't advertise
  # 3440x1440) and pick the best available mode. Modeline from: gtf 3440 1440 60
  xrandr = "${pkgs.xorg.xrandr}/bin/xrandr";
  applyUltrawideMode = ''
    ${xrandr} --newmode "3440x1440_60" 419.11 3440 3688 4064 4688 1440 1441 1444 1490 -HSync +VSync 2>/dev/null || true
    ${xrandr} --addmode HDMI-0 "3440x1440_60" 2>/dev/null || true

    ${xrandr} --output HDMI-0 --mode "3440x1440_60" --rate 60 --scale 1x1 --panning 3440x1440 || \
    ${xrandr} --output HDMI-0 --mode 2560x1440 --rate 60 --scale 1x1 --panning 2560x1440 || \
    ${xrandr} --output HDMI-0 --mode 1920x1080 --rate 60 || \
    true
  '';
in
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

  # Allow NVIDIA to accept custom modelines not in the HDMI dummy plug's EDID.
  # Without this, xrandr --addmode silently fails for non-EDID resolutions.
  services.xserver.screenSection = ''
    Option "ModeValidation" "AllowNonEdidModes"
  '';

  # Set display resolution early (runs when X server starts, before session).
  # Default to 3440x1440 ultrawide for Steam Link / Sunshine; fall back to 2560x1440, then 1080p.
  services.xserver.displayManager.setupCommands = applyUltrawideMode;

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

    ${applyUltrawideMode}
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

    # Streaming settings
    settings = {
      # Capture method — NvFBC is lowest latency for NVIDIA GPUs
      capture = "nvfbc";
      # Hardware encoding via NVENC
      encoder = "nvenc";
      # Prefer AV1 (RTX 5090 has excellent AV1 NVENC — ~30-40% better quality/bitrate than H.264)
      # Falls back to HEVC/H.264 if the client doesn't support it
      av1_mode = 2;   # 0=off, 1=allow, 2=prefer
      hevc_mode = 2;  # 0=off, 1=allow, 2=prefer
    };
  };

  # ==========================================================================
  # AUDIO SUPPORT (PipeWire)
  # ==========================================================================
  # Required for game audio streaming

  # Use PipeWire (modern audio server)
  services.pipewire = {
    enable = true;
    audio.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  # Firewall ports are handled by:
  #   services.sunshine.openFirewall = true
  #   programs.steam.remotePlay.openFirewall = true
  #   programs.steam.dedicatedServer.openFirewall = true

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
  # GAMEMODE (CPU/scheduler optimization during gaming)
  # ==========================================================================
  programs.gamemode.enable = true;

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
  # without requiring an active login session, and so tmux/other processes
  # survive SSH logout (works with KillUserProcesses = true in logind)
  users.users.bolt.linger = true;
  users.users.pollard.linger = true;
}
