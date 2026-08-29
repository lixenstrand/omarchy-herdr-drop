local source = assert(arg[1], "expected Herdr Drop Lua module path")
local callbacks = {}
local binds = {}
local animations = {}
local moves = {}
local windows_on_special = {}
local active_window = nil
local selected_window = nil
local cursor = { x = 0, y = 0 }

package.preload["hypr.herdr-drop-settings"] = function()
  return { animation_speed = 4 }
end

_G.hl = {
  dsp = {
    exec_cmd = function(command) return { command = command } end,
    window = {
      move = function(options) return options end,
    },
  },
  animation = function(options) table.insert(animations, options) end,
  dispatch = function(action) table.insert(moves, action) end,
  bind = function(key, callback, flags)
    binds[key] = { callback = callback, flags = flags }
  end,
  get_cursor_pos = function() return cursor end,
  get_window = function() return selected_window end,
  get_workspace_windows = function(selector)
    assert(selector == "special:herdrdrop")
    return windows_on_special
  end,
  get_active_window = function() return active_window end,
  on = function(event, callback) callbacks[event] = callback end,
  unbind = function() end,
}

_G.o = {
  bind = function() end,
  window = function() end,
}

dofile(source)

assert(callbacks["window.open"], "window.open isolation hook is missing")
assert(callbacks["window.move_to_workspace"],
  "window.move_to_workspace isolation hook is missing")
assert(callbacks["window.active"], "window.active dismissal hook is missing")
assert(callbacks["layer.opened"], "layer.opened dismissal hook is missing")
assert(callbacks["config.reloaded"], "reload cleanup hook is missing")
assert(binds["mouse:272"], "outside-click binding is missing")
assert(binds["mouse:272"].flags.release == true,
  "outside-click binding does not wait for button release")
assert(binds["mouse:272"].flags.non_consuming == true,
  "outside-click binding consumes application clicks")
assert(animations[1].leaf == "specialWorkspaceIn" and animations[1].enabled == true,
  "opening animation is missing")
assert(animations[2].leaf == "specialWorkspaceOut" and animations[2].enabled == false,
  "closing animation is still enabled")

local function action_count(field, value)
  local count = 0
  for _, action in ipairs(moves) do
    if action[field] == value then count = count + 1 end
  end
  return count
end

local regular = { name = "1" }
local special = { name = "special:herdrdrop" }
local monitor = {
  active_workspace = regular,
  active_special_workspace = special,
}
local drop = {
  class = "org.omarchy.herdrdrop",
  workspace = special,
  monitor = monitor,
}
selected_window = drop
local foreign = {
  class = "chrome-music.youtube.com__-Default",
  workspace = special,
  monitor = monitor,
}

callbacks["window.open"](foreign)
assert(action_count("window", foreign) == 1,
  "foreign window was not removed from Herdr Drop")
assert(moves[1].workspace == regular, "foreign window moved to wrong workspace")
assert(moves[1].window == foreign, "wrong foreign window was moved")
assert(moves[1].follow == false, "moving foreign window changed workspace")
assert(action_count("command", "sh -c 'sleep 0.1; herdr-drop hide'") == 1,
  "opening a foreign window did not hide Herdr Drop")

callbacks["window.open"]({
  class = "org.omarchy.herdrdrop",
  workspace = special,
  monitor = monitor,
})
callbacks["window.open"]({
  class = "foot",
  workspace = regular,
  monitor = monitor,
})
assert(action_count("window", foreign) == 1,
  "Herdr or a normal-workspace window was moved")
assert(action_count("command", "sh -c 'sleep 0.1; herdr-drop hide'") == 2,
  "opening a normal-workspace window did not hide Herdr Drop")

local moved_foreign = {
  class = "firefox",
  workspace = regular,
  monitor = monitor,
}
callbacks["window.move_to_workspace"](moved_foreign, special)
assert(action_count("window", moved_foreign) == 1,
  "foreign window moved into Herdr Drop was not removed")

windows_on_special = {
  foreign,
  { class = "org.omarchy.herdrdrop", workspace = special, monitor = monitor },
}
callbacks["config.reloaded"]()
assert(action_count("window", foreign) == 2,
  "reload did not clean an existing foreign window from Herdr Drop")

callbacks["window.active"](drop)
callbacks["window.active"](foreign)
assert(action_count("command", "herdr-drop hide") == 1,
  "focus leaving Herdr Drop did not hide the panel")

monitor.active_special_workspace = nil
callbacks["window.active"](drop)
callbacks["window.active"](foreign)
assert(action_count("command", "herdr-drop hide") == 1,
  "a hidden Herdr Drop panel was toggled back open")

monitor.active_special_workspace = special
drop.at = { x = 100, y = 100 }
drop.size = { x = 400, y = 300 }
selected_window = drop
cursor = { x = 200, y = 200 }
binds["mouse:272"].callback()
assert(action_count("command", "herdr-drop hide") == 1,
  "a click inside Herdr Drop hid the panel")

cursor = { x = 50, y = 50 }
binds["mouse:272"].callback()
assert(action_count("command", "herdr-drop hide") == 2,
  "a click outside Herdr Drop did not hide the panel")

callbacks["layer.opened"]({ namespace = "omarchy-background" })
assert(action_count("command", "herdr-drop hide") == 2,
  "a persistent shell layer hid Herdr Drop")

callbacks["layer.opened"]({ namespace = "omarchy-menu" })
assert(action_count("command", "herdr-drop hide") == 3,
  "opening the Omarchy menu did not hide Herdr Drop")
