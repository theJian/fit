if exists("g:fit_loaded")
    finish
endif
let g:fit_loaded = 1

lua require 'fit'
