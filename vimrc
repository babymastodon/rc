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
:nnoremap Q <Nop>

" use the system clipboard as the default yank location
" (need to install vim from source)
set clipboard=unnamedplus

" Insert Ascii Text Headers
command! -nargs=* Header read !figlet -f starwars -k -w 60 -c <args>

" More intuitive movement
:noremap H ^
:noremap L $

noremap J 5j
noremap K 5k
noremap <C-j> 10j10<C-e>
noremap <C-k> 10k10<C-y>

" moar commands
:command! WQ wq
:command! Wq wq
:command! W w
:command! Q q
:command! Tabe tabe
:command! TAbe tabe
:command! TABe tabe
:command! TABE tabe

" tab navigation like firefox
:nnoremap <C-S-tab> :tabprevious<CR>
:nnoremap <C-tab>   :tabnext<CR>
:nnoremap <C-t>     :tabnew<CR>
:inoremap <C-S-tab> <Esc>:tabprevious<CR>i
:inoremap <C-tab>   <Esc>:tabnext<CR>i
:inoremap <C-t>     <Esc>:tabnew<CR>

