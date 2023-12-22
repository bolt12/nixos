" -----------------------
" General Editor Settings
" -----------------------

" Better Unix and UTF-8 support
set viewoptions=folds,options,cursor,unix,slash
set encoding=utf-8

" True color support
set termguicolors

" Theme
colorscheme gruvbox

" Enhance UI and Experience
set laststatus=2
set noshowmode
set number                  " Show line numbers.
set numberwidth=1           " Minimum line number column width.
set cmdheight=2             " Number of screen lines to use for the commandline.
set textwidth=78            " Lines length limit (0 if no limit).
set cursorline              " Highlight line cursor is currently on
set lazyredraw
set mouse=a
set nowrap
filetype plugin indent on
syntax on

" Code folding
set foldmethod=indent   " Use indentation levels for folding
set foldnestmax=3       " Limit folding to 3 nested levels
set nofoldenable        " Start with no folds closed (adjust as desired)

" Improve Command Line Experience
set wildignore+=*\\tmp\\*,*.swp,*.swo,*.zip,.git,.cabal-sandbox
set wildmode=list:longest,full
set wildmenu

" Clipboard integration
set clipboard=unnamedplus

" Avoid Annoying Sound on Errors
set noerrorbells
set vb t_vb=

" Other editor options
set guicursor=
set magic
set mat=2
set history=10000

" -------------------
" Tabs and Formatting
" -------------------

" Use spaces instead of tabs by default
set expandtab
set tabstop=2
set softtabstop=2
set shiftwidth=2
set smarttab
set smartindent

" Sensible auto-formatting
set formatoptions=jtcrq
set linebreak               " Don't cut lines in the middle of a word.
set showmatch               " Shows matching parenthesis.
set matchtime=2             " Time during which the matching parenthesis is shown.
set listchars=tab:▸\ ,eol:¬ " Invisible characters representation when :set list.

" ---------------------
" Search and Navigation
" ---------------------

set incsearch   " Incremental search.
set hlsearch
set ignorecase  " Case insensitive.
set smartcase   " Case sensitive if uppercase present in pattern.

" -----------------
" Custom Functions
" -----------------

" Toggle between tabs and spaces
function! TabToggle()
  if &expandtab
    set noexpandtab
  else
    set expandtab
  endif
endfunc

" Trim trailing whitespace
function! TrimWhitespace()
    let l:save_cursor = getpos('.')
    %s/\s\+$//e
    call setpos('.', l:save_cursor)
endfun
command! TrimWhitespace call TrimWhitespace() " Command to manually trim whitespace
autocmd BufWritePre * :call TrimWhitespace()  " Trim whitespace on every save

" -----------------------
" Auto-commands and Mappings
" -----------------------

" Avoid the ex-mode
nnoremap Q <Nop>
nnoremap gQ <Nop>

" Close quickfix window with Esc
nnoremap <Esc> :cclose<CR>

" Clear search highlighting with Ctrl-Z
nnoremap <C-z> :nohlsearch<CR>

augroup custom_autocmds
  autocmd!
  " Provide Vimscript help on the word under the cursor with Alt-Z
  autocmd FileType vim nnoremap <buffer> <M-z> :execute "help" expand("<cword>")<CR>

  " Enable spell check for markdown files
  au BufNewFile,BufRead *.md setlocal spell

  " Return to last edit position when opening files
  autocmd BufReadPost *
       \ if line("'\"") > 0 && line("'\"") <= line("$") |
       \   exe "normal! g`\"" |
       \ endif
augroup END
