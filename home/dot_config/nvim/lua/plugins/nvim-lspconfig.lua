return {
	"neovim/nvim-lspconfig",
	opts = {
		servers = {
			-- Ensure mason installs the server
			clangd = {
				keys = {
					{ "<leader>ch", "<cmd>ClangdSwitchSourceHeader<cr>", desc = "Switch Source/Header (C/C++)" },
				},
				root_dir = function(fname)
					return require("lspconfig.util").root_pattern(
						"Makefile",
						"configure.ac",
						"configure.in",
						"config.h.in",
						"meson.build",
						"meson_options.txt",
						"build.ninja"
					)(fname) or require("lspconfig.util").root_pattern(
						"compile_commands.json",
						"compile_flags.txt"
					)(fname) or require("lspconfig.util").find_git_ancestor(fname)
				end,
				capabilities = {
					offsetEncoding = { "utf-16" },
				},
				cmd = {
					"clangd",
					"--background-index",
					"--clang-tidy",
					"--header-insertion=iwyu",
					"--completion-style=detailed",
					"--function-arg-placeholders",
					"--fallback-style=llvm",
					"--compile-commands-dir=build64",
				},
				init_options = {
					usePlaceholders = true,
					completeUnimported = true,
					clangdFileStatus = true,
				},
			},
		},
		setup = {
			clangd = function(_, opts)
				local clangd_ext_opts = LazyVim.opts("clangd_extensions.nvim")
				require("clangd_extensions").setup(
					vim.tbl_deep_extend("force", clangd_ext_opts or {}, { server = opts })
				)
				return false
			end,
		},
	},
}
