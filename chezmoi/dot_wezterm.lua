-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- This is where you actually apply your config choices

config.color_scheme = 'Tartan (terminal.sexy)'
config.hide_tab_bar_if_only_one_tab = true
config.font = wezterm.font(
  "FantasqueSansMono Nerd Font Mono", {
    stretch = 'Expanded',
    weight = 'Regular'
  }
)
config.font_size = 12.2
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}
config.initial_rows = 30
config.initial_cols = 90
config.keys = {
  -- Disable the default Alt+Enter fullscreen behaviour as
  -- this is used by Neovim GitHub Copilot to synthesize
  -- solutions.
  {
    key = 'Enter',
    mods = 'ALT',
    action = wezterm.action.DisableDefaultAssignment,
  }
}
-- Maybe I should try fix this instead of suppressing this warning.
config.warn_about_missing_glyphs=false

-- and finally, return the configuration to wezterm
return config
