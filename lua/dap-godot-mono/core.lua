local M = {}

local project_cache = {}
local scene_cache = {}
local plugin_configs_registered = false

local function clear_caches()
  project_cache = {}
  scene_cache = {}
  plugin_configs_registered = false
end

M.clear_caches = clear_caches

local DEFAULT_IGNORED_DIRS = {
  [".git"] = true,
  [".godot"] = true,
  [".import"] = true,
  ["node_modules"] = true,
  ["bin"] = true,
  ["obj"] = true,
  ["addons"] = true,
  ["build"] = true,
  ["dist"] = true,
}

local function get_opt(opts, key)
  if opts and opts.godot ~= nil and opts.godot[key] ~= nil then
    return opts.godot[key]
  end
  if opts then
    return opts[key]
  end
  return nil
end

local function fast_find_file(filename, dir, depth, max_depth, ignored)
  if depth > max_depth then
    return nil
  end
  local ok, handle = pcall(vim.uv.fs_scandir, dir)
  if not ok or not handle then
    return nil
  end
  local dirs_to_check = {}
  while true do
    local name, ftype = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    local full = dir .. "/" .. name
    if ftype == "file" and name == filename then
      return full
    elseif ftype == "directory" then
      if not ignored[name] then
        table.insert(dirs_to_check, full)
      end
    end
  end
  for _, sub in ipairs(dirs_to_check) do
    local found = fast_find_file(filename, sub, depth + 1, max_depth, ignored)
    if found then
      return found
    end
  end
  return nil
end

local function find_godot_project(opts)
  opts = opts or {}
  local current_dir = vim.fn.getcwd()
  if project_cache[current_dir] then
    return project_cache[current_dir].dir_path
  end
  local ignored = DEFAULT_IGNORED_DIRS
  local user_ignored = get_opt(opts, "ignored_dirs")
  if user_ignored and type(user_ignored) == "table" then
    local map = {}
    for k, v in pairs(DEFAULT_IGNORED_DIRS) do
      map[k] = v
    end
    for _, name in ipairs(user_ignored) do
      map[name] = true
    end
    ignored = map
  end
  local max_depth = get_opt(opts, "scan_depth") or get_opt(opts, "sln_scan_depth") or 2 -- `scan_depth` preferred; `sln_scan_depth` kept for compatibility
  local function sln_in_dir(dir)
    local ok, handle = pcall(vim.uv.fs_scandir, dir)
    if not ok or not handle then
      return nil
    end
    while true do
      local name, ftype = vim.uv.fs_scandir_next(handle)
      if not name then
        break
      end
      if ftype == "file" and name:match("%.sln$") then
        return dir .. "/" .. name
      end
    end
    return nil
  end
  local sln_here = sln_in_dir(current_dir)
  if sln_here then
    local found = fast_find_file("project.godot", current_dir, 0, max_depth, ignored)
    if found then
      local project_dir = vim.fs.dirname(found)
      project_cache[current_dir] = { dir_path = project_dir, sln = sln_here }
      return project_dir
    end
  end
  local sln_candidate = nil
  local sln_candidate_dir = nil
  local ok, handle = pcall(vim.uv.fs_scandir, current_dir)
  if ok and handle then
    while true do
      local name, ftype = vim.uv.fs_scandir_next(handle)
      if not name then
        break
      end
      if ftype == "directory" then
        local child = current_dir .. "/" .. name
        local s = sln_in_dir(child)
        if s then
          sln_candidate = s
          sln_candidate_dir = child
          break
        end
      end
    end
  end
  if not sln_candidate then
    local parent = vim.fn.fnamemodify(current_dir, ":h")
    if parent and parent ~= current_dir then
      local s = sln_in_dir(parent)
      if s then
        sln_candidate = s
        sln_candidate_dir = parent
      end
    end
  end
  if sln_candidate and sln_candidate_dir then
    local found = fast_find_file("project.godot", sln_candidate_dir, 0, max_depth, ignored)
    if found then
      local project_dir = vim.fs.dirname(found)
      project_cache[current_dir] = { dir_path = project_dir, sln = sln_candidate }
      return project_dir
    end
  end
  local sln_up = vim.fs.find(function(name)
    return name:match("%.sln$")
  end, {
    upward = true,
    path = current_dir,
    stop = vim.env.HOME,
  })[1]
  if sln_up then
    local sln_up_dir = vim.fs.dirname(sln_up)
    local found = fast_find_file("project.godot", sln_up_dir, 0, max_depth, ignored)
    if found then
      local project_dir = vim.fs.dirname(found)
      project_cache[current_dir] = { dir_path = project_dir, sln = sln_up }
      return project_dir
    end
  end
  project_cache[current_dir] = { dir_path = nil, sln = nil }
  return nil
end

local function get_cached_sln_for_cwd()
  local current_dir = vim.fn.getcwd()
  local entry = project_cache[current_dir]
  if entry then
    return entry.sln
  end
  return nil
end

local function find_scenes(project_dir, exclude_patterns)
  if scene_cache[project_dir] then
    return scene_cache[project_dir]
  end
  local scenes = vim.fn.globpath(project_dir, "**/*.tscn", true, true)
  local filtered_scenes = {}
  exclude_patterns = exclude_patterns or {}
  for _, scene in ipairs(scenes) do
    local should_exclude = false
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
  return get_opt(opts, "godot_executable")
end

local function build_launch_args(godot_exe, project_dir, scene_path, opts, adapter_conf)
  local args = { "--interpreter=vscode", "--", godot_exe, "--path", project_dir }
  if get_opt(opts, "verbose") then
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
  local scenes = find_scenes(project_dir, get_opt(opts, "scene_exclude_patterns"))
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
  opts = opts or {}
  local project_dir = find_godot_project(opts)
  if not project_dir then
    return
  end
  local sln_path = get_cached_sln_for_cwd()
  local build_cmd = get_opt(opts, "build_cmd")
  if sln_path and build_cmd and type(build_cmd) == "table" then
    local already = false
    for _, v in ipairs(build_cmd) do
      if v == sln_path then
        already = true
        break
      end
    end
    if not already then
      local new_build = {}
      for _, v in ipairs(build_cmd) do
        table.insert(new_build, v)
      end
      table.insert(new_build, sln_path)
      -- prefer to write back to opts.godot if present, otherwise top-level
      if opts.godot then
        opts.godot.build_cmd = new_build
      else
        opts.build_cmd = new_build
      end
      build_cmd = new_build
    end
  end
  local netcoredbg_path = get_opt(opts, "netcoredbg_path") or vim.fn.exepath("netcoredbg")
  if netcoredbg_path == "" then
    vim.notify(
      "dap-godot-mono: 'netcoredbg' not found.\n"
      .. "Please install it via Mason (:Mason) or set 'netcoredbg_path' in your config.",
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
  if not plugin_configs_registered then
    local configs = {
      {
        type = "godot",
        name = "Godot: Select Scene to Launch",
        request = "launch",
        program = "",
        preLaunchTask = "Godot Build",
        scene_picker = true,
        _godot_plugin_config = true,
      },
      {
        type = "godot",
        name = "Godot: Launch Main Scene",
        request = "launch",
        program = "",
        preLaunchTask = "Godot Build",
        _godot_plugin_config = true,
      },
    }
    for _, cfg in ipairs(configs) do
      table.insert(dap.configurations.cs, 1, cfg)
    end
    plugin_configs_registered = true
  end
  setup_overseer_task(build_cmd)
end

M.find_godot_project = find_godot_project

return M
