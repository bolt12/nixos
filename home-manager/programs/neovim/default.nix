{ inputs
, pkgs
, ... }:

let
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    overlays = [
      inputs.neovim-nightly-overlay.overlays.default
    ];
  };

  # Nightly renamed nvim.desktop → org.neovim.nvim.desktop but the nixpkgs
  # wrapper hardcodes the old name.  Add a compat symlink so wrapping succeeds.
  neovim-nightly = unstable.neovim-unwrapped.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      if [ -f $out/share/applications/org.neovim.nvim.desktop ] && [ ! -f $out/share/applications/nvim.desktop ]; then
        ln -s org.neovim.nvim.desktop $out/share/applications/nvim.desktop
      fi
    '';
  });

  plugins = pkgs.vimPlugins;
  plugins-unstable = unstable.vimPlugins;

  vim-bujo = pkgs.vimUtils.buildVimPlugin {
    name = "vim-bujo";
    src = inputs.vim-bujo;
  };

  vim-silicon = pkgs.vimUtils.buildVimPlugin {
    name = "vim-silicon";
    src = inputs.vim-silicon;
  };

  llama-vim = pkgs.vimUtils.buildVimPlugin {
    name = "llama-vim";
    src = inputs.llama-vim;
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

  telescope-ui-select = pkgs.vimUtils.buildVimPlugin {
    name = "telescope-ui-select-nvim";
    src = inputs.telescope-ui-select-nvim;
  };

  e-ink = pkgs.vimUtils.buildVimPlugin {
    name = "e-ink-nvim";
    src = inputs.e-ink-nvim;
  };

  cornelis = {
    # plugin packages in required Vim plugin dependencies
    plugin = inputs.cornelis.packages.${pkgs.stdenv.hostPlatform.system}.cornelis-vim;
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

  overriddenPlugins = with pkgs; [ ];

  unstablePlugins = with plugins-unstable; [
    indent-blankline-nvim   # indente blank lines
  ];

  myVimPlugins = with plugins; [
    barbar-nvim              # fancy status bar
    base16-vim               # colors
    cheatsheet-nvim          # command cheatsheet
    cmp-buffer               # auto complete sources
    cmp-cmdline              # auto complete sources
    cmp-git                  # auto complete sources
    cmp_luasnip              # snippets
    cmp-nvim-lsp             # auto complete sources
    cmp-path                 # auto complete sources
    colorizer                # colors
    cornelis                 # agda-mode for neovim
    e-ink                    # e-ink colorscheme
    friendly-snippets        # snippets
    gitsigns-nvim            # git integration
    gruvbox-community        # color theme
    haskell-snippets-nvim    # snippets
    haskell-tools-nvim       # haskell lsp tools
    haskell-vim              # haskell vim
    highstr                  # highlight stuff
    lean-nvim                # Lean NVim plugin
    litee-nvim               # Litee library
    llama-vim                # llama.cpp completion
    luasnip                  # snippets
    matchit-zip              # match parentheses
    neoscroll                # smooth scrollng
    nui-nvim                 # ui building plugin
    nvim-cmp                 # auto complete
    nvim-lspconfig           # LSP config support
    nvim-spectre             # a search panel for neovim
    (plugins-unstable.nvim-treesitter.withPlugins (p: [
      # Primary languages
      p.haskell p.nix p.lua p.bash p.python
      p.c p.cpp p.rust
      # Markup & data
      p.markdown p.markdown_inline p.json p.yaml p.toml
      p.html p.css p.xml
      # Vim/editor
      p.vim p.vimdoc p.query p.regex
      # Version control
      p.diff p.git_rebase p.gitcommit
      # Infrastructure
      p.dockerfile p.sql
    ]))
    nvim-web-devicons        # file icons
    plenary-nvim             # lua dependency for other plugins
    popup-nvim               # popups
    rainbow_parentheses-vim  # for nested parentheses
    tabular                  # align things
    telescope-nvim           # fuzzy finder
    telescope-ui-select      # telescope picker
    telescope-undo-nvim      # undo tree with telescope
    undotree                 # undo tree for neovim
    venn                     # draw diagrams
    vim-airline              # bottom status bar
    vim-airline-themes       # status bar themes
    vim-bujo                 # todos
    vim-floaterm             # floating window terminal
    vim-fugitive             # git plugin
    vim-haskellConcealPlus   # Unicode
    vim-hoogle               # haskell hoogle
    vim-markdown             # markdown support
    vim-nix                  # nix support (highlighting, etc)
    vim-obsession            # save vim session
    vim-pandoc-syntax        # pandoc syntax support
    vim-silicon              # vim Silicon integration
    vim-surround             # quickly edit surroundings (brackets, html tags, etc)
    which-key-nvim           # WhichKey helps you remember your Neovim keymap
    wilder-nvim              # wild menu enhancements
    zk-nvim                  # zk plugin
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
    package      = neovim-nightly;
    extraConfig  = vimConfig;
    plugins      = myVimPlugins;
    viAlias      = true;
    vimAlias     = true;
    vimdiffAlias = true;
    withNodeJs   = true;
    withPython3  = true;
    withRuby     = true;
    extraPackages = [ inputs.cornelis.packages.${pkgs.stdenv.hostPlatform.system}.cornelis ];
  };

  xdg.configFile = {
    "nvim/cheatsheet.txt".text = cheatsheetTxt;
    "nvim/custom-plugins" = {
      recursive = true;
      source = ./custom-plugins;
    };
  };
}
