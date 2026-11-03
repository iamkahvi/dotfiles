-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Disabled until ~/.local/bin/handy is installed.
-- o.bind(
--   "ALT + SPACE",
--   "Handy transcription",
--   "/home/iamkahvi/.local/bin/handy --toggle-transcription"
-- )

-- Send Ctrl+T to whichever application is focused.
hl.unbind("SUPER + T")
o.bind("SUPER + T", "New tab", hl.dsp.send_shortcut({ mods = "CTRL", key = "T" }))

-- Close a browser tab with Ctrl+W; preserve the normal window-close binding elsewhere.
local function active_window_is_browser()
  local window = hl.get_active_window()
  if not window then
    return false
  end

  for _, tag in ipairs(window.tags or {}) do
    local clean_tag = tag:gsub("%*$", "")
    if clean_tag == "chromium-based-browser" or clean_tag == "firefox-based-browser" then
      return true
    end
  end

  return false
end

local function close_browser_tab_or_window()
  if active_window_is_browser() then
    hl.dispatch(hl.dsp.send_shortcut({ mods = "CTRL", key = "W" }))
  else
    hl.dispatch(hl.dsp.window.close())
  end
end

hl.unbind("SUPER + W")
o.bind("SUPER + W", "Close browser tab/window", close_browser_tab_or_window)

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Map CTRL+J / CTRL+K to the Down / Up arrow keys (sends the arrow key
-- event to the focused window, repeats while held).
o.bind("CTRL + J", "Down arrow", hl.dsp.send_shortcut({ mods = "", key = "down" }))
o.bind("CTRL + K", "Up arrow", hl.dsp.send_shortcut({ mods = "", key = "up" }))

-- GUI applications use Ctrl for word navigation/deletion. Terminals already
-- use Alt/Meta for this, so preserve their native sequences.
local function active_window_is_terminal()
  local window = hl.get_active_window()
  if not window then
    return false
  end

  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then
      return true
    end
  end

  return false
end

local terminal_word_keys = {
  -- Readline and most terminal applications use Meta-b/Meta-f for word jumps.
  left = "b",
  right = "f",
}

local function word_shortcut(key)
  return function()
    local terminal = active_window_is_terminal()
    local mods = terminal and "ALT" or "CTRL"
    local output_key = terminal and (terminal_word_keys[key] or key) or key
    hl.dispatch(hl.dsp.send_shortcut({ mods = mods, key = output_key }))
  end
end

o.bind("ALT + LEFT", "Previous word", word_shortcut("left"))
o.bind("ALT + RIGHT", "Next word", word_shortcut("right"))
o.bind("ALT + BACKSPACE", "Delete previous word", word_shortcut("backspace"))

-- Mac keyboard: F10/F11/F12 as mute / volume down / volume up (matches Apple keycap icons).
-- fn+F10/F11/F12 keep working via the existing XF86 bindings.
o.bind("F10", "Mute", "omarchy-audio-output-volume mute-toggle", { locked = true })
o.bind("F11", "Volume down", "omarchy-audio-output-volume lower", { locked = true, repeating = true })
o.bind("F12", "Volume up", "omarchy-audio-output-volume raise", { locked = true, repeating = true })

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Toggle the focused window into a 75%-wide centered master layout.
-- SUPER+C remains Omarchy's universal copy binding, so use SUPER+ALT+C.
o.bind(
  "SUPER + ALT + C",
  "Toggle centered master layout",
  os.getenv("HOME") .. "/dotfiles/scripts/toggle-centered-master"
)
