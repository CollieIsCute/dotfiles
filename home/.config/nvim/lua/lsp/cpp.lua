require('lsp.utility.goDef')
local capabilities = require('cmp_nvim_lsp').default_capabilities()
require('lspconfig').clangd.setup{
    capabilities = capabilities,
	flags = {
		debounce_text_changes = 150,
	}
}

local ls = require("luasnip")
local s = ls.s -- This is a snippet creator. ex. s(<trigger>, <nodes>)

-- This is a format node.
-- It takes a format string, and a list of nodes
-- fmt(<fmt_string>, {...nodes})
local fmt = require("luasnip.extras.fmt").fmt

-- This is an insert_node
-- It takes a position (like $1) and optionally some default text
-- i(<opsition>, [default_text])
local i = ls.insert_node

-- Repeats a node
-- rep(<position>)
local rep = require("luasnip.extras").rep

ls.snippets = {
    cpp = {
        s("inc", fmt("#include<{}>", {i(1, "default")})),
    }
}
