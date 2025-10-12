" Adwaita (Light) Vim colorscheme
" Filename: adwaita.vim
" Author: ChatGPT (generated)
" A pragmatic approximation of GNOME Adwaita (light)
" Place in ~/.vim/colors/adwaita.vim or $XDG_CONFIG_HOME/nvim/colors/adwaita.vim
" License: MIT

set background=light
hi clear
if exists("syntax_on")
  syntax reset
endif
let g:colors_name = "adwaita"

" ===== Palette (hex) =====
" bg         #ffffff
" bg_alt     #f6f5f4
" fg         #2e3436
" fg_alt     #4a4f51
" blue       #1a73e8
" teal       #0aa4a1
" green      #2e7d32
" yellow     #b58900
" orange     #d8843e
" red        #c01c28
" magenta    #8e44ad
" purple     #6c4ea1
" gray       #9aa0a6
" comment    #8a8f98

" Helper to set group with gui/cterm
function! s:HL(group, guifg, guibg, attr, ctermfg, ctermbg, ctermattr) abort
  exec 'hi ' . a:group
        \ . (a:guifg != '' ? ' guifg=' . a:guifg : ' guifg=NONE')
        \ . (a:guibg != '' ? ' guibg=' . a:guibg : ' guibg=NONE')
        \ . (a:attr  != '' ? ' gui='   . a:attr  : ' gui=NONE')
        \ . (a:ctermfg != '' ? ' ctermfg=' . a:ctermfg : ' ctermfg=NONE')
        \ . (a:ctermbg != '' ? ' ctermbg=' . a:ctermbg : ' ctermbg=NONE')
        \ . (a:ctermattr != '' ? ' cterm=' . a:ctermattr : ' cterm=NONE')
endfunction

" Core UI
call s:HL('Normal',       '#2e3436', '#ffffff', '',        '235', '231', '')
call s:HL('CursorLine',   '',        '#f6f5f4', '',        '',    '255',  '')
call s:HL('CursorColumn', '',        '#f6f5f4', '',        '',    '255',  '')
call s:HL('ColorColumn',  '',        '#f6f5f4', '',        '',    '255',  '')
call s:HL('LineNr',       '#9aa0a6', '',        '',        '245', '',     '')
call s:HL('CursorLineNr', '#1a73e8', '',        'bold',    '33',  '',     'bold')
call s:HL('SignColumn',   '#2e3436', '#ffffff', '',        '235', '231',  '')
call s:HL('VertSplit',    '#e6e4e1', '#ffffff', '',        '252', '231',  '')
call s:HL('WinSeparator', '#e6e4e1', '#ffffff', '',        '252', '231',  '')

call s:HL('StatusLine',   '#2e3436', '#e6e4e1', 'NONE',    '235', '252',  'NONE')
call s:HL('StatusLineNC', '#4a4f51', '#f0efed', 'NONE',    '240', '254',  'NONE')
call s:HL('Pmenu',        '#2e3436', '#f0efed', 'NONE',    '235', '254',  'NONE')
call s:HL('PmenuSel',     '#ffffff', '#1a73e8', 'bold',    '231', '33',   'bold')
call s:HL('PmenuSbar',    '',        '#e6e4e1', '',        '',    '252',  '')
call s:HL('PmenuThumb',   '',        '#cfcfcf', '',        '',    '250',  '')

call s:HL('Visual',       '',        '#e6f0fe', '',        '',    '195',  '')
call s:HL('Search',       '#ffffff', '#1a73e8', 'NONE',    '231', '33',   'NONE')
call s:HL('IncSearch',    '#ffffff', '#0aa4a1', 'bold',    '231', '37',   'bold')
call s:HL('MatchParen',   '#c01c28', '#f6f5f4', 'bold',    '160', '255',  'bold')

call s:HL('Folded',       '#4a4f51', '#f6f5f4', '',        '240', '255',  '')
call s:HL('FoldColumn',   '#9aa0a6', '#ffffff', '',        '245', '231',  '')
call s:HL('Whitespace',   '#e6e4e1', '',        '',        '252', '',     '')

" Diagnostics
call s:HL('Error',        '#ffffff', '#c01c28', 'bold',    '231', '160',  'bold')
call s:HL('WarningMsg',   '#ffffff', '#b58900', 'bold',    '231', '136',  'bold')
call s:HL('ModeMsg',      '#2e3436', '#e6e4e1', 'bold',    '235', '252',  'bold')
call s:HL('MoreMsg',      '#2e7d32', '',        'bold',    '29',  '',     'bold')
call s:HL('Question',     '#1a73e8', '',        'bold',    '33',  '',     'bold')

" Syntax groups
call s:HL('Comment',      '#8a8f98', '',        'italic',  '246', '',     'NONE')
call s:HL('Identifier',   '#0aa4a1', '',        'NONE',    '37',  '',     'NONE')
call s:HL('Function',     '#1a73e8', '',        'NONE',    '33',  '',     'NONE')
call s:HL('Statement',    '#6c4ea1', '',        'NONE',    '61',  '',     'NONE')
call s:HL('Conditional',  '#6c4ea1', '',        'bold',    '61',  '',     'bold')
call s:HL('Repeat',       '#6c4ea1', '',        'bold',    '61',  '',     'bold')
call s:HL('Operator',     '#6c4ea1', '',        'NONE',    '61',  '',     'NONE')
call s:HL('Keyword',      '#8e44ad', '',        'bold',    '97',  '',     'bold')
call s:HL('Exception',    '#c01c28', '',        'bold',    '160', '',     'bold')

call s:HL('Constant',     '#b85700', '',        'NONE',    '172', '',     'NONE')
call s:HL('String',       '#2e7d32', '',        'NONE',    '29',  '',     'NONE')
call s:HL('Character',    '#2e7d32', '',        'NONE',    '29',  '',     'NONE')
call s:HL('Number',       '#b58900', '',        'NONE',    '136', '',     'NONE')
call s:HL('Boolean',      '#b58900', '',        'bold',    '136', '',     'bold')
call s:HL('Float',        '#b58900', '',        'NONE',    '136', '',     'NONE')

call s:HL('PreProc',      '#c01c28', '',        'NONE',    '160', '',     'NONE')
call s:HL('Include',      '#1a73e8', '',        'NONE',    '33',  '',     'NONE')
call s:HL('Define',       '#c01c28', '',        'NONE',    '160', '',     'NONE')
call s:HL('Macro',        '#c01c28', '',        'NONE',    '160', '',     'NONE')
call s:HL('PreCondit',    '#c01c28', '',        'NONE',    '160', '',     'NONE')

call s:HL('Type',         '#0b806a', '',        'NONE',    '29',  '',     'NONE')
call s:HL('StorageClass', '#0b806a', '',        'NONE',    '29',  '',     'NONE')
call s:HL('Structure',    '#0b806a', '',        'NONE',    '29',  '',     'NONE')
call s:HL('Typedef',      '#0b806a', '',        'NONE',    '29',  '',     'NONE')

call s:HL('Special',      '#d8843e', '',        'NONE',    '172', '',     'NONE')
call s:HL('Delimiter',    '#4a4f51', '',        'NONE',    '240', '',     'NONE')
call s:HL('SpecialComment','#8a8f98', '',       'italic',  '246', '',     'NONE')
call s:HL('Tag',          '#1a73e8', '',        'bold',    '33',  '',     'bold')

call s:HL('Todo',         '#ffffff', '#b58900', 'bold',    '231', '136',  'bold')
call s:HL('Underlined',   '#1a73e8', '',        'underline','33', '',     'underline')
call s:HL('ErrorMsg',     '#ffffff', '#c01c28', 'bold',    '231', '160',  'bold')
call s:HL('WarningMsg',   '#ffffff', '#b58900', 'bold',    '231', '136',  'bold')

" Treesitter common links (when available)
if has('nvim')
  hi link @comment               Comment
  hi link @string                String
  hi link @number                Number
  hi link @boolean               Boolean
  hi link @constant              Constant
  hi link @variable              Identifier
  hi link @function              Function
  hi link @method                Function
  hi link @keyword               Keyword
  hi link @type                  Type
  hi link @operator              Operator
  hi link @punctuation           Delimiter
  hi link @tag                   Tag
endif
