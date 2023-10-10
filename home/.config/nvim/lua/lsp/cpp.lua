require('lsp.utility.goDef')
require('lspconfig').clangd.setup{
	on_attach = on_attach,
	flags = {
		debounce_text_changes = 150,
	}
}

