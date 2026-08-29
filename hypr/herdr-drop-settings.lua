-- Copied once to ~/.config/hypr/herdr-drop-settings.lua. Edit that copy;
-- rerunning the installer never overwrites it.
return {
  key = "SUPER + A",
  width = 0.82,
  height = 0.68,
  left = 0.09,
  top = 24,
  rounding = 12,

  -- false inherits Omarchy's current theme. Set an integer to override the
  -- border width, or an opacity rule such as "0.98 override 0.94 override".
  border_size = false,
  opacity = false,

  -- Special-workspace animations are global. Leave false to preserve Omarchy.
  -- Set a speed such as 4 to opt into Herdr Drop's slide animation.
  animation_speed = false,

  -- Hide the panel when another window or the desktop receives focus.
  close_on_focus_loss = true,
}
