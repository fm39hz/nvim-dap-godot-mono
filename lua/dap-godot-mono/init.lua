local M = {}

local default_opts = {
	godot_executable = os.getenv("GODOT") or "godot",
	netcoredbg_path = vim.fn.exepath("netcoredbg"),
	verbose = false,
}

local config = {}
local project_cache = {}

local function find_godot_project()
	local current_dir = vim.fn.getcwd()

	if project_cache[current_dir] then
		return project_cache[current_dir].dir_path
	end

	local found_file = vim.fs.find("project.godot", {
		path = current_dir,
		upward = true,
		type = "file",
		stop = vim.env.HOME,
	})[1]

	if found_file then
		local project_dir = vim.fs.dirname(found_file)
		project_cache[current_dir] = { dir_path = project_dir }
		return project_dir
	end

	return nil
end

local function setup_overseer_task()
	local has_overseer, overseer = pcall(require, "overseer")
	if not has_overseer then
		return
	end

	overseer.register_template({
		name = "Godot Build",
		builder = function()
			local project_dir = find_godot_project() or vim.fn.getcwd()
			return {
				cmd = { "dotnet", "build" },
				cwd = project_dir,
				components = { "default", "on_output_quickfix" },
			}
		end,
		condition = {
			callback = function()
				return find_godot_project() ~= nil
			end,
		},
	})
end

function M.setup(opts)
	local project_dir = find_godot_project()
	if not project_dir then
		return
	end

	config = vim.tbl_deep_extend("force", default_opts, opts or {})
	local ok, dap = pcall(require, "dap")
	if not ok then
		return
	end

	setup_overseer_task()

	dap.adapters.godot = function(cb, adapter_conf)
		local args = { "--interpreter=vscode", "--", config.godot_executable, "--path", project_dir }

		if config.verbose then
			table.insert(args, "--verbose")
		end
		if adapter_conf.args then
			local extra = type(adapter_conf.args) == "table" and adapter_conf.args or { adapter_conf.args }
			for _, arg in ipairs(extra) do
				table.insert(args, arg)
			end
		end

		cb({
			type = "executable",
			command = config.netcoredbg_path,
			args = args,
			options = { cwd = project_dir },
		})
	end

	dap.configurations.cs = dap.configurations.cs or {}

	local godot_config = {
		type = "godot",
		name = "Godot: Launch Game",
		request = "launch",
		program = "",
		preLaunchTask = "Godot Build",
	}

	table.insert(dap.configurations.cs, 1, godot_config)
end

return M
