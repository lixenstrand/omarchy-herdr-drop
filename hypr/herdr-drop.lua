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
local special_workspace = "special:" .. special

-- A visible special workspace becomes the launch target for unrelated apps.
-- Keep this one private by returning every non-Herdr window to the regular
-- workspace that remains active underneath it.
local function isolate_window(window, workspace)
  if window == nil or window.class == app_id then return end

  local current = workspace or window.workspace
  if current == nil or current.name ~= special_workspace then return end

  local monitor = window.monitor
  local target = monitor and monitor.active_workspace or nil
  if target == nil or target.name == special_workspace then return end

  hl.dispatch(hl.dsp.window.move({
    workspace = target,
    follow = false,
    window = window,
  }))
end

hl.on("window.open", isolate_window)
hl.on("window.move_to_workspace", isolate_window)
hl.on("config.reloaded", function()
  for _, window in ipairs(hl.get_workspace_windows(special_workspace) or {}) do
    isolate_window(window)
  end
end)

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
  workspace = special_workspace .. " silent",
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
    -- Hyprland reverses the forced direction for an outgoing workspace:
    -- "bottom" targets negative Y here, so the panel actually leaves upward.
    style = "slidefadevert bottom",
  })
end
