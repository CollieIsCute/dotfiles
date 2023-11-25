require('lsp.utility.goDef')
local capabilities = require('cmp_nvim_lsp').default_capabilities()
require('lspconfig').marksman.setup{
    capabilities = capabilities,
}
