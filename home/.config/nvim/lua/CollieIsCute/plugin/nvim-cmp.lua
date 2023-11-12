local cmp = require('cmp')
cmp.seutp({
    snippet = {
        expand = function(args)
            require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
        end,
    },
    sources = {
        { name = 'snippet' },
        { name = 'buffer' },
        { name = 'path' },
    },
})
