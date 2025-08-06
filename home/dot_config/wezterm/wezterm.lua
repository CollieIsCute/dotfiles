local wezterm = require 'wezterm'
local config = wezterm.config_builder()
config.max_fps      = 170
config.ssh_domains  = {}
config.harfbuzz_features = { 'liga=1' }
config.enable_tab_bar = false

-- Catppuccin Mocha theme
config.color_scheme = 'Catppuccin Mocha'

-- Font configuration
config.font = wezterm.font('JetBrains Mono', { weight = 'Regular' })
config.font_size = 12.0

return config
