-- Herdr Drop: a persistent Herdr client in a drop-down special workspace.
-- User-owned geometry lives in ~/.config/hypr/herdr-drop-settings.lua.

local settings = {
  key = "SUPER + A",
  width = 0.78,
  height = 0.60,
  left = 0.11,
  top = 36,
  animation_speed = 4,
}

local user_settings = require("hypr.herdr-drop-settings")
if type(user_settings) == "table" then
  for key, value in pairs(user_settings) do settings[key] = value end
end

local app_id = "org.omarchy.herdrdrop"
local special = "herdrdrop"

-- Always unbind first: the installer reports the previous owner before this
-- file is loaded, and Hyprland must not retain two actions for the same key.
hl.unbind(settings.key)
o.bind(settings.key, "Herdr drop-down", "herdr-drop")

o.window("^(" .. app_id:gsub("%.", "\\.") .. ")$", {
  float = true,
  size = {
    "(monitor_w*" .. tostring(settings.width) .. ")",
    "(monitor_h*" .. tostring(settings.height) .. ")",
  },
  move = {
    "(monitor_w*" .. tostring(settings.left) .. ")",
    tostring(settings.top),
  },
  workspace = "special:" .. special .. " silent",
})

-- These leaves are global to special workspaces. Set animation_speed = false
-- in the settings file to preserve Omarchy's active special-workspace style.
if settings.animation_speed then
  hl.animation({
    leaf = "specialWorkspaceIn",
    enabled = true,
    speed = settings.animation_speed,
    bezier = "easeOutQuint",
    style = "slidefadevert top",
  })

  hl.animation({
    leaf = "specialWorkspaceOut",
    enabled = true,
    speed = settings.animation_speed,
    bezier = "easeOutQuint",
    style = "slidefadevert bottom",
  })
end
