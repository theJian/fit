local actions = require('fit.actions')
local win = require('fit.win')
local util = require('fit.util')
local debounce = util.debounce
local memo = util.memo
local map = util.map
local filter = util.filter
local echoerr = util.echoerr
local redraw = util.redraw

local options = {
	width = 'auto',
	lines = 12,
}

local current_options
local current_accept_command

local function quit(win)
	current_options = nil
	win:close()
end

actions:add(
	{'<esc>'},
	function()
		vim.api.nvim_input('<C-c>')
	end
)

actions:add(
	{'<c-j>'},
	function()
		if current_options then
			current_options.cursor_move_next()
		end
	end
)

actions:add(
	{'<c-k>'},
	function()
		if current_options then
			current_options.cursor_move_prev()
		end
	end
)

actions:add(
	{'<cr>'},
	function()
		local target = current_options.get_target()
		win:once_close(function()
			local command = current_accept_command or 'e'
			vim.api.nvim_command(string.format('%s %s', command, target))
		end)
		vim.api.nvim_input('<C-c>')
	end
)

-- local function actions.backspace()
-- end

-- local function actions.backspace_word()
-- end

-- local function actions.clear()
-- end

-- local function actions.cursor_left()
-- end

-- local function actions.cursor_right()
-- end

-- local function actions.cursor_start()
-- end

-- local function actions.cursor_end()
-- end

-- local function actions.delete()
-- end

local run_command = (function()
	local loop = vim.loop
	local handle

	return function(command, onread)
		if handle then
			handle:kill('sigint')
		end

		if not command then return end

		local stdout = loop.new_pipe(false)
		local stderr = loop.new_pipe(false)

		handle = loop.spawn('bash', {
			args = { '-c', command },
			stdio = { nil, stdout, stderr }
		}, function()
			stdout:read_stop()
			stderr:read_stop()
			stdout:close()
			stderr:close()
			handle:close()
		end)

		loop.read_start(stdout, onread)
		loop.read_start(stderr, onread)
	end
end)()

local function make_command(command_string, placeholders)
	local command = command_string
	for k,v in pairs(placeholders) do
		command = string.gsub(command, k, v)
	end
	return command
end

local function create_options()
	local matches = {}
	local cursor = 0
	local listeners = {}

	local function subscribe(callback)
		table.insert(listeners, callback)
		local function unsubscribe()
			listeners = filter(listeners, function(listener)
				return listener ~= callback
			end)
		end
		return unsubscribe
	end

	local function notify()
		for _, listener in ipairs(listeners) do
			listener(matches, cursor)
		end
	end

	local function init_matcher(next_matches)
		matches = next_matches
		cursor = math.max(0, math.min(#matches, 1))
		notify()
	end

	local function append_matches(new_matches)
		vim.list_extend(matches, new_matches)
		if cursor == 0 and #matches > 0 then
			cursor = 1
		end
		notify()
	end

	local function cursor_move_next()
		cursor = math.min(cursor + 1, #matches)
		notify()
	end

	local function cursor_move_prev()
		cursor = math.max(cursor - 1, math.min(#matches, 1))
		notify()
	end

	local function get_target()
		return matches[cursor]
	end

	return {
		subscribe = subscribe,
		init_matcher = init_matcher,
		append_matches = append_matches,
		cursor_move_next = cursor_move_next,
		cursor_move_prev = cursor_move_prev,
		get_target = get_target,
	}
end

local function render_options(buf, width, height, lines)
	-- local border = string.rep('─', width - 2)
	-- local top = '┌' .. border .. '┐'
	-- local bottom = '└' .. border .. '┘'
	vim.api.nvim_buf_set_lines(buf, 1, -1, 0, lines)
	redraw()
end

local function open_win(on_change, on_accept)
	local search = ''
	win:open(options)

	current_options = create_options()
	current_options.subscribe(vim.schedule_wrap(function(matches, cursor)
		win:set_select_options(matches)
		win:set_cursor(cursor)
	end))

	local on_search_update = memo(function(text)
		current_options.init_matcher({})
		win:set_search(text)
		on_change(text, function(new_matches)
			current_options.append_matches(new_matches)
		end)
	end)

	-- listen keyboard
	vim.api.nvim_command('mapclear <buffer>')

	actions:fallback(function(key)
		search = search .. key
		on_search_update(search)
	end)

	local function listen_key()
		local status, key = pcall(function() return vim.fn.getchar() end)
		if not status then
			quit(win)
			return
		end
		if type(key) == 'number' then
			key = vim.fn.nr2char(key)
		end

		actions:dispatch(key)

		return vim.schedule(listen_key)
	end
	vim.schedule(listen_key)
end

-- Methods
M = {
	actions = actions
}

function M.find(find_command, accept_command)
	if not find_command then
		echoerr('find_command is not defined')
		return
	end

	if type(find_command) ~= 'string' then
		echoerr('Expected find_command to be a string')
		return
	end

	local confined_find_command = make_command(find_command, {
		['<cwd>']  = vim.fn.getcwd(),
		['<file>'] = vim.fn.expand('%:p'),
		['<dir>']  = vim.fn.expand('%:p:h'),
	})

	local on_change = debounce(function(text, done)
		local command = make_command(confined_find_command, {
			['<query>'] = text
		})

		run_command(command, function(err, data)
			if err then
				-- TODO: process error
				return
			end

			if data then
				done(vim.split(vim.trim(data), '\n'))
			end
		end)
	end)

	current_accept_command = accept_command
	open_win(on_change)
end

function M.setup(user_options)
	options = vim.tbl_extend('force', options, user_options or {})
end

return M
