-- :h mason-default-settings
require("mason").setup({
  PATH = "prepend",
  ui = {
    icons = {
      package_installed = "✓",
      package_pending = "➜",
      package_uninstalled = "✗",
    },
  },
})

require("mason-lspconfig").setup({
    ensure_installed = {
		"clangd"
	}
})
