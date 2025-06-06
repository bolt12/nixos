set laststatus=2
let g:airline_powerline_fonts = 1
let g:airline_theme='base16'

set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%{ObsessionStatus()}
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

lua << EOF
require('neoscroll').setup({
  mappings = {                 -- Keys to be mapped to their corresponding default scrolling animation
    '<C-u>', '<C-d>',
    '<C-b>', '<C-f>',
    '<C-y>', '<C-e>',
    'zt', 'zz', 'zb',
  },
  hide_cursor = true,          -- Hide cursor while scrolling
  stop_eof = true,             -- Stop at <EOF> when scrolling downwards
  respect_scrolloff = false,   -- Stop scrolling when the cursor reaches the scrolloff margin of the file
  cursor_scrolls_alone = true, -- The cursor will keep on scrolling even if the window cannot scroll further
  easing = 'linear',           -- Default easing function
  pre_hook = nil,              -- Function to run before the scrolling animation starts
  post_hook = nil,             -- Function to run after the scrolling animation ends
  performance_mode = false,    -- Disable "Performance Mode" on all buffers.
})
EOF

lua << EOF
require('gitsigns').setup {
  signs = {
    add          = { text = '│' },
    change       = { text = '│' },
    delete       = { text = '_' },
    topdelete    = { text = '‾' },
    changedelete = { text = '~' },
    untracked    = { text = '┆' },
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
    virt_text_priority = 100,
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
  on_attach = function(bufnr)
    local gs = package.loaded.gitsigns

    local function map(mode, l, r, opts)
      opts = opts or {}
      opts.buffer = bufnr
      vim.keymap.set(mode, l, r, opts)
    end

    -- Navigation
    map('n', ']c', function()
      if vim.wo.diff then return ']c' end
      vim.schedule(function() gs.next_hunk() end)
      return '<Ignore>'
    end, {expr=true})

    map('n', '[c', function()
      if vim.wo.diff then return '[c' end
      vim.schedule(function() gs.prev_hunk() end)
      return '<Ignore>'
    end, {expr=true})

    -- Actions
    map('n', '<leader>ghs', gs.stage_hunk)
    map('n', '<leader>ghr', gs.reset_hunk)
    map('v', '<leader>ghs', function() gs.stage_hunk {vim.fn.line('.'), vim.fn.line('v')} end)
    map('v', '<leader>ghr', function() gs.reset_hunk {vim.fn.line('.'), vim.fn.line('v')} end)
    map('n', '<leader>ghS', gs.stage_buffer)
    map('n', '<leader>ghu', gs.undo_stage_hunk)
    map('n', '<leader>ghR', gs.reset_buffer)
    map('n', '<leader>ghp', gs.preview_hunk)
    map('n', '<leader>ghb', function() gs.blame_line{full=true} end)
    map('n', '<leader>gtb', gs.toggle_current_line_blame)
    map('n', '<leader>ghd', gs.diffthis)
    map('n', '<leader>ghD', function() gs.diffthis('~') end)
    map('n', '<leader>gtd', gs.toggle_deleted)

    -- Text object
    map({'o', 'x'}, 'ih', ':<C-U>Gitsigns select_hunk<CR>')
  end
}
EOF

lua << EOF
require('telescope').setup{
  extensions = {
    undo = {
      use_delta = true,
      use_custom_command = nil, -- setting this implies `use_delta = false`. Accepted format is: { "bash", "-c", "echo '$DIFF' | delta" }
      side_by_side = true,
      vim_diff_opts = { ctxlen = 0 },
      entry_format = "state #$ID, $STAT, $TIME",
      time_format = "",
      saved_only = false,
      layout_strategy = "vertical",
      layout_config = {
        preview_height = 0.8,
      },
    },
    -- Telescope layout setup
    telescope_theme = {
        function_name_1 = {
            -- Theme options
        },
        function_name_2 = "dropdown",
        -- e.g. realistic example
        show_custom_functions = {
            layout_config = { width = 0.4, height = 0.4 },
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

    -- For plugin specific cheatsheets
    bundled_plugin_cheatsheets = true,

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

local cmp = require'cmp'
local luasnip = require'luasnip'

local haskell_snippets = require('haskell-snippets').all
luasnip.add_snippets('haskell', haskell_snippets, { key = 'haskell' })

cmp.setup ({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body) -- For `luasnip` users.
    end,
  },
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'luasnip' }, -- For luasnip users.
    { name = 'path' },
    { name = 'cmp_git' },
  }, {
    { name = 'buffer' },
  }),
  mapping = cmp.mapping.preset.insert({

   -- ... Your other mappings ...

   -- ["<CR>"] = cmp.mapping({
   --   i = function(fallback)
   --     if cmp.visible() and cmp.get_active_entry() then
   --       cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = false })
   --     else
   --       fallback()
   --     end
   --   end,
   --   s = cmp.mapping.confirm({ select = true }),
   --   c = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }),
   -- }),
   ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.

   ["<Tab>"] = cmp.mapping(function(fallback)
     if cmp.visible() then
       cmp.select_next_item()
     elseif luasnip.locally_jumpable(1) then
       luasnip.jump(1)
     else
       fallback()
     end
   end, { "i", "s" }),

   ["<S-Tab>"] = cmp.mapping(function(fallback)
     if cmp.visible() then
       cmp.select_prev_item()
     elseif luasnip.locally_jumpable(-1) then
       luasnip.jump(-1)
     else
       fallback()
     end
   end, { "i", "s" }),
  })
})
cmp.setup.filetype('gitcommit', {
  sources = cmp.config.sources({
    { name = 'git' },
  }, {
    { name = 'buffer' },
  })
})
require("cmp_git").setup()
cmp.setup.cmdline(':', {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources({
    { name = 'path' }
  }, {
    {
      name = 'cmdline',
      option = {
        ignore_cmds = { 'Man', '!' }
      }
    }
  })
})

-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline({ '/', '?' }, {
  mapping = cmp.mapping.preset.cmdline(),
  sources = {
    { name = 'buffer' }
  }
})

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(':', {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources({
    { name = 'path' }
  }, {
    { name = 'cmdline' }
  }),
  matching = { disallow_symbol_nonprefix_matching = false }
})

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

lua << EOF
require("ibl").setup()
EOF

lua << EOF
-- Define the directory containing your custom plugins.
local plugins_dir = "/home/bolt/.config/nvim/custom-plugins"
-- Add that directory to package.path.
package.path = package.path .. ";" .. plugins_dir .. "/?.lua"

require('chatgpt-ui')
require('journal-wrap-images')
EOF

lua << EOF
local wk = require("which-key")
wk.setup { }
EOF

" Wilder nvim
call wilder#enable_cmdline_enter()
set wildcharm=<Tab>
cmap <expr> <Tab> wilder#in_context() ? wilder#next() : "\<Tab>"
cmap <expr> <S-Tab> wilder#in_context() ? wilder#previous() : "\<S-Tab>"
call wilder#set_option('modes', ['/', '?', ':'])

call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     wilder#substitute_pipeline(),
      \     wilder#cmdline_pipeline({
      \       'fuzzy': 1,
      \       'sorter': wilder#python_difflib_sorter(),
      \     }),
      \     wilder#python_search_pipeline({
      \       'pattern': 'fuzzy',
      \     }),
      \   ),
      \ ])

let s:highlighters = [
        \ wilder#pcre2_highlighter(),
        \ wilder#basic_highlighter(),
        \ ]

call wilder#set_option('renderer', wilder#renderer_mux({
      \ ':': wilder#popupmenu_renderer({
      \   'highlighter': s:highlighters,
      \ }),
      \ '/': wilder#wildmenu_renderer({
      \   'highlighter': s:highlighters,
      \ }),
      \ }))


au BufRead,BufNewFile *.agda call AgdaFiletype()
au BufRead,BufNewFile *.lagda.md call AgdaFiletype()
au QuitPre *.agda :CornelisCloseInfoWindows
function! AgdaFiletype()
    nnoremap <C-c> <Nop>
    nnoremap <buffer> <leader><C-c><C-l> :CornelisLoad<CR>
    nnoremap <buffer> <leader><C-c><C-r> :CornelisRefine<CR>
    nnoremap <buffer> <leader><C-c><C-c> :CornelisMakeCase<CR>
    nnoremap <buffer> <leader><C-c>tc    :CornelisTypeContext<CR>
    nnoremap <buffer> <leader><C-c>ti    :CornelisTypeContextInfer<CR>
    nnoremap <buffer> <leader><C-c><C-s> :CornelisSolve<CR>
    nnoremap <buffer> <leader><C-C><C-a> :CornelisAuto<CR>
    nnoremap <buffer> <leader><C-C><C-h> :CornelisHelperFunc<CR>
    nnoremap <buffer> <leader><C-C><C-n> :CornelisNormalize<CR>
    nnoremap <buffer> gd        :CornelisGoToDefinition<CR>
    nnoremap <buffer> [/        :CornelisPrevGoal<CR>
    nnoremap <buffer> ]/        :CornelisNextGoal<CR>
    nnoremap <buffer> <C-A>     :CornelisInc<CR>
    nnoremap <buffer> <C-X>     :CornelisDec<CR>
endfunction

" Start Obsession on vim start
autocmd VimEnter * Obsession

" SUMMARY
" a= -> Align on equal sign
" a- -> Align on case match
" a; -> Align on :: match
"
" set virtualedit=all or set ve=all.
" This will allow you to freely move the cursor in the buffer. (see help virtualedit)
" Enter in Visual Block mode using <C-v>. Select the region where the box should be.
" Invoke :VBox. This will draw a rectangle. In case, it has a width or a height of 1, it will draw a line.
