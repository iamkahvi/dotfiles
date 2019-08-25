filetype off  " required
set encoding=UTF-8

let mapleader = ","
imap <leader>jj <Esc>
imap <leader>ww <Esc>:w<CR>
imap <leader>wq <Esc>:wq<CR>
inoremap { {<CR>}<Esc>ko	

" ==== Vim Drops
filetype plugin on
set omnifunc=syntaxcomplete#Complete

" ==== Vim Splits
nnoremap <leader>[ <C-w>h
nnoremap <leader>] <C-w>l

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
Plugin 'honza/vim-snippets'
Plugin 'SirVer/ultisnips'
Plugin 'mlaursen/vim-react-snippets'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'scrooloose/nerdcommenter'
Plugin 'tmhedberg/SimpylFold'
Plugin 'scrooloose/nerdtree'
Plugin 'vim-scripts/indentpython.vim'
Plugin 'nathanaelkane/vim-indent-guides'
Plugin 'tpope/vim-surround'
Plugin 'junegunn/goyo.vim'
call vundle#end()

" ==== Colors and other basic settings
set autoindent
set mouse=a
nnoremap o o<Esc>
syntax enable
let python_highlight_all=1
" set background=dark
" colorscheme solarized
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
" Set indentation to 2 spaces for certain files
autocmd FileType javascript,typescript,html,css,json setlocal shiftwidth=2
autocmd FileType javascript,typescript,html,css,json setlocal softtabstop=2
filetype plugin on

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

set undolevels=9001
" ==== Enable mouse
" set mouse=a
" ==== Hide command bar
set noshowmode
