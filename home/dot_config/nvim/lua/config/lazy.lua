local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	spec = {
		{ "LazyVim/LazyVim", import = "lazyvim.plugins" },
		-- Picker extra (Snacks Picker - recommended by folke)
		{ import = "lazyvim.plugins.extras.editor.snacks_picker" },
		-- Language extras
		{ import = "lazyvim.plugins.extras.lang.clangd" },
		-- AI extras (copilot inline + NES, chat replaced by CodeCompanion)
		{ import = "lazyvim.plugins.extras.ai.copilot" },
		{ import = "lazyvim.plugins.extras.ai.sidekick" },
		-- Custom plugin overrides
		{ import = "plugins" },
	},
	checker = { enabled = true, notify = false },
})
