return {
  {
    "AstroNvim/astrocore",
    opts = { treesitter = { ensure_installed = { "asm" } } },
  },
  {
    "AstroNvim/astrolsp",
    opts = { servers = { "asm_lsp" } },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = { ensure_installed = { "asm-lsp" } },
  },
}
