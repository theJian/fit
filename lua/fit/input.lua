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
	self.search = search:sub(1, cursor - 1) .. ch .. search:sub(cursor)
	self.cursor = cursor + #ch
	self:emit_change()
end

function input:cursor_move_left()
	self.cursor = math.max(self.cursor - 1, 1)
	self:emit_change()
end

function input:cursor_move_right()
	self.cursor = math.min(self.cursor + 1, self.search:len() + 1)
	self:emit_change()
end

function input:backspace()
	local search = self.search
	local cursor = self.cursor
	self.search = search:sub(1, cursor - 2) .. search:sub(cursor)
	self.cursor = math.max(cursor - 1, 1)
	self:emit_change()
end

function input:backspace_word()
	local search = self.search
	local cursor = self.cursor
	local text_before_cursor = search:sub(1, cursor - 1)
	local new_cursor = vim.fn.match(text_before_cursor, '\\k*\\s*$') + 1 -- change to one-based
	print(text_before_cursor)
	if new_cursor > 0 then
		self.search = search:sub(1, new_cursor - 1) .. search:sub(cursor)
		self.cursor = new_cursor
		self:emit_change()
	end
end

return input
