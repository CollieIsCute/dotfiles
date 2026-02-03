return {
  "CollieIsCute/smart-splits.nvim",
  lazy = false,
  opts = {
    multiplexer_integration = "tmux",
  },
  keys = {
    { "<C-h>", function() require("smart-splits").move_cursor_left() end, desc = "Go to Left Window" },
    { "<C-j>", function() require("smart-splits").move_cursor_down() end, desc = "Go to Lower Window" },
    { "<C-k>", function() require("smart-splits").move_cursor_up() end, desc = "Go to Upper Window" },
    { "<C-l>", function() require("smart-splits").move_cursor_right() end, desc = "Go to Right Window" },
    { "<C-Left>", function() require("smart-splits").resize_left() end, desc = "Resize Left" },
    { "<C-Down>", function() require("smart-splits").resize_down() end, desc = "Resize Down" },
    { "<C-Up>", function() require("smart-splits").resize_up() end, desc = "Resize Up" },
    { "<C-Right>", function() require("smart-splits").resize_right() end, desc = "Resize Right" },
  },
}
