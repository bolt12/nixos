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
        export _JAVA_AWT_WM_NONREPARENTING=1
        export _JAVA_OPTIONS="-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dsun.java2d.xrender=true";
        export SUDO_ASKPASS="${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass"
        export SSH_ASKPASS="${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass"
        '';
      };

    }
