require("lazy").setup({
  {
    "AstroNvim/AstroNvim",
    version = "^6",
    import = "astronvim.plugins",
    opts = {
      mapleader = " ",
      maplocalleader = ",",
    },
  },
  { import = "community" },
  { import = "plugins" },
}, {
  install = { colorscheme = { "astrotheme", "habamax" } },
  checker = { enabled = true, notify = false },
  ui = { backdrop = 100 },
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "netrwPlugin", "tarPlugin", "tohtml", "zipPlugin" },
    },
  },
})
