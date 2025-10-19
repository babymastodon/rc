" tabs are saved as spaces
set expandtab

" let netrw manage cwd
set noautochdir
let g:netrw_keepdir = 0

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

" stick to the color pallette
set notermguicolors     " disable truecolor
set t_Co=16             " tell Vim we only have 16 colors

" enable vimrc line extensions
set nocompatible

" default fold level to syntax
" set foldmethod=syntax
" set foldlevelstart=10

" all folds open by default
autocmd BufWinEnter * let &foldlevel = max(map(range(1, line('$')), 'foldlevel(v:val)'))

" enable mouse
set mouse=a

" show netrw previews in vertically split window
let g:netrw_preview = 1

" Disable Ex Mode
:nnoremap Q <Nop>

" open file under cursor in vertical split
noremap gf :vertical wincmd F<CR>

" enable spellcheck
" set spell spelllang=en_us

" pressing F2 enters paste mode
set pastetoggle=<F2>

" map <F3> to YCMHover to show type information
noremap <F3> <plug>(YCMHover)
let g:ycm_auto_hover = ''

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

" Files should be UTF-8 by default
set encoding=utf-8

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

" tagbar
nnoremap <F9> :TagbarToggle<CR>
let g:tagbar_width = 80
let g:tagbar_type_go = {
  \ 'ctagstype' : 'go',
  \ 'kinds'     : [
    \ 'p:package',
    \ 'i:imports:1',
    \ 'c:constants',
    \ 'v:variables',
    \ 't:types',
    \ 'n:interfaces',
    \ 'w:fields',
    \ 'e:embedded',
    \ 'm:methods',
    \ 'r:constructor',
    \ 'f:functions'
  \ ],
  \ 'sro' : '.',
  \ 'kind2scope' : {
    \ 't' : 'ctype',
    \ 'n' : 'ntype'
  \ },
  \ 'scope2kind' : {
    \ 'ctype' : 't',
    \ 'ntype' : 'n'
  \ },
  \ 'ctagsbin'  : 'gotags',
  \ 'ctagsargs' : '-sort -silent'
\ }

" format json
nnoremap gj :%!python -m json.tool<CR>

" python with virtualenv support
" Virtualenv needs to be active when opening vim
" py3 << EOF
" import os
" import sys
" if 'VIRTUAL_ENV' in os.environ:
"   project_base_dir = os.environ['VIRTUAL_ENV']
"   activate_this = os.path.join(project_base_dir, 'bin/activate_this.py')
"   exec(open(activate_this).read(), {'__file__': activate_this})
" EOF

" enable python highlighting
let python_highlight_all=1

" quickfix and loclist
let g:lt_location_list_toggle_map = '<leader>l'
let g:lt_quickfix_list_toggle_map = '<leader>q'
let g:lt_height = 10
noremap - :cprev<CR>
noremap = :cnext<CR>

" go to first linter error, and iterate through the errors
:nnoremap ; :lfirst<CR>
:nnoremap + :lnext<CR>
:nnoremap _ :lprev<CR>

" resize
" nnoremap + :exe "resize " . (winheight(0) * 3/2)<CR>
" nnoremap _ :exe "resize " . (winheight(0) * 2/3)<CR>

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

" search and hilight word under cursor
nnoremap * :keepjumps normal! mi*`i<CR>

" enter joins selected lines in visual mode
vnoremap <C-m> :join<CR>

" 120 character line limit python
highlight OverLength ctermbg=green ctermfg=white
autocmd FileType python 2match OverLength /\%>120v.\+/

" Press F5 to toggle highlighting on/off, and show current value.
noremap <F5> :set hlsearch! hlsearch?<CR>
set hlsearch
set incsearch

" Press & to switch between two related files
au FileType cpp nnoremap & :e %:p:s,.h$,.X123X,:s,.cpp$,.h,:s,.X123X$,.cpp,<CR>
au FileType html nnoremap & :e %<.js<CR>
au FileType javascript nnoremap & :e %<.html<CR>
au FileType go nnoremap & :e %:p:s,\([^_][^t][^e][^s][^t]\).go$,\1.X123X,:s,_test.go$,.go,:s,.X123X$,_test.go,<CR>

" highlight trailing whitespace
highlight ExtraWhitespace ctermbg=green ctermbg=green
match ExtraWhitespace /\s\+$/
autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
autocmd InsertLeave * match ExtraWhitespace /\s\+$/
autocmd BufWinLeave * call clearmatches()

" reset the tmux status line
augroup TmuxGitBadgeCleanup
  autocmd!
  autocmd BufWritePost * silent! call system('rm -f /tmp/tmux-git-badge.*')
augroup END

" fix bug in go-vim syntax file
let go_highlight_trailing_whitespace_error = 0

" default ycm compilation flags
let g:ycm_global_ycm_extra_conf = '~/.ycm_extra_conf.py'
" disable ycm autoconfirmation
let g:ycm_confirm_extra_conf = 0
" get identifiers from tag files
let g:ycm_collect_identifiers_from_tags_files = 1
let ycm_auto_trigger = 1
" use ycm's goto def, instead of vim's default
nnoremap gd :YcmCompleter GoTo<CR>
nnoremap gl :YcmCompleter FixIt<CR>

" ale linters
let g:ale_linters = {
\  'python': ['flake8', 'pyright']
\}
let g:ale_fixers = {
\  'python': [
\    'autopep8',
\    'autoflake',
\    'isort',
\    'remove_trailing_lines',
\    'trim_whitespace',
\    'yapf'
\  ]
\}
let g:ale_python_autopep8_options = '--ignore F811,W503,W504,E731,E125'
let g:ale_python_autoflake_options= '--ignore-init-module-imports --remove-all-unused-imports --ignore-pass-after-docstring'
let g:ale_fix_on_save = 1
nnoremap ' :ALEImport<CR>
nnoremap " :ALEFix<CR>
nnoremap <F4> :ALEStopAllLSPs<CR>:YcmRestartServer<CR>

let g:go_fmt_experimental = 1
let g:go_fmt_fail_silently = 1
let g:go_doc_keywordprg_enabled = 0
let g:go_bin_path = expand("~/bin")
let g:go_oracle_include_tests = 1
let g:go_fmt_command = "goimports"
let g:go_def_mode = "godef"
let g:go_def_mapping_enabled=0

let g:ctrlp_map = '<C-n>'
let g:ctrlp_extensions = ['tag', 'dir']
let g:ctrlp_max_files=0
let g:ctrlp_max_depth=40
let g:ctrlp_regexp = 1
let g:ctrlp_switch_buffer=0
let g:ctrlp_user_command = { 'types': { 1: ['.git', 'cd %s && git ls-files'], 2: ['.hg', 'hg --cwd %s locate -I .'], }, 'fallback': 'find %s -type f' }

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
xnoremap s :'<,'>sort<CR>

" ctrp plugin
let g:ctrlp_map = '<C-f>'

" grep shortcuts
command! -nargs=+ Gr execute 'silent Ggrep!' <q-args> | silent! botright cwindow 15 | cc | redraw! | let @/=<q-args> | set hls
nnoremap gr :Gr <C-R>=expand("<cword>")<CR><CR>

function! MyTabLine()
  let s = ''
  let t = tabpagenr()

  for i in range(1, tabpagenr('$'))
    let s .= '%' . i . 'T'

    " get buffer name
    let buflist = tabpagebuflist(i)
    let winnr  = tabpagewinnr(i)
    let bufnr  = buflist[winnr - 1]
    let file   = bufname(bufnr)
    let buftype = getbufvar(bufnr, 'buftype')

    if buftype ==# 'nofile'
      if file =~ '\/.'
        let file = substitute(file, '.*\/\ze.', '', '')
      endif
    else
      let file = fnamemodify(file, ':t')
    endif
    if empty(file)
      let file = '[No Name]'
    endif

    let mod = getbufvar(bufnr, '&modified') ? ' •' : ''

    " highlight + edges
    if i == t

      let s .= '%#TabCap#%#TabLineSel#' . i . ' ' . file . mod . '%#TabCap#%#TabLine# '
    else
      if getbufvar(bufnr, '&modified')

        let s .= '%#TabCapMod#%#TabLineMod#' . i . ' ' . file . mod . '%#TabCapMod#%#TabLine# '
      else
        let s .= '%#TabLine# ' . i . ' ' . file . mod . '  '
      endif
    endif
  endfor

  " fill + close button
  let s .= '%#TabLineFill#%T%='
  let s .= (tabpagenr('$') > 1 ? '%999X✕' : '✕')
  return s
endfunction


let g:clang_format#style_options = { "BinPackArguments" : "false", "BinPackParameters" : "false", "CommentPragmas" : ".*\\$", "Language" : "Cpp", "Standard" : "C++11"}
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
" let g:csv_autocmd_arrange	   = 1
" let g:csv_autocmd_arrange_size = 1024*1024
let g:csv_highlight_column = 'y'

" Python document generation
" To install: ~/.vim/bundle/vim-pydocstring/lib/install.sh ~/.vim/bundle/vim-pydocstring/lib/install.sh
let g:pydocstring_formatter = 'google'
let g:pydocstring_enable_mapping = '0'
nnoremap <F10> :Pydocstring<CR>

" Git shortcuts
" :Gdiff should show side-by-side
set diffopt=vertical
:command! Diff Gdiff master
hi DiffAdd cterm=NONE ctermfg=NONE ctermbg=194
hi DiffChange cterm=NONE ctermfg=NONE ctermbg=231
hi DiffText cterm=NONE ctermfg=NONE ctermbg=189
hi DiffDelete cterm=NONE ctermfg=NONE ctermbg=224

" :Rc should open vimrc
:command! Rc :edit! ~/.vimrc
:command! Src :source ~/.vimrc

" Packages
call plug#begin('~/.vim/plugged')

Plug 'jnwhiteh/vim-golang'
Plug 'vim-scripts/Cpp11-Syntax-Support'
Plug 'nvie/vim-flake8'
Plug 'hynek/vim-python-pep8-indent'
Plug 'tpope/vim-fugitive'
Plug 'pangloss/vim-javascript'
Plug 'fatih/vim-go'
Plug 'majutsushi/tagbar'
Plug 'Valloric/ListToggle'
Plug 'chrisbra/csv.vim'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'powerman/vim-plugin-AnsiEsc'
Plug 'dense-analysis/ale'
Plug 'ycm-core/YouCompleteMe'
Plug 'heavenshell/vim-pydocstring'
Plug 'rhysd/conflict-marker.vim'
Plug 'pedrohdz/vim-yaml-folds'
Plug 'sheerun/vim-polyglot'

call plug#end()

" Filetype settings
filetype plugin indent on
syntax on

" custom colors
colorscheme default
highlight Comment                      ctermfg=8
highlight TabLine      cterm=underline ctermfg=7  ctermbg=NONE
highlight TabLineSel   cterm=NONE      ctermfg=0  ctermbg=2
highlight TabLineFill  cterm=underline ctermfg=7  ctermbg=NONE
highlight TabCap       cterm=NONE      ctermfg=2  ctermbg=NONE
highlight TabLineMod   cterm=NONE      ctermfg=15 ctermbg=8
highlight TabCapMod    cterm=NONE      ctermfg=8  ctermbg=NONE
highlight StatusLine   cterm=underline,bold ctermfg=2  ctermbg=None
highlight StatusCap    cterm=underline ctermfg=2  ctermbg=0
highlight StatusLineNC cterm=underline ctermfg=7  ctermbg=NONE
highlight VertSplit    cterm=NONE      ctermfg=7  ctermbg=NONE
highlight Search       cterm=NONE      ctermfg=0  ctermbg=3
highlight IncSearch    cterm=NONE      ctermfg=0  ctermbg=3
set fillchars=vert:│

" fancy tab bar
set stal=2
set tabline=%!MyTabLine()
set showtabline=1

" fancy status line
function! StatusLineFunc()
  if win_getid() == g:statusline_winid
    return '%<%F %h%m%r%y %= %-14.(%l,%c%V %) %P'
  else
    return '%<%F %h%m%r%y %= %-14.(%l,%c%V %) %P'
  endif
endfunction
set fillchars+=stl:┈,stlnc:\ 
set statusline=%!StatusLineFunc()
