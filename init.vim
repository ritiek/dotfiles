" if problems, remember -u option can be used to set path to .vim conf file

set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
call plug#begin('~/.vim/plugged')

Plug 'JuliaEditorSupport/julia-vim'
"Plug 'ajh17/Spacegray.vim'
Plug 'xuhdev/SingleCompile'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-fugitive'
Plug 'rafi/awesome-vim-colorschemes'
Plug 'Yggdroot/indentLine'
Plug 'preservim/nerdtree'
Plug 'ryanoasis/vim-devicons'
Plug 'jlanzarotta/bufexplorer'
Plug 'fidian/hexmode'
Plug 'troydm/zoomwintab.vim'
Plug 'supercollider/scvim'
Plug 'dermusikman/sonicpi.vim'
Plug 'udalov/kotlin-vim'
Plug 'kshenoy/vim-signature'
Plug 'farmergreg/vim-lastplace'
"Plug 'dense-analysis/ale'
Plug 'rust-lang/rust.vim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'preservim/tagbar'
Plug 'christoomey/vim-conflicted'
Plug 'andymass/vim-matchup'
Plug 'pechorin/any-jump.vim'
"Plug 'tmhedberg/SimpylFold'
Plug 'github/copilot.vim'
"Plug 'ycm-core/YouCompleteMe'
Plug 'metakirby5/codi.vim'
Plug 'mg979/vim-visual-multi'

call plug#end()
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line

" vim hardcodes background color erase even if the terminfo file does
" not contain bce (not to mention that libvte based terminals
" incorrectly contain bce in their terminfo files). This causes
" incorrect background rendering when using a color theme with a
" background color.
let &t_ut=''

set background=dark
syntax on
"let g:gruvbox_italic=1
"let g:gruvbox_contrast_dark='hard'
"let g:gruvbox_contrast_light='hard'

"colorscheme spacegray
colorscheme space-vim-dark
"colorscheme one
set t_Co=256
"set termguicolors

autocmd FileType sh,python set commentstring=#\ %s
autocmd FileType c,cpp,java,rust set commentstring=//\ %s
autocmd FileType tex set commentstring=%\ %s
autocmd FileType yml,yaml set commentstring=#\ %s

let g:airline_theme = 'fairyfloss'
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#fnamemod = ':t'
let g:airline#extensions#tabline#buffer_nr_show = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#zoomwintab#enabled = 1
let g:airline#extensions#ale#enabled = 1
"let g:airline#extensions#hunks#enabled = 0
let g:airline#extensions#branch#enabled = 0

let g:ale_sign_warning = ''
let g:ale_set_highlights = 0
let g:ale_lint_on_text_changed = 'never'
"let g:ale_linters = {'rust': ['rustc', 'rls']}
"let g:ale_rust_ignore_error_codes = ['E0283', 'E0412', 'E0432', 'E0433', 'E0601']

"let g:webdevicons_enable_airline_statusline = 1
"let g:webdevicons_enable_airline_tabline = 1

let g:matchup_matchparen_offscreen = {'method': 'popup'}
let g:matchup_transmute_enabled = 1

set laststatus=2

"¦, ┆, │, ⎸, or ▏
let g:indentLine_char = '¦'

if !exists('g:airline_symbols')
    let g:airline_symbols = {}
endif

" unicode symbols
let g:airline_left_sep = '»'
let g:airline_left_sep = '▶'
let g:airline_right_sep = '«'
let g:airline_right_sep = '◀'
let g:airline_symbols.linenr = '␊'
let g:airline_symbols.linenr = '␤'
let g:airline_symbols.linenr = '¶'
let g:airline_symbols.branch = '⎇'
let g:airline_symbols.paste = 'ρ'
let g:airline_symbols.paste = 'Þ'
let g:airline_symbols.paste = '∥'
let g:airline_symbols.whitespace = 'Ξ'

" airline symbols
let g:airline_left_sep = ''
let g:airline_left_alt_sep = ''
let g:airline_right_sep = ''
let g:airline_right_alt_sep = ''
let g:airline_symbols.branch = ''
let g:airline_symbols.readonly = ''
let g:airline_symbols.linenr = ''

set encoding=utf-8
set tabstop=4
set softtabstop=0
set shiftwidth=4
set expandtab
set number
set mouse=a
set title
set clipboard+=unnamedplus
set notimeout
set ttimeout
"set foldmethod=expr
"set foldexpr=VimFolds(v:lnum)
"set foldlevel=5
"set foldcolumn=5

" Keep undo history when switching tabs
set hidden

highlight WhiteSpaces ctermbg=darkgrey guibg=darkgrey
match WhiteSpaces /\s\+$/

highlight Search ctermbg=grey guibg=darkgrey

" Suppresses "Press Enter to confirm" when using :w to write files via scp://
cabbrev w <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'w \| redraw' : 'w')<CR>

"SingleCompile plugin
nmap <F8> :SCCompile<CR>
nmap <F9> :SCCompileRun<CR>

"AnyJump to definations
nmap <silent><Enter> :AnyJump<CR>

"Disabling ALE as it slows down nvim in large projects.
"ALE error navigation
"nmap <silent><C-k> <Plug>(ale_previous_wrap)
"nmap <silent><C-j> <Plug>(ale_next_wrap)

"git blame
nmap <silent><C-w>b :Git blame<CR>

"Hexmode plugin
nmap <C-w>B :Hexmode<CR>

"indentLine plugin
nmap <C-i> :IndentLinesToggle<CR>

"zoomwintab plugin
nmap <silent><C-w>z :ZoomWinTabToggle<CR>

"Tmux like bindings
nmap <C-s> <C-a>
nmap <silent><C-w>- :split<CR>
nmap <silent><C-w><bar> :vsplit<CR>
"nmap <C-w>c :tabe<CR>
nmap <silent><C-w>c :enew<CR>
"nmap <C-w>n :tabn<CR>
nmap <silent><C-w>n :bnext<CR>
"nmap <C-w>N :tabp<CR>
nmap <silent><C-w>N :bprevious<CR>
"nmap <C-w>x :q!<CR>
nmap <silent><C-w>x :bdelete<CR>

nmap <C-w>= :reg<CR>

nmap <silent><tab> :NERDTreeToggle<CR>

nmap <silent><S-tab> :Telescope find_files<CR>
nmap <silent><C-w>/ :Telescope live_grep<CR>

nmap <silent>\ :TagbarToggle<CR>
nmap <C-w><tab> <tab>

nmap <silent><C-w>s :ToggleBufExplore<CR>

nmap <silent><C-w>1 :buffer 1<CR>
nmap <silent><C-w>2 :buffer 2<CR>
nmap <silent><C-w>3 :buffer 3<CR>
nmap <silent><C-w>4 :buffer 4<CR>
nmap <silent><C-w>5 :buffer 5<CR>
nmap <silent><C-w>6 :buffer 6<CR>
nmap <silent><C-w>7 :buffer 7<CR>
nmap <silent><C-w>8 :buffer 8<CR>
nmap <silent><C-w>9 :buffer 9<CR>

let g:VM_mouse_mappings = 1

"f, F insert character
nnoremap <silent>f :exec "normal i".nr2char(getchar())."\e"<CR>
nnoremap <silent>F :exec "normal a".nr2char(getchar())."\e"<CR>

"Ctrl-j/k deletes blank line below/above, and Alt-j/k inserts.
"nnoremap <silent><C-j> m`:silent +g/\m^\s*$/d<CR>``:noh<CR>
"nnoremap <silent><C-k> m`:silent -g/\m^\s*$/d<CR>``:noh<CR>
nnoremap <silent><A-j> :set paste<CR>m`o<Esc>``:set nopaste<CR>
nnoremap <silent><A-k> :set paste<CR>m`O<Esc>``:set nopaste<CR>

tnoremap <silent><Esc> <C-\><C-n>

"Copilot
imap <silent><script><expr> <C-o> copilot#Accept("\<CR>")
let g:copilot_no_tab_map = v:true
nmap <C-o> :Copilot<CR>

" █
"highlight WhiteSpaces ctermbg=green guibg=#55aa55

"set list
"set listchars=tab:→\ ,trail:█,nbsp:-

hi NonText ctermbg=none
hi Normal guibg=NONE ctermbg=NONE
