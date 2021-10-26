set encoding=UTF-8

set hls
set ic
set is
set nu
set noswf

let mapleader = ","
imap <leader>jj <Esc>
imap <leader>ww <Esc>:w<CR>
imap <leader>wq <Esc>:wq<CR>

" ==== Vim Drops
filetype plugin on
set omnifunc=syntaxcomplete#Complete

" ==== Vim Splits
nnoremap <leader>[ <C-w>h
nnoremap <leader>] <C-w>l

call plug#begin('~/.vim/plugged')
Plug 'tpope/vim-sensible'
Plug 'VundleVim/Vundle.vim'
Plug 'honza/vim-snippets'
Plug 'mlaursen/vim-react-snippets'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'scrooloose/nerdcommenter'
Plug 'tmhedberg/SimpylFold'
Plug 'scrooloose/nerdtree'
Plug 'vim-scripts/indentpython.vim'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'tpope/vim-surround'
Plug 'junegunn/goyo.vim'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'rust-lang/rust.vim'
call plug#end()

" ==== Colors and other basic settings
set autoindent
set backspace=indent,eol,start
set complete-=i
set smarttab
set mouse=a
nnoremap o o<Esc>

syntax enable

let python_highlight_all=1
let g:airline_theme='minimalist'
let g:airline_powerline_fonts = 1
set clipboard=unnamed
set shiftwidth=4
set tabstop=4
set softtabstop=4
set number
set cursorline
set wildmenu
set lazyredraw	
set showmatch
set backspace=indent,eol,start

" ==== VIM Search options
set incsearch
set hlsearch
nnoremap <leader>n :nohlsearch<CR>

" ==== Python Options
" (https://realpython.com/vim-and-python-a-match-made-in-heaven/#macos-os-x)
autocmd FileType python
    \ set tabstop=4 |
    \ set softtabstop=4 |
    \ set shiftwidth=4 |
    \ set textwidth=79 |
    \ set expandtab |
    \ set autoindent |
    \ set fileformat=unix

"au BufRead,BufNewFile *.py,*.pyw,*.c,*.h match BadWhitespace /\s\+$/

" ==== VIM Folding
set foldlevel=99
set foldmethod=indent
nnoremap <space> za
vnoremap <space> zf

" ==== Custome Key Bindings
" move vertically by visual line
nnoremap j gj
nnoremap k gk

" ==== NERDTREE
let NERDTreeIgnore = ['__pycache__', '\.pyc$', '\.o$', '\.so$', '\.a$', '\.swp', '*\.swp', '\.swo', '\.swn', '\.swh', '\.swm', '\.swl', '\.swk', '\.sw*$', '[a-zA-Z]*egg[a-zA-Z]*', '.DS_Store']

let NERDTreeShowHidden=1
let g:NERDTreeWinPos="left"
let g:NERDTreeDirArrows=0
map <silent><leader>ne :NERDTreeToggle<CR>
let NERDTreeMinimalUI = 1
let NERDTreeDirArrows = 1

" ==== Syntastic
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0

" ==== Rust
let g:rustfmt_autosave = 1

set undolevels=9001
" ==== Enable mouse
set mouse=a
" ==== Hide command bar
set noshowmode

iab retrun   return
iab rerturn  return
iab rertrun  return
iab retnru   return
iab erturn   return
iab ertnru   return
iab thsi     this
iab fcuntoin function
iab functoin function
iab fucntion function
iab funcotin function
iab funcoitn function
iab funciton function
iab funciotn function
iab costn    const
iab conts    const
iab csont    const
iab THe      The
iab THis     This
iab !+       !=
iab +>       =>
