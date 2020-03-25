local util = require('fit.util')
local echoerr = util.echoerr
local redraw = util.redraw
local map = util.map
local truncate_string = util.truncate_string

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

	echoerr('options.width must be "auto" or a positive number')
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

local function create_win_container(buf, options)
	local row, col, width, height = get_win_bounding(options.width)
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

function win:open(options)
	self.lines = options.lines
	self.search = ''
	self.buf = vim.api.nvim_create_buf(false, true)
	self.container = create_win_container(self.buf, { width = options.width })
	self.width = vim.api.nvim_win_get_width(self.container)
end

function win:set_search(search)
	self:update('search', search)
end

function win:set_select_options(select_options)
	self:update('select_options', select_options)
end

function win:set_cursor(cursor)
	self:update('cursor', cursor)
end

function win:update(field, value)
	if value ~= self[field] then
		self[field] = value
		self:schedule_render()
	end
end

function win:schedule_render()
	self.dirty = true
	vim.schedule(function()
		self:render()
	end)
end

function win:render()
	if self.dirty then
		local top = math.max(self.cursor - math.floor(self.lines / 2), 1)
		local bottom = top + self.lines
		local interval = map(
			vim.list_extend({}, self.select_options, top, bottom),
			function(line, index)
				local absolute_index = top + index - 1
				local indent_prefix = '  '
				if absolute_index == self.cursor then
					indent_prefix = '> '
				end
				return indent_prefix .. truncate_string(line, self.width - #indent_prefix, true)
			end
		)
		local height = #interval + 1 -- select options height + search input height
		vim.api.nvim_win_set_height(self.container, height)
		vim.api.nvim_buf_set_lines(self.buf, 0, -1, 0, {truncate_string(self.search, self.width, true), unpack(interval)})

		redraw()
		self.dirty = false
	end
end

function win:close()
	if self.win then
		vim.api.nvim_win_close(self.win, true)
		self.win = nil
	end
end

return win
