local M = {}

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

M.config = vim.deepcopy(default_config)

local function merge_config(user_config)
  if not user_config then
    return
  end
  for k, v in pairs(user_config) do
    if type(v) == "table" and type(M.config[k]) == "table" then
      M.config[k] = v
    else
      M.config[k] = v
    end
  end
end

local function get_lsp_root(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local clients = {}

  if vim.lsp.get_clients then
    clients = vim.lsp.get_clients({ bufnr = bufnr })
  elseif vim.lsp.buf_get_clients then
    clients = vim.lsp.buf_get_clients(bufnr)
  else
    clients = vim.lsp.get_active_clients()
  end

  if not clients then
    return nil
  end

  for _, client in ipairs(clients) do
    local root = (client.config and client.config.root_dir)
        or client.root_dir
    if root and root ~= "" then
      return root
    end
  end

  return nil
end

-- Get pattern root for a buffer using vim.fs.find
local function get_pattern_root(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return nil
  end

  local dir = vim.fs.dirname(name)
  if not dir or dir == "" then
    return nil
  end

  local patterns = M.config.patterns or {}
  if #patterns == 0 then
    return nil
  end

  local found = vim.fs.find(patterns, {
    path = dir,
    upward = true,
    stop = vim.loop.os_homedir(),
  })

  if #found > 0 then
    return vim.fs.dirname(found[1])
  end

  return nil
end

-- Determine project root based on detection_methods
local function detect_root(bufnr)
  local methods = M.config.detection_methods or {}

  for _, method in ipairs(methods) do
    if method == "pattern" then
      local root = get_pattern_root(bufnr)
      if root then
        return root, "pattern"
      end
    elseif method == "lsp" then
      local root = get_lsp_root(bufnr)
      if root then
        return root, "lsp"
      end
    end
  end

  return nil, nil
end

-- Set cwd if appropriate
local function set_cwd_for_buf(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Skip special buffers
  local bt = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
  if bt ~= "" then
    return
  end

  -- Skip unnamed buffers
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return
  end

  local root, _ = detect_root(bufnr)
  if not root then
    return
  end

  local cwd = vim.loop.cwd()
  if cwd == root then
    return
  end

  local ok, err
  if M.config.use_local_cwd then
    ok, err = pcall(vim.cmd.lcd, root)
  else
    ok, err = pcall(vim.fn.chdir, root)
  end

  if not ok then
    vim.notify(
      ("project.nvim: failed to change directory to %s: %s"):format(root, err),
      vim.log.levels.WARN
    )
    return
  end
end

local function setup_user_commands()
  vim.api.nvim_create_user_command("ProjectRoot", function()
    set_cwd_for_buf(0)
  end, {
    desc = "Detect and set project root for current buffer",
  })
end

local function setup_autocmds()
  local group = vim.api.nvim_create_augroup("ProjectRootAutocmd", {
    clear = true,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(args)
      set_cwd_for_buf(args.buf)
    end,
    desc = "Set project root cwd on buffer enter",
  })
end

function M.setup(user_config)
  merge_config(user_config)
  setup_autocmds()
  setup_user_commands()
end

return M
