local util = require 'fit.util'
local filter = util.filter

local event = {}

function event:new()
	local o = { listeners = {} }
	setmetatable(o, self)
	self.__index = self
	return o
end

function event:on(name, fn)
	self.listeners[name] = self.listeners[name] or {}
	table.insert(self.listeners[name], fn)

	return function()
		self:off(name, fn)
	end
end

function event:off(name, fn)
	local listeners = self.listeners[name]

	if not listeners then
		return
	end

	self.listeners[name] = filter(
		listeners,
		function(i_listener)
			return i_listener ~= listener
		end
	)
end

function event:off_all(name)
	self.listeners[name] = nil
end

function event:emit(name, ...)
	local listeners = self.listeners[name]

	if not listeners then
		return
	end

	for _index, listener in ipairs(listeners) do
		listener(unpack({...}))
	end
end

return event
