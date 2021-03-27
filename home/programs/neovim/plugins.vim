set laststatus=2
let g:airline_powerline_fonts = 1
let g:airline_theme='base16'

set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:airline#extensions#coc#enabled = 1
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

"Idris2
"<LocalLeader>r reload file
"<LocalLeader>t show type
"<LocalLeader>a Create an initial clause for a type declaration.
"<LocalLeader>c case split
"<LocalLeader>mc make case
"<LocalLeader>w add with clause
"<LocalLeader>e evaluate expression
"<LocalLeader>l make lemma
"<LocalLeader>m add missing clause
"<LocalLeader>f refine item
"<LocalLeader>o obvious proof search
"<LocalLeader>s proof search
"<LocalLeader>i open idris response window
"<LocalLeader>d show documentation

" Conceal
let g:haskell_conceal_wide = 1
let g:haskell_conceal_enumerations = 0
let hscoptions="𝐒𝐓𝐄𝐌xRtB𝔻wNrlCchfDZQBI-A↱"

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

nnoremap <leader>f :CtrlP<CR>

" Highlighting for jsonc filetype
autocmd FileType json syntax match Comment +\/\/.\+$+

" Hoogle config
let g:hoogle_search_count = 20
au BufNewFile,BufRead *.hs map <silent> <F1> :Hoogle<CR>
au BufNewFile,BufRead *.hs map <silent> <C-c> :HoogleClose<CR>

nnoremap <leader>h :Hoogle <CR>

" Floaterm
hi Floaterm guibg=#282c34

noremap <A-S-d> :FloatermToggle<CR>
noremap! <A-S-d> <Esc>:FloatermToggle<CR>
tnoremap <A-S-d> <C-\><C-n>:FloatermToggle<CR>

" SUMMARY
" a= -> Align on equal sign
" a- -> Align on case match
" a; -> Align on :: match
