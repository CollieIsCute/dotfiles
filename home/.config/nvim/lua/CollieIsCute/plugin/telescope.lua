require('CollieIsCute.keyMapping')
local telescope = require('telescope')
local builtin = require('telescope.builtin')
telescope.setup({
    defaults = {
        file_ignore_patterns = {
            "build",
            "log"
        }
	},
})
vim.keymap.set('n', '<leader>pf', builtin.find_files, {})
local recurse_submodule_git_files = function()
    local opt = {
        recurse_submodules = true,
    }
    builtin.git_files(opt);
end
vim.keymap.set('n', '<C-p>', recurse_submodule_git_files, {})
vim.keymap.set('n', '<leader>ps', function()
	builtin.grep_string({ search = vim.fn.input("Grep > ") });
end)
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)
