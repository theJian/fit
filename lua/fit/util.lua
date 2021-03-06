local function clear_timer(timer)
	if timer and not timer:is_closing() then
		timer:stop()
		timer:close()
	end
end

local function debounce(fn)
	local delay = 100 -- ms
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

local function truncate_string(string, width, hide_left)
	if vim.fn.strdisplaywidth(string) > width then
		local left, right, prefix, subfix
		if hide_left then
			left = 2 - width
			right = -1
			prefix = '..'
			subfix = ''
		else
			left = 1
			right = width - 2
			prefix = ''
			subfix = '..'
		end
		return prefix .. string.sub(string, left, right) .. subfix
	end

	return string
end

local function termcode(k)
	return vim.api.nvim_replace_termcodes(k, true, true, true)
end

local function redraw()
	vim.api.nvim_command('redraw')
end

local function right_pad(str, width)
	return str .. string.rep(' ', width - vim.fn.strdisplaywidth(str))
end

return {
	debounce = debounce;
	memo = memo;
	map = map;
	filter = filter;
	echoerr = echoerr;
	truncate_string = truncate_string;
	termcode = termcode;
	redraw = redraw;
	right_pad = right_pad;
}
