local M = {}

local default_opts = {
	godot_executable = os.getenv("GODOT") or "godot",
	netcoredbg_path = nil,
	verbose = false,
}

local loaded = false
local user_opts = {}

local function is_godot_project()
	return vim.fs.find("project.godot", {
		upward = true,
		stop = vim.env.HOME,
		path = vim.fn.getcwd(),
	})[1] ~= nil
end

function M.setup(opts)
	user_opts = vim.tbl_deep_extend("force", default_opts, opts or {})

	local function load_core()
		if not is_godot_project() then
			return
		end

		vim.schedule(function()
			require("dap-godot-mono.core").configure(user_opts)
			loaded = true
		end)
	end

	if vim.bo.filetype == "cs" then
		load_core()
	end

	local group = vim.api.nvim_create_augroup("DapGodot", { clear = true })

	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = "cs",
		callback = load_core,
	})

	vim.api.nvim_create_autocmd("DirChanged", {
		group = group,
		callback = function()
			if loaded then
				vim.schedule(function()
					require("dap-godot-mono.core").configure(user_opts)
				end)
			elseif is_godot_project() then
				load_core()
			end
		end,
	})
end

return M
