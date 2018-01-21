if exists("g:loaded_fit") || v:version < 800
    finish
endif
let g:loaded_fit = 1

command -nargs=* -complete=file Files call s:files(<f-args>)

function! s:files(...)
    let directory = get(a:, 1, ".")
    call fit#files({"directory": directory})
endfunction
