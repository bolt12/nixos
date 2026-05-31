{ pkgs, inputs, ... }:

let
  unstable = import inputs.nixpkgs-unstable {
    # 26.05 deprecated `pkgs.system`; read the platform from stdenv instead.
    system = pkgs.stdenv.hostPlatform.system;
    overlays = [
      inputs.emacs-overlay.overlay
    ];
  };

in
{
  programs.emacs = {
    enable = true;
    package = unstable.emacs;
    extraPackages =
      epkgs: with epkgs; [
        use-package
        nix-mode
        all-the-icons-ivy
        doom-themes # Add doom-themes from nixpkgs
      ];
  };
  home.file.".emacs.d" = {
    source = ./emacs.d;
    recursive = true;
  };
}
