-- Hammerspoon config
-- Stripped to only actively used functionality

hs.window.animationDuration = 0
hs.application.enableSpotlightForNameSearches(true)

local fs = require "hs.fs"
local alert = require "hs.alert"
local hotkey = require "hs.hotkey"

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
