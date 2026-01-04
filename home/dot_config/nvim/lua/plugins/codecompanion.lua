-- CodeCompanion.nvim with Copilot adapter and VectorCode integration
-- Replaces copilot-chat with better codebase search capabilities
-- Uses <leader>C prefix to avoid conflict with Sidekick's <leader>a keys
return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "Davidyz/VectorCode", -- Semantic code indexing
    },
    cmd = {
      "CodeCompanion",
      "CodeCompanionChat",
      "CodeCompanionActions",
      "CodeCompanionCmd",
    },
    opts = {
      -- Use Copilot adapter with Claude Opus 4.5 for chat (strongest model)
      adapters = {
        copilot = function()
          return require("codecompanion.adapters").extend("copilot", {
            schema = {
              model = {
                default = "claude-opus-4.5",
              },
            },
          })
        end,
      },
      -- Set Copilot as default for all interactions
      interactions = {
        chat = {
          adapter = "copilot",
        },
        inline = {
          adapter = "copilot",
        },
        cmd = {
          adapter = "copilot",
        },
      },
      -- VectorCode extension for semantic codebase search
      extensions = {
        vectorcode = {
          opts = {
            add_tool = true,
            add_slash_command = true,
          },
        },
      },
      -- Display settings
      display = {
        chat = {
          window = {
            layout = "vertical",
            width = 0.4,
          },
          show_settings = false, -- Must be false to allow adapter switching with 'ga'
        },
        diff = {
          provider = "mini_diff",
        },
      },
    },
    -- Use <leader>C prefix (capital C for CodeCompanion)
    -- Avoids conflict with Sidekick's <leader>a keys
    keys = {
      -- Chat (using <leader>C for CodeCompanion)
      { "<leader>CC", "<cmd>CodeCompanionChat Toggle<cr>", desc = "CodeCompanion Chat Toggle", mode = { "n", "v" } },
      { "<leader>Cc", "<cmd>CodeCompanionChat<cr>", desc = "New CodeCompanion Chat", mode = { "n", "v" } },
      -- Actions
      { "<leader>Ca", "<cmd>CodeCompanionActions<cr>", desc = "CodeCompanion Actions", mode = { "n", "v" } },
      -- Add to chat
      { "<leader>Ct", "<cmd>CodeCompanionChat Add<cr>", desc = "Add to CodeCompanion Chat", mode = "v" },
      -- Inline
      { "<leader>Ci", "<cmd>CodeCompanion<cr>", desc = "CodeCompanion Inline", mode = { "n", "v" } },
      -- Quick actions
      { "<leader>Ce", "<cmd>CodeCompanionCmd /explain<cr>", desc = "Explain Code", mode = "v" },
      { "<leader>Cf", "<cmd>CodeCompanionCmd /fix<cr>", desc = "Fix Code", mode = "v" },
      { "<leader>Cr", "<cmd>CodeCompanionCmd /refactor<cr>", desc = "Refactor Code", mode = "v" },
    },
    config = function(_, opts)
      require("codecompanion").setup(opts)
      -- Register which-key group
      local ok, wk = pcall(require, "which-key")
      if ok then
        wk.add({
          { "<leader>C", group = "+CodeCompanion" },
        })
      end
    end,
  },
  -- VectorCode for semantic code indexing
  {
    "Davidyz/VectorCode",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "VectorCode" },
    build = "uv tool upgrade vectorcode || uv tool install --force vectorcode",
    opts = {
      async_backend = "lsp",
      notify = true,
      n_query = 10,
    },
  },
}
