local wezterm = require 'wezterm'
local config = wezterm.config_builder()
config.max_fps      = 170
config.ssh_domains  = {}
config.harfbuzz_features = { 'liga=1' }
config.enable_tab_bar = false

return config
