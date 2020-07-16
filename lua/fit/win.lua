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
	self.input_scroll_left = 0
	self.dirty = false
	self.update_queue = {}
	self.buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(self.buf, 'bufhidden', 'wipe')
	self.container = create_win_container(self.buf, { width = config.width })
	self.width = vim.api.nvim_win_get_width(self.container)
	self.inner_width = self.width - 2 -- subtract left and right border

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
	local increment = math.min(state.cursor - self.input_scroll_left - 1, 0) +
							math.max(state.cursor - self.input_scroll_left - inner_width, 0)
	self.input_scroll_left = self.input_scroll_left + increment
	local visible_input_line = string.sub(input_line, self.input_scroll_left + 1, self.input_scroll_left + inner_width)
	local border_v = '│'

	local lines = {'╭' .. string.rep('─', inner_width) .. '╮'}
	vim.list_extend(lines,
		{border_v .. right_pad(visible_input_line, inner_width) .. border_v}
	)
	vim.list_extend(lines,
		map(state.options, function(line)
			local display_line = right_pad(
				truncate_string(line, inner_width, true),
				inner_width
			)
			return border_v .. display_line .. border_v
		end)
	)
	vim.list_extend(lines,
		{'╰' .. string.rep('─', inner_width) .. '╯'}
	)

	local height = #lines
	vim.api.nvim_win_set_height(self.container, height)
	vim.api.nvim_buf_set_lines(self.buf, 0, -1, 0, lines)

	local border_top = 1
	local border_v_width = #border_v
	local cursor_pos = state.cursor - self.input_scroll_left + border_v_width
	print(cursor_pos)
	vim.api.nvim_buf_clear_namespace(self.buf, -1, 0, -1)
	vim.api.nvim_buf_add_highlight(self.buf, 0, 'FitCursor', border_top, cursor_pos - 1, cursor_pos)
	if state.focus > 0 then
		vim.api.nvim_buf_add_highlight(self.buf, 0, 'FitSel', state.focus + border_top, border_v_width, border_v_width + inner_width)
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
