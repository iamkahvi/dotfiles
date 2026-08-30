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

-- Mac keyboard: F10/F11/F12 as mute / volume down / volume up (matches Apple keycap icons).
-- fn+F10/F11/F12 keep working via the existing XF86 bindings.
o.bind("F10", "Mute", "omarchy-audio-output-volume mute-toggle", { locked = true })
o.bind("F11", "Volume down", "omarchy-audio-output-volume lower", { locked = true, repeating = true })
o.bind("F12", "Volume up", "omarchy-audio-output-volume raise", { locked = true, repeating = true })

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")
