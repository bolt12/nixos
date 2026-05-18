{
  config,
  pkgs,
  inputs,
  constants,
  ...
}:

let
  rpiLanEndpoint = "${constants.network.rpi.lanIp}:${toString constants.network.wireguard.port}";
  rpiWanEndpoint = "${constants.network.rpi.hostname}:${toString constants.network.wireguard.port}";

  # Select the WireGuard endpoint from the active uplink:
  # home LAN uses the RPi's private address to avoid broken hairpin NAT,
  # otherwise we fall back to the public DDNS endpoint.
  selectWireGuardEndpoint = pkgs.writeShellScript "wg0-select-endpoint" ''
    set -eu

    if ! ${pkgs.iproute2}/bin/ip link show dev ${constants.network.wireguard.interface} >/dev/null 2>&1; then
      exit 0
    fi

    default_route="$(${pkgs.iproute2}/bin/ip route show default 2>/dev/null || true)"
    if printf '%s\n' "$default_route" | ${pkgs.gnugrep}/bin/grep -Fq "via ${constants.network.lan.gateway}"; then
      endpoint='${rpiLanEndpoint}'
    else
      endpoint='${rpiWanEndpoint}'
    fi

    ${pkgs.wireguard-tools}/bin/wg set ${constants.network.wireguard.interface} \
      peer ${constants.network.wireguard.rpiServerPubKey} \
      endpoint "$endpoint"
  '';

  updateWireGuardEndpointOnNetworkChange = pkgs.writeShellScript "wg0-dispatcher-endpoint" ''
    set -eu

    iface="$1"
    state="$2"

    case "$state" in
      up|dhcp4-change|dhcp6-change|connectivity-change|reapply)
        ;;
      *)
        exit 0
        ;;
    esac

    if [ "$iface" = "${constants.network.wireguard.interface}" ]; then
      exit 0
    fi

    ${selectWireGuardEndpoint}
  '';
in
{
  # Use the GRUB 2 boot loader.
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      efi = {
        canTouchEfiVariables = true;
      };
      systemd-boot.enable = true;
    };

    kernelModules = [
      "acpi_call"
      "hid_cherry"
    ];
    extraModulePackages = with config.boot.kernelPackages; [ acpi_call ];
    blacklistedKernelModules = [ ];
    plymouth.enable = true;
    tmp = {
      useTmpfs = true;
      cleanOnBoot = true;
    };
    runSize = "75%"; # Size of useTmpfs defaults to 50% of RAM
  };

  # Performance optimizations for better system responsiveness and SSD longevity
  boot.kernel.sysctl = {
    # Reduce SSD wear by writing dirty pages less frequently (1.5s vs default 5s)
    # Better for systems with sufficient RAM - improves I/O performance
    "vm.dirty_writeback_centisecs" = 1500;

    # Disable NMI watchdog to save CPU cycles and improve power efficiency
    # Trade-off: slightly less debugging capability if system hard-locks
    "kernel.nmi_watchdog" = 0;
  };

  i18n.inputMethod.fcitx5 = {
    waylandFrontend = true;
    settings.globalOptions = {
      SwitchKey = "Shift_L+Shift_R";
    };
    quickPhraseFiles = {
      latex = ../../../home-manager/programs/fcitx5/latex.mb;
    };
  };

  # Intel UHD 620 Hardware Acceleration
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver
      libva-vdpau-driver
      libvdpau-va-gl
      intel-media-driver
    ];
  };

  powerManagement = {
    enable = true;
    powertop.enable = true;
  };

  environment = {
    etc = {
      "greetd/environments".text = ''
        niri-session
        sway
        bash
      '';
    };

    # Most variables moved to home-manager modules/wayland.nix for centralization
    # Keeping only system-level Java configuration here
    variables._JAVA_OPTIONS = "-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dsun.java2d.xrender=true";
    variables._JAVA_AWT_WM_NONREPARENTING = "1";

    # List packages installed in system profile. To search, run:
    # $ nix search wget
    systemPackages = with pkgs; [
    ];
  };

  programs = {
    sway.enable = true;
    nix-ld.enable = true;
    # Embedded compositor for games — swallows Alt+click before niri sees it,
    # so Dota and similar can use Alt-modified mouse actions while niri's
    # mod-key stays Alt. The system wrapper grants CAP_SYS_NICE for realtime
    # scheduling; plain `pkgs.gamescope` in home.packages would skip that.
    gamescope.enable = true;
  };

  services = {

    logind.settings.Login = {
      # Systemd /run/user increase size
      RuntimeDirectorySize = "75%";
      # When docked (external monitors connected), keep working with the
      # lid closed instead of suspending. niri-lid-watch (HM service)
      # toggles eDP-1 off so we don't render to a hidden panel.
      HandleLidSwitchDocked = "ignore";
    };

    dbus.enable = true;

    # Enable the OpenSSH daemon.
    openssh.enable = true;

    # Enable CUPS to print documents.
    printing.enable = true;

    # Firefox NixOs wiki recommends
    pipewire = {
      enable = true;
      audio.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    # USB Automounting
    gvfs.enable = true;

    udisks2.enable = true;

    devmon.enable = true;

    upower.enable = true;

    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "cage -s -- gtkgreet";
          user = "bolt";
        };
      };
    };

    libinput = {
      enable = true;
      touchpad.clickMethod = "clickfinger";
    };

    tlp = {
      enable = true;
      settings = {
        # Battery charge thresholds to preserve battery longevity
        START_CHARGE_THRESH_BAT0 = 85; # Start charging when battery drops below 85%
        STOP_CHARGE_THRESH_BAT0 = 90; # Stop charging at 90% to reduce battery wear

        # CPU scaling governors for optimal performance vs battery life balance
        CPU_SCALING_GOVERNOR_ON_AC = "performance"; # Max performance when plugged in
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave"; # Conserve battery when unplugged

        # Runtime power management - automatically manages device power states
        RUNTIME_PM_ON_AC = "on"; # Enable power management on AC (small savings)
        RUNTIME_PM_ON_BAT = "auto"; # Aggressive power management on battery

        # Additional power saving tweaks for better battery life
        WIFI_PWR_ON_AC = "off"; # Keep WiFi at full power on AC
        WIFI_PWR_ON_BAT = "on"; # Enable WiFi power saving on battery
        SOUND_POWER_SAVE_ON_AC = 0; # Disable audio power saving on AC
        SOUND_POWER_SAVE_ON_BAT = 1; # Enable audio power saving on battery
      };
    };

    blueman.enable = true;

    flatpak.enable = true;

    fwupd.enable = true;

    # AnnePro2 keyboard (Obins, idVendor=04d9 idProduct=a293) — let regular
    # users open the HID nodes so ObinsKit talks to it without sudo. Running
    # an Electron app as root requires --no-sandbox, which we intentionally
    # avoid. We use GROUP="users" instead of TAG+="uaccess" because seat
    # device binding under greetd+cage doesn't reliably attach USB HID nodes
    # to seat0, so the ACL would never get applied.
    udev.extraRules = ''
      KERNEL=="hidraw*", ATTRS{idVendor}=="04d9", ATTRS{idProduct}=="a293", MODE="0660", GROUP="users"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="04d9", ATTRS{idProduct}=="a293", MODE="0660", GROUP="users"
    '';
  };

  # Portal arbitration. Without explicit `config.niri`, niri falls back to
  # whichever backend wins detection — silently breaking PipeWire screencast
  # in Slack/Zoom/OBS. Route ScreenCast/Screenshot to gnome (the only backend
  # with a working niri implementation), keep FileChooser on gtk so flatpak
  # file pickers don't try to spawn Nautilus, and leave Sway on its defaults.
  xdg = {
    portal = {
      enable = true;
      configPackages = [
        pkgs.xdg-desktop-portal
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-wlr
        pkgs.xdg-desktop-portal-gnome
      ];
      wlr.enable = true;
      config.niri = {
        default = [ "gnome" "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
      };
    };
  };

  networking = {
    networkmanager.dispatcherScripts = [
      {
        source = updateWireGuardEndpointOnNetworkChange;
        type = "basic";
      }
    ];

    wireguard.interfaces = {
      wg0 = {
        ips = [ constants.network.wireguard.x1Ip ];
        listenPort = constants.network.wireguard.port;
        privateKeyFile = constants.paths.wireguardPrivateKey;

        peers = [
          {
            publicKey = constants.network.wireguard.rpiServerPubKey;

            # Route only the VPN subnet — avoids a default-route conflict at
            # boot (0.0.0.0/0 caused a routing loop before WiFi came up).
            allowedIPs = [ constants.network.wireguard.subnet ];

            endpoint = "${constants.network.rpi.hostname}:${toString constants.network.wireguard.port}";

            # Keepalives keep NAT tables alive on the upstream router.
            persistentKeepalive = 25;
          }
        ];

        # Re-apply the right peer endpoint after every tunnel restart so
        # service restarts do not undo the home-LAN override.
        postSetup = "${selectWireGuardEndpoint}";
      };
    };
  };

  security = {
    pam.services.swaylock = { };

    polkit.enable = true;

    rtkit.enable = true;
  };

}
