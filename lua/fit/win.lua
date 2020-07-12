local util = require 'fit.util'
local echoerr = util.echoerr
local redraw = util.redraw
local map = util.map
local truncate_string = util.truncate_string
local right_pad = util.right_pad

local function get_auto_top(editor_height)
	if editor_height < 15 then
		return 0
	end
	return math.floor(editor_height / 3)
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

	echoerr('config.width must be "auto" or a positive number')
	return get_win_width('auto')
end

local function get_win_bounding(max_width)
	local ew = vim.api.nvim_get_option('columns')
	local eh = vim.api.nvim_get_option('lines')
	local width = get_win_width(max_width, ew)
	local height = 1
	local col = math.floor((ew - width) / 2)
	local row = get_auto_top(eh)
	return row, col, width, height
end

local function create_win_container(buf, config)
	local row, col, width, height = get_win_bounding(config.width)
	return vim.api.nvim_open_win(buf, true, {
		relative = 'editor',
		style = 'minimal',
		row = row,
		col = col,
		width = width,
		height = height,
	})
end

local win = {}

local initial_state = {
	input = '';
	cursor = 1;
	focus = 0;
	options = {};
}

function win:open(config)
	self.state = initial_state
	self.dirty = false
	self.update_queue = {}
	self.buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(self.buf, 'bufhidden', 'wipe')
	self.container = create_win_container(self.buf, { width = config.width })
	self.width = vim.api.nvim_win_get_width(self.container)

	win:repaint()
end

function win:update(next_state)
	if self.container then
		table.insert(self.update_queue, next_state)
		self:schedule_render()
	end
end

function win:schedule_render()
	if self.dirty then
		return
	end

	self.dirty = true
	vim.schedule(function()
		self:render()
	end)
end

function win:render()
	if self.dirty then
		local next_state = vim.tbl_extend('force', self.state, unpack(self.update_queue))

		if not vim.deep_equal(next_state, self.state) then
			self.state = next_state
			self:repaint()
		end

		self.update_queue = {}
		self.dirty = false
	end
end

function win:repaint()
	local state = self.state
	local inner_width = self.width - 2 -- subtract left and right border

	local input_line = state.input .. ' ' -- Adding a space at the end to allow the cursor to move just past the end of the line
	local option_lines = map(
		state.options,
		function(line, index)
			local indent_prefix = (index == state.focus and '>' or ' ')
			return indent_prefix .. line
		end
	)

	local lines = {'╭' .. string.rep('─', inner_width) .. '╮'}
	vim.list_extend(lines,
		map({input_line, unpack(option_lines)}, function(line)
			local display_line = right_pad(
				truncate_string(line, inner_width, true),
				inner_width
			)
			return string.format('│%s│', display_line)
		end)
	)
	vim.list_extend(lines,
		{'╰' .. string.rep('─', inner_width) .. '╯'}
	)

	local height = #lines
	vim.api.nvim_win_set_height(self.container, height)
	vim.api.nvim_buf_set_lines(self.buf, 0, -1, 0, lines)

	local border_top = 1
	local border_left = #'│'
	local cursor_pos = state.cursor + border_left
	vim.api.nvim_buf_clear_namespace(self.buf, -1, 0, -1)
	vim.api.nvim_buf_add_highlight(self.buf, 0, 'FitCursor', border_top, cursor_pos - 1, cursor_pos)
	if state.focus > 0 then
		vim.api.nvim_buf_add_highlight(self.buf, 0, 'FitSel', state.focus + border_top, border_left, border_left + inner_width)
	end

	redraw()
end

function win:close()
	if self.container then
		vim.api.nvim_win_close(self.container, true)
		self.container = nil

		-- clear pending updates
		self.update_queue = {}
		self.dirty = false
	end
end

return win
