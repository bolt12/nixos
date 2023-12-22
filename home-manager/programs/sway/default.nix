{ pkgs, inputs, ... }:
let

  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    overlays = [
    ];
  };

in
  {

    services.gnome-keyring.enable = true;

    wayland.windowManager.sway = {
      enable = true;
      wrapperFeatures.base = true;
      wrapperFeatures.gtk = true;
      xwayland = true;
      extraSessionCommands =
        ''
        export SDL_VIDEODRIVER=wayland
        export QT_QPA_PLATFORM=wayland
        export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
        export _JAVA_AWT_WM_NONREPARENTING=1
        export SUDO_ASKPASS="${pkgs.ksshaskpass}/bin/ksshaskpass"
        export SSH_ASKPASS="${pkgs.ksshaskpass}/bin/ksshaskpass"
        export XDG_SESSION_TYPE=wayland
        export XDG_CURRENT_DESKTOP=sway
        export NIXOS_OZONE_WL=1=sway

        export _JAVA_OPTIONS="-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dsun.java2d.xrender=true";
        export MOZ_DISABLE_RDD_SANDBOX="1";
        export MOZ_ENABLE_WAYLAND="1";
        export ECORE_EVAS_ENGINE="wayland_egl";
        export ELM_ENGINE="wayland_egl";
        export EDITOR="nvim";
        export VISUAL="nvim";
        '';
      };

    }
