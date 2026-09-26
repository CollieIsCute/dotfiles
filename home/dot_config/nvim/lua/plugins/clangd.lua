-- Custom clangd configuration (extends lazyvim.plugins.extras.lang.clangd)
-- Only includes settings that override or extend the default LazyVim clangd extra
return {
	{
		"neovim/nvim-lspconfig",
		opts = {
			servers = {
				clangd = {
					cmd = {
						"clangd",
						"--query-driver=/usr/bin/gcc,/usr/bin/g++,/opt/toolchains/**/bin/*gcc,/opt/toolchains/**/bin/*g++",
					},
				},
			},
		},
	},
}
