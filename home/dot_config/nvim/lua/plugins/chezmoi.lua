return {
  "AstroNvim/astrocore",
  opts = function(_, opts)
    -- Let chezmoi.vim discover the effective source directory, including .chezmoiroot.
    opts.options.g["chezmoi#source_dir_path"] = nil
    opts.options.g["chezmoi#use_external"] = 1
    -- AstroFile repeats native detection after chezmoi.vim has added its suffix.
    opts.filetypes = opts.filetypes or {}
    opts.filetypes.pattern = opts.filetypes.pattern or {}
    opts.filetypes.pattern[".*%.tmpl"] = {
      function(_, bufnr)
        local original = vim.b[bufnr].chezmoi_original_filetype
        if original then
          return original == "" and "chezmoitmpl" or original .. ".chezmoitmpl"
        end
      end,
      { priority = 10 },
    }

    -- Keep chezmoi.vim's layered Vim syntax for template buffers.
    opts.treesitter.highlight = function(_, bufnr)
      return not vim.bo[bufnr].filetype:match("chezmoitmpl$")
    end
  end,
}
