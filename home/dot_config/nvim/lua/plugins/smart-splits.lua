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
        for arrow, key in pairs({ Left = "H", Down = "J", Up = "K", Right = "L" }) do
          maps["<M-" .. arrow .. ">"] = maps["<C-" .. arrow .. ">"]
          maps["<C-" .. arrow .. ">"] = maps["<C-" .. key .. ">"]
        end
      end,
    },
  },
}
