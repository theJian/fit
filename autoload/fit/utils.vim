function! fit#utils#defineDefault(name, default)
    if !exists(a:name)
        let {a:name} = a:default
    endif
endfunction

function! fit#utils#error(errorMsg)
    echoerr '[fit] ' . a:errorMsg
endfunction

function! fit#utils#openFile(path, command)
    execute a:command . ' ' . fnameescape(fnamemodify(a:path, ':~:.'))
endfunction
