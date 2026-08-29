local source = assert(arg[1], "expected Herdr Drop Lua module path")
local callbacks = {}
local moves = {}
local windows_on_special = {}

package.preload["hypr.herdr-drop-settings"] = function()
  return { animation_speed = false }
end

_G.hl = {
  dsp = {
    window = {
      move = function(options) return options end,
    },
  },
  animation = function() end,
  dispatch = function(action) table.insert(moves, action) end,
  get_workspace_windows = function(selector)
    assert(selector == "special:herdrdrop")
    return windows_on_special
  end,
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
assert(callbacks["config.reloaded"], "reload cleanup hook is missing")

local regular = { name = "1" }
local special = { name = "special:herdrdrop" }
local monitor = { active_workspace = regular }
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
