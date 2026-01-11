return {
	"sphamba/smear-cursor.nvim",
	opts = {
		hide_target_hack = true,
		cursor_color = "none",

		-- 啟用 Legacy Computing Symbols 以改善對角線渲染（減少鋸齒）
		legacy_computing_symbols_support = true,
		use_diagonal_blocks = true,

		-- 高效能機器優化：更快更銳利的動畫
		time_interval = 7, -- ~143fps (預設 17ms)
		stiffness = 0.8,
		trailing_stiffness = 0.7,
		damping = 0.97,
		distance_stop_animating = 0.5,
	},
}
