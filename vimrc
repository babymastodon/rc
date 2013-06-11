filetype plugin on
filetype indent on
set nosmartindent
set tabstop=2
set shiftwidth=2
set expandtab
set autochdir
set pastetoggle=<F2>
map <F1> <Esc>
imap <F1> <Esc>
set bs=2
au BufNewFile,BufRead wscript* set filetype=python
syntax on

au FileType python setl sw=4 sts=4 et
au FileType mcs51a setl sw=3 sts=3 et

let g:netrw_preview = 1

set shcf=-ci

" also download: http://www.thouters.be/downloads/vim-mcs51-v3.zip
" for asm syntax highlighting

au BufNewFile,BufRead *.cpp set syntax=cpp11

" Disable Ex Mode
:map Q <Nop>

" use the system clipboard as the default yank location
" (need to install vim from source)
set clipboard=unnamedplus

" Insert Ascii Text Headers
command -nargs=* Header read !figlet -f starwars -k -w 60 -c <args>

" More intuitive movement
:noremap K {
:noremap J }
:noremap H ^
:noremap L $

