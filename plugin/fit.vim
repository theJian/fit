if exists("g:fit_loaded")
    finish
endif
let g:fit_loaded = 1

" if !exists('g:FitMatchCommand')
"     call fit#utils#error('g:FitMatchCommand is not defined')
"     finish
" endif

" call fit#utils#defineDefault('g:FitMaxHeight', 10)

" command -nargs=* -complete=file FFiles call fit#files#open(<f-args>)

lua require 'fit'
