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
  close_on_focus_loss = true,
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
local app_selector = "class:^(" .. app_id:gsub("%.", "\\.") .. ")$"
local focused_drop_monitor = nil
local transient_shell_layers = {
  ["omarchy-menu"] = true,
  ["omarchy-image-selector"] = true,
  ["omarchy-emojis"] = true,
  ["omarchy-clipboard"] = true,
  ["omarchy-keyboard-panel"] = true,
}

local function same_monitor(left, right)
  return left ~= nil and right ~= nil and left.id == right.id
end

local function hide_drop_on_monitor(monitor)
  if not settings.close_on_focus_loss or monitor == nil then return end

  local active_special = monitor.active_special_workspace
  if active_special == nil or active_special.name ~= special_workspace then return end

  -- Toggle dispatchers act on the currently focused monitor. Calling one
  -- after pointer focus crosses to another monitor moves the special
  -- workspace there instead of hiding it. Close through the monitor that
  -- actually owns the panel.
  monitor:set_special_workspace({})
end

local function hide_visible_drop_on_monitor(trigger_monitor)
  if trigger_monitor == nil then return end
  local window = hl.get_window(app_selector)
  if window == nil or not same_monitor(window.monitor, trigger_monitor) then return end
  hide_drop_on_monitor(window.monitor)
end

-- A click outside the panel focuses either another window or no window. Hide
-- the special workspace after that focus transition while leaving the Herdr
-- client and all of its sessions alive.
local function close_drop_on_focus_loss(window)
  if window ~= nil and window.class == app_id then
    focused_drop_monitor = window.monitor
    return
  end

  local monitor = focused_drop_monitor
  -- A desktop click can clear the active window before Hyprland updates its
  -- focused-monitor state. The cursor already identifies the clicked monitor.
  local next_monitor = window and window.monitor or hl.get_monitor_at_cursor()
  if next_monitor == nil then next_monitor = hl.get_active_monitor() end
  -- Another monitor remains usable while the drop stays visible on the
  -- monitor where it opened. Only focus loss on that same monitor dismisses
  -- the panel.
  if monitor ~= nil and next_monitor ~= nil
      and not same_monitor(monitor, next_monitor) then return end

  focused_drop_monitor = nil
  hide_drop_on_monitor(monitor)
end

local function close_drop_on_outside_click()
  if not settings.close_on_focus_loss then return end

  local window = hl.get_window(app_selector)
  if window == nil or window.monitor == nil then return end

  local active_special = window.monitor.active_special_workspace
  if active_special == nil or active_special.name ~= special_workspace then return end

  local cursor_monitor = hl.get_monitor_at_cursor()
  if cursor_monitor ~= nil and not same_monitor(window.monitor, cursor_monitor) then return end

  local cursor = hl.get_cursor_pos()
  if cursor == nil or window.at == nil or window.size == nil then return end

  local inside = cursor.x >= window.at.x
    and cursor.x < window.at.x + window.size.x
    and cursor.y >= window.at.y
    and cursor.y < window.at.y + window.size.y
  if not inside then hide_drop_on_monitor(window.monitor) end
end

-- Launchers are layer surfaces, not windows. Hide the drop as soon as an
-- interactive Omarchy panel opens; a subsequently launched application is
-- covered separately by window.open.
local function close_drop_on_layer_open(layer)
  if layer == nil or not transient_shell_layers[layer.namespace] then return end
  hide_visible_drop_on_monitor(layer.monitor)
end

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

local function handle_window_open(window)
  isolate_window(window)
  if window == nil or window.class == app_id then return end
  if settings.close_on_focus_loss then
    -- Let Hyprland finish placing the new window before hiding its launch
    -- surface, then close it through its owning monitor.
    hl.timer(function()
      hide_visible_drop_on_monitor(window.monitor)
    end, { timeout = 100, type = "oneshot" })
  end
end

hl.on("window.open", handle_window_open)
hl.on("window.move_to_workspace", isolate_window)
hl.on("window.active", close_drop_on_focus_loss)
hl.on("layer.opened", close_drop_on_layer_open)
hl.bind("mouse:272", close_drop_on_outside_click, {
  release = true,
  non_consuming = true,
  transparent = true,
})
hl.on("config.reloaded", function()
  for _, window in ipairs(hl.get_workspace_windows(special_workspace) or {}) do
    isolate_window(window)
  end
  close_drop_on_focus_loss(hl.get_active_window())
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
    enabled = false,
  })
end
