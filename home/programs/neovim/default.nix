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

  haskell-tools = pkgs.vimUtils.buildVimPlugin {
    name = "haskell-tools";
    src = sources.haskell-tools;
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

  haskell-snippets = pkgs.vimUtils.buildVimPlugin {
    name = "haskell-snippets";
    src = sources.haskell-snippets;
  };

  gh-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "gh-nvim";
    src = sources.gh-nvim;
  };

  overriddenPlugins = with pkgs; [ ];

  unstablePlugins = with plugins-unstable; [
  ];

  myVimPlugins = with plugins; [
    abbrev                  # Abbreviations fix
    barbar-nvim             # fancy status bar
    base16-vim              # colors
    cheatsheet-nvim         # command cheatsheet
    cmp-git                 # auto complete sources
    cmp_luasnip             # snippets
    cmp-nvim-lsp            # auto complete sources
    colorizer               # colors
    friendly-snippets       # snippets
    gh-nvim                 # gh code review plugin
    git-messenger-vim       # Check git commits on cursor hover
    gitsigns-nvim           # git integration
    gruvbox-community       # color theme
    haskell-snippets        # snippets
    haskell-tools           # haskell lsp tools
    haskell-vim             # haskell vim
    highstr                 # highlight stuff
    litee-nvim              # Litee library
    luasnip                 # snippets
    matchit-zip             # match parentheses
    neoscroll               # smooth scrollng
    nvim-cmp                # auto complete
    nvim-lspconfig          # LSP config support
    nvim-spectre            # a search panel for neovim
    nvim-web-devicons       # file icons
    plenary-nvim            # lua dependency for other plugins
    popup-nvim              # popups
    rainbow_parentheses-vim # for nested parentheses
    specs-nvim              # Show where your cursor moves when jumping large distances
    tabular                 # align things
    telescope-nvim          # fuzzy finder
    telescope-ui-select-nvim # telescope picker
    telescope-undo-nvim     # undo tree with telescope
    undotree                # undo tree for neovim
    venn                    # draw diagrams
    vim-airline             # bottom status bar
    vim-airline-themes      # status bar themes
    vim-bujo                # todos
    vim-floaterm            # floating window terminal
    vim-fugitive            # git plugin
    vim-haskellConcealPlus  # Unicode
    vim-hoogle              # haskell hoogle
    vim-markdown            # markdown support
    vim-nix                 # nix support (highlighting, etc)
    vim-pandoc-syntax       # pandoc syntax support
    vim-silicon             # vim Silicon integration
    vim-surround            # quickly edit surroundings (brackets, html tags, etc)
    zk-nvim                 # zk plugin
  ] ++ unstablePlugins
  ++ overriddenPlugins;

  baseConfig = builtins.readFile ./config.vim;
  cheatsheetTxt = builtins.readFile ./cheatsheet.txt;
  pluginsConfig = builtins.readFile ./plugins.vim;
  vimConfig = baseConfig + pluginsConfig;

in
{
  programs.neovim = {
    enable = true;
    package = unstable.neovim-nightly;
    extraConfig = vimConfig;
    plugins = myVimPlugins;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withNodeJs = true;
    withPython3 = true;
    withRuby = true;
  };

  xdg.configFile = {
    "nvim/cheatsheet.txt".text = cheatsheetTxt;
  };
}
