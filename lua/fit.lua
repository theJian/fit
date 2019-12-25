local options = {
	finders = {
		files = 'rg --color never --files <dir> | fzy --show-matches=<query>',
	},
	width = 'auto',
	lines = 12,
}

local current_matcher

local actions = {}
function actions.cancel()
	current_matcher = nil
	vim.api.nvim_win_close(0, true)
end

function actions.select_next()
	if current_matcher then
		current_matcher.cursor_move_next()
	end
end

function actions.select_prev()
	if current_matcher then
		current_matcher.cursor_move_prev()
	end
end

function actions.accept()
	local target = current_matcher.get_target()
	current_matcher = nil
	vim.api.nvim_win_close(0, true)
	vim.api.nvim_command('e ' .. target)
end

-- local function actions.accept_split()
-- end

-- local function actions.accept_vsplit()
-- end

-- local function actions.accept_tab()
-- end

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

local keybindings = {}
keybindings.cancel = '<esc>'
keybindings.select_next = '<c-j>'
keybindings.select_prev = '<c-k>'
keybindings.accept = '<cr>'

local function echoerr(msg)
	vim.api.nvim_err_writeln('[fit]' .. msg)
end

local function filter(list, test)
	local result = {}
	for index, value in ipairs(list) do
		if test(value, index) then
			table.insert(result, value)
		end
	end
	return result
end

local function map(list, fn)
	local result = {}
	for index, value in ipairs(list) do
		result[index] = fn(value, index)
	end
	return result
end

local function memo(fn)
	local lastArg = {}
	local lastResult
	return function(...)
		local arg = {...}
		if not vim.deep_equal(lastArg, arg) then
			lastResult = fn(...)
			lastArg = arg
		end
		return lastResult
	end
end

local function clear_timer(timer)
	if timer and not timer:is_closing() then
		timer:stop()
		timer:close()
	end
end

local function debounce(fn)
	local delay = 50 -- ms
	local timer
	return function (...)
		local arg = {...}
		clear_timer(timer)
		timer = vim.loop.new_timer()
		timer:start(
			delay,
			0,
			vim.schedule_wrap(function()
				clear_timer(timer)
				fn(unpack(arg))
			end)
		)
	end
end

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

local function get_auto_width(editor_width)
	local min_width = math.min(editor_width, 60)
	local w = math.floor(editor_width / 2)
	return math.max(min_width, w)
end

local function get_win_width(width, editor_width)
	if width == 'auto' then
		return get_auto_width(editor_width)
	end

	if type(width) == 'number' and width > 0 then
		return math.min(width, editor_width)
	end

	echoerr('options.width must be "auto" or a positive number')
	return get_win_width('auto')
end

local function get_auto_top(editor_height)
	local max_top = 5
	if editor_height < 15 then
		return 0
	end
	return max_top
end

local function get_win_pos()
	local col, width
	local ew = vim.api.nvim_get_option('columns')
	local eh = vim.api.nvim_get_option('lines')
	local width = get_win_width(options.width, ew)
	local col = math.floor((ew - width) / 2)
	local row = get_auto_top(eh)
	local height = 1
	return row, col, width, height
end

local function command_put_char(char)
	return string.format(':call nvim_put(["%s"], "c", 0, 1)<cr>', char)
end

local function command_call_action(action_type)
	return string.format(':lua fit.actions.%s()<cr>', action_type)
end

local function create_matcher()
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

local function open_win(on_change)
	local lines = options.lines
	local row, col, width, height = get_win_pos()
	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = 'editor',
		style = 'minimal',
		row = row,
		col = col,
		width = width,
		height = height,
	})

	current_matcher = create_matcher()
	current_matcher.subscribe(vim.schedule_wrap(function(matches, cursor)
		local top = math.max(cursor - math.floor(lines / 2), 1)
		local bottom = top + lines
		local renderlist = {}
		vim.list_extend(renderlist, matches, top, bottom)
		renderlist = map(renderlist, function(line, index)
			local orig_index = top + index - 1
			if orig_index == cursor then
				return '> ' .. line
			end
			return '  ' .. line
		end)
		vim.api.nvim_win_set_height(win, #renderlist + 1)
		vim.api.nvim_buf_set_lines(buf, 1, -1, 0, renderlist)
	end))

	local on_search_update = memo(function(text)
		current_matcher.init_matcher({})
		on_change(text, function(result)
			local new_matches = vim.split(vim.trim(result), '\n')
			current_matcher.append_matches(new_matches)
		end)
	end)

	vim.api.nvim_buf_attach(buf, false, {
		on_lines = function(_buf, _changedtick, firstline, lastline, new_lastline)
			local text = vim.api.nvim_get_current_line()
			text = vim.trim(text)

			on_search_update(text)
		end
	})

	-- remap keyboard
	for i=32, 126 do
		local char = string.char(i)
		vim.api.nvim_buf_set_keymap(buf, 'n', char, command_put_char(char), {
			noremap = true,
			nowait = true,
			silent = true,
		})
	end

	for k,v in pairs(keybindings) do
		if actions[k] then
			vim.api.nvim_buf_set_keymap(buf, 'n', v, command_call_action(k), {
				noremap = true,
				nowait = true,
				silent = true,
			})
		end
	end
end

-- Methods
fit = {}
fit.actions = actions

function fit.finder(name)
	local finder = options.finders[name]

	if not finder then
		echoerr('Finder is not defined')
		return
	end

	if type(finder) ~= 'string' then
		echoerr('Expected finder to be a string')
		return
	end

	local mid_command = make_command(finder, {
		['<cwd>']  = vim.fn.getcwd(),
		['<file>'] = vim.fn.expand('%:p'),
		['<dir>']  = vim.fn.expand('%:p:h'),
	})

	local on_change = debounce(function(text, cb)
		local command = make_command(mid_command, {
			['<query>'] = text
		})

		run_command(command, function(err, data)
			if err then
				-- TODO: process error
				return
			end

			if data then
				cb(data)
			end
		end)
	end)

	open_win(on_change)
end

return fit
