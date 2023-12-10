local ls = require("luasnip")
local s = ls.s
local fmt = require("luasnip.extras.fmt").fmt
local i = ls.insert_node
local rep = require("luasnip.extras").rep

ls.add_snippets("cpp", {
    -- include files
    s("inc", fmt("#include<{}>", i(1))),
    s("cls", fmt("class {} {{\nprivate:\npublic:\n}}", i(1))),
})

