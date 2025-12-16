# nvim-dap-godot-mono

A simple adapter to debug Godot 4 (Mono/C#) projects using nvim-dap and netcoredbg.

The plugin detects Godot projects by locating a .sln file (solution) and then searching downward from the solution directory for a `project.godot` file. Detection options include `ignored_dirs` to skip heavy folders and `scan_depth` to control how deep the downward scan runs.

## Features

- Auto-detection based on .sln -> project.godot
- Injects Godot DAP configurations into `dap.configurations.cs`
- Integrates with overseer.nvim to run `dotnet build` before debugging
- Honors `GODOT` environment variable or looks for `godot` in PATH

<https://github.com/user-attachments/assets/9acb26ed-4338-4991-9312-a0350118537e>

## ⚡ Requirements

- Neovim \>= 0.9.0
- [nvim-dap](https://github.com/mfussenegger/nvim-dap)
- [overseer.nvim](https://github.com/stevearc/overseer.nvim) (Handling builds)
- **netcoredbg**: You must have `netcoredbg` installed (via Mason or system package manager).
- **Godot 4 (.NET version)**
- **.NET SDK**: Required to run `dotnet build`.

## 📦 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "fm39hz/nvim-dap-godot-mono",
  dependencies = {
    "stevearc/overseer.nvim", -- Required for build tasks
    -- Note: nvim-dap is NOT listed here to avoid loading it too early.
    -- The plugin will load nvim-dap lazily when a C# file is opened.
  },
  ft = "cs",
  opts = {}
}
```

## ⚙️ Configuration

Here is the default setup configuration. You can customize it by passing your own options to the `opts`.

**Default Configuration:**

```lua
 {
  "fm39hz/nvim-dap-godot-mono",
  dependencies = {
   "stevearc/overseer.nvim",
  },
  ft = "cs",
  opts = {
    -- Godot-specific configuration grouped under `godot`.
    godot = {
      -- Path to the Godot executable.
      -- Defaults to the $GODOT environment variable, or "godot" if not set.
      godot_executable = os.getenv("GODOT") or "godot",

      -- Path to netcoredbg executable.
      -- Defaults to looking it up in your PATH (works with Mason).
      -- Set to nil to let the plugin auto-detect.
      netcoredbg_path = nil,

      -- Whether to print extra debug info
      verbose = false,

      -- Custom build command
      -- Defaults to { "dotnet", "build" }
      build_cmd = { "dotnet", "build" },

      -- How deep to scan from the solution directory for project.godot
      -- Defaults to 2. Set to 0 to only check the solution directory.
      scan_depth = 2,

      -- Scene exclusion patterns (Lua patterns)
      -- Scenes matching these patterns will be excluded from the scene picker
      -- Defaults to { "/addons/", "/%.godot/" }
      scene_exclude_patterns = { "/addons/", "/%.godot/" },
    },

    -- Backwards compatibility: old top-level keys are still accepted but
    -- nesting them under `godot` is preferred and will be required in a
    -- future release. If you still use top-level keys they will be migrated
    -- with a deprecation warning.
  },
 },
```

### Options Explained

| Option                   | Type      | Description                                                                                                                                                             |
| :----------------------- | :-------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `godot_executable`       | `string`  | The command to launch Godot. If you have Godot in your PATH, leave this as `"godot"`. If you use a flatpak or a specific path, set it here (e.g., `"/usr/bin/godot4"`). |
| `netcoredbg_path`        | `string`  | Path to the `netcoredbg` binary. If you installed it via Mason, `vim.fn.exepath("netcoredbg")` handles this automatically.                                              |
| `verbose`                | `boolean` | If `true`, adds `--verbose` flag to Godot launch arguments for detailed logs.                                                                                           |
| `build_cmd`              | `table`   | Custom build command as a table (e.g., `{ "dotnet", "build", "--configuration", "Debug" }`). Defaults to `{ "dotnet", "build" }`.                                       |
| `scan_depth`         | `number`  | How deep to scan downward from the solution directory for `project.godot`. Defaults to `2`. Set to `0` to only check the solution directory, or higher to recurse more. `sln_scan_depth` is accepted for compatibility. |
| `scene_exclude_patterns` | `table`   | List of Lua patterns to exclude scenes from the picker. Defaults to `{ "/addons/", "/%.godot/" }`. Add custom patterns like `"/test/"` to exclude test scenes.          |

## 🚀 Usage

1. Open a C\# file (`.cs`) inside your Godot project.
2. Set a breakpoint using `nvim-dap` (e.g., `:DapToggleBreakpoint`).
3. Start debugging (e.g., `:DapContinue` or press F5).
4. Select one of the available options:
   - **"Godot: Launch Main Scene"** - Launches the main scene defined in project settings
   - **"Godot: Select Scene to Launch"** - Shows a picker to select which scene to launch
5. The plugin will trigger a `dotnet build` via Overseer.
   - If build **fails**: The debugger won't start, and errors will be shown in the Quickfix list.
   - If build **succeeds**: Godot will launch, and the debugger will attach.

## 🤝 Troubleshooting

**"Godot: Launch Game" is not showing up?**
Ensure you are in the root of your project or that a `project.godot` file exists in the parent directories. The plugin does not activate for non-Godot projects.

**Debugger starts but nothing happens?**
Make sure `godot_executable` is pointing to the correct binary. Try setting `verbose = true` in the setup config and check `:messages` for the full command being executed.

**Build fails but no error window?**
Make sure you have `overseer.nvim` installed and configured.
