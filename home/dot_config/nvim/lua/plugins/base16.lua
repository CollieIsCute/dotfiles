return {
  { "RRethy/base16-nvim", lazy = true },
  {
    "AstroNvim/astroui",
    dependencies = { "RRethy/base16-nvim" },
    opts = { colorscheme = "matugen" },
  },
}
