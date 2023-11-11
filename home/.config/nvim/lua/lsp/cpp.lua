require('lsp.utility.goDef')
require('lspconfig').clangd.setup{
	flags = {
		debounce_text_changes = 150,
	}
}

