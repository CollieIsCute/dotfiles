local cmp = require('cmp')
local luasnip = require('luasnip')

local kind_icon = {
    Text = "󱩽",
    Method = "",
    Function = "󰊕",
    Constructor = "󱁤",
    Field = "",
    Variable = "󰆧",
    Class = "󰯱",
    Interface = "",
    Module = "󰕳",
    Property = "",
    Unit = "󰎦",
    Value = "",
    Enum = "",
    Keyword = "󰌆",
    Snippet = "",
    Color = "",
    File = "",
    Reference = "",
    Folder = "",
    EnumMember = "",
    Constant = "",
    Struct = "",
    Event = "",
    Operator = "",
    TypeParameter = "󰗴",
}

cmp.setup({
    formatting = {
        fields = { "kind", "abbr", "menu" },
        format = function(entry, vim_item)
            -- kind_icon
            vim_item.kind = string.format("%s ", kind_icon[vim_item.kind])
            vim_item.menu=({
                luasnip = "[Snippet]",
                buffer = "[Buffer]",
                path = "[Path]",
            })[entry.source.name]
            return vim_item
        end,
    },
    mapping = {
        ["<C-j>"] = cmp.mapping.select_next_item(),
        ["<C-k>"] = cmp.mapping.select_prev_item(),
        ['<C-b>'] = cmp.mapping(cmp.mapping.scroll_docs(-1), { "i", "c" }),
        ['<C-f>'] = cmp.mapping(cmp.mapping.scroll_docs(1), { "i", "c" }),
        ['<C-y>'] = cmp.mapping.confirm {select = true},
        ['<C-e>'] = cmp.mapping{
            i = cmp.mapping.abort(),
            c = cmp.mapping.close(),
        }
    },
    snippet = {
        expand = function(args)
            require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
        end,
    },
    sources = {
        { name = 'nvim_lsp'},
        { name = 'luasnip' },
        { name = 'buffer' },
        { name = 'path' },
    },
    confirm_opts = {
        behavior = cmp.ConfirmBehavior.Replace,
        select = false,
    },
    experimental = {
        ghost_text = true,
        native_menu = false,
    },
})
