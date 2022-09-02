{ config, lib, ... }:

let
  sources = (import ../../nix/sources.nix);

  pkgs = import sources.nixpkgs {
    overlays = [
      (import sources.emacs-overlay)
    ];
  };

  unstable = import sources.nixpkgs-unstable {
    overlays = [
      (import sources.emacs-overlay)
    ];
  };
in {
  programs.emacs = {
    enable = true;
    package = pkgs.emacsPgtk;
    extraPackages = epkgs: with epkgs; [
      use-package
      nix-mode
      all-the-icons-ivy
      doom-themes
    ];
  };
  home.file.".emacs.d" = {
    source = ./emacs.d;
    recursive = true;
  };
  # home.file.".doom.d" = {
  #   source = ./doom.d;
  #   recursive = true;
  #   onChange = builtins.readFile ./reload.sh;
  # };
}
