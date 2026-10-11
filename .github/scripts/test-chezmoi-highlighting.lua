-- Run with installed LazyVim plugins/parsers: nvim --headless -u NONE -i NONE -l .github/scripts/test-chezmoi-highlighting.lua
local data = vim.fn.stdpath("data")
for _, plugin in ipairs({ "LazyVim", "nvim-treesitter" }) do
  vim.opt.rtp:append(data .. "/lazy/" .. plugin)
end
vim.opt.rtp:append(data .. "/site")

LazyVim = { treesitter = require("lazyvim.util.treesitter"), error = error }
local upstream = require("lazyvim.plugins.treesitter")[1]
local override = dofile("home/dot_config/nvim/lua/plugins/chezmoi.lua")[1]
local opts = vim.deepcopy(upstream.opts)
opts.ensure_installed = {}
opts.indent.enable = false
opts.folds.enable = false
opts.highlight.disable = { "toml" }
if override.init then
  override.init()
end
if override.opts then
  override.opts(nil, opts)
end
upstream.config(nil, opts)

local function check(filetype, highlighted)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "print('hello')" })
  vim.bo[buf].filetype = filetype
  vim.wait(20, function()
    return false
  end)
  assert((vim.treesitter.highlighter.active[buf] ~= nil) == highlighted, filetype .. ": unexpected Treesitter state")
  vim.api.nvim_buf_delete(buf, { force = true })
end

check("lua", true)
check("lua.chezmoitmpl", false)
check("chezmoitmpl", false)
check("toml", false)

local changed = vim.api.nvim_create_buf(false, true)
vim.bo[changed].filetype = "lua.chezmoitmpl"
vim.bo[changed].filetype = "lua"
vim.wait(20, function()
  return false
end)
assert(vim.treesitter.highlighter.active[changed], "changed filetype: highlighter stopped")
vim.api.nvim_buf_delete(changed, { force = true })

-- A scheduled callback must tolerate closing the template before it runs.
local buf = vim.api.nvim_create_buf(false, true)
vim.bo[buf].filetype = "lua.chezmoitmpl"
vim.api.nvim_buf_delete(buf, { force = true })
vim.wait(20, function()
  return false
end)
assert(vim.v.errmsg == "", vim.v.errmsg)
print("chezmoi highlighting: PASS")
