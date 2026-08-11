# Steam + Sunshine for Moonlight game streaming (NVIDIA-only, dummy HDMI).
{
  config,
  lib,
  pkgs,
  ...
}:

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
  # The HDMI dummy plug advertises 3840x2160@60 as its native/preferred EDID
  # mode (see `DISPLAY=:0 xrandr`, the "+" mode), so no custom modeline is
  # needed. Selecting the native mode directly (rather than forcing a custom
  # 3440x1440 modeline) stops XFCE's display profile from fighting xrandr, which
  # was a source of full-frame flicker in Steam Remote Play / Sunshine captures.
  # Client (4K monitor on x1-g8) shows this 1:1.
  xrandr = "${pkgs.xrandr}/bin/xrandr";
  xfconfQuery = "${pkgs.xfconf}/bin/xfconf-query";
  gtf = "${pkgs.xorg-server}/bin/gtf";
  grep = "${pkgs.gnugrep}/bin/grep";
  gawk = "${pkgs.gawk}/bin/awk";
  tr = "${pkgs.coreutils}/bin/tr";
  sed = "${pkgs.gnused}/bin/sed";
  date = "${pkgs.coreutils}/bin/date";
  mkdir = "${pkgs.coreutils}/bin/mkdir";
  applyUltrawideMode = ''
    export DISPLAY="''${DISPLAY:-:0}"

    # XFCE persists display state and can reapply the plug's native mode with
    # fractional scaling after X setup has already run. Pin its profile to the
    # native 4K mode at scale 1.0 so it does not fight the xrandr mode below.
    ${xfconfQuery} -c displays -p /AutoEnableProfiles -n -t int -s 0 2>/dev/null || true
    ${xfconfQuery} -c displays -p /Notify -n -t int -s 0 2>/dev/null || true
    ${xfconfQuery} -c displays -p /Default/HDMI-0/Resolution -n -t string -s "3840x2160" 2>/dev/null || true
    ${xfconfQuery} -c displays -p /Default/HDMI-0/RefreshRate -n -t double -s 60 2>/dev/null || true
    ${xfconfQuery} -c displays -p /Default/HDMI-0/Scale -n -t double -s 1.0 2>/dev/null || true

    # Select the native 4K mode; fall back to lower native modes if unavailable.
    ${xrandr} --fb 3840x2160 --output HDMI-0 --mode 3840x2160 --rate 60 --scale 1x1 --transform none --panning 3840x2160+0+0 || \
    ${xrandr} --fb 2560x1440 --output HDMI-0 --mode 2560x1440 --rate 60 --scale 1x1 --transform none --panning 2560x1440+0+0 || \
    ${xrandr} --fb 1920x1080 --output HDMI-0 --mode 1920x1080 --rate 60 --scale 1x1 --transform none --panning 1920x1080+0+0 || \
    true
  '';
  applyGamingDisplay = pkgs.writeShellScriptBin "ninho-apply-gaming-display" applyUltrawideMode;

  # Sunshine runs this as a global_prep_cmd "do" when a Moonlight client
  # connects: it switches the dummy plug (HDMI-0) to the resolution the client
  # requested, so the stream is captured 1:1 instead of downscaling the pinned
  # 4K desktop. Sunshine exports SUNSHINE_CLIENT_WIDTH/HEIGHT/FPS to prep
  # commands. The matching "undo" (applyGamingDisplay) restores native 4K on
  # disconnect. The sunshine user service runs with an empty PATH (the upstream
  # NixOS module forces it null), so every binary here is an absolute path.
  resizeToClientMode = ''
    export DISPLAY="''${DISPLAY:-:0}"
    out=HDMI-0
    w="''${SUNSHINE_CLIENT_WIDTH:-3840}"
    h="''${SUNSHINE_CLIENT_HEIGHT:-2160}"
    r="''${SUNSHINE_CLIENT_FPS:-60}"
    log="''${HOME:-/home/bolt}/.config/sunshine/resize.log"
    ${mkdir} -p "$(dirname "$log")" 2>/dev/null || true

    # Guard against non-numeric values leaking in from the environment.
    case "$w" in "" | *[!0-9]*) w=3840 ;; esac
    case "$h" in "" | *[!0-9]*) h=2160 ;; esac
    case "$r" in "" | *[!0-9]*) r=60 ;; esac

    # Reuse an already-usable mode when present: an EDID mode named exactly
    # "WxH" (covers 1080p, 1440p, 1280x800, 1920x1200, ...) or a previously
    # synthesized "WxH_<rate>". Only synthesize + register when neither exists.
    # Re-running --newmode for an existing name errors (BadName) every connect.
    mode=$(${xrandr} --query | ${gawk} -v w="$w" -v h="$h" \
      '$1 == w "x" h { print $1; exit } $1 ~ "^" w "x" h "_" { print $1; exit }')
    if [ -z "$mode" ]; then
      # gtf prints: Modeline "NAME"  <clock/timings>. Strip the "Modeline"
      # prefix AND the surrounding quotes so --newmode, --addmode and --mode all
      # use the same bare NAME (e.g. the 3440x1440 BlitzWolf ultrawide, allowed
      # by AllowNonEdidModes). If the quotes leak into --newmode, the mode is
      # created as `"NAME"` and --mode NAME can never find it (silent no-op).
      line=$(${gtf} "$w" "$h" "$r" | ${sed} -n 's/^[[:space:]]*Modeline[[:space:]]*//p' | ${tr} -d '"')
      mode=$(printf '%s' "$line" | ${gawk} '{print $1}')
      ${xrandr} --newmode $line 2>>"$log" || true
      ${xrandr} --addmode "$out" "$mode" 2>>"$log" || true
    fi

    # Resize framebuffer + output to the client mode; match refresh if the mode
    # supports it, else fall back to mode-only.
    ${xrandr} --fb "''${w}x''${h}" --output "$out" --mode "$mode" --rate "$r" \
      --scale 1x1 --transform none --panning "''${w}x''${h}+0+0" 2>>"$log" ||
      ${xrandr} --fb "''${w}x''${h}" --output "$out" --mode "$mode" \
        --scale 1x1 --transform none --panning "''${w}x''${h}+0+0" 2>>"$log" ||
      true

    # Record the outcome so a failed switch is visible in the log, not silent.
    printf '%s  request=%sx%s@%s  mode=%s  %s\n' \
      "$(${date} '+%Y-%m-%d %H:%M:%S')" "$w" "$h" "$r" "$mode" \
      "$(${xrandr} --query | ${grep} -E '^HDMI-0 connected' || true)" >>"$log" 2>/dev/null || true

    # Never fail: a non-zero prep-cmd can make Sunshine refuse to start the stream.
    exit 0
  '';
  sunshineResize = pkgs.writeShellScriptBin "ninho-sunshine-resize" resizeToClientMode;
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

  # Disable X server DPMS and screen blanking entirely. Without this the dummy
  # plug's virtual display powers off after the DPMS Off timeout (default 900s);
  # Sunshine's NvFBC capture of the blanked framebuffer then streams a black
  # screen to Moonlight. `xfce.enableScreensaver = false` only stops the XFCE
  # screensaver, not X's built-in DPMS timers, so pin all four to 0 here where
  # they take effect from X startup rather than racing the session.
  services.xserver.serverFlagsSection = ''
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
  '';

  # Set display resolution early (runs when X server starts, before session).
  # Default to native 3840x2160 4K for Steam Remote Play / Sunshine; fall back to 2560x1440, then 1080p.
  services.xserver.displayManager.setupCommands = "${applyGamingDisplay}/bin/ninho-apply-gaming-display";

  # Start a minimal desktop session (required for Sunshine)
  services.xserver.desktopManager.xfce = {
    enable = true;
    enableScreensaver = false;
  };
  services.displayManager.defaultSession = "xfce";

  # Thunar (auto-started by the XFCE session) spawns thunar-volman per
  # block-device event; without the plugin installed it logs a flood of
  # "Failed to launch the volume manager" errors on every session restart.
  programs.thunar.plugins = [ pkgs.thunar-volman ];

  # Allow local connections to X server without authentication
  # This is needed for Sunshine to access the display
  # Also disable compositor (prevents black screen in games) and ensure proper resolution
  services.xserver.displayManager.sessionCommands = ''
    ${pkgs.xhost}/bin/xhost +local:

    # Disable XFCE compositor to fix game streaming black screen issues
    ${pkgs.xfconf}/bin/xfconf-query -c xfwm4 -p /general/use_compositing -s false || true

    ${applyGamingDisplay}/bin/ninho-apply-gaming-display
  '';

  # XFCE starts its settings daemon after display-manager setupCommands and may
  # reapply ~/.config/xfce4/.../displays.xml. Reassert the gaming resolution
  # from session autostart after XFCE has finished restoring its profile.
  environment.etc."xdg/autostart/ninho-gaming-display.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Ninho Gaming Display
    Comment=Force the headless gaming display to the native 4K resolution
    Exec=${pkgs.runtimeShell} -c 'sleep 2; ${applyGamingDisplay}/bin/ninho-apply-gaming-display'
    OnlyShowIn=XFCE;
    X-GNOME-Autostart-enabled=true
  '';

  # ==========================================================================
  # STEAM CONFIGURATION
  # ==========================================================================

  # Enable Steam with optimizations for game streaming
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Opens Steam Remote Play ports
    dedicatedServer.openFirewall = true; # Opens Source dedicated server ports

    # Additional libraries for better compatibility
    package = pkgs.steam.override {
      extraPkgs =
        pkgs: with pkgs; [
          libxcursor
          libxi
          libxinerama
          libxscrnsaver
          libpng
          libpulseaudio
          libvorbis
          stdenv.cc.cc.lib
          libkrb5
          keyutils
        ];
    };
  };

  # Embedded compositor for games: provides a per-game compositor that
  # isolates input handling from the host. The system wrapper grants
  # CAP_SYS_NICE for realtime scheduling.
  programs.gamescope.enable = true;

  # ==========================================================================
  # SUNSHINE STREAMING SERVER
  # ==========================================================================
  # Sunshine is an open-source GameStream server
  # Works perfectly with Moonlight clients (better than Steam Link for headless)

  # 26.05 stable sunshine ships autoStart/capSysAdmin/settings, so the previous
  # stable→unstable module swap is no longer needed.
  services.sunshine = {
    enable = true;
    autoStart = true;
    openFirewall = true; # Automatically opens required ports
    package = pkgs.sunshine.override { cudaSupport = true; };

    # Enable hardware capabilities for best performance
    capSysAdmin = true;

    # Streaming settings
    settings = {
      # Capture method: NvFBC is lowest latency for NVIDIA GPUs
      capture = "nvfbc";
      # Hardware encoding via NVENC
      encoder = "nvenc";
      # Prefer AV1 (RTX 5090 has excellent AV1 NVENC, ~30-40% better quality/bitrate than H.264)
      # Falls back to HEVC/H.264 if the client doesn't support it
      av1_mode = 2; # 0=off, 1=allow, 2=prefer
      hevc_mode = 2; # 0=off, 1=allow, 2=prefer

      # Match the host display to the Moonlight client's resolution. Without
      # this, Sunshine captures the pinned 4K desktop and downscales it, so a
      # 1080p laptop (x1-g8) never gets a native-resolution stream. This runs
      # for every app (Desktop, Steam, games): "do" switches HDMI-0 to the
      # client's requested mode, "undo" restores native 4K on disconnect.
      # Rendered into sunshine.conf as a single-line JSON array value.
      global_prep_cmd = builtins.toJSON [
        {
          do = "${sunshineResize}/bin/ninho-sunshine-resize";
          undo = "${applyGamingDisplay}/bin/ninho-apply-gaming-display";
          elevated = "false";
        }
      ];
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
    applyGamingDisplay
    sunshineResize
    pkgs.xrandr
    pkgs.xdpyinfo

    # Streaming
    sunshine

    # Steam
    steam
    steamcmd # CLI for debugging

    # Performance monitoring
    iftop # Network bandwidth monitor
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

  users.users.bolt.extraGroups = [
    "input"
    "render"
  ];
  users.users.pollard.extraGroups = [
    "input"
    "render"
  ];

  # ==========================================================================
  # USER LINGERING & NVIDIA PERMISSIONS
  # ==========================================================================
  # Enable lingering so user services (like Sunshine) start at boot
  # without requiring an active login session, and so tmux/other processes
  # survive SSH logout (works with KillUserProcesses = true in logind)
  users.users.bolt.linger = true;
  users.users.pollard.linger = true;
}
