if exists("g:loaded_fit") || v:version < 800
    finish
endif
let g:loaded_fit = 1

if !exists('g:FitMatchCommand')
    call fit#utils#error('g:FitMatchCommand is not defined')
    finish
endif

call fit#utils#defineDefault('g:FitMaxHeight', 10)

command -nargs=* -complete=file FFiles call fit#files#open(<f-args>)
