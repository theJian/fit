local element = require 'fit.element'

local input = element:new()

function input:clear()
	self.search = ''
	self.cursor = 1
	self:emit_change()
end

function input:insert(ch)
	local search = self.search
	local cursor = self.cursor
	self.search = vim.fn.strcharpart(search, 0, cursor - 1) .. ch .. vim.fn.strcharpart(search, cursor - 1)
	self.cursor = cursor + vim.fn.strchars(ch)
	self:emit_change()
end

function input:cursor_move_left()
	self.cursor = math.max(self.cursor - 1, 1)
	self:emit_change()
end

function input:cursor_move_right()
	self.cursor = math.min(self.cursor + 1, vim.fn.strchars(self.search) + 1)
	self:emit_change()
end

function input:backspace()
	local search = self.search
	local cursor = self.cursor
	self.search = vim.fn.strcharpart(search, 0, cursor - 2) .. vim.fn.strcharpart(search, cursor - 1)
	self.cursor = math.max(cursor - 1, 1)
	self:emit_change()
end

function input:backspace_word()
	local search = self.search
	local cursor = self.cursor
	local text_before_cursor = vim.fn.strcharpart(search, 0, cursor - 1)
	local match_byte_index = vim.fn.match(text_before_cursor, '\\k*\\s*$')
	if match_byte_index >= 0 then
		local new_text_before_cursor = vim.fn.strpart(text_before_cursor, 0, match_byte_index)
		local new_cursor = vim.fn.strchars(new_text_before_cursor) + 1
		self.search = new_text_before_cursor .. vim.fn.strcharpart(search, cursor - 1)
		self.cursor = new_cursor
		self:emit_change()
	end
end

return input
