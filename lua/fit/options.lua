local element = require 'fit.element'

local options = element:new()

function options:clear()
	self.matches = {}
	self.focus = 0
	self:emit_change()
end

function options:set_matches(matches)
	self.matches = matches
	if #matches > 0 then
		self.focus = 1
	end
	self:emit_change()
end

function options:push_matches(matches)
	vim.list_extend(self.matches, matches)
	if self.focus == 0 and #matches > 0 then
		self.focus = 1
	end
	self:emit_change()
end

function options:focus_next()
	self.focus = math.min(self.focus + 1, #self.matches)
	self:emit_change()
end

function options:focus_prev()
	self.focus = math.max(self.focus - 1, math.min(#self.matches, 1))
	self:emit_change()
end

function options:get_focused_option()
	return self.matches[self.focus]
end

return options
