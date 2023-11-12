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
    {
        "nvim-telescope/telescope.nvim",
        branch = '0.1.x',
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
        "hrsh7th/nvim-cmp",
        config = function()
            require("CollieIsCute/plugin/nvim-cmp")
        end,
        dependencies = {
            'L3MON4D3/LuaSnip',
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-buffer',
            'hrsh7th/cmp-path',
            'saadparwaiz1/cmp_luasnip'
        }
    }
})
