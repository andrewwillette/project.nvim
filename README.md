# Project.nvim

Automatically set "current working directory" to respect the context of the open buffer.

Default Configuration:
```lua
local default_config = {
  patterns = {
    ".git",
    "_darcs",
    ".hg",
    ".bzr",
    ".svn",
    "Makefile",
    "package.json",
    "go.mod",
    "pubspec.yaml",
    "Cargo.toml",
  },
  -- order matters: tried in sequence until one finds a root
  detection_methods = { "pattern", "lsp" },
  -- use `:cd` (global cwd). Set to true if you want window-local cwd (`:lcd`)
  use_local_cwd = false,
}
```
