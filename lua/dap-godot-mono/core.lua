local M = {}

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

  project_cache[current_dir] = { dir_path = nil }
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

function M.configure(opts)
  if not find_godot_project() then
    return
  end

  local netcoredbg_path = opts.netcoredbg_path or vim.fn.exepath("netcoredbg")
  if netcoredbg_path == "" then
    vim.notify("dap-godot-mono: 'netcoredbg' not found in PATH.", vim.log.levels.WARN)
    return
  end

  local ok, dap = pcall(require, "dap")
  if not ok then
    return
  end

  dap.adapters.godot = function(cb, adapter_conf)
    local project_dir = find_godot_project() or vim.fn.getcwd()
    local godot_exe = adapter_conf.program and adapter_conf.program ~= "" and adapter_conf.program
        or opts.godot_executable

    local args = { "--interpreter=vscode", "--", godot_exe, "--path", project_dir }

    if opts.verbose then
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
      command = netcoredbg_path,
      args = args,
      options = { cwd = project_dir, env = adapter_conf.env },
    })
  end

  dap.configurations.cs = dap.configurations.cs or {}

  for i = #dap.configurations.cs, 1, -1 do
    if dap.configurations.cs[i].type == "godot" then
      table.remove(dap.configurations.cs, i)
    end
  end

  local configs = {
    {
      type = "godot",
      name = "Godot: Launch Game",
      request = "launch",
      program = "",
      preLaunchTask = "Godot Build",
    },
  }
  for _, cfg in ipairs(configs) do
    table.insert(dap.configurations.cs, 1, cfg)
  end

  setup_overseer_task()
end

return M
