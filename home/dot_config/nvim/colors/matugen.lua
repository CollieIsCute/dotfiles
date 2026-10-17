-- Matugen owns lua/matugen.lua; keep its generated palette and live reload hook.
local ok, matugen = pcall(require, "matugen")
if ok then
  matugen.setup()
  vim.g.colors_name = "matugen"
else
  vim.cmd.colorscheme("base16-default-dark")
end
