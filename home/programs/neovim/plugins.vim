set laststatus=2
let g:airline_powerline_fonts = 1
let g:airline_theme='base16'

set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*
set statusline+=%{get(b:,'gitsigns_head','')}
set statusline+=%{get(b:,'gitsigns_status','')}

let g:airline#extensions#tabline#enabled = 1

"Tabs
nmap <A-1> <Plug>AirlineSelectTab1
nmap <A-2> <Plug>AirlineSelectTab2
nmap <A-3> <Plug>AirlineSelectTab3
nmap <A-4> <Plug>AirlineSelectTab4
nmap <A-5> <Plug>AirlineSelectTab5
nmap <A-6> <Plug>AirlineSelectTab6
nmap <A-7> <Plug>AirlineSelectTab7
nmap <A-8> <Plug>AirlineSelectTab8
nmap <A-9> <Plug>AirlineSelectTab9
nmap <C-N> <Plug>AirlineSelectPrevTab
nmap <C-P> <Plug>AirlineSelectNextTab

" Markdown

" disable header folding
let g:vim_markdown_folding_disabled = 1

" do not use conceal feature, the implementation is not so good
let g:vim_markdown_conceal = 0

" disable math tex conceal feature
let g:tex_conceal = ""
let g:vim_markdown_math = 1

" support front matter of various format
let g:vim_markdown_frontmatter = 1  " for YAML format
let g:vim_markdown_toml_frontmatter = 1  " for TOML format
let g:vim_markdown_json_frontmatter = 1  " for JSON format

augroup pandoc_syntax
    au! BufNewFile,BufFilePre,BufRead *.md set filetype=markdown.pandoc
augroup END

" Intellij Vim disable beep sound
:set visualbell

" Conceal
let g:haskell_conceal_wide = 1
let g:haskell_conceal_enumerations = 0
let hscoptions="℘𝐒𝐓𝐄𝐌xRtbB𝔻wiNrlchDZQBI-A↱"

"TABULAR
let g:haskell_tabular = 1
vmap a= :Tabularize /=<CR>
vmap a; :Tabularize /::<CR>
vmap a- :Tabularize /-><CR>
vmap a\| :Tabularize /\|<CR>
vmap a, :Tabularize /,<CR>

" Haskell-vim
let g:haskell_enable_quantification = 1   " to enable highlighting of `forall`
let g:haskell_enable_recursivedo = 1      " to enable highlighting of `mdo` and `rec`
let g:haskell_enable_arrowsyntax = 1      " to enable highlighting of `proc`
let g:haskell_enable_pattern_synonyms = 1 " to enable highlighting of `pattern`
let g:haskell_enable_typeroles = 1        " to enable highlighting of type roles
let g:haskell_enable_static_pointers = 1  " to enable highlighting of `static`
let g:haskell_backpack = 1                " to enable highlighting of backpack keywords
let g:haskell_indent_if = 3
let g:haskell_indent_case = 2
let g:haskell_indent_let = 4
let g:haskell_indent_where = 2
let g:haskell_indent_before_where = 2
let g:haskell_classic_highlighting = 0
let g:haskell_indent_do = 3
let g:haskell_indent_in = 1
let g:haskell_indent_guard = 2
let g:haskell_indent_case_alternative = 1
let g:haskellmode_completion_ghc = 0

" Disable hlint-refactor-vim's default keybindings
let g:hlintRefactor#disableDefaultKeybindings = 1

" hlint-refactor-vim keybindings
map <silent> <leader>hr :call ApplyOneSuggestion()<CR>
map <silent> <leader>hR :call ApplyAllSuggestions()<CR>

" Rainbow colored parentheses
let g:rainbow_active = 1
let g:rainbow#max_level = 16
let g:rainbow#pairs = [['(', ')'], ['[', ']']]
let g:rainbow#colors = {
\   'dark': [
\     ['yellow',  'orange1'     ],
\     ['green',   'yellow1'     ],
\     ['cyan',    'greenyellow' ],
\     ['magenta', 'green1'      ],
\     ['red',     'springgreen1'],
\     ['yellow',  'cyan1'       ],
\     ['green',   'slateblue1'  ],
\     ['cyan',    'magenta1'    ],
\     ['magenta', 'purple1'     ]
\   ] }

nnoremap <leader>F :CtrlP<CR>

" Highlighting for jsonc filetype
autocmd FileType json syntax match Comment +\/\/.\+$+

" Hoogle config
" let g:hoogle_search_count = 20
" au BufNewFile,BufRead *.hs map <silent> <F1> :Hoogle<CR>
" au BufNewFile,BufRead *.hs map <silent> <C-c> :HoogleClose<CR>

" nnoremap <leader>h :Hoogle <CR>

" Floaterm
hi Floaterm guibg=#282c34

noremap <A-S-d> :FloatermToggle<CR>
noremap! <A-S-d> <Esc>:FloatermToggle<CR>
tnoremap <A-S-d> <C-\><C-n>:FloatermToggle<CR>

nmap <C-b>a <Plug>BujoAddnormal
imap <C-b>a <Plug>BujoAddinsert
nmap <C-b>c <Plug>BujoChecknormal
imap <C-b>c <Plug>BujoCheckinsert

lua require('neoscroll').setup()

lua << EOF
require('specs').setup{
    show_jumps  = true,
    min_jump = 30,
    popup = {
        delay_ms = 0, -- delay before popup displays
        inc_ms = 10, -- time increments used for fade/resize effects
        blend = 10, -- starting blend, between 0-100 (fully transparent), see :h winblend
        width = 30,
        winhl = "PMenu",
        fader = require('specs').linear_fader,
        resizer = require('specs').shrink_resizer
    },
    ignore_filetypes = {},
    ignore_buftypes = {
        nofile = true,
    },
}
EOF

lua << EOF
local abbrev_man = require("abbrev-man")

abbrev_man.setup({
	load_natural_dictionaries_at_startup = true,
	load_programming_dictionaries_at_startup = false,
	natural_dictionaries = {
		["nt_en"] = {},
		["nt_pt"] = {},
	},
})
EOF

lua << EOF
require('gitsigns').setup {
  signs = {
    add          = {hl = 'GitSignsAdd'   , text = '│', numhl='GitSignsAddNr'   , linehl='GitSignsAddLn'},
    change       = {hl = 'GitSignsChange', text = '│', numhl='GitSignsChangeNr', linehl='GitSignsChangeLn'},
    delete       = {hl = 'GitSignsDelete', text = '_', numhl='GitSignsDeleteNr', linehl='GitSignsDeleteLn'},
    topdelete    = {hl = 'GitSignsDelete', text = '‾', numhl='GitSignsDeleteNr', linehl='GitSignsDeleteLn'},
    changedelete = {hl = 'GitSignsChange', text = '~', numhl='GitSignsChangeNr', linehl='GitSignsChangeLn'},
  },
  signcolumn = true,  -- Toggle with `:Gitsigns toggle_signs`
  numhl = false,
  linehl = false,
  word_diff  = false, -- Toggle with `:Gitsigns toggle_word_diff`
  watch_gitdir = {
    interval = 1000,
    follow_files = true
  },
  attach_to_untracked = true,
  current_line_blame = true, -- Toggle with `:Gitsigns toggle_current_line_blame`
  current_line_blame_opts = {
    virt_text = true,
    virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
    delay = 1000,
    ignore_whitespace = false,
  },
  current_line_blame_formatter = '<author>, <author_time:%Y-%m-%d> - <summary>',
  sign_priority = 6,
  update_debounce = 100,
  status_formatter = nil, -- Use default
  max_file_length = 40000,
  preview_config = {
    -- Options passed to nvim_open_win
    border = 'single',
    style = 'minimal',
    relative = 'cursor',
    row = 0,
    col = 1
  },
  yadm = {
    enable = false
  },
  keymaps = {
    -- Default keymap options
    noremap = true,
    buffer = true,

    ['n ]c'] = { expr = true, "&diff ? ']c' : '<cmd>lua require\"gitsigns\".next_hunk()<CR>'"},
    ['n [c'] = { expr = true, "&diff ? '[c' : '<cmd>lua require\"gitsigns\".prev_hunk()<CR>'"},

    ['n <leader>ghs'] = '<cmd>lua require"gitsigns".stage_hunk()<CR>',
    ['v <leader>ghs'] = '<cmd>lua require"gitsigns".stage_hunk({vim.fn.line("."), vim.fn.line("v")})<CR>',
    ['n <leader>ghu'] = '<cmd>lua require"gitsigns".undo_stage_hunk()<CR>',
    ['n <leader>ghr'] = '<cmd>lua require"gitsigns".reset_hunk()<CR>',
    ['v <leader>ghr'] = '<cmd>lua require"gitsigns".reset_hunk({vim.fn.line("."), vim.fn.line("v")})<CR>',
    ['n <leader>ghR'] = '<cmd>lua require"gitsigns".reset_buffer()<CR>',
    ['n <leader>ghp'] = '<cmd>lua require"gitsigns".preview_hunk()<CR>',
    ['n <leader>gbl'] = '<cmd>lua require"gitsigns".blame_line(true)<CR>',

    -- Text objects
    ['o ih'] = ':<C-U>lua require"gitsigns".select_hunk()<CR>',
    ['x ih'] = ':<C-U>lua require"gitsigns".select_hunk()<CR>'
  },
}
EOF

lua << EOF
require('telescope').setup{
  extensions = {
    undo = {
      use_delta = true,
      use_custom_command = nil, -- setting this implies `use_delta = false`. Accepted format is: { "bash", "-c", "echo '$DIFF' | delta" }
      side_by_side = true,
      diff_context_lines = vim.o.scrolloff,
      entry_format = "state #$ID, $STAT, $TIME",
      time_format = "",
      saved_only = false,
      layout_strategy = "vertical",
      layout_config = {
        preview_height = 0.8,
      },
    },
    ["ui-select"] = {
      require("telescope.themes").get_dropdown {
        -- even more opts
      }

      -- pseudo code / specification for writing custom displays, like the one
      -- for "codeactions"
      -- specific_opts = {
      --   [kind] = {
      --     make_indexed = function(items) -> indexed_items, width,
      --     make_displayer = function(widths) -> displayer
      --     make_display = function(displayer) -> function(e)
      --     make_ordinal = function(e) -> string
      --   },
      --   -- for example to disable the custom builtin "codeactions" display
      --      do the following
      --   codeactions = false,
      -- }
    }
  },
  defaults = {
    vimgrep_arguments = {
      'rg',
      '--color=never',
      '--no-heading',
      '--with-filename',
      '--line-number',
      '--column',
      '--smart-case'
    },
    prompt_prefix = "> ",
    selection_caret = "> ",
    entry_prefix = "  ",
    initial_mode = "insert",
    selection_strategy = "reset",
    sorting_strategy = "descending",
    layout_strategy = "horizontal",
    layout_config = {
      horizontal = {
        mirror = false,
      },
      vertical = {
        mirror = false,
      },
    },
    file_sorter =  require'telescope.sorters'.get_fuzzy_file,
    file_ignore_patterns = {},
    generic_sorter =  require'telescope.sorters'.get_generic_fuzzy_sorter,
    winblend = 0,
    border = {},
    borderchars = { '─', '│', '─', '│', '╭', '╮', '╯', '╰' },
    color_devicons = true,
    use_less = true,
    path_display = {},
    set_env = { ['COLORTERM'] = 'truecolor' }, -- default = nil,
    file_previewer = require'telescope.previewers'.vim_buffer_cat.new,
    grep_previewer = require'telescope.previewers'.vim_buffer_vimgrep.new,
    qflist_previewer = require'telescope.previewers'.vim_buffer_qflist.new,

    -- Developer configurations: Not meant for general override
    buffer_previewer_maker = require'telescope.previewers'.buffer_previewer_maker
  }
}

-- To get ui-select loaded and working with telescope, you need to call
-- load_extension, somewhere after setup function:
require("telescope").load_extension("ui-select")
require("telescope").load_extension("undo")
EOF

" Find files using Telescope command-line sugar.
nnoremap <leader>ff <cmd>Telescope find_files<cr>
nnoremap <leader>fg <cmd>Telescope live_grep<cr>
nnoremap <leader>fb <cmd>Telescope buffers<cr>
nnoremap <leader>fh <cmd>Telescope help_tags<cr>

lua << EOF
require("cheatsheet").setup({
    -- Whether to show bundled cheatsheets

    -- For generic cheatsheets like default, unicode, nerd-fonts, etc
    bundled_cheatsheets = true,
    -- bundled_cheatsheets = {
    --     enabled = {},
    --     disabled = {},
    -- },

    -- For plugin specific cheatsheets
    bundled_plugin_cheatsheets = true,
    -- bundled_plugin_cheatsheets = {
    --     enabled = {},
    --     disabled = {},
    -- }

    -- For bundled plugin cheatsheets, do not show a sheet if you
    -- don't have the plugin installed (searches runtimepath for
    -- same directory name)
    include_only_installed_plugins = true,
})
EOF

lua << EOF

-- Global mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
vim.keymap.set('n', '<space>e', vim.diagnostic.open_float)
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist)

local has_words_before = function()
  unpack = unpack or table.unpack
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

local luasnip = require'luasnip'
local cmp = require'cmp'

local haskell_snippets = require('haskell-snippets').all
luasnip.add_snippets('haskell', haskell_snippets, { key = 'haskell' })

cmp.setup {
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body) -- For `luasnip` users.
    end,
  },
  sources = {
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
    { name = 'git' }
  },
  mapping = cmp.mapping.preset.insert({

    -- ... Your other mappings ...

    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      -- You could replace the expand_or_jumpable() calls with expand_or_locally_jumpable()
      -- that way you will only jump inside the snippet region
      elseif luasnip.expand_or_locally_jumpable() then
        luasnip.expand_or_jump()
      elseif has_words_before() then
        cmp.complete()
      else
        fallback()
      end
    end, { "i", "s" }),

    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  })
}

-- The nvim-cmp almost supports LSP's capabilities so You should advertise it to LSP servers..
local capabilities = require('cmp_nvim_lsp').default_capabilities()

vim.g.haskell_tools = {
        hls = {
          on_attach = function(client, bufnr, ht)
            local bufnr = vim.api.nvim_get_current_buf()
            local opts = { noremap = true, silent = true, buffer = bufnr, }

            vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
            vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
            vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
            vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
            vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
            vim.keymap.set('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, opts)
            vim.keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, opts)
            vim.keymap.set('n', '<leader>wl', function()
              print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
            end, opts)
            vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, opts)
            vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
            vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, opts)
            vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
            vim.keymap.set('n', '<leader>f', function()
              vim.lsp.buf.format { async = true }
            end, opts)

            -- haskell-language-server relies heavily on codeLenses,
            -- so auto-refresh (see advanced configuration) is enabled by default
            vim.keymap.set('n', '<leader>cl', vim.lsp.codelens.run, opts)
            -- Hoogle search for the type signature of the definition under the cursor
            vim.keymap.set('n', '<leader>hs', ht.hoogle.hoogle_signature, opts)
            -- Evaluate all code snippets
            vim.keymap.set('n', '<leader>ea', ht.lsp.buf_eval_all, opts)
            -- Toggle a GHCi repl for the current package
            vim.keymap.set('n', '<leader>rr', ht.repl.toggle, opts)
            -- Toggle a GHCi repl for the current buffer
            vim.keymap.set('n', '<leader>rf', function()
              ht.repl.toggle(vim.api.nvim_buf_get_name(0))
            end, opts)
            vim.keymap.set('n', '<leader>rq', ht.repl.quit, opts)
          end,
          default_settings = {
            haskell = {
              hlintOn = true,
              maxNumberOfProblems = 10,
              formattingProvider = "stylish-haskell",
              completionSnippetsOn = true,
              plugin = {
                stan = { globalOn = false }
              }
            },
          },
          capabilities = capabilities
        },
      }

EOF

lua << EOF
local lspconfig = require('lspconfig')
local configs = require('lspconfig/configs')

configs.zk = {
  default_config = {
    cmd = {'zk', 'lsp'},
    filetypes = {'markdown'},
    root_dir = function()
      return vim.loop.cwd()
    end,
    settings = {}
  };
}

lspconfig.zk.setup({ on_attach = function(client, buffer)
  -- Add keybindings here, see https://github.com/neovim/nvim-lspconfig#keybindings-and-completion
  local bufnr = vim.api.nvim_get_current_buf()
  local opts = { noremap = true, silent = true, buffer = bufnr, }

  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
  vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
  vim.keymap.set('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, opts)
  vim.keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, opts)
  vim.keymap.set('n', '<leader>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, opts)
  vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, opts)
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
  vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, opts)
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
  vim.keymap.set('n', '<leader>f', function()
    vim.lsp.buf.format { async = true }
  end, opts)
end })
EOF

lua << EOF
require('litee.lib').setup()
require('litee.gh').setup({
  -- deprecated, around for compatability for now.
  jump_mode   = "invoking",
  -- remap the arrow keys to resize any litee.nvim windows.
  map_resize_keys = false,
  -- do not map any keys inside any gh.nvim buffers.
  disable_keymaps = false,
  -- the icon set to use.
  icon_set = "default",
  -- any custom icons to use.
  icon_set_custom = nil,
  -- whether to register the @username and #issue_number omnifunc completion
  -- in buffers which start with .git/
  git_buffer_completion = true,
  -- defines keymaps in gh.nvim buffers.
  keymaps = {
      -- when inside a gh.nvim panel, this key will open a node if it has
      -- any futher functionality. for example, hitting <CR> on a commit node
      -- will open the commit's changed files in a new gh.nvim panel.
      open = "<CR>",
      -- when inside a gh.nvim panel, expand a collapsed node
      expand = "zo",
      -- when inside a gh.nvim panel, collpased and expanded node
      collapse = "zc",
      -- when cursor is over a "#1234" formatted issue or PR, open its details
      -- and comments in a new tab.
      goto_issue = "gd",
      -- show any details about a node, typically, this reveals commit messages
      -- and submitted review bodys.
      details = "d",
      -- inside a convo buffer, submit a comment
      submit_comment = "<C-s>",
      -- inside a convo buffer, when your cursor is ontop of a comment, open
      -- up a set of actions that can be performed.
      actions = "<C-a>",
      -- inside a thread convo buffer, resolve the thread.
      resolve_thread = "<C-r>",
      -- inside a gh.nvim panel, if possible, open the node's web URL in your
      -- browser. useful particularily for digging into external failed CI
      -- checks.
      goto_web = "gx"
  }
})
EOF

lua << EOF
require('spectre').setup({
  live_update = false, -- auto execute search again when you write to any file in vim
  find_engine = {
    ['rg'] = {
          cmd = "rg",
          -- default args
          args = {
            '--color=never',
            '--no-heading',
            '--with-filename',
            '--line-number',
            '--column',
            '--multiline',
          } ,
          options = {
            ['ignore-case'] = {
              value= "--ignore-case",
              icon="[I]",
              desc="ignore case"
            },
            ['hidden'] = {
              value="--hidden",
              desc="hidden file",
              icon="[H]"
            },
            -- you can put any rg search option you want here it can toggle with
            -- show_option function
          }
        },
      }
})
EOF

" SUMMARY
" a= -> Align on equal sign
" a- -> Align on case match
" a; -> Align on :: match
"
" set virtualedit=all or set ve=all.
" This will allow you to freely move the cursor in the buffer. (see help virtualedit)
" Enter in Visual Block mode using <C-v>. Select the region where the box should be.
" Invoke :VBox. This will draw a rectangle. In case, it has a width or a height of 1, it will draw a line.
