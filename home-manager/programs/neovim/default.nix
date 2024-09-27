{ inputs
, pkgs
, system
, ... }:

let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    overlays = [
      inputs.neovim-nightly-overlay.overlays.default
    ];
  };

  plugins = pkgs.vimPlugins;
  plugins-unstable = unstable.vimPlugins;

  haskell-tools = pkgs.vimUtils.buildVimPlugin {
    name = "haskell-tools";
    src = inputs.haskell-tools;
  };

  vim-bujo = pkgs.vimUtils.buildVimPlugin {
    name = "vim-bujo";
    src = inputs.vim-bujo;
  };

  vim-silicon = pkgs.vimUtils.buildVimPlugin {
    name = "vim-silicon";
    src = inputs.vim-silicon;
  };

  neoscroll = pkgs.vimUtils.buildVimPlugin {
    name = "neoscroll-nvim";
    src = inputs.neoscroll-nvim;
  };

  venn = pkgs.vimUtils.buildVimPlugin {
    name = "venn-nvim";
    src = inputs.venn-nvim;
  };

  highstr = pkgs.vimUtils.buildVimPlugin {
    name = "HighStr-nvim";
    src = inputs.HighStr-nvim;
  };

  cheatsheet-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "cheatsheet-nvim";
    src = inputs.cheatsheet-nvim;
  };

  haskell-snippets = pkgs.vimUtils.buildVimPlugin {
    name = "haskell-snippets";
    src = inputs.haskell-snippets-nvim;
  };

  gh-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "gh-nvim";
    src = inputs.gh-nvim;
  };

  telescope-ui-select = pkgs.vimUtils.buildVimPlugin {
    name = "telescope-ui-select-nvim";
    src = inputs.telescope-ui-select-nvim;
  };

  cornelis = {
    # plugin packages in required Vim plugin dependencies
    plugin = inputs.cornelis.packages.${system}.cornelis-vim;
    config = ''
      let g:cornelis_use_global_binary = 1
      let g:cornelis_split_location = 'bottom'
      " Highlight holes with a yellow undercurl/underline:
      highlight CornelisHole ctermfg=yellow ctermbg=NONE cterm=undercurl

      " Highlight "generalizables" (declarations in `variable` blocks) like constants:
      highlight link CornelisGeneralizable Constant

      au BufWritePost *.agda execute "normal! :CornelisLoad\<CR>"
    '';
  };

  advanced-search = pkgs.vimUtils.buildVimPlugin {
    name = "advanced-search";
    src = inputs.advanced-search;
  };

  overriddenPlugins = with pkgs; [ ];

  unstablePlugins = with plugins-unstable; [
    indent-blankline-nvim   # indente blank lines
  ];

  myVimPlugins = with plugins; [
    advanced-search         # advanced git search extension
    barbar-nvim             # fancy status bar
    base16-vim              # colors
    cheatsheet-nvim         # command cheatsheet
    cmp-git                 # auto complete sources
    cmp-cmdline             # auto complete sources
    cmp-buffer              # auto complete sources
    cmp-path                # auto complete sources
    cmp_luasnip             # snippets
    cmp-nvim-lsp            # auto complete sources
    colorizer               # colors
    cornelis                # agda-mode for neovim
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
    nui-nvim                # ui building plugin
    plenary-nvim            # lua dependency for other plugins
    popup-nvim              # popups
    rainbow_parentheses-vim # for nested parentheses
    tabular                 # align things
    telescope-nvim          # fuzzy finder
    telescope-ui-select     # telescope picker
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

  baseConfig    = builtins.readFile ./config.vim;
  cheatsheetTxt = builtins.readFile ./cheatsheet.txt;
  pluginsConfig = builtins.readFile ./plugins.vim;
  vimConfig     = baseConfig + pluginsConfig;

in
{
  programs.neovim = {
    enable       = true;
    package      = unstable.neovim;
    extraConfig  = vimConfig;
    plugins      = myVimPlugins;
    viAlias      = true;
    vimAlias     = true;
    vimdiffAlias = true;
    withNodeJs   = true;
    withPython3  = true;
    withRuby     = true;
    extraPackages = [ inputs.cornelis.packages.${system}.cornelis ];
  };

  xdg.configFile = {
    "nvim/cheatsheet.txt".text = cheatsheetTxt;
    "nvim/custom-plugins" = {
      recursive = true;
      source = ./custom-plugins;
    };
  };
}
