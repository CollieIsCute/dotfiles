require('lsp.utility.goDef')
require('lspconfig').lua_ls.setup{
	on_attach = on_attach,
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

