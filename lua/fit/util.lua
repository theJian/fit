local function clear_timer(timer)
	if timer and not timer:is_closing() then
		timer:stop()
		timer:close()
	end
end

local function debounce(fn)
	local delay = 50 -- ms
	local timer
	return function (...)
		local arg = {...}
		clear_timer(timer)
		timer = vim.loop.new_timer()
		timer:start(
			delay,
			0,
			vim.schedule_wrap(function()
				clear_timer(timer)
				fn(unpack(arg))
			end)
		)
	end
end

local function map(list, fn)
	local result = {}
	for index, value in ipairs(list) do
		result[index] = fn(value, index)
	end
	return result
end

local function filter(list, test)
	local result = {}
	for index, value in ipairs(list) do
		if test(value, index) then
			table.insert(result, value)
		end
	end
	return result
end

local function memo(fn)
	local lastArg = {}
	local lastResult
	return function(...)
		local arg = {...}
		if not vim.deep_equal(lastArg, arg) then
			lastResult = fn(...)
			lastArg = arg
		end
		return lastResult
	end
end

local function echoerr(msg)
	vim.api.nvim_err_writeln('[fit]' .. msg)
end

local function truncate_string(string, width)
	if #string > width then
		return string.sub(string, 1, width - 2) .. '..'
	end

	return string
end

return {
	debounce = debounce,
	memo = memo,
	map = map,
	filter = filter,
	echoerr = echoerr,
	truncate_string = truncate_string,
}
