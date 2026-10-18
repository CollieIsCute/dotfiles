return {
  "mrjones2014/smart-splits.nvim",
  lazy = false,
  opts = {
    multiplexer_integration = "tmux",
  },
  specs = {
    {
      "AstroNvim/astrocore",
      opts = function(_, opts)
        local maps = opts.mappings.n
        for arrow, key in pairs({ Left = "h", Down = "j", Up = "k", Right = "l" }) do
          maps["<M-" .. key .. ">"] = maps["<C-" .. arrow .. ">"]
          maps["<C-" .. arrow .. ">"] = false
        end
      end,
    },
  },
}
