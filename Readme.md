# nvim-dap-godot-mono

A simple, "it just works" adapter to debug **Godot 4 (Mono/C\#)** projects using [nvim-dap](https://github.com/mfussenegger/nvim-dap) and [netcoredbg](https://github.com/Samsung/netcoredbg).

This plugin automatically detects if you are in a Godot project. If detected, it registers the necessary DAP configurations to build and debug your game. If not, it stays silent and doesn't pollute your standard .NET debugger list.

## ✨ Features

- **Auto-detection**: Only activates when a `project.godot` file is found.
- **Seamless Integration**: Injects "Godot: Launch Game" directly into `dap.configurations.cs`.
- **Build Support**: Integrates with [overseer.nvim](https://github.com/stevearc/overseer.nvim) to automatically run `dotnet build` before debugging (reports errors in Quickfix).
- **Environment Aware**: Respects your `GODOT` environment variable or looks for `godot` in your PATH.


https://github.com/user-attachments/assets/9acb26ed-4338-4991-9312-a0350118537e


## ⚡ Requirements

- Neovim \>= 0.9.0
- [nvim-dap](https://github.com/mfussenegger/nvim-dap)
- [overseer.nvim](https://github.com/stevearc/overseer.nvim) (Handling builds)
- **netcoredbg**: You must have `netcoredbg` installed (via Mason or system package manager).
- **Godot 4 (.NET version)**

## 📦 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "fm39hz/nvim-dap-godot-mono",
  dependencies = {
    "mfussenegger/nvim-dap",
    "stevearc/overseer.nvim",
  },
  ft = "cs",
  opts = {}
}
```

## ⚙️ Configuration

The plugin works out of the box for most setups. However, you can pass a configuration table to the `setup()` function.

**Default Configuration:**

```lua
require("dap-godot-mono").setup({
  -- Path to the Godot executable.
  -- Defaults to the $GODOT environment variable, or "godot" if not set.
  godot_executable = os.getenv("GODOT") or "godot",

  -- Path to netcoredbg executable.
  -- Defaults to looking it up in your PATH (works with Mason).
  netcoredbg_path = vim.fn.exepath("netcoredbg"),

  -- Whether to print extra debug info
  verbose = false,
})
```

### Options Explained

| Option             | Type      | Description                                                                                                                                                             |
| :----------------- | :-------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `godot_executable` | `string`  | The command to launch Godot. If you have Godot in your PATH, leave this as `"godot"`. If you use a flatpak or a specific path, set it here (e.g., `"/usr/bin/godot4"`). |
| `netcoredbg_path`  | `string`  | Path to the `netcoredbg` binary. If you installed it via Mason, `vim.fn.exepath("netcoredbg")` handles this automatically.                                              |
| `verbose`          | `boolean` | If `true`, adds `--verbose` flag to Godot launch arguments for detailed logs.                                                                                           |

## 🚀 Usage

1. Open a C\# file (`.cs`) inside your Godot project.
2. Set a breakpoint using `nvim-dap` (e.g., `:DapToggleBreakpoint`).
3. Start debugging (e.g., `:DapContinue` or press F5).
4. Select **"Godot: Launch Game"** from the menu (it will be the first option).
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
