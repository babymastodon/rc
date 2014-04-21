" tabs are saved as spaces
set expandtab

" filepaths relative to the current file
set autochdir

" default tab widths
set bs=2
set tabstop=2
set shiftwidth=2

" smartindent only good for C
set nosmartindent
set autoindent

" specific tab widths
au FileType python setl sw=4 sts=4 et
au FileType mcs51a setl sw=3 sts=3 et

" custom file extensions
au BufNewFile,BufRead *.cpp set syntax=cpp11
au BufRead,BufNewFile *.go set filetype=go
au BufNewFile,BufRead *.md set filetype=pandoc

" all folds open by default
au BufRead * normal zR

" show netrw previews in vertically split window
let g:netrw_preview = 1

" Disable Ex Mode
:nnoremap Q <Nop>

" use the system clipboard as the default yank location
" (need to install vim from source)
silent! set clipboard^=unnamedplus
set clipboard^=unnamed

" pressing F2 enters paste mode
set pastetoggle=<F2>

" map F1 to escape
map <F1> <Esc>
imap <F1> <Esc>

" Insert Ascii Text Headers
command! -nargs=* Header read !figlet -f starwars -k -w 60 -c <args>

" show whitespace
nnoremap S :set list!<CR>

" write to file
nnoremap W :w<CR>

" reload buffer
nnoremap E :edit!<CR>

" More intuitive movement
noremap H 10h
noremap L 10l
noremap <C-h> ^
noremap <C-l> $

noremap J 5j
noremap K 5k
noremap <C-j> 15<C-e>
noremap <C-k> 15<C-y>

" Map open directory to ctrl-d
nnoremap <C-d> :e .<CR>

" Splits open on the right
set splitright

" moar commands
:command! WQ wq
:command! Wq wq
:command! W w
:command! Q q
:command! Tabe tabe
:command! TAbe tabe
:command! TABe tabe
:command! TABE tabe

" Ctrl-t opens a new tab
:nnoremap <C-t>     :tab split<CR>
:inoremap <C-t>     <Esc>:tab split<CR>

" autoload tag files
:set tags=./tags;
" jump backwards in the ctag stack
:nnoremap <C-p> <C-t>
" disable preview split on autocomplete
:set completeopt-=preview

" ctrl m joins selected lines in all modes
noremap <C-m> :join<CR>

" 80 character line limit python
highlight OverLength ctermbg=red ctermfg=white
autocmd FileType python 2match OverLength /\%>80v.\+/

" Press F4 to toggle highlighting on/off, and show current value.
:noremap <F4> :set hlsearch! hlsearch?<CR>

" highlight trailing whitespace
highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s\+$/
autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
autocmd InsertLeave * match ExtraWhitespace /\s\+$/
autocmd BufWinLeave * call clearmatches()

" fix bug in go-vim syntax file
let go_highlight_trailing_whitespace_error = 0

" default ycm compilation flags
let g:ycm_global_ycm_extra_conf = '~/.ycm_extra_conf.py'
" disable ycm autoconfirmation
let g:ycm_confirm_extra_conf = 0
" get identifiers from tag files
let g:ycm_collect_identifiers_from_tags_files = 1

" pandoc auto formatting
let g:pandoc_use_hard_wraps = 1
let g:pandoc_use_conceal = 1
let g:tex_conceal = "adgm"
hi Conceal ctermbg=231 ctermfg=Black

" enable cscope support
set cscopetag
set csto=1
set cscopeverbose
nnoremap <C-\>s :cs find s <C-R>=expand("<cword>")<CR><CR>
nnoremap <C-\>g :cs find g <C-R>=expand("<cword>")<CR><CR>
nnoremap <C-\>c :cs find c <C-R>=expand("<cword>")<CR><CR>
nnoremap <C-\>t :cs find t <C-R>=expand("<cword>")<CR><CR>
nnoremap <C-\>e :cs find e <C-R>=expand("<cword>")<CR><CR>
nnoremap <C-\>f :cs find f <C-R>=expand("<cfile>")<CR><CR>
nnoremap <C-\>i :cs find i ^<C-R>=expand("<cfile>")<CR>$<CR>
nnoremap <C-\>d :cs find d <C-R>=expand("<cword>")<CR><CR>
function! LoadCscope()
  let db = findfile("cscope.out", ".;")
  if (!empty(db))
    let path = strpart(db, 0, match(db, "/cscope.out$"))
    set nocscopeverbose " suppress 'duplicate connection' error
    exe "cs reset"
    exe "cs add " . db . " " . path
    set cscopeverbose
  endif
endfunction
au BufEnter /* call LoadCscope()


" configure multi-key timeouts
set timeoutlen=4000
set ttimeout
set ttimeoutlen=100


" Vundle packages
set nocompatible
filetype off
syntax on
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()


Bundle 'gmarik/vundle'
Bundle 'vim-pandoc/vim-pandoc'
Bundle 'jnwhiteh/vim-golang'
Bundle 'vim-scripts/Cpp11-Syntax-Support'
Bundle 'Valloric/YouCompleteMe'

filetype plugin on
filetype indent on
