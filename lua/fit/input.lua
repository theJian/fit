local input = {}

function input:clear()
	self.search = ''
	self.cursor = 1
end

function input:insert(ch)
	local search = self.search
	local cursor = self.cursor
	self.search = search:sub(1, cursor) .. ch .. search:sub(cursor + 1)
	self.cursor = cursor + 1
end

function input:cursor_move_left()
	self.cursor = math.max(self.cursor - 1, 1)
end

function input:cursor_move_right()
	self.cursor = math.min(self.cursor + 1, self.search:len() + 1)
end

function input:delete_before()
	local search = self.search
	local cursor = self.cursor
	self.search = search:sub(1, cursor - 1) .. search:sub(cursor + 1)
end

return input
