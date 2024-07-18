return {
	"nvim-cmp",
	opts = function(_, opts)
	  table.insert(opts.sorting.comparators, 1, require("clangd_extensions.cmp_scores"))
	end,
  }