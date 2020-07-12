local event = require 'fit.event'

local element = event

function element:emit_change()
	return self:emit('change')
end

function element:on_change(listener)
	return self:on('change', listener)
end

return element
