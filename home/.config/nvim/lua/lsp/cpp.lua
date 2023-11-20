require('lsp.utility.goDef')
local capabilities = require('cmp_nvim_lsp').default_capabilities()
require('lspconfig').clangd.setup{
    capabilities = capabilities,
	flags = {
		debounce_text_changes = 150,
	}
}

