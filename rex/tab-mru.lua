-- Move each tab to the front of its session when it stays active for DWELL seconds.
-- Run: rex do ~/.config/rex/tab-mru.lua --all [dwell=1.5]
-- init.lua cannot hold rex.on handlers in Rex 0.1.0-preview.19.
-- Thus the launchd agent rex/dotfiles.rex-tab-mru.plist runs this script.

local DWELL = tonumber(rex.args.dwell) or 1.5
local pending = {}

local function promote(sid, wid)
  local ok, view = pcall(rex.call, "session.view", { session_id = sid })
  if not ok or type(view) ~= "table" or view.active_window_id ~= wid then return end
  local first = view.windows and view.windows[1] and view.windows[1].window_id
  if not first or first == wid then return end
  local moved, err = pcall(rex.call, "session.move_window", {
    session_id = sid, window_id = wid, before_window_id = first,
  })
  if not moved then rex.log("tab-mru: move failed: " .. tostring(err)) end
end

rex.on("active_window_changed", function(_, ev)
  local sid, wid = ev.session_id, ev.window_id
  if not sid or not wid then return end
  local token = {}
  pending[sid] = token
  rex.after(DWELL, function()
    if pending[sid] ~= token then return end
    pending[sid] = nil
    promote(sid, wid)
  end)
end)
