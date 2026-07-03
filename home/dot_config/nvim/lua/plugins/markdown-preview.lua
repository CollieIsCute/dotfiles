return {
  {
    "iamcco/markdown-preview.nvim",
    init = function()
      vim.g.mkdp_auto_close = 0
      vim.g.mkdp_combine_preview = 0
    end,
  },
}
