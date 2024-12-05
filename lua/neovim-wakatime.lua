local last_sent_time

local version = vim.version()
local user_agent = string.format("neovim/%d.%d.%d neovim-wakatime/0.1.0", version.major, version.minor, version.patch)

local wakatime_command = ""

local function send_heartbeats(is_write)
	if vim.bo.buftype ~= "" then
		return
	end
	last_sent_time = vim.loop.gettimeofday()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))

	local command = {
		wakatime_command,
		"--entity",
		vim.api.nvim_buf_get_name(0),
		"--time",
		last_sent_time,
		"--language",
		vim.bo.filetype,
		"--lines-in-file",
		vim.api.nvim_buf_line_count(0),
		"--lineno",
		row,
		"--cursorpos",
		col + 1,
		"--plugin",
		user_agent
	}
	if is_write == true then
		table.insert(command, "--write")
	end
	vim.system(
		command,
		vim.schedule_wrap(function(obj)
			if obj.code ~= 0 then
				vim.notify(
					string.format("failed to upload heartbeats: %s %s", obj.stdout, obj.stderr),
					vim.log.levels.ERROR
				)
			end
		end)
	)
end

local neovim_wakatime = {}

function neovim_wakatime.setup()
	if vim.fn.executable("wakatime") == 1 then
		wakatime_command = "wakatime"
	elseif vim.fn.executable("wakatime-cli") == 1 then
		wakatime_command = "wakatime-cli"
	else
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
			if vim.loop.gettimeofday() - last_sent_time >= 120 then
				send_heartbeats(false)
			end
		end,
	})
end

return neovim_wakatime
