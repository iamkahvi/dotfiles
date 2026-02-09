-- Hammerspoon config
-- Stripped to only actively used functionality

hs.window.animationDuration = 0
hs.application.enableSpotlightForNameSearches(true)

local grid = require "hs.grid"
local window = require "hs.window"
local alert = require "hs.alert"
local hotkey = require "hs.hotkey"
local fs = require "hs.fs"

-- Grid setup
grid.GRIDWIDTH = 5
grid.GRIDHEIGHT = 8
grid.MARGINX = 0.25
grid.MARGINY = 0.25
local gw = grid.GRIDWIDTH
local gh = grid.GRIDHEIGHT

local gobig = {x = 0, y = 0, w = gw, h = gh}
local goleft = {x = 0, y = 0, w = gw / 2, h = gh}
local goright = {x = gw / 2, y = 0, w = gw / 2, h = gh}
local gomiddle = {x = 0.025 * gw, y = 0.025 * gh, w = gw * 0.95, h = gh * 0.95}

local function gridset(frame)
  return function()
    local win = window.focusedWindow()
    if win then
      grid.set(win, frame, win:screen())
    else
      alert.show("No focused window.")
    end
  end
end

-- Window management (cmd+ctrl)
hotkey.bind({"cmd", "ctrl"}, "k", gridset(gobig))
hotkey.bind({"cmd", "ctrl"}, "h", gridset(goleft))
hotkey.bind({"cmd", "ctrl"}, "l", gridset(goright))
hotkey.bind({"cmd", "ctrl"}, "j", gridset(gomiddle))

-- Quick note creation
local function createAndOpenMarkdownFile()
  local date = os.date("%Y-%m-%dT%H.%M.%S")
  local dateString = os.date("%A, %B %e")
  local button, fileNameInputted = hs.dialog.textPrompt("File name:", "", date)
  local fileName = fileNameInputted .. ".md"
  local filePath = fs.pathToAbsolute("~") .. "/notes/" .. fileName

  local file = io.open(filePath, "w")
  if file then
    file:write("# " .. dateString .. "\n\n")
    file:close()
    hs.execute("subl " .. filePath .. ":3 -n")
  else
    alert.show("Failed to create file at " .. filePath)
  end
end

hotkey.bind({}, "f12", createAndOpenMarkdownFile)

alert.show("Hammerspoon loaded.")
