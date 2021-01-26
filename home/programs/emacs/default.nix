{
  programs.emacs = {
    enable = true;
    extraPackages = epkgs: with epkgs; [
      use-package
      nix-mode
      all-the-icons-ivy
      doom
      doom-modeline
      doom-themes
    ];
  };
  home.file.".doom.d" = {
    source = ./doom.d;
    recursive = true;
    onChange = builtins.readFile ./reload.sh;
  };
}
