return {
  {
    "AstroNvim/astrolsp",
    opts = {
      config = {
        tinymist = {
          -- Keep standalone documents usable outside a Git repository.
          root_dir = function(bufnr, on_dir)
            local root = vim.fs.root(bufnr, { "typst.toml", ".git" })
            on_dir(root or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
          end,
        },
      },
    },
  },
  {
    "chomosuke/typst-preview.nvim",
    -- Load its configured Mason binary paths before updating preview dependencies.
    build = ":lua require('typst-preview').update()",
    keys = {
      { "<leader>cp", "<cmd>TypstPreviewToggle<cr>", ft = "typst", desc = "Toggle Typst Preview" },
    },
  },
}
