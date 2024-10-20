-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
  config = wezterm.config_builder()
end

wezterm.on('toggle-colorscheme', function(window, pane)
  local overrides = window:get_config_overrides() or {}
  if not overrides.color_scheme then
    -- overrides.color_scheme = 'Dracula'
    overrides.color_scheme = 'Tartan (terminal.sexy)'
  else
    overrides.color_scheme = nil
  end
  window:set_config_overrides(overrides)
end)

-- This is where you actually apply your config choices

-- config.front_end = "WebGpu"  -- Enable in case of no OpenGL
config.enable_wayland = true
config.color_scheme = 'Dracula'
-- config.color_scheme = 'Tartan (terminal.sexy)'
config.hide_tab_bar_if_only_one_tab = true
config.font = wezterm.font(
  "FantasqueSansM Nerd Font Mono", {
    stretch = 'Expanded',
    weight = 'Regular'
  }
)
config.font_size = 12.2
config.audible_bell = "Disabled"
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
  },
  {
    key = 'E',
    mods = 'CTRL',
    action = wezterm.action.EmitEvent 'toggle-colorscheme',
  },
  {
    key = 'f',
    mods = 'CTRL',
    action = wezterm.action.ToggleFullScreen,
  },
}
-- Maybe I should try fix this instead of suppressing this warning.
config.warn_about_missing_glyphs = false

config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false

config.hide_mouse_cursor_when_typing = false
-- config.mux_enable_ssh_agent = false

-- config.window_background_image = "/home/ritiek/Pictures/island-fantastic-coast-mountains-art.jpg"
-- config.window_background_opacity = 0.7

-- and finally, return the configuration to wezterm
return config
