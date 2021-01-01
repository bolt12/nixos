{ config, lib, pkgs, ... }:

let
  custom-plugins = pkgs.callPackage ./custom-plugins.nix {
    inherit (pkgs.vimUtils) buildVimPlugin;
  };

  plugins = pkgs.vimPlugins // custom-plugins;

  overriddenPlugins = with pkgs; [];

  myVimPlugins = with plugins; [
    coc-nvim                # LSP client + autocompletion plugin
    coc-yank                # yank plugin for CoC
    dhall-vim               # Syntax highlighting for Dhall lang
    fzf-vim                 # fuzzy finder
    ghcid                   # ghcid for Haskell
    lightline-vim           # configurable status line (can be used by coc)
    quickfix-reflector-vim  # make modifications right in the quickfix window
    rainbow_parentheses-vim # for nested parentheses
    vim-airline             # bottom status bar
    vim-airline-themes
    vim-nix                 # nix support (highlighting, etc)
    vim-surround            # quickly edit surroundings (brackets, html tags, etc)
  ] ++ overriddenPlugins;

  baseConfig    = builtins.readFile ./config.vim;
  cocConfig     = builtins.readFile ./coc.vim;
  cocSettings   = builtins.toJSON (import ./coc-settings.nix);
  pluginsConfig = builtins.readFile ./plugins.vim;
  vimConfig     = baseConfig + pluginsConfig + cocConfig;

  # neovim-5 nightly stuff
  # neovim-5     = pkgs.callPackage ./dev/nightly.nix {};
  # nvim5-config = builtins.readFile ./dev/metals.vim;
  # new-plugins  = pkgs.callPackage ./dev/plugins.nix {
  #   inherit (pkgs.vimUtils) buildVimPlugin;
  #   inherit (pkgs) fetchFromGitHub;
  # };
  # nvim5-plugins = with new-plugins; [
  #   completion-nvim
  #   diagnostic-nvim
  #   nvim-lsp
  # ];
in
{
  programs.neovim = {
    enable       = true;
    extraConfig  = vimConfig;
    # package      = neovim-5;
    plugins      = myVimPlugins;
    viAlias      = true;
    vimAlias     = true;
    vimdiffAlias = true;
    withNodeJs   = true; # for coc.nvim
    withPython   = true; # for plugins
    withPython3  = true; # for plugins
  };

  xdg.configFile = {
    "nvim/coc-settings.json".text = cocSettings;
  };
}
