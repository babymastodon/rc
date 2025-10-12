" Adwaita Dark Vim colorscheme
" Filename: adwaita_dark.vim
" Author: ChatGPT (generated)
" A pragmatic approximation of GNOME Adwaita (dark)
" Place in ~/.vim/colors/adwaita_dark.vim or $XDG_CONFIG_HOME/nvim/colors/adwaita_dark.vim
" License: MIT

set background=dark
hi clear
if exists("syntax_on")
  syntax reset
endif
let g:colors_name = "adwaita_dark"

" ===== Palette (hex) =====
" bg         #1e1e1e
" bg_alt     #242424
" fg         #e6e6e6
" fg_alt     #c7c7c7
" blue       #8ab4f8
" teal       #58c7c0
" green      #6abf69
" yellow     #f2c744
" orange     #f4a261
" red        #ff6b6b
" magenta    #c678dd
" purple     #b39df3
" gray       #8a8f98
" comment    #9aa0a6

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
call s:HL('Normal',       '#e6e6e6', '#1e1e1e', '',        '254', '234',  '')
call s:HL('CursorLine',   '',        '#242424', '',        '',    '235',  '')
call s:HL('CursorColumn', '',        '#242424', '',        '',    '235',  '')
call s:HL('ColorColumn',  '',        '#242424', '',        '',    '235',  '')
call s:HL('LineNr',       '#9aa0a6', '',        '',        '245', '',     '')
call s:HL('CursorLineNr', '#8ab4f8', '',        'bold',    '111', '',     'bold')
call s:HL('SignColumn',   '#e6e6e6', '#1e1e1e', '',        '254', '234',  '')
call s:HL('VertSplit',    '#2a2a2a', '#1e1e1e', '',        '236', '234',  '')
call s:HL('WinSeparator', '#2a2a2a', '#1e1e1e', '',        '236', '234',  '')

call s:HL('StatusLine',   '#e6e6e6', '#2a2a2a', 'NONE',    '254', '236',  'NONE')
call s:HL('StatusLineNC', '#c7c7c7', '#232323', 'NONE',    '251', '235',  'NONE')
call s:HL('Pmenu',        '#e6e6e6', '#2a2a2a', 'NONE',    '254', '236',  'NONE')
call s:HL('PmenuSel',     '#1e1e1e', '#8ab4f8', 'bold',    '234', '111',  'bold')
call s:HL('PmenuSbar',    '',        '#2f2f2f', '',        '',    '236',  '')
call s:HL('PmenuThumb',   '',        '#3a3a3a', '',        '',    '237',  '')

call s:HL('Visual',       '',        '#334155', '',        '',    '238',  '')
call s:HL('Search',       '#1e1e1e', '#8ab4f8', 'NONE',    '234', '111',  'NONE')
call s:HL('IncSearch',    '#1e1e1e', '#58c7c0', 'bold',    '234', '79',   'bold')
call s:HL('MatchParen',   '#ff6b6b', '#242424', 'bold',    '203', '235',  'bold')

call s:HL('Folded',       '#c7c7c7', '#242424', '',        '251', '235',  '')
call s:HL('FoldColumn',   '#9aa0a6', '#1e1e1e', '',        '245', '234',  '')
call s:HL('Whitespace',   '#2a2a2a', '',        '',        '236', '',     '')

" Diagnostics / messages
call s:HL('Error',        '#1e1e1e', '#ff6b6b', 'bold',    '234', '203',  'bold')
call s:HL('WarningMsg',   '#1e1e1e', '#f2c744', 'bold',    '234', '221',  'bold')
call s:HL('ModeMsg',      '#e6e6e6', '#2a2a2a', 'bold',    '254', '236',  'bold')
call s:HL('MoreMsg',      '#6abf69', '',        'bold',    '71',  '',     'bold')
call s:HL('Question',     '#8ab4f8', '',        'bold',    '111', '',     'bold')

" Syntax groups
call s:HL('Comment',      '#9aa0a6', '',        'italic',  '245', '',     'NONE')
call s:HL('Identifier',   '#58c7c0', '',        'NONE',    '79',  '',     'NONE')
call s:HL('Function',     '#8ab4f8', '',        'NONE',    '111', '',     'NONE')
call s:HL('Statement',    '#b39df3', '',        'NONE',    '141', '',     'NONE')
call s:HL('Conditional',  '#b39df3', '',        'bold',    '141', '',     'bold')
call s:HL('Repeat',       '#b39df3', '',        'bold',    '141', '',     'bold')
call s:HL('Operator',     '#b39df3', '',        'NONE',    '141', '',     'NONE')
call s:HL('Keyword',      '#c678dd', '',        'bold',    '176', '',     'bold')
call s:HL('Exception',    '#ff6b6b', '',        'bold',    '203', '',     'bold')

call s:HL('Constant',     '#f4a261', '',        'NONE',    '215', '',     'NONE')
call s:HL('String',       '#6abf69', '',        'NONE',    '71',  '',     'NONE')
call s:HL('Character',    '#6abf69', '',        'NONE',    '71',  '',     'NONE')
call s:HL('Number',       '#f2c744', '',        'NONE',    '221', '',     'NONE')
call s:HL('Boolean',      '#f2c744', '',        'bold',    '221', '',     'bold')
call s:HL('Float',        '#f2c744', '',        'NONE',    '221', '',     'NONE')

call s:HL('PreProc',      '#ff6b6b', '',        'NONE',    '203', '',     'NONE')
call s:HL('Include',      '#8ab4f8', '',        'NONE',    '111', '',     'NONE')
call s:HL('Define',       '#ff6b6b', '',        'NONE',    '203', '',     'NONE')
call s:HL('Macro',        '#ff6b6b', '',        'NONE',    '203', '',     'NONE')
call s:HL('PreCondit',    '#ff6b6b', '',        'NONE',    '203', '',     'NONE')

call s:HL('Type',         '#58c7c0', '',        'NONE',    '79',  '',     'NONE')
call s:HL('StorageClass', '#58c7c0', '',        'NONE',    '79',  '',     'NONE')
call s:HL('Structure',    '#58c7c0', '',        'NONE',    '79',  '',     'NONE')
call s:HL('Typedef',      '#58c7c0', '',        'NONE',    '79',  '',     'NONE')

call s:HL('Special',      '#f4a261', '',        'NONE',    '215', '',     'NONE')
call s:HL('Delimiter',    '#c7c7c7', '',        'NONE',    '251', '',     'NONE')
call s:HL('SpecialComment','#9aa0a6', '',       'italic',  '245', '',     'NONE')
call s:HL('Tag',          '#8ab4f8', '',        'bold',    '111', '',     'bold')

call s:HL('Todo',         '#1e1e1e', '#f2c744', 'bold',    '234', '221',  'bold')
call s:HL('Underlined',   '#8ab4f8', '',        'underline','111','',     'underline')
call s:HL('ErrorMsg',     '#1e1e1e', '#ff6b6b', 'bold',    '234', '203',  'bold')
call s:HL('WarningMsg',   '#1e1e1e', '#f2c744', 'bold',    '234', '221',  'bold')

" Treesitter common links
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
