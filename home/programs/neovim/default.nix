{ config, lib, ... }:

let
  sources = (import ../../nix/sources.nix);

  pkgs = import sources.nixpkgs {
    overlays = [
      (import sources.neovim-nightly-overlay)
    ];
  };

  unstable = import sources.nixpkgs-unstable { };

  plugins = pkgs.vimPlugins;
  plugins-unstable = unstable.vimPlugins;

  unstablePlugins = with plugins-unstable; [
    # nvim-lightbulb
    # lspsaga-nvim
  ];

  vim-bujo = pkgs.vimUtils.buildVimPlugin {
    name = "vim-bujo";
    src = sources.vim-bujo;
  };

  overriddenPlugins = with pkgs; [];

  myVimPlugins = with plugins; [
    vim-airline             # bottom status bar
    vim-airline-themes      # status bar themes
    matchit-zip             # match parentheses
    base16-vim              # colors
    tabular                 # align things
    vim-markdown            # markdown support
    vim-pandoc-syntax       # pandoc syntax support
    rainbow_parentheses-vim # for nested parentheses
    colorizer               # colors
    vim-floaterm            # floating window terminal
    vim-surround            # quickly edit surroundings (brackets, html tags, etc)
    vim-hoogle              # haskell hoogle
    gruvbox                 # color theme
    coc-nvim                # lsp based intellisense
    haskell-vim             # haskell vim
    vim2hs                  # vim2hs unicode
    hlint-refactor-vim      # hlint
    vim-nix                 # nix support (highlighting, etc)
    ctrlp-vim               # nix support (highlighting, etc)
    vim-bujo                # todos
  ] ++ unstablePlugins
    ++ overriddenPlugins;

  baseConfig    = builtins.readFile ./config.vim;
  cocConfig     = builtins.readFile ./coc.vim;
  cocSettings   = builtins.toJSON (import ./coc-settings.nix);
  pluginsConfig = builtins.readFile ./plugins.vim;
  vimConfig     = baseConfig + pluginsConfig + cocConfig;

in
{
  programs.neovim = {
    enable       = true;
    package      = pkgs.neovim-nightly;
    extraConfig  = vimConfig;
    plugins      = myVimPlugins;
    viAlias      = true;
    vimAlias     = true;
    vimdiffAlias = true;
    withNodeJs   = true; # for coc.nvim
    withPython3  = true; # for plugins
    withRuby     = true;
  };

  xdg.configFile = {
    "nvim/coc-settings.json".text = cocSettings;
  };
}
