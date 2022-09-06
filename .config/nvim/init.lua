vim.opt.number = true
vim.opt.autoindent = true
vim.opt.cursorline = true
vim.opt.shiftwidth = 4
vim.opt.incsearch = true

-- Plug-in
require('CollieIsCute/plugin')

-- EdenEast/nightfox.nvim setting
require('CollieIsCute/nightfox')

-- key mapping
require('CollieIsCute/keyMapping')

-- neoclide/coc.nvim configuration
vim.cmd 'runtime ./lua/CollieIsCute/coc.vim'
