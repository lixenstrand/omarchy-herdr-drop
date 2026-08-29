local source = assert(arg[1], "expected Herdr Drop Lua module path")
local callbacks = {}
local binds = {}
local moves = {}
local windows_on_special = {}
local active_window = nil
local selected_window = nil
local cursor = { x = 0, y = 0 }

package.preload["hypr.herdr-drop-settings"] = function()
  return { animation_speed = false }
end

_G.hl = {
  dsp = {
    exec_cmd = function(command) return { command = command } end,
    window = {
      move = function(options) return options end,
    },
  },
  animation = function() end,
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
assert(callbacks["config.reloaded"], "reload cleanup hook is missing")
assert(binds["mouse:272"], "outside-click binding is missing")
assert(binds["mouse:272"].flags.release == true,
  "outside-click binding does not wait for button release")
assert(binds["mouse:272"].flags.non_consuming == true,
  "outside-click binding consumes application clicks")

local regular = { name = "1" }
local special = { name = "special:herdrdrop" }
local monitor = {
  active_workspace = regular,
  active_special_workspace = special,
}
local foreign = {
  class = "chrome-music.youtube.com__-Default",
  workspace = special,
  monitor = monitor,
}

callbacks["window.open"](foreign)
assert(#moves == 1, "foreign window was not removed from Herdr Drop")
assert(moves[1].workspace == regular, "foreign window moved to wrong workspace")
assert(moves[1].window == foreign, "wrong foreign window was moved")
assert(moves[1].follow == false, "moving foreign window changed workspace")

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
assert(#moves == 1, "Herdr or a normal-workspace window was moved")

local moved_foreign = {
  class = "firefox",
  workspace = regular,
  monitor = monitor,
}
callbacks["window.move_to_workspace"](moved_foreign, special)
assert(#moves == 2 and moves[2].window == moved_foreign,
  "foreign window moved into Herdr Drop was not removed")

windows_on_special = {
  foreign,
  { class = "org.omarchy.herdrdrop", workspace = special, monitor = monitor },
}
callbacks["config.reloaded"]()
assert(#moves == 3 and moves[3].window == foreign,
  "reload did not clean an existing foreign window from Herdr Drop")

local drop = {
  class = "org.omarchy.herdrdrop",
  workspace = special,
  monitor = monitor,
}
callbacks["window.active"](drop)
callbacks["window.active"](foreign)
assert(#moves == 4 and moves[4].command == "herdr-drop hide",
  "focus leaving Herdr Drop did not hide the panel")

monitor.active_special_workspace = nil
callbacks["window.active"](drop)
callbacks["window.active"](foreign)
assert(#moves == 4, "a hidden Herdr Drop panel was toggled back open")

monitor.active_special_workspace = special
drop.at = { x = 100, y = 100 }
drop.size = { x = 400, y = 300 }
selected_window = drop
cursor = { x = 200, y = 200 }
binds["mouse:272"].callback()
assert(#moves == 4, "a click inside Herdr Drop hid the panel")

cursor = { x = 50, y = 50 }
binds["mouse:272"].callback()
assert(#moves == 5 and moves[5].command == "herdr-drop hide",
  "a click outside Herdr Drop did not hide the panel")
