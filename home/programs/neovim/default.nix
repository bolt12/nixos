{ config, lib, pkgs, ... }:

let

  plugins = pkgs.vimPlugins;

  overriddenPlugins = with pkgs; [];

  myVimPlugins = with plugins; [
    vim-airline             # bottom status bar
    vim-airline-themes      # TODO
    matchit-zip             # match parentheses
    base16-vim              # colors
    tabular                 # align things
    vim-markdown            # markdown support
    vim-pandoc-syntax       # pandoc syntax support
    rainbow_parentheses-vim # for nested parentheses
    colorizer               # colors
    vim-surround            # quickly edit surroundings (brackets, html tags, etc)
    coc-nvim                # TODO
    haskell-vim             # TODO
    vim2hs                  # TODO
    hlint-refactor-vim      # TODO
    vim-nix                 # nix support (highlighting, etc)
    ctrlp-vim               # nix support (highlighting, etc)
  ] ++ overriddenPlugins;

  baseConfig    = builtins.readFile ./config.vim;
  cocConfig     = builtins.readFile ./coc.vim;
  cocSettings   = builtins.toJSON (import ./coc-settings.nix);
  pluginsConfig = builtins.readFile ./plugins.vim;
  vimConfig     = baseConfig + pluginsConfig + cocConfig;

in
{
  programs.neovim = {
    enable       = true;
    extraConfig  = vimConfig;
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
