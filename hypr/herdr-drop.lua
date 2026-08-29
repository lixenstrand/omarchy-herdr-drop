-- Herdr Drop: a persistent Herdr client in a drop-down special workspace.
-- User-owned geometry lives in ~/.config/hypr/herdr-drop-settings.lua.

local settings = {
  key = "SUPER + A",
  width = 0.82,
  height = 0.68,
  left = 0.09,
  top = 24,
  rounding = 12,
  border_size = false,
  opacity = false,
  animation_speed = false,
}

local user_settings = require("hypr.herdr-drop-settings")
if type(user_settings) == "table" then
  for key, value in pairs(user_settings) do settings[key] = value end
end

-- Optional integrations may apply a small final geometry/style profile while
-- keeping the base package independent of a particular bar implementation.
local integration_ok, integration_settings =
  pcall(require, "hypr.herdr-drop-integration")
if integration_ok and type(integration_settings) == "table" then
  for key, value in pairs(integration_settings) do settings[key] = value end
end

local app_id = "org.omarchy.herdrdrop"
local special = "herdrdrop"

-- Always unbind first: the installer reports the previous owner before this
-- file is loaded, and Hyprland must not retain two actions for the same key.
hl.unbind(settings.key)
o.bind(settings.key, "Herdr drop-down", "herdr-drop")

local window_rules = {
  float = true,
  size = {
    "(monitor_w*" .. tostring(settings.width) .. ")",
    "(monitor_h*" .. tostring(settings.height) .. ")",
  },
  move = {
    "(monitor_w*" .. tostring(settings.left) .. ")",
    tostring(settings.top),
  },
  rounding = settings.rounding,
  workspace = "special:" .. special .. " silent",
}

-- Keep Omarchy's theme-owned border and opacity unless explicitly overridden.
if settings.border_size ~= false then window_rules.border_size = settings.border_size end
if settings.opacity ~= false then window_rules.opacity = settings.opacity end

o.window("^(" .. app_id:gsub("%.", "\\.") .. ")$", window_rules)

-- These leaves are global to every special workspace, so custom animation is
-- opt-in. The default preserves the user's active Omarchy animation.
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
    style = "slidefadevert top",
  })
end
