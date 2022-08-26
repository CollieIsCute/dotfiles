set nu
set autoindent
set cursorline
set shiftwidth=4
set incsearch
syntax on

" Plug-in
runtime ./plugin.vim

" key mapping
runtime ./keyMapping.vim

" neoclide/coc.nvim configuration
runtime ./coc.vim

" EdenEast/nightfox.nvim setting
runtime ./nightfox.lua
