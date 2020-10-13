if exists("g:fit_loaded") | finish | endif
let g:fit_loaded = 1

hi def link FitNormal Normal
hi def FitCursor cterm=reverse gui=reverse
hi def FitSel    cterm=reverse gui=reverse
