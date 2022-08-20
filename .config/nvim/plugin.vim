call plug#begin()

Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'jackguo380/vim-lsp-cxx-highlight'
Plug 'iamcco/markdown-preview.nvim', { 'do': 'cd app && yarn install' }
" plenary is needed by telescope
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim', { 'tag': '0.1.0' }

call plug#end()
