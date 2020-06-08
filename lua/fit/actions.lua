local util = require('fit.util')
local map = util.map
local termcode = util.termcode

local actions = {}

function actions:handler(key)
	if self.fallback_fn then
		return self.fallback_fn(key)
	end
end

function actions:add(keys, handler)
	local next_handler = self.handler
	local coded_keys = map(keys, termcode)
	self.handler = function(self, key)
		if vim.tbl_contains(coded_keys, key) then
			return handler(key)
		else
			return next_handler(self, key)
		end
	end
end

function actions:dispatch(key)
	return self:handler(key)
end

function actions:fallback(f)
	self.fallback_fn = f
end

return actions
