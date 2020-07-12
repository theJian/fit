local loop = vim.loop

local worker = {}

function worker:run(command, options)
	if not command then return end

	self:stop()

	local on_read, on_write, stdin, stdout, handle

	on_read = options.on_read
	on_write = options.on_write
	stdin = loop.new_pipe(false)
	stdout = loop.new_pipe(false)
	handle = loop.spawn('bash', {
		args = { '-c', command },
		stdio = { stdin, stdout, nil }
	}, function()
		stdin:close()
		stdout:read_stop()
		stdout:close()
		handle:close()
	end)
	self.handle = handle

	loop.read_start(stdout, on_read)
	if on_write then
		loop.write(stdin, on_write())
		loop.shutdown(stdin)
	end
end

function worker:stop()
	local handle = self.handle
	if handle then
		handle:kill('sigkill')
	end
end

return worker
