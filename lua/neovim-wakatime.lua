local last_sent_time

local version = vim.version()
local user_agent = string.format("neovim/%d.%d.%d neovim-wakatime/0.1.0", version.major, version.minor, version.patch)

local function process_cli_args(key, value)
	if key == "lines" then
		return { "--lines-in-file", value }
	end
	if key == "is_write" then
		if value == false then
			return {}
		end
		return { "--write" }
	end
	return { string.format("--%s", key), value }
end

local function send_heartbeats(is_write)
	last_sent_time = vim.loop.gettimeofday()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))

	local heartbeats = {
		entity = vim.api.nvim_buf_get_name(0),
		time = last_sent_time,
		language = vim.bo.filetype,
		lines = vim.api.nvim_buf_line_count(0),
		lineno = row,
		cursorpos = col + 1,
		is_write = is_write,
	}

	local command = { "wakatime" }
	for key, value in pairs(heartbeats) do
		for _, item in ipairs(process_cli_args(key, value)) do
			table.insert(command, item)
		end
	end
	table.insert(command, "--plugin")
	table.insert(command, user_agent)
	vim.system(
		command,
		vim.schedule_wrap(function(obj)
			if obj.code ~= 0 then
				vim.notify(string.format("failed to upload heartbeats: %s", obj.stderr), vim.log.levels.ERROR)
			end
		end)
	)
end

local attentiveacting = {}

function attentiveacting.setup()
	if vim.fn.executable("wakatime") == 0 then
		vim.notify("failed to find executable `wakatime`", vim.log.levels.ERROR)
		return
	end
	vim.api.nvim_create_autocmd("BufEnter", {
		callback = function()
			send_heartbeats(false)
		end,
	})
	vim.api.nvim_create_autocmd("BufWritePost", {
		callback = function()
			send_heartbeats(true)
		end,
	})
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		callback = function()
			if vim.loop.gettimeofday() - last_sent_time >= 60 then
				send_heartbeats(false)
			end
		end,
	})
end

return attentiveacting
