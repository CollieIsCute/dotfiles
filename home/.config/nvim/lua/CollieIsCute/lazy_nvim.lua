local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    {
        "iamcco/markdown-preview.nvim",
        build = function()
            vim.fn["mkdp#util#install"]()
        end,
        config = function()
            vim.g.mkdp_theme = 'dark'
            require('CollieIsCute.plugin.markdown_preview')
        end,
        ft = "markdown"
    },
    {
        "williamboman/mason-lspconfig.nvim",
        dependencies = {
            "williamboman/mason.nvim",
            "neovim/nvim-lspconfig"
        }
    },
    {
        "williamboman/mason.nvim",
        config = function()
            require("CollieIsCute/plugin/mason")
        end
    },
    "neovim/nvim-lspconfig",
    {
        "nvim-telescope/telescope.nvim",
        tag = '0.1.2',
        dependencies = { 'nvim-lua/plenary.nvim' },
        config = function()
            require("CollieIsCute/plugin/telescope")
        end
    },
    {
        "EdenEast/nightfox.nvim",
        config = function()
            require("CollieIsCute/plugin/nightfox")
        end
    },
    {
        "nvim-treesitter/nvim-treesitter",
        build = ':TSUpdateSync',
        config = function()
            require("CollieIsCute/plugin/treesitter")
        end,
        dependencies = {
            'nvim-treesitter/nvim-treesitter-textobjects',
        }
    },
    {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v2.x',
        dependencies = {
            -- LSP Support
            {'neovim/nvim-lspconfig'},             -- Required
            {'williamboman/mason.nvim'},           -- Optional
            {'williamboman/mason-lspconfig.nvim'}, -- Optional
            -- Autocompletion
            {'hrsh7th/nvim-cmp'},     -- Required
            {'hrsh7th/cmp-nvim-lsp'}, -- Required
            {'L3MON4D3/LuaSnip'}     -- Required
        },
        config = function()
            require("CollieIsCute/plugin/lsp")
        end
    }
})
