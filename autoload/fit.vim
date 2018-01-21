let s:BUFFER_NAME = "fit"

function! fit#error(error)
    echo a:error
endfunction

function! fit#init(items, ...)
    if len(a:items) == 0
        return fit#error("Nothing to Match")
    endif

    let options = get(a:, 1, {})
    let openBufferCommand = get(options, "openBufferCommand", "enew")
    let bufferName = get(options, "bufferName", s:BUFFER_NAME)

    " creating a buffer
    execute openBufferCommand

    execute "silent file " . bufferName

    " remove all mappings
    mapclear <buffer>
    mapclear! <buffer>

    " set local options
    " setlocal laststatus=0
    setlocal filetype=fit
    setlocal buftype=nofile
    setlocal conceallevel=3
    setlocal concealcursor=nvic
    setlocal nonumber
    setlocal norelativenumber
    setlocal noshowmode
    setlocal nowrap
    setlocal nocursorline
    setlocal nocursorcolumn

    " set buffer variables
    let b:curtBuf = bufnr("%")
    let b:items = a:items
    let b:itemsAmount = len(b:items)
    let b:picker = get(options, "picker", function("fit#getMatches"))
    let b:hiddenLines = []
    let b:header = get(options, "header", [])
    let b:prompt = get(options, "prompt", "> ")
    let b:query = ""
    let b:prevQuery = b:query
    let b:queryLine = len(b:header) + 1
    let b:firstMatchLine = b:queryLine + 1
    let b:hoveredLine = b:firstMatchLine
    let b:queryStartColumn = len(b:prompt) + 1

    call fit#initMappings()
    call fit#initEventListeners()
    call fit#initHighlighting()
endfunction

function! fit#getMatches(items)
    let pickCommand = "fzy --show-matches=%s"
    let command = printf(pickCommand, shellescape(b:query))
    let availables = []

    for item in a:items
        call add(availables, item.path)
    endfor

    let matches = systemlist(command, availables)

    return matches
endfunction

function! fit#mappingsCall(fn, ...)
    call call(a:fn, a:000)

    return ""
endfunction

function! fit#initMappings()
    inoremap <expr> <buffer> <BS> fit#canGoLeft() ? "\<BS>" : ""
    inoremap <expr> <buffer> <C-H> fit#canGoLeft() ? "\<C-H>" : ""
    inoremap <expr> <buffer> <Left> fit#canGoLeft() ? "" : "\<Left>"
    inoremap <expr> <buffer> <Del> col(".") == col("$") ? "" : "\<Del>"
    inoremap <silent> <buffer> <Tab> <C-R>=fit#mappingsCall("fit#selectNext")<CR>
    inoremap <silent> <buffer> <C-J> <C-R>=fit#mappingsCall("fit#selectNext")<CR>
    inoremap <silent> <buffer> <C-N> <C-R>=fit#mappingsCall("fit#selectNext")<CR>
    inoremap <silent> <buffer> <S-Tab> <C-R>=fit#mappingsCall("fit#selectPrev")<CR>
    inoremap <silent> <buffer> <C-K> <C-R>=fit#mappingsCall("fit#selectPrev")<CR>
    inoremap <silent> <buffer> <C-P> <C-R>=fit#mappingsCall("fit#selectPrev")<CR>
    inoremap <silent> <buffer> <CR> <C-R>=fit#mappingsCall("fit#accept")<CR>
endfunction

function! fit#selectNext()
    let nextHoveredLine = b:hoveredLine + 1

    if nextHoveredLine <= line('$') && nextHoveredLine <= winheight(0)
        call fit#hoverLine(nextHoveredLine)
    endif
endfunction

function! fit#selectPrev()
    let nextHoveredLine = b:hoveredLine - 1

    if nextHoveredLine >= b:firstMatchLine
        call fit#hoverLine(nextHoveredLine)
    endif
endfunction

function! fit#accept()
    let buffer = b:curtBuf
    let selectedIndex = b:hoveredLine - b:firstMatchLine
    let selectedPath = get(b:matches, selectedIndex, v:null)

    stopinsert
    execute printf("silent edit %s", fnameescape(selectedPath))
    call fit#closeBuffer(buffer)
endfunction

function! fit#hoverLine(line)
    let b:hoveredLine = a:line

    syntax clear fitHovered
    execute printf('syntax match fitHovered /\%%%il.*$/', a:line)
endfunction

function! fit#closeBuffer(buffer)
    execute "bdelete " . a:buffer
endfunction

function! fit#canGoLeft()
    return col('.') > b:queryStartColumn
endfunction

function! fit#textChangedI()
    let b:query = strpart(getline(b:queryLine), b:queryStartColumn - 1)

    if b:query !=# b:prevQuery
        let b:prevQuery = b:query
        call timer_start(0, "fit#redraw")
    endif
endfunction

function! fit#insertLeave()
    call fit#closeBuffer(b:curtBuf)
endfunction

function! fit#initEventListeners()
    autocmd TextChangedI <buffer> call fit#textChangedI()
    autocmd InsertLeave <buffer> call fit#insertLeave()
endfunction

function! fit#initHighlighting()
    hi link fitHovered Visual
endfunction

function! fit#fill()
    " insert header
    call fit#updateHeader()

    " insert query line
    call fit#setQueryLine()

    call timer_start(0, "fit#redraw")
    call feedkeys("s")
endfunction

function! fit#setQueryLine()
    call setline(b:queryLine, b:prompt . b:query)

    " move cursor to the end of query line
    call cursor(b:queryLine, 999)
endfunction

function! fit#updateHeader()
    call setline(1, b:header)
endfunction

function! fit#redraw(timer)
    let winView = winsaveview()

    if line('$') > b:queryLine
        silent execute b:firstMatchLine . ",$d"
    endif

    call winrestview(winView)

    let b:matches = call(b:picker, [b:items])
    let b:matchesAmount = len(b:matches)

    call fit#updateHeader()

    let i = b:firstMatchLine
    let lastVisibleIndex = winheight(0) - b:firstMatchLine
    let visibleLines = b:matches[:lastVisibleIndex]

    for line in visibleLines
        call setline(i, line)
        let i += 1
    endfor

    if b:matchesAmount > 0
        call fit#hoverLine(b:firstMatchLine)
    endif
endfunction

function! fit#files(...)
    let options = get(a:, 1, {})
    let options.bufferName = get(options, "bufferName", "Files")
    let options.prompt = get(options, "prompt", "Files>> ")

    let directory = get(options, "directory", ".")
    let findCommand = get(options, "findCommand", "rg --color never --files --fixed-strings %s")
    let options.header = get(options, "header", s:getHeader(directory))

    if !isdirectory(fnamemodify(directory, ":p"))
        return fit#error(printf("Can't find directory %s", directory))
    endif

    let command = printf(findCommand, directory)

    " remove ./ at the beginning of the line
    let command .= ' | sed "s|^\./||"'

    let paths = systemlist(command)
    if len(paths) == 0
        return fit#error("No files available")
    endif

    let items = []
    for path in paths
        let item = {}
        let item.path = path
        let item.baseName = fnamemodify(path, ":t")

        call add(items, item)
    endfor

    call fit#init(items, options)

    call fit#fill()
endfunction

function! s:getHeader(directory)
    let directory = fnamemodify(a:directory, ":~")
    let title = "Fit Files Finder"
    let divider = repeat("=", 74)
    let header = []

    call add(header, divider)

    call add(header, title)

    call add(header, ' Directory: ' . directory)

    call add(header, divider)

    return header
endfunction
