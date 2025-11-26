{ pkgs, inputs, ... }:

let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    overlays = [
      inputs.emacs-overlay.overlay
    ];
  };

in {
  programs.emacs = {
    enable = true;
    package = unstable.emacs;
    extraPackages = epkgs: with epkgs; [
      use-package
      nix-mode
      all-the-icons-ivy
      doom-themes  # Add doom-themes from nixpkgs
    ];
  };
  home.file.".emacs.d" = {
    source = ./emacs.d;
    recursive = true;
  };
}
