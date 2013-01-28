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
