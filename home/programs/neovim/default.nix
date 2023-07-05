{ config, lib, ... }:

let
  sources = (import ../../nix/sources.nix);

  unstable = import sources.nixpkgs-unstable {
    overlays = [
      (import sources.neovim-nightly-overlay)
    ];
  };

  pkgs = import sources.nixpkgs { };

  plugins = pkgs.vimPlugins;
  plugins-unstable = unstable.vimPlugins;

  coc-nvim-22-11 = pkgs.vimUtils.buildVimPlugin {
    name = "coc.nvim";
    src = sources.coc-nvim;
  };

  vim-bujo = pkgs.vimUtils.buildVimPlugin {
    name = "vim-bujo";
    src = sources.vim-bujo;
  };

  vim-silicon = pkgs.vimUtils.buildVimPlugin {
    name = "vim-silicon";
    src = sources.vim-silicon;
  };

  neoscroll = pkgs.vimUtils.buildVimPlugin {
    name = "neoscroll-nvim";
    src = sources.neoscroll-nvim;
  };

  venn = pkgs.vimUtils.buildVimPlugin {
    name = "venn-nvim";
    src = sources.venn-nvim;
  };

  highstr = pkgs.vimUtils.buildVimPlugin {
    name = "HighStr-nvim";
    src = sources.HighStr-nvim;
  };

  abbrev = pkgs.vimUtils.buildVimPlugin {
    name = "abbrev";
    src = sources.AbbrevMan-nvim;
  };

  cheatsheet-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "cheatsheet-nvim";
    src = sources.cheatsheet-nvim;
  };

  overriddenPlugins = with pkgs; [ ];

  unstablePlugins = with plugins-unstable; [
  ];

  myVimPlugins = with plugins; [
    coc-nvim-22-11 # lsp based intellisense
    vim-airline # bottom status bar
    vim-airline-themes # status bar themes
    matchit-zip # match parentheses
    base16-vim # colors
    tabular # align things
    vim-markdown # markdown support
    vim-pandoc-syntax # pandoc syntax support
    rainbow_parentheses-vim # for nested parentheses
    colorizer # colors
    haskell-vim # haskell vim
    vim-haskellConcealPlus # Unicode
    vim-nix # nix support (highlighting, etc)
    gruvbox-community # color theme
    Shade-nvim # dims inactive windows
    specs-nvim # Show where your cursor moves when jumping large distances
    neoscroll # smooth scrollng
    venn # draw diagrams
    nvim-web-devicons # file icons
    barbar-nvim # fancy status bar
    highstr # highlight stuff
    abbrev # Abbreviations fix
    gitsigns-nvim # git integration
    popup-nvim # popups
    plenary-nvim # lua dependency for other plugins
    telescope-nvim # fuzzy finder
    cheatsheet-nvim # command cheatsheet
    vim-bujo # todos
    vim-floaterm # floating window terminal
    vim-hoogle # haskell hoogle
    vim-silicon # vim Silicon integration
    vim-surround # quickly edit surroundings (brackets, html tags, etc)
    vim-fugitive # git plugin
    zk-nvim # zk plugin
  ] ++ unstablePlugins
  ++ overriddenPlugins;

  baseConfig = builtins.readFile ./config.vim;
  cocConfig = builtins.readFile ./coc.vim;
  cocSettings = builtins.toJSON (import ./coc-settings.nix);
  cheatsheetTxt = builtins.readFile ./cheatsheet.txt;
  pluginsConfig = builtins.readFile ./plugins.vim;
  vimConfig = baseConfig + pluginsConfig + cocConfig;

in
{
  programs.neovim = {
    enable = true;
    package = unstable.neovim-unwrapped;
    extraConfig = vimConfig;
    plugins = myVimPlugins;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withNodeJs = true; # for coc.nvim
    withPython3 = true; # for plugins
    withRuby = true;
  };

  xdg.configFile = {
    "nvim/coc-settings.json".text = cocSettings;
    "nvim/cheatsheet.txt".text = cheatsheetTxt;
  };
}
