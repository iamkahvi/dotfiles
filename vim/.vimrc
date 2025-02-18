" ==== Leader Key ====
let mapleader = " "

" ==== General Settings ====
set encoding=UTF-8
set clipboard=unnamedplus
set autoindent
set backspace=indent,eol,start
set complete-=i
set smarttab
set mouse=a

" ==== Indentation and Formatting ====
set shiftwidth=2
set tabstop=2
set softtabstop=2

" ==== UI Enhancements ====
set number
set relativenumber
set cursorline
set wildmenu
set lazyredraw
set showmatch

" ==== Undo and Folding ====
set undolevels=9001
set foldlevel=99
set foldmethod=indent

" ==== Keep cursor centered ====
set scrolloff=999

" ==== Interface and Appearance ====
set hls            " Highlight search results
set ic             " Ignore case in searches
set is             " Incremental search
set nu             " Show line numbers
set noswf          " Disable swap files
set incsearch      " Enable incremental search
set hlsearch       " Enable search highlighting
syntax enable      " Enable syntax highlighting

" ==== Key Mappings ====

" Insert Mode Shortcuts
imap <leader>jj <Esc>
imap <leader>ww <Esc>:w<CR>
imap <leader>wq <Esc>:wq<CR>

" Normal Mode Shortcuts
nnoremap <leader>ww :w<CR>
nnoremap <leader>wq :wq<CR>

" Window Navigation
nnoremap <leader>[ <C-w>h
nnoremap <leader>] <C-w>l

" Cursor Movement
nnoremap j j^
nnoremap k k^
nnoremap J 5j^
nnoremap K 5k^
vnoremap J 5j^
vnoremap K 5k^

" Indentation
nnoremap <Tab> >>
nnoremap <S-Tab> <<
vnoremap <Tab> >gv
vnoremap <S-Tab> <gv

" Disable Arrow Keys in Normal and Visual Mode
nnoremap <Up> <Nop>
nnoremap <Down> <Nop>
nnoremap <Left> <Nop>
nnoremap <Right> <Nop>
vnoremap <Up> <Nop>
vnoremap <Down> <Nop>
vnoremap <Left> <Nop>
vnoremap <Right> <Nop>

" Insert new line in Normal Mode
nnoremap <leader>o :put _<CR>
nnoremap <leader>O :put! _<CR>

" Duplicate line
nnoremap <C-d> Yp

" Search Options
nnoremap <leader>n :nohlsearch<CR>

" Undo & Redo
inoremap <C-z> <C-o>u
nnoremap U <C-r>

" Deleting and Moving Words
nnoremap <leader>d "_dd
inoremap <M-BS> <C-w>
inoremap <Esc>b <C-Left>
inoremap <M-Left> <C-o>b
inoremap <Esc>f <C-Right>
inoremap <M-Right> <C-o>w

" Folding
nnoremap <leader>f za
vnoremap <leader>f zf

" Move lines up and down in normal mode
nnoremap <C-j> :m .+1<CR>==
nnoremap <C-k> :m .-2<CR>==
nnoremap <A-j> :m .+1<CR>==
nnoremap <A-k> :m .-2<CR>==

" Move lines up and down in insert mode
inoremap <C-j> <Esc>:m .+1<CR>==gi
inoremap <C-k> <Esc>:m .-2<CR>==gi
inoremap <A-j> <Esc>:m .+1<CR>==gi
inoremap <A-k> <Esc>:m .-2<CR>==gi

" Keep cursor at the end after yanking in visual mode
vnoremap y y`]

" Rust
let g:rustfmt_autosave = 1

" ==== Filetype Specific Configurations ====
" Python
autocmd FileType python
    \ set tabstop=4 |
    \ set softtabstop=4 |
    \ set shiftwidth=4 |
    \ set textwidth=79 |
    \ set expandtab |
    \ set autoindent |
    \ set fileformat=unix

let python_highlight_all=1

