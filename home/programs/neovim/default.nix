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

  auto-save = pkgs.vimUtils.buildVimPlugin {
    name = "auto-save";
    src = sources.AutoSave-nvim;
  };

  abbrev = pkgs.vimUtils.buildVimPlugin {
    name = "abbrev";
    src = sources.AbbrevMan-nvim;
  };

  cheatsheet-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "cheatsheet-nvim";
    src = sources.cheatsheet-nvim;
  };

  goto-preview = pkgs.vimUtils.buildVimPlugin {
    name = "goto-preview";
    src = sources.goto-preview;
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
    coc-nvim                # lsp based intellisense
    haskell-vim             # haskell vim
    vim-haskellConcealPlus  # Unicode
    vim-nix                 # nix support (highlighting, etc)
    gruvbox-community       # color theme
    Shade-nvim              # dims inactive windows
    specs-nvim              # Show where your cursor moves when jumping large distances
    neoscroll               # smooth scrollng
    venn                    # draw diagrams
    nvim-web-devicons       # file icons
    barbar-nvim             # fancy status bar
    highstr                 # highlight stuff
    auto-save               # auto-save files
    abbrev                  # Abbreviations fix
    gitsigns-nvim           # git integration
    popup-nvim              # popups
    plenary-nvim            # lua dependency for other plugins
    telescope-nvim          # fuzzy finder
    cheatsheet-nvim         # command cheatsheet
    goto-preview            # go to line preview
    vim-bujo                # todos
    vim-floaterm            # floating window terminal
    vim-hoogle              # haskell hoogle
    vim-silicon             # vim Silicon integration
    vim-surround            # quickly edit surroundings (brackets, html tags, etc)
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
