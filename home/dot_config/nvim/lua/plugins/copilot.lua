return {
  {
    "zbirenbaum/copilot.lua",
    opts = {
      suggestion = {
        keymap = { accept = false, next = "<M-]>", prev = "<M-[>" },
      },
      panel = { enabled = false },
      filetypes = { markdown = true, help = true },
    },
  },
  {
    "AstroNvim/astrocore",
    opts = {
      options = {
        g = {
          ai_accept = function()
            local suggestion = require("copilot.suggestion")
            if suggestion.is_visible() then
              suggestion.accept()
              return true
            end
          end,
        },
      },
    },
  },
}
