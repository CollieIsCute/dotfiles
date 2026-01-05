-- Disable treesitter highlighting for chezmoi template files
-- Treesitter overwrites chezmoi.vim's layered Vim syntax highlighting
-- https://github.com/alker0/chezmoi.vim#scaletreesitter-nvim-treesitter
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      local original_disable = opts.highlight and opts.highlight.disable
      opts.highlight = opts.highlight or {}
      opts.highlight.disable = function(lang, buf)
        -- Check original disable function first
        if type(original_disable) == "function" and original_disable(lang, buf) then
          return true
        elseif type(original_disable) == "table" and vim.tbl_contains(original_disable, lang) then
          return true
        end
        -- Disable treesitter for chezmoi template files
        local ft = vim.bo[buf].filetype
        if string.find(ft, "chezmoitmpl") then
          return true
        end
        return false
      end
    end,
  },
}
