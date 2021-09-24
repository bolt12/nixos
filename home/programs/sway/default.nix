{ config, pkgs, ... }:
let

  sources = import ../../nix/sources.nix;

  unstable = import sources.nixpkgs-unstable {
    overlays = [
      (import sources.nixpkgs-wayland)
    ];
  };

in
{

services.gnome-keyring.enable = true;

wayland.windowManager.sway = {
  enable = true;
  package = unstable.sway-unwrapped;
  wrapperFeatures.base = true ;
  wrapperFeatures.gtk = true ;
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
    '';
};

}
