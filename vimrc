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
au BufNewFile,BufRead *.coffee set filetype=coffee
au BufNewFile,BufRead *.ql set filetype=sql
au BufNewFile,BufRead *.templ set filetype=perl
au BufNewFile,BufRead *.dash set filetype=perl
au BufNewFile,BufRead *.alert set filetype=perl

" default fold level to syntax
" set foldmethod=syntax
" set foldlevelstart=10

" all folds open by default
autocmd BufWinEnter * let &foldlevel = max(map(range(1, line('$')), 'foldlevel(v:val)'))

" show netrw previews in vertically split window
let g:netrw_preview = 1

" Disable Ex Mode
:nnoremap Q <Nop>

" open file under cursor in vertical split
noremap gf :vertical wincmd F<CR>

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

" go to first syntastic error
:nnoremap ; :lfirst<CR>

" tagbar
nnoremap <F9> :TagbarToggle<CR>

" quickfix and loclist
let g:lt_location_list_toggle_map = '<leader>l'
let g:lt_quickfix_list_toggle_map = '<leader>q'
let g:lt_height = 10
noremap - :cprev<CR>
noremap = :cnext<CR>

" resize
nnoremap + :exe "resize " . (winheight(0) * 3/2)<CR>
nnoremap _ :exe "resize " . (winheight(0) * 2/3)<CR>

" go to next tag match
noremap ) :tn<CR>
noremap ( :tp<CR>

" autoload tag files
:set tags=./tags;
" jump backwards in the ctag stack
:nnoremap <C-p> <C-t>
" next/previous tag match
" NOTE: replaced with quicklist navigation
" :nnoremap + :tnext<CR>
" :nnoremap _ :tprevious<CR>

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
noremap <F4> :set hlsearch! hlsearch?<CR>
set hlsearch

" Press & to switch between two related files
au FileType cpp nnoremap & :e %:p:s,.h$,.X123X,:s,.cpp$,.h,:s,.X123X$,.cpp,<CR>
au FileType html nnoremap & :e %<.js<CR>
au FileType javascript nnoremap & :e %<.html<CR>
au FileType go nnoremap & :e %:p:s,\([^_][^t][^e][^s][^t]\).go$,\1.X123X,:s,_test.go$,.go,:s,.X123X$,_test.go,<CR>

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
" use ycm's goto def, instead of vim's default
nnoremap gd :YcmCompleter GoTo<CR>
nnoremap gl :YcmCompleter FixIt<CR>

" syntastic checkers
let g:syntastic_python_checkers = ['python']
let g:syntastic_coffee_checkers = ['coffeelint', 'coffee']
let g:syntastic_html_tidy_ignore_errors=[" proprietary attribute \"ng-", "trimming empty"]
let g:syntastic_mode_map = { "mode": "active", "active_filetypes": [], "passive_filetypes": ["javac", "java"] }
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_javascript_checkers = ['jshint']
let g:syntastic_always_populate_loc_list=1
let g:syntastic_auto_loc_list = 0

" pandoc auto formatting
let g:pandoc_use_hard_wraps = 1
let g:pandoc_use_conceal = 1
let g:tex_conceal = "adgm"
hi Conceal ctermbg=231 ctermfg=Black
hi pandocNewLine ctermbg=231 ctermfg=Black
let g:pandoc#modules#disabled = ["folding"]

let g:go_fmt_experimental = 1
let g:go_fmt_fail_silently = 1
let g:go_doc_keywordprg_enabled = 0
let g:go_bin_path = expand("~/bin")
let g:go_oracle_include_tests = 1
let g:go_fmt_command = "goimports"

let g:ctrlp_map = '<C-n>'
let g:ctrlp_extensions = ['tag', 'dir']
let g:ctrlp_max_files=0
let g:ctrlp_max_depth=40
let g:ctrlp_switch_buffer=0

" enable cscope support
set nocscopetag
set csto=1
set cscopeverbose
set cscopequickfix=s-,c-,d-,i-,t-,e-
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

" find and replace all occurances of the word under the cursor
nnoremap gs :%s/\<<C-r><C-w>\>//g<Left><Left>

" sort the selection
xnoremap s '<,'>sort<CR>

" ctrp plugin
let g:ctrlp_map = '<C-f>'

" grep shortcuts
command! -nargs=+ Gr execute 'silent Ggrep!' <q-args> | silent! botright cwindow 15 | cc | redraw! | let @/=<q-args> | set hls
nnoremap gr :Gr <C-R>=expand("<cword>")<CR><CR>

" Rename tabs to show tab number.
" (Based on http://stackoverflow.com/questions/5927952/whats-implementation-of-vims-default-tabline-function)
if exists("+showtabline")
    function! MyTabLine()
        let s = ''
        let wn = ''
        let t = tabpagenr()
        let i = 1
        while i <= tabpagenr('$')
            let buflist = tabpagebuflist(i)
            let winnr = tabpagewinnr(i)
            let s .= '%' . i . 'T'
            let s .= (i == t ? '%1*' : '%2*')
            let s .= ' '
            let wn = tabpagewinnr(i,'$')

            let s .= '%#TabNum#'
            let s .= i
            " let s .= '%*'
            let s .= (i == t ? '%#TabLineSel#' : '%#TabLine#')
            let bufnr = buflist[winnr - 1]
            let file = bufname(bufnr)
            let buftype = getbufvar(bufnr, 'buftype')
            if buftype == 'nofile'
                if file =~ '\/.'
                    let file = substitute(file, '.*\/\ze.', '', '')
                endif
            else
                let file = fnamemodify(file, ':p:t')
            endif
            if file == ''
                let file = '[No Name]'
            endif
            let s .= ' ' . file . ' '
            let i = i + 1
        endwhile
        let s .= '%T%#TabLineFill#%='
        let s .= (tabpagenr('$') > 1 ? '%999XX' : 'X')
        return s
    endfunction
    set stal=2
    set tabline=%!MyTabLine()
    set showtabline=1
    highlight link TabNum Special
endif

let g:clang_format#style_options = {
    \ "BinPackArguments" : "false",
    \ "BinPackParameters" : "false",
    \ "CommentPragmas" : ".*\\$",
    \ "Language" : "Cpp",
    \ "Standard" : "C++11"}
au BufWrite *.{cc,cpp,h} :ClangFormat

" Toggle checkboxes
fu! ToggleCB()
	let line = getline('.')

	if(match(line, "\\[ \\]") != -1)
		let line = substitute(line, "\\[ \\]", "[x]", "")
	elseif(match(line, "\\[x\\]") != -1)
		let line = substitute(line, "\\[x\\]", "[ ]", "")
	endif

	call setline('.', line)
endf

command! ToggleCB call checkbox#ToggleCB()

nnoremap <silent> gk :ToggleCB<cr>

" CSV files
hi CSVColumnEven term=bold ctermbg=Black ctermfg=White
hi CSVColumnOdd  term=bold ctermbg=Grey ctermfg=Black

" Vundle packages
set nocompatible
filetype off
syntax on
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

Bundle 'gmarik/vundle'
Bundle 'vim-pandoc/vim-pandoc'
Bundle 'jnwhiteh/vim-golang'
Bundle 'vim-scripts/Cpp11-Syntax-Support'
Bundle 'Valloric/YouCompleteMe'
Bundle 'scrooloose/syntastic'
Bundle 'hynek/vim-python-pep8-indent'
Bundle 'tpope/vim-fugitive'
Bundle "pangloss/vim-javascript"
Bundle 'solarnz/thrift.vim'
Bundle 'fatih/vim-go'
Bundle 'majutsushi/tagbar'
Bundle 'yegappan/greplace'
Bundle 'rodjek/vim-puppet'
Bundle 'Valloric/ListToggle'
Bundle 'rhysd/vim-clang-format'
Bundle 'chrisbra/csv.vim'
Bundle 'vhdirk/vim-cmake'
Bundle 'ctrlpvim/ctrlp.vim'

call vundle#end()
filetype plugin on
filetype indent on
