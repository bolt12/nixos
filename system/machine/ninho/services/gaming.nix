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
  services.xserver.displayManager.lightdm = {
    enable = true;
    autoLogin = {
      enable = true;
      user = "bolt";
    };
  };

  # Set display resolution early (runs when X server starts, before session)
  services.xserver.displayManager.setupCommands = ''
    ${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-0 --mode 1920x1080 --rate 60 || \
    ${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-0 --mode 1920x1080 || \
    true
  '';

  # Start a minimal desktop session (required for Sunshine)
  services.xserver.desktopManager.xfce = {
    enable = true;
    enableScreensaver = false;
  };
  services.xserver.displayManager.defaultSession = "xfce";

  # Allow local connections to X server without authentication
  # This is needed for Sunshine to access the display
  services.xserver.displayManager.sessionCommands = ''
    ${pkgs.xorg.xhost}/bin/xhost +local:
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

  # Create systemd service to auto-start Steam in Big Picture mode
  # This makes it ready for streaming without manual intervention
  systemd.user.services.steam-headless = {
    description = "Steam Headless Session for Game Streaming";
    wantedBy = [ "default.target" ];
    after = [ "graphical-session.target" ];

    environment = {
      DISPLAY = ":0";
      STEAM_RUNTIME = "1";
      # Force Steam to use X11 (better compatibility than Wayland for streaming)
      SDL_VIDEODRIVER = "x11";
    };

    serviceConfig = {
      Type = "simple";
      # Start Steam in Big Picture mode, silent (no popups)
      ExecStart = "${pkgs.steam}/bin/steam -bigpicture -silent";
      Restart = "on-failure";
      RestartSec = 10;
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

    # Sunshine configuration
    settings = {
      # Video encoder - use NVIDIA NVENC hardware encoding
      encoder = "nvenc";

      # Video quality settings
      min_fps_factor = 1;
      fec_percentage = 20;  # Forward error correction for packet loss

      # Audio configuration
      audio_sink = "auto";

      # Performance
      min_threads = 2;
    };

    # Declarative application configuration
    # This replaces auto-detection and gives you exactly the apps you want
    applications = {
      env = {
        PATH = "$(PATH):$(HOME)/.local/bin";
      };
      apps = [
        # Steam Big Picture - Main gaming interface
        {
          name = "Steam Big Picture";
          cmd = "${pkgs.steam}/bin/steam -bigpicture";
          auto-detach = "true";
          image-path = "${pkgs.steam}/share/pixmaps/steam.png";
        }

        # Desktop presets at different resolutions
        # Each switches resolution on launch and restores to 1080p on exit

        # 1080p Desktop - Default resolution, universal compatibility
        {
          name = "Desktop (1080p)";
          prep-cmd = [
            {
              do = "${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-0 --mode 1920x1080 --rate 60";
              undo = "${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-0 --mode 1920x1080 --rate 60";
            }
          ];
          auto-detach = "true";
        }

        # 720p Desktop - Better performance for slower networks or older devices
        {
          name = "Desktop (720p)";
          prep-cmd = [
            {
              do = "${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-0 --mode 1280x720 --rate 60";
              undo = "${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-0 --mode 1920x1080 --rate 60";
            }
          ];
          auto-detach = "true";
        }

        # 4K Desktop - Maximum quality for high-end devices and fast networks
        {
          name = "Desktop (4K)";
          prep-cmd = [
            {
              do = "${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-0 --mode 3840x2160 --rate 60";
              undo = "${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-0 --mode 1920x1080 --rate 60";
            }
          ];
          auto-detach = "true";
        }

        # Android Phone Desktop - Optimized for modern smartphone screens (20:9 aspect ratio)
        # Works great for Galaxy S21/S22/S23, Pixel 6/7/8, OnePlus 9/10, etc.
        # Adjust to 2340x1080 (19.5:9) or 1920x1080 (16:9) if needed for your specific phone
        {
          name = "Desktop (Phone)";
          prep-cmd = [
            {
              do = "${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-0 --mode 2400x1080 --rate 60 || ${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-0 --mode 1920x1080 --rate 60";
              undo = "${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-0 --mode 1920x1080 --rate 60";
            }
          ];
          auto-detach = "true";
        }
      ];
    };
  };

  # Configure Sunshine systemd service environment
  systemd.user.services.sunshine = {
    # Wait for graphical session to be ready
    after = [ "graphical-session.target" ];

    environment = {
      DISPLAY = ":0";
      # Use the user's X authority file
      XAUTHORITY = "/home/bolt/.Xauthority";
    };

    serviceConfig = {
      # Restart on failure (X server might not be ready immediately)
      Restart = "on-failure";
      RestartSec = "5s";
    };
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
