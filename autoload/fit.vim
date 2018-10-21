let s:BUFFER_NAME = "[fit]"

let s:DEFAULT_OPTIONS = {}

let s:OPTIONS = {
    \ 'timeout':       1,
    \ 'timeoutlen':    0,
    \ 'hlsearch':      0,
    \ 'insertmode':    0,
    \ 'showcmd':       0,
    \ 'report':        9999,
    \ 'sidescroll':    0,
    \ 'sidescrolloff': 0,
    \ 'equalalways':   0,
    \ 'shellslash':    1,
    \ }

let s:DEFAULT_KEY_BINDINGS = {
    \ 'selectNext':    ['fit#selectNext', '<C-n>', '<C-j>'],
    \ 'selectPrev':    ['fit#selectPrev', '<C-p>', '<C-k>'],
    \ 'acceptSplit':   ['fit#acceptSplit', '<C-s>'],
    \ 'acceptVsplit':  ['fit#acceptVsplit', '<C-v>'],
    \ 'acceptTab':     ['fit#acceptTab', '<C-t>'],
    \ 'accept':        ['fit#accept', '<CR>'],
    \ 'backspace':     ['fit#backspace', '<BS>'],
    \ 'backspaceWord': ['fit#backspaceWord', '<C-w>'],
    \ 'cancel':        ['fit#cancel', '<C-c>'],
    \ 'clear':         ['fit#clear', '<C-u>'],
    \ 'cursorLeft':    ['fit#cursorLeft', '<Left>', '<C-h>'],
    \ 'cursorRight':   ['fit#cursorRight', '<Right>', '<C-l>'],
    \ 'cursorStart':   ['fit#cursorStart', '<C-a>', '<home>'],
    \ 'cursorEnd':     ['fit#cursorEnd', '<C-e>', '<end>'],
    \ 'delete':        ['fit#delete', '<Del>', '<C-d>'],
    \ }

function! fit#selectPrev()
    normal! k
endfunction

function! fit#selectNext()
    normal! j
endfunction

function! fit#delete()
    if b:pos < len(b:input)
        let [left, cursor, right] = s:splitInput()
        let b:input = left . right
        call s:renderPrompt()
        call s:onInputChange()
    endif
endfunction

function! fit#cursorStart()
    let b:pos = 0
    call s:renderPrompt()
endfunction

function! fit#cursorEnd()
    let b:pos = len(b:input)
    call s:renderPrompt()
endfunction

function! fit#cursorRight()
    if b:pos < len(b:input)
        let b:pos += 1
        call s:renderPrompt()
    endif
endfunction

function! fit#cursorLeft()
    if b:pos > 0
        let b:pos -= 1
        call s:renderPrompt()
    endif
endfunction

function! fit#clear()
    let b:input = ''
    let b:pos = 0
    call s:renderPrompt()
    call s:onInputChange()
endfunction

function! fit#backspaceWord()
    if b:pos == 0 || b:input == ''
        return
    endif

    let [left, cursor, right] = s:splitInput()
    let nextLeft = substitute(left, "\\S*\\s*$", "", "")
    let b:input = nextLeft . cursor . right
    let b:pos = len(nextLeft)
    call s:renderPrompt()
    call s:onInputChange()
endfunction

function! fit#backspace()
    if b:pos == 0 || b:input == ''
        return
    endif

    let [left, cursor, right] = s:splitInput()
    let b:input = left[0 : -2] . cursor . right
    let b:pos -= 1
    call s:renderPrompt()
    call s:onInputChange()
endfunction

function! fit#cancel()
    call s:restoreOptions()

    " close window
    let bufNr = bufnr("%")
    let restCmd = b:restCmd
    execute "silent! close!"
    execute "silent! bdelete! " . bufNr
    execute restCmd

    redraw
    echo
endfunction

function! s:getSelection()
    let lnum = getcurpos()[1]
    return get(b:matches, lnum - 1)
endfunction

function! fit#acceptSplit()
    call fit#accept('split')
endfunction

function! fit#acceptVsplit()
    call fit#accept('vsplit')
endfunction

function! fit#acceptTab()
    call fit#accept('tabedit')
endfunction

function! fit#accept(...)
    if b:matchesAmount == 0
        return
    endif

    let command = get(a:, 1, 'edit')
    let selection = s:getSelection()

    call fit#cancel()
    call fit#utils#openFile(selection, command)
endfunction

function! s:getMatchCommand(query)
    return substitute(g:FitMatchCommand, "<query>", shellescape(a:query), "g")
endfunction

function! s:getMatches(items, query) abort
    let matchCommand = s:getMatchCommand(a:query)
    return systemlist(matchCommand, a:items)
endfunction

function! fit#redraw(timer)
    let b:matches = s:getMatches(b:candidates, b:input)
    let b:matchesAmount = len(b:matches)
    let height = min([len(b:matches), g:FitMaxHeight])

    silent! %delete
    execute printf('resize %d', height)
    call setline(1, b:matches)
endfunction

function! s:onInputChange()
    if b:timerId != -1
        call timer_stop(b:timerId)
    endif
    let b:timerId = timer_start(0, "fit#redraw")
endfunction

function! s:createBuffer(...)
    let restCmd = printf("%iwincmd w|%s", winnr(), winrestcmd())
    execute printf("silent! keepalt botright 1split %s", s:BUFFER_NAME)

    let options = get(a:, 1, {})
    let b:input = ''
    let b:pos = 0
    let b:prompt = get(options, 'prompt', '>>')
    let b:candidates = get(options, 'candidates', [])
    let b:restCmd = restCmd
    let b:timerId = -1

    call s:setLocalOptions()
endfunction

function! s:setLocalOptions()
    setlocal bufhidden=unload " unload buf when no longer displayed
    setlocal buftype=nofile   " buffer is not related to any file
    setlocal noswapfile       " don't create a swapfile
    setlocal nowrap           " don't soft-wrap
    setlocal nonumber         " don't show line numbers
    setlocal norelativenumber " don't show line numbers
    setlocal nolist           " don't use List mode (visible tabs etc)
    setlocal foldcolumn=0     " don't show a fold column at side
    setlocal foldlevel=99     " don't fold anything
    setlocal cursorline       " highlight line cursor is on
    setlocal nospell          " spell-checking off
    setlocal nobuflisted      " don't show up in the buffer list
    setlocal textwidth=0      " don't hard-wrap (break long lines)
    setlocal nomore           " don't pause when the command-line overflows
    setlocal colorcolumn=0    " turn off column highlight
    setlocal nocursorcolumn   " turn off cursor column
    setlocal signcolumn=no
endfunction

function! s:setOptions()
    for [opt, val] in items(s:OPTIONS)
        let s:DEFAULT_OPTIONS[opt] = getbufvar("%", "&" . opt)
        call setbufvar("%", "&" . opt, val)
    endfor
endfunction

function! s:restoreOptions()
    for [opt, val] in items(s:DEFAULT_OPTIONS)
        call setbufvar("%", "&" . opt, val)
    endfor
endfunction

function! fit#handleBasicKey(key)
    let [left, cursor, right] = s:splitInput()
    let b:input = left . a:key . cursor . right
    let b:pos += 1
    call s:renderPrompt()
    call s:onInputChange()
endfunction

function! s:mapKey(key, handler, ...)
    let arglist = join(a:000, ", ")
    execute printf("noremap <silent> <buffer> <nowait> %s :call %s(%s)<cr>", a:key, a:handler, arglist)
endfunction

function! s:defineMappings()
    " Basic keys
    let lowercase = 'abcdefghijklmnopqrstuvwxyz'
    let uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    let numbers = '0123456789'
    let punctuation = "<>`@#~!\"$%^&/()=+*-_.,;:?\\\'{}[] " " and space
    for str in [lowercase, uppercase, numbers, punctuation]
        for key in split(str, '\zs')
            call s:mapKey(printf('<Char-%d>', char2nr(key)), 'fit#handleBasicKey', string(key))
        endfor
    endfor

    for [action, binding] in items(s:DEFAULT_KEY_BINDINGS)
        let [handler; keys] = binding
        for key in keys
            call s:mapKey(key, handler)
        endfor
    endfor
endfunction

function! s:splitInput()
    let left = b:pos == 0 ? '' : b:input[: b:pos-1]
    let cursor = b:input[b:pos]
    let right = b:input[b:pos+1 :]
    return [left, cursor, right]
endfunction

function! s:renderPrompt()
    let [left, cursor, right] = s:splitInput()

    echohl Comment
    echon b:prompt
    echon ' '

    echohl None
    echon left

    echohl Underlined
    echon cursor == '' ? ' ' : cursor

    echohl None
    echon right
endfunction

function! s:defineHighlighting()
    highlight link FitNoMatches Error
    syntax match FitNoMatches '^--NO MATCHES--$'
endfunction

function! fit#open(...)
    let handler = get(a:, 1, {})
    let prompt = get(handler, "prompt", ">>")
    let candidates = get(handler, "candidates", [])

    call s:createBuffer({ 'prompt': prompt, 'candidates': candidates })
    call s:setOptions()
    call s:defineMappings()
    call s:defineHighlighting()
    call s:renderPrompt()

    call timer_start(0, "fit#redraw")
endfunction
