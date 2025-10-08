return {
	{
		"nvim-treesitter/nvim-treesitter",
		opts = { ensure_installed = { "cpp" } },
	},
	{
		"p00f/clangd_extensions.nvim",
		opts = {
			server = {
				-- 例：同時允許系統 gcc/g++ 與自訂交叉編譯器
				cmd = {
					"clangd",
					"--query-driver=/usr/bin/gcc,/usr/bin/g++,/opt/toolchains/**/bin/*gcc,/opt/toolchains/**/bin/*g++",
					-- 你原本想加的其他 clangd 參數也都放這裡
					"--background-index",
					"--clang-tidy",
				},
			},
			inlay_hints = {
				inline = true,
			},
		},
	},
	{
		"mfussenegger/nvim-dap",
		config = function()
			local dap = require("dap")
			if not dap.adapters["codelldb"] then
				require("dap").adapters["codelldb"] = {
					type = "server",
					host = "localhost",
					port = "${port}",
					executable = {
						command = "codelldb",
						args = {
							"--port",
							"${port}",
						},
					},
				}
			end
			for _, lang in ipairs({ "c", "cpp" }) do
				dap.configurations[lang] = {
					{
						type = "codelldb",
						request = "launch",
						name = "Launch file",
						program = function()
							return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
						end,
						cwd = "${workspaceFolder}",
					},
					{
						type = "codelldb",
						request = "attach",
						name = "Attach to process",
						pid = require("dap.utils").pick_process,
						cwd = "${workspaceFolder}",
					},
				}
			end
		end,
	},
	{
		-- Ensure C/C++ debugger is installed
		"mason-org/mason.nvim",
		optional = true,
		opts = { ensure_installed = { "codelldb" } },
	},
}
