return {
  {
    "iamcco/markdown-preview.nvim",
    -- A command build loads the plugin before calling its Vim autoload function.
    build = ":call mkdp#util#install()",
    init = function()
      vim.g.mkdp_auto_close = 0
    end,
  },
}
