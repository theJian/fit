local worker = require 'fit.worker'
local kb = require 'fit.kb'
local win = require 'fit.win'
local input = require 'fit.input'
local options = require 'fit.options'
local event = require 'fit.event'
local util = require 'fit.util'
local debounce = util.debounce
local memo = util.memo
local map = util.map
local filter = util.filter
local echoerr = util.echoerr
local redraw = util.redraw
local termcode = util.termcode

local settings = {
	width = 'auto',
	lines = 13,
}

local actions = event:new()

local function quit()
	worker:stop()
	win:close()
	actions:emit('quit')
end

kb:add(
	{'<esc>'},
	function()
		return false
	end
)

kb:add(
	{'<c-j>'},
	function()
		options:focus_next()
	end
)

kb:add(
	{'<c-k>'},
	function()
		options:focus_prev()
	end
)

kb:add(
	{'<cr>'},
	function()
		actions:emit('accept', options:get_focused_option())
		return false
	end
)

kb:add(
	{'<left>'},
	function()
		input:cursor_move_left()
	end
)

kb:add(
	{'<right>'},
	function()
		input:cursor_move_right()
	end
)

kb:add(
	{'<bs>', '<c-h>'},
	function()
		input:backspace()
	end
)

kb:add(
	{'<c-u>'},
	function()
		input:clear()
	end
)

kb:add(
	{'<c-w>'},
	function()
		input:backspace_word()
	end
)

kb:fallback(function(key)
	input:insert(key)
end)

input:on_change(function()
	win:update({
		input = input.search;
		cursor = input.cursor;
	})
end)

input:on_change(function()
	actions:emit('input', input.search)
end)

options:on_change(function()
	local slice_start = math.max(
		math.min(options.focus - math.floor(settings.lines / 2), #options.matches - settings.lines + 1),
		1
	)
	local slice_end = slice_start + settings.lines
	win:update({
		focus = options.focus - slice_start + 1;
		options = {unpack(options.matches, slice_start, slice_end - 1)};
	})
end)

local function make_command(command_string, placeholders)
	local command = command_string
	for k,v in pairs(placeholders) do
		command = string.gsub(command, k, v)
	end
	return command
end

local function render_options(buf, width, height, lines)
	-- local border = string.rep('─', width - 2)
	-- local top = '┌' .. border .. '┐'
	-- local bottom = '└' .. border .. '┘'
	vim.api.nvim_buf_set_lines(buf, 1, -1, 0, lines)
	redraw()
end

local function show_win(on_change, on_accept)
	input:clear()
	options:clear()
	win:open(settings)

	local function listen_key()
		local status, key = pcall(function() return vim.fn.getchar() end)
		if not status then
			quit()
			return
		end
		if type(key) == 'number' then
			key = vim.fn.nr2char(key)
		end

		local should_continue = kb:dispatch(key) ~= false
		if not should_continue then
			quit()
			return
		end

		return vim.schedule(listen_key)
	end
	vim.schedule(listen_key)
end

local function open_finder(config)
	local script = config.script
	local accept_command = config.accept_command
	local on_write = config.on_write

	script = make_command(script, {
		['<cwd>']  = vim.fn.getcwd(),
		['<file>'] = vim.fn.expand('%:p'),
		['<dir>']  = vim.fn.expand('%:p:h'),
	})

	show_win()

	local selected
	actions:on('input', memo(debounce(function(text)
		options:clear()
		worker:run(
			make_command(script, {
				['<query>'] = text
			}),
			{
				on_read = function(err, data)
					if err then
						-- TODO: process error
						return
					end

					if data then
						options:push_matches(vim.split(vim.trim(data), '\n'))
					end
				end;

				on_write = on_write;
			}
		)
	end)))
	actions:on('accept', function(result) selected = result end)
	actions:on('quit', function()
		if selected then
			vim.api.nvim_command(string.format('%s %s', accept_command, selected))
		end

		actions:off_all('input')
		actions:off_all('accept')
		actions:off_all('quit')
	end)
end

-- Methods
M = {
	kb = kb
}

function M.find(script, accept_command)
	vim.validate{
		script={script, 'string'};
		accept_command={accept_command, 'string', true};
	}

	open_finder({
		script = script;
		accept_command = accept_command or 'e';
	})
end

function M.buffers(script, accept_command)
	vim.validate{
		script={script, 'string'};
		accept_command={accept_command, 'string', true};
	}

	local loaded_buf_handlers = filter(vim.api.nvim_list_bufs(), function(handler)
		return vim.api.nvim_buf_is_loaded(handler)
	end)
	local buf_names = map(loaded_buf_handlers, function(handler)
		return vim.api.nvim_buf_get_name(handler)
	end)
	local write_data = table.concat(buf_names, '\n')

	open_finder({
		script = script;
		accept_command = accept_command or 'b';
		on_write = function() return write_data end;
	})
end

function M.setup(user_settings)
	settings = vim.tbl_extend('force', settings, user_settings or {})
end

return M
