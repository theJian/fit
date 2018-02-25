let s:handler = {
    \"prompt": "Files>>",
    \"candidates": [],
    \}

function! fit#files#open(...) abort
    let directory = get(a:, 1, getcwd())

    if !isdirectory(fnamemodify(directory, ":p"))
        return fit#utils#error(printf("%s No such directory", directory))
    endif

    if !exists('g:FitFilesFindCommand')
        return fit#utils#error('g:FitFilesFindCommand is not defined')
    endif

    if type(g:FitFilesFindCommand) != type("")
        return fit#utils#error('Expected g:FitFilesFindCommand to be a string')
    endif

    let findCommand = s:getFindCommand(directory)
    let s:handler.candidates = systemlist(findCommand)

    call fit#open(s:handler)
endfunction

function! s:getFindCommand(directory)
    let findCommand = substitute(g:FitFilesFindCommand, "<dir>", a:directory, "g")

    " remove ./ at the beginning of the line
    let findCommand .= ' | sed "s|^\./||"'

    return findCommand
endfunction
