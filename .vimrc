set encoding=UTF-8

let mapleader = ","

set hls
set ic
set is
set nu
set noswf

set clipboard=unnamedplus

imap <leader>jj <Esc>
imap <leader>ww <Esc>:w<CR>
imap <leader>wq <Esc>:wq<CR>

nnoremap <leader>ww :w<CR>
nnoremap <leader>wq :wq<CR>

" ==== Vim Drops
filetype plugin on
set omnifunc=syntaxcomplete#Complete

" ==== Vim Splits
nnoremap <leader>[ <C-w>h
nnoremap <leader>] <C-w>l

let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
Plug 'junegunn/goyo.vim'
Plug 'scrooloose/nerdcommenter'
Plug 'scrooloose/nerdtree'
Plug 'tpope/vim-surround'
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

" Disable arrow keys in normal mode
nnoremap <Up> <Nop>
nnoremap <Down> <Nop>
nnoremap <Left> <Nop>
nnoremap <Right> <Nop>

" Disable arrow keys in visual mode
vnoremap <Up> <Nop>
vnoremap <Down> <Nop>
vnoremap <Left> <Nop>
vnoremap <Right> <Nop>

nnoremap j j^
nnoremap k k^

nnoremap J 5j^
nnoremap K 5k^

" Indent with Tab in normal mode
nnoremap <Tab> >>
nnoremap <S-Tab> <<

" Indent selection with Tab in visual mode
vnoremap <Tab> >gv
vnoremap <S-Tab> <gv

let python_highlight_all=1
set shiftwidth=4
set tabstop=4
set softtabstop=4
set number
set relativenumber
set cursorline
set wildmenu
set lazyredraw
set showmatch
set backspace=indent,eol,start

" ==== VIM Search options
set incsearch
set hlsearch
nnoremap <leader>n :nohlsearch<CR>

" TODO 
" - shortcut for searching whole file for word under cursor  (not just forward
" and back)
" - shortcut for centering cursor on screen (zz) whenever I go to a specific
"   line
" - shortcut for deleting word in insert mode (opt + backspace)
" - shortcut to undo from insert mode
" - shortcut to redo with U in normal mode

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

" ==== NERDTREE
let NERDTreeIgnore = ['__pycache__', '\.pyc$', '\.o$', '\.so$', '\.a$', '\.swp', '*\.swp', '\.swo', '\.swn', '\.swh', '\.swm', '\.swl', '\.swk', '\.sw*$', '[a-zA-Z]*egg[a-zA-Z]*', '.DS_Store']

let NERDTreeShowHidden=1
let g:NERDTreeWinPos="left"
let g:NERDTreeDirArrows=0
map <silent><leader>ne :NERDTreeToggle<CR>
let NERDTreeMinimalUI = 1
let NERDTreeDirArrows = 1

" ==== Rust
let g:rustfmt_autosave = 1

set undolevels=9001
" ==== Enable mouse
set mouse=a

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
