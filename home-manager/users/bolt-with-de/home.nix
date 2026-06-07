{
  config,
  lib,
  pkgs,
  inputs,
  system,
  ...
}:

# Bolt's desktop configuration for bolt-nixos
# This imports the base bolt configuration and adds desktop environment components
# Zero redundancy: all headless config comes from ../bolt/home.nix

let
  # Power monitors on/off in a compositor-agnostic way for the swayidle
  # service below. niri has no swaymsg; Sway has no `niri msg`. Pick at
  # runtime from the session's $XDG_CURRENT_DESKTOP.
  monitorsPower =
    state:
    pkgs.writeShellScript "monitors-${state}" ''
      if [ "''${XDG_CURRENT_DESKTOP:-}" = "niri" ]; then
        ${pkgs.niri}/bin/niri msg action power-${state}-monitors
      else
        ${pkgs.sway}/bin/swaymsg "output * dpms ${if state == "off" then "off" else "on"}"
      fi
    '';
  monitorsOff = monitorsPower "off";
  monitorsOn = monitorsPower "on";
in
{
  imports = [
    # Import base bolt configuration (headless)
    ../bolt/home.nix

    # Stylix theming
    inputs.stylix.homeModules.stylix
    # Niri ↔ Stylix bridge (themes border colors from base16 scheme).
    # Lives in niri-flake (not stylix); only wires into HM when imported here.
    inputs.niri.homeModules.stylix

    inputs.dms.homeModules.dank-material-shell
    inputs.dms.homeModules.niri
    # Registers every DMS plugin (disabled by default); enable individual ones
    # via programs.dank-material-shell.plugins.<id>.enable below.
    inputs.dms-plugin-registry.modules.default

    # Add desktop-specific profiles
    ../../profiles/desktop.nix
    ../../profiles/fonts.nix
    ../../profiles/wayland.nix

    # Add desktop-specific modules
    ../../modules/wayland.nix

    # Add desktop program configurations
    ../../programs/sway/default.nix
    ../../programs/waybar/default.nix
    ../../programs/fuzzel/default.nix
    ../../programs/niri/default.nix
    # Noctalia (Quickshell-based) is currently broken on this iGPU + Mesa —
    # its render thread crashes inside libLLVM. Re-enable once upstream
    # stabilizes, or once we move off Mesa 25.2.x + LLVM 21.x.
    # (Noctalia v4 is now EOL / v5 is alpha; prefer the DMS trial below.)
    # ../../programs/noctalia/default.nix

    # DankMaterialShell escape-hatch helpers (dms-stop / dms-start). DMS
    # itself is enabled below via the upstream dank-material-shell module.
    ../../programs/dms/default.nix

    # Desktop-specific user data (Syncthing configuration)
    ./user-data.nix
  ];

  # Ninho-only modules excluded on the laptop:
  #   - development-lean.nix: Lean4 toolchain (heavy, only used on ninho)
  #   - emanote-user.nix: journal server (bolt's data lives on ninho)
  disabledModules = [
    ../../profiles/development-lean.nix
    ../../services/emanote-user.nix
  ];

  # Desktop-specific input method configuration
  i18n = {
    inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        addons = with pkgs; [
          fcitx5-gtk
          qt6Packages.fcitx5-qt
          qt6Packages.fcitx5-configtool
          fcitx5-mozc
          fcitx5-nord
          fcitx5-rime
        ];
      };
    };
  };

  # Adopt the 26.05 HM default explicitly (keep gtk4 untheme'd; let
  # libadwaita/Stylix manage gtk4 styling). Silences the gated warning
  # without bumping home.stateVersion.
  gtk.gtk4.theme = null;

  # Desktop-specific programs
  programs = {
    firefox = {
      enable = true;
      # Adopt the 26.05 HM default (XDG path) explicitly.
      configPath = "${config.xdg.configHome}/mozilla/firefox";
    };

    # DankMaterialShell is the daily-driver shell/bar (replaced waybar). The
    # module installs Quickshell + every feature dep (dgop, matugen, cava,
    # khal, wtype) — all enable* flags default true, so we don't list them.
    #
    # Autostart is via the systemd user service ONLY (Restart=on-failure,
    # bound to the wayland target). `niri.enableSpawn` is therefore OFF: with
    # both on, niri's spawn-at-startup AND the service would each launch DMS,
    # double-spawning the shell.
    #
    # `enableKeybinds` / `includes.enable` stay OFF so our hand-authored niri
    # binds (programs/niri/keybindings.nix) and window/layer rules remain
    # authoritative — DMS IPC binds (Mod+Space launcher, Mod+V clipboard,
    # etc.) can be wired in manually later if wanted.
    dank-material-shell = {
      enable = true;
      systemd.enable = true;
      quickshell.package = pkgs.quickshell;
      niri = {
        enableKeybinds = false;
        enableSpawn = false;
        includes.enable = false;
      };

      # Plugins from the dms-plugin-registry module (imported above). Each is
      # disabled by default; we opt in here. Starter set chosen for this X1:
      # niri-/any-compatible, light deps, high value. Verified each plugin's
      # `compositors` includes niri/any (ddcBrightness/displayProfile are
      # hyprland-only and intentionally omitted). Browse the rest at
      # https://danklinux.com/plugins and flip `.enable = true` to add.
      plugins = {
        # Power: recovers the power-profile UX we'd otherwise lose by keeping
        # TLP over power-profiles-daemon. Bar widget + control-center toggle.
        # Also fronts the ThinkPad charge thresholds (thinkpad_acpi exposes
        # charge_control_{start,end}_threshold; TLP drives them at 85/90).
        # NOTE: the dmsLenovoBatterySettings plugin is intentionally NOT used —
        # it targets `ideapad_laptop` (consumer IdeaPads); this X1 Carbon uses
        # `thinkpad_acpi`, so that widget would be non-functional here.
        tlpControl.enable = true; # needs `tlp` (already enabled in x1-g8)

        # Idle inhibitor toggle (handier than a keybind for ad-hoc "stay awake").
        caffeine.enable = true;

        # Launcher extensions for the Mod+d spotlight.
        calculator.enable = true;
        emojiLauncher.enable = true;

        # Bar widgets that suit this repo / workflow.
        nixMonitor.enable = true; # nix store / GC / build status
        powerUsagePlugin.enable = true; # live battery watt draw
        claudeCodeUsage.enable = true; # Claude Code token usage
      };
    };
  };

  # Stretchly — Wayland-native break reminder (replaces safeeyes, which has
  # broken fullscreen/DND detection under Niri). Autostarted via niri's
  # spawn-at-startup; minimizes to tray on launch.
  home.packages = [ pkgs.stretchly ];

  # Desktop-specific services
  services = {
    lorri.enable = true;
    # No blueman-applet here: DankMaterialShell (the bar on niri) ships its own
    # Bluetooth widget, so the GTK tray applet would be a duplicate icon. The
    # Sway fallback spawns blueman-applet itself, and blueman-manager stays
    # installed (waybar BT click + niri window rule still launch it on demand).
    udiskie.enable = true;
    poweralertd.enable = true;

    # Idle management — lock after 5min, monitors off after 10min.
    # swayidle is a generic Wayland idle client (ext-idle-notify), so it runs
    # under niri as well as Sway. The lock command (swaylock) is portable, but
    # the monitor-power command is compositor-specific: `swaymsg ... dpms` only
    # works on Sway, while niri uses `niri msg action power-off-monitors`. We
    # dispatch on $XDG_CURRENT_DESKTOP so the same service is correct in both
    # sessions (previously this used swaymsg unconditionally, so the screen
    # never powered off under niri — it only locked).
    swayidle = {
      enable = true;
      timeouts = [
        {
          timeout = 300;
          command = "swaylock -f --clock --indicator --effect-blur 7x5 --effect-vignette 0.5:0.5";
        }
        {
          timeout = 600;
          command = "${monitorsOff}";
          resumeCommand = "${monitorsOn}";
        }
      ];
      events = {
        before-sleep = "swaylock -f --clock --indicator --effect-blur 7x5 --effect-vignette 0.5:0.5";
      };
    };

    wlsunset = {
      enable = true;
      latitude = "39";
      longitude = "-8";
    };

    # kanshi was previously responsible for switching between docked-dual /
    # docked-blitzwolf / docked-lg / undocked profiles based on detected
    # outputs. Niri's static output declarations in programs/niri/default.nix
    # already cover the geometry/scale/refresh per monitor, and niri silently
    # ignores declared-but-disconnected outputs (re-applies on hotplug), so
    # kanshi is redundant.
    #
    # Trade-offs accepted vs the kanshi setup:
    #   - eDP-1 stays enabled while docked (kanshi disabled it). Toggle with
    #     `Mod+ctrl+Shift+e` (see programs/niri/keybindings.nix) when wanted.
    #   - The 4K-when-LG-solo profile (3840x2160@30, scale 2.0) is gone; the
    #     LG runs at 1920x1080@30 always now. Use `Mod+ctrl+Shift+m` to
    #     bump it to 4K mode at runtime if needed.
  };

  # Stylix theming — Catppuccin Mocha (unified with sway/waybar)
  stylix = {
    enable = true;
    autoEnable = false;

    image = ../../wallpapers/earth-moon-bg.jpg;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    polarity = "dark";

    fonts = {
      monospace = {
        package = pkgs.jetbrains-mono;
        name = "JetBrains Mono";
      };
      # Inter for UI chrome (bar, GTK apps) — the de-facto "cosy" UI font.
      # JetBrains Mono stays the monospace/terminal face above.
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };
    };

    cursor = {
      package = pkgs.numix-cursor-theme;
      name = "Numix-Cursor";
      size = 24;
    };

    targets = {
      gtk.enable = true;
      bat.enable = true;
      fzf.enable = true;
      niri.enable = true; # provided by inputs.niri.homeModules.stylix
    };
  };
}
