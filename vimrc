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
au BufRead,BufNewFile *.go setlocal noexpandtab
au BufNewFile,BufRead *.md set filetype=pandoc
au BufNewFile,BufRead *.coffee set filetype=coffeescript

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

" open file under cursor in vertical split
noremap <C-f> :vertical wincmd F<CR>

" pressing F2 enters paste mode
set pastetoggle=<F2>

" map F1 to escape
noremap <F1> <ESC>

" map <F3> to syntasticcheck
noremap <F3> :w<CR>:SyntasticCheck<CR>

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

" parens jump to next syntastic error
:nnoremap ( :lprev<CR>
:nnoremap ) :lnext<CR>

" autoload tag files
:set tags=./tags;
" jump backwards in the ctag stack
:nnoremap <C-p> <C-t>
" next/previous tag match
:nnoremap + :tnext<CR>
:nnoremap _ :tprevious<CR>

" disable preview split on autocomplete
:set completeopt-=preview

" fancy status line
:set statusline=%<%F\ %h%m%r%y%=%-14.(%l,%c%V%)\ %P

" search and hilight word under cursor
nnoremap * :keepjumps normal! mi*`i<CR>

" enter joins selected lines in visual mode
vnoremap <C-m> :join<CR>

" 120 character line limit python
highlight OverLength ctermbg=green ctermfg=white
autocmd FileType python 2match OverLength /\%>120v.\+/

" Press F4 to toggle highlighting on/off, and show current value.
:noremap <F4> :set hlsearch! hlsearch?<CR>

" highlight trailing whitespace
highlight ExtraWhitespace ctermbg=green guibg=green
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

" syntastic checkers
let g:syntastic_python_checkers = ['flake8']
let g:syntastic_go_checkers = ['go', 'gofmt']
let g:syntastic_coffeescript_checkers = ['coffeelint']
let g:syntastic_coffee_coffeelint_args = '~/repos/website/website/coffeelint.json'
let g:syntastic_html_tidy_ignore_errors=[" proprietary attribute \"ng-", "trimming empty"]
let g:syntastic_mode_map = {
      \ "mode": "active",
      \ "active_filetypes": [],
      \ "passive_filetypes": ["javac", "java"] }
let g:syntastic_always_populate_loc_list = 1

" pandoc auto formatting
let g:pandoc_use_hard_wraps = 1
let g:pandoc_use_conceal = 1
let g:tex_conceal = "adgm"
hi Conceal ctermbg=231 ctermfg=Black
hi pandocNewLine ctermbg=231 ctermfg=Black
let g:pandoc#modules#disabled = ["folding"]

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
Bundle 'scrooloose/syntastic'
Bundle 'hynek/vim-python-pep8-indent'
Bundle 'tpope/vim-fugitive'

filetype plugin on
filetype indent on
