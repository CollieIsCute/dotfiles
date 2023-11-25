require('lsp.utility.goDef')
local capabilities = require('cmp_nvim_lsp').default_capabilities()
require('lspconfig').lua_ls.setup{
    capabilities = capabilities,
	flags = {
		debounce_text_changes = 150,
	},
    settings = {
        Lua = {
            diagnostics = {
                -- Get the language server to recognize the `vim` global
                globals = {'vim'},
            },
        },
    },
}

