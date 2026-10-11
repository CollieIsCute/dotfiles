-- Disable treesitter highlighting for chezmoi template files
-- Treesitter overwrites chezmoi.vim's layered Vim syntax highlighting
-- https://github.com/alker0/chezmoi.vim#scaletreesitter-nvim-treesitter
return {
  {
    "alker0/chezmoi.vim",
    init = function()
      -- Let chezmoi.vim resolve .chezmoiroot instead of LazyVim's repo-root path.
      vim.g["chezmoi#use_tmp_buffer"] = 1
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "chezmoitmpl", "*.chezmoitmpl" },
        callback = function(ev)
          -- Run after LazyVim's FileType callback starts the highlighter.
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(ev.buf) and vim.bo[ev.buf].filetype:match("chezmoitmpl$") then
              vim.treesitter.stop(ev.buf)
            end
          end)
        end,
      })
    end,
  },
}
