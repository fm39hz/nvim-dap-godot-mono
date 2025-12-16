local M = {}

local default_opts = {
  godot = {
    godot_executable = os.getenv("GODOT") or "godot",
    netcoredbg_path = nil,
    verbose = false,
    build_cmd = { "dotnet", "build" },
    scene_exclude_patterns = { "/addons/", "/%.godot/" },
    ignored_dirs = { ".git", ".godot", ".import", "node_modules", "bin", "obj", "addons", "build", "dist" },
    scan_depth = 2,
  },

}

local loaded = false
local user_opts = {}

local function is_godot_project()
  local ok, core = pcall(require, "dap-godot-mono.core")
  if ok and core and type(core.find_godot_project) == "function" then
    return core.find_godot_project({
      ignored_dirs = default_opts.godot.ignored_dirs,
      scan_depth = default_opts.godot.scan_depth,
    }) ~= nil
  end

  return vim.fs.find("project.godot", {
    upward = true,
    stop = vim.env.HOME,
    path = vim.fn.getcwd(),
  })[1] ~= nil
end

function M.setup(opts)
  opts = opts or {}
  -- ensure backward-compat: migrate top-level godot keys into `opts.godot`
  local migrated = false
  local godot_keys = { "godot_executable", "netcoredbg_path", "verbose", "build_cmd", "scene_exclude_patterns", "ignored_dirs", "scan_depth", "sln_scan_depth" }
  opts.godot = opts.godot or {}
  for _, k in ipairs(godot_keys) do
    if opts[k] ~= nil and opts.godot[k] == nil then
      opts.godot[k] = opts[k]
      opts[k] = nil
      migrated = true
    end
  end
  if migrated then
    vim.notify("dap-godot-mono: top-level godot options are deprecated — move them under `godot = { ... }`. Migrated for now.", vim.log.levels.WARN)
  end

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
      local core = require("dap-godot-mono.core")
      core.clear_caches()

      if loaded then
        vim.schedule(function()
          core.configure(user_opts)
        end)
      elseif is_godot_project() then
        load_core()
      end
    end,
  })
end

return M
