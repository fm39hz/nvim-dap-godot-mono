local M = {}

local project_cache = {}
local scene_cache = {}
local plugin_configs_registered = false

-- Clear all caches (useful when directory changes)
local function clear_caches()
  project_cache = {}
  scene_cache = {}
  plugin_configs_registered = false
end

M.clear_caches = clear_caches

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

local function find_scenes(project_dir, exclude_patterns)
  -- Check cache first
  if scene_cache[project_dir] then
    return scene_cache[project_dir]
  end

  local scenes = vim.fn.globpath(project_dir, "**/*.tscn", true, true)
  local filtered_scenes = {}

  for _, scene in ipairs(scenes) do
    local should_exclude = false
    
    -- Check against exclude patterns
    for _, pattern in ipairs(exclude_patterns) do
      if string.match(scene, pattern) then
        should_exclude = true
        break
      end
    end
    
    if not should_exclude then
      local relative_path = vim.fn.fnamemodify(scene, ":.")
      table.insert(filtered_scenes, relative_path)
    end
  end
  
  -- Cache the results
  scene_cache[project_dir] = filtered_scenes
  return filtered_scenes
end

local function setup_overseer_task(build_cmd)
  local has_overseer, overseer = pcall(require, "overseer")
  if not has_overseer then
    return
  end
  overseer.register_template({
    name = "Godot Build",
    builder = function()
      local project_dir = find_godot_project() or vim.fn.getcwd()
      return {
        cmd = build_cmd,
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

local function get_godot_executable(adapter_conf, opts)
  if adapter_conf.program and adapter_conf.program ~= "" then
    return adapter_conf.program
  end
  return opts.godot_executable
end

local function build_launch_args(godot_exe, project_dir, scene_path, opts, adapter_conf)
  local args = { "--interpreter=vscode", "--", godot_exe, "--path", project_dir }

  if opts.verbose then
    table.insert(args, "--verbose")
  end

  if scene_path then
    table.insert(args, scene_path)
  end

  if adapter_conf.args then
    local extra_args = type(adapter_conf.args) == "table" and adapter_conf.args or { adapter_conf.args }
    vim.list_extend(args, extra_args)
  end

  return args
end

local function show_scene_picker(project_dir, opts, launch_callback)
  local scenes = find_scenes(project_dir, opts.scene_exclude_patterns)
  
  if #scenes == 0 then
    vim.notify("No .tscn files found!", vim.log.levels.WARN)
    launch_callback(nil)
    return
  end

  vim.ui.select(scenes, {
    prompt = "Select Scene to Launch:",
    format_item = function(item)
      return "🎬 " .. item
    end,
  }, function(choice)
    if choice then
      launch_callback(choice)
    else
      vim.notify("Debug cancelled", vim.log.levels.INFO)
    end
  end)
end

function M.configure(opts)
  if not find_godot_project() then
    return
  end

  local netcoredbg_path = opts.netcoredbg_path or vim.fn.exepath("netcoredbg")
  if netcoredbg_path == "" then
    vim.notify(
      "dap-godot-mono: 'netcoredbg' not found.\n" ..
      "Please install it via Mason (:Mason) or set 'netcoredbg_path' in your config.",
      vim.log.levels.ERROR
    )
    return
  end

  local ok, dap = pcall(require, "dap")
  if not ok then
    return
  end

  dap.adapters.godot = function(cb, adapter_conf)
    local project_dir = find_godot_project() or vim.fn.getcwd()
    local godot_exe = get_godot_executable(adapter_conf, opts)

    local function launch_debug(scene_path)
      local args = build_launch_args(godot_exe, project_dir, scene_path, opts, adapter_conf)
      cb({
        type = "executable",
        command = netcoredbg_path,
        args = args,
        options = { cwd = project_dir, env = adapter_conf.env },
      })
    end

    if adapter_conf.scene_picker then
      show_scene_picker(project_dir, opts, launch_debug)
    else
      launch_debug(nil)
    end
  end

  dap.configurations.cs = dap.configurations.cs or {}

  -- Only add configurations once to avoid duplicates and preserve user configs
  if not plugin_configs_registered then
    local configs = {
      {
        type = "godot",
        name = "Godot: Select Scene to Launch",
        request = "launch",
        program = "",
        preLaunchTask = "Godot Build",
        scene_picker = true,
        _godot_plugin_config = true, -- Mark as plugin-added
      },
      {
        type = "godot",
        name = "Godot: Launch Main Scene",
        request = "launch",
        program = "",
        preLaunchTask = "Godot Build",
        _godot_plugin_config = true, -- Mark as plugin-added
      },
    }

    for _, cfg in ipairs(configs) do
      table.insert(dap.configurations.cs, 1, cfg)
    end
    
    plugin_configs_registered = true
  end

  setup_overseer_task(opts.build_cmd)
end

return M
