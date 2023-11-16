hs.hotkey.bind({"cmd", "alt", "ctrl"}, "W", function()
    hs.notify.new({title = "Hammerspoon", informativeText = "Hello World"}):send()
end)

function launchIterm()
    if hs.application.find("iTerm2") then
        hs.applescript.applescript([[
			tell application "iTerm2"
				create window with default profile
			end tell
		]])
    else
        hs.application.open("iTerm")
    end
end

function launchChrome()
    if hs.application.find("Chrome") then
        hs.applescript.applescript([[
			tell application "Chrome"
				make new window
                activate
			end tell
		]])
    else
        hs.application.open("Chrome")
    end
end

hs.window.animationDuration = 0

-- Import the necessary Hammerspoon modules
local fs = require "hs.fs"
local application = require "hs.application"
local window = require "hs.window"
local hotkey = require "hs.hotkey"
local keycodes = require "hs.keycodes"
local fnutils = require "hs.fnutils"
local alert = require "hs.alert"
local screen = require "hs.screen"
local mounse = require "hs.mouse"
local grid = require "hs.grid"
local hints = require "hs.hints"
local timer = require "hs.timer"
local appfinder = require "hs.appfinder"

local definitions = nil
local hyper = nil

local gridset = function(frame)
    return function()
        local win = window.focusedWindow()
        if win then
            grid.set(win, frame, win:screen())
        else
            alert.show("No focused window.")
        end
    end
end

auxWin = nil
function saveFocus()
    auxWin = window.focusedWindow()
    alert.show("Window '" .. auxWin:title() .. "' saved.")
end
function focusSaved() if auxWin then auxWin:focus() end end

local hotkeys = {}

function createHotkeys()
    for key, fun in pairs(definitions) do
        local mod = hyper
        if string.len(key) == 2 and string.sub(key, 2, 2) == "c" then
            mod = {"cmd"}
        elseif string.len(key) == 2 and string.sub(key, 2, 2) == "l" then
            mod = {"ctrl"}
        end

        local hk = hotkey.new(mod, string.sub(key, 1, 1), fun)
        table.insert(hotkeys, hk)
        hk:enable()
    end
end

function rebindHotkeys()
    for i, hk in ipairs(hotkeys) do hk:disable() end

    hotkeys = {}
    createHotkeys()
    alert.show("Rebound Hotkeys")
end

function applyPlace(win, place)
    local scrs = screen.allScreens()
    local scr = scrs[place[1]]
    grid.set(win, place[2], scr)
end

function applyLayout(layout)
    return function()
        for appName, place in pairs(layout) do
            local app = appfinder.appFromName(appName)
            if app then
                for i, win in ipairs(app:allWindows()) do
                    applyPlace(win, place)
                end
            end
        end
    end
end

-- Actual config =================================

hs.application.enableSpotlightForNameSearches(true)
hyper = {"cmd", "ctrl"}
hs.window.animationDuration = 0;
-- hints.style = "vimperator"
-- Set grid size.
grid.GRIDWIDTH = 5
grid.GRIDHEIGHT = 8
grid.MARGINX = 0.25
grid.MARGINY = 0.25
local gw = grid.GRIDWIDTH
local gh = grid.GRIDHEIGHT

local gomiddle = {x = 0.025 * gw, y = 0.025 * gh, w = gw * 0.95, h = gh * 0.95}
local goleft = {x = 0, y = 0, w = gw / 2, h = gh}
local goright = {x = gw / 2, y = 0, w = gw / 2, h = gh}
local gobig = {x = 0, y = 0, w = gw, h = gh}
local gothirdleft = {
    x = 0.33 * gw,
    y = 0.025 * gh,
    w = gw * 0.66,
    h = gh * 0.95
}
local gothirdright = {x = gw * 0.34, y = 0, w = gw * 0.66, h = gh}
local gosmall = {x = gw * 0.35, y = gh * 0.3, w = gw * 0.3, h = gh * 0.35}
local narrowmiddle = {x = 1, y = 0, w = 3 * 1.025, h = 8}

local fullApps = {
    "Safari", "Aurora", "Nightly", "Xcode", "Qt Creator", "Google Chrome",
    "Papers 3.4.2", "ReadKit", "Google Chrome Canary", "Eclipse", "Coda 2",
    "iTunes", "Emacs", "Firefox", "Sublime Text"
}
local layout2 = {Spotify = {2, gomiddle}, ["iTerm2"] = {2, goright}}
fnutils.each(fullApps, function(app) layout2[app] = {1, gobig} end)
local layout2fn = applyLayout(layout2)

local mouseOrigin
local inMove = 0

definitions = {
    [";"] = saveFocus,
    a = focusSaved,

    j = gridset(gomiddle),
    h = gridset(goleft),
    l = gridset(goright),
    k = gridset(gobig),
    i = gridset(gosmall),
    o = gridset(narrowmiddle),
    t = launchIterm,
    c = launchChrome,
    m = createAndOpenMarkdownFile,

    -- g = layout2fn,
    u = grid.pushWindowNextScreen,
    r = hs.reload,

    ["9"] = function() window.focusedWindow():focusTab(9000) end
}

-- Function to create and open a markdown file
function createAndOpenMarkdownFile()
  print("HWLLOOO")
  alert.show("HELLOO")
    -- Get the current date and time
    local date = os.date("%Y-%m-%dT%H.%M.%S")

    -- Create the date string
    local dateString = os.date("%A, %B %e")

    -- Create the file name
    local fileName = date .. ".md"

    -- Create the file path
    local filePath = fs.pathToAbsolute("~") .. "/notes/" .. fileName

    alert.show("Create file at " .. filePath .. "")

    -- Create the file
    local file = io.open(filePath, "w")

    -- Check if the file was created successfully
    if file then
        -- Write "# " at the beginning of the file
        file:write("# " .. dateString .. "\n\n")

        -- Close the file
        file:close()

        -- Open the file with SublimeText and position the cursor at line 1, character 3
        hs.execute("/Applications/Sublime\\ Text.app/Contents/SharedSupport/bin/subl " .. filePath .. ":3 -n")
    else
        print("Failed to create file")
    end
end

function init()
    createHotkeys()

    hotkey.bind({}, "f10", launchIterm)
    hotkey.bind({}, "f11", launchChrome)
    hotkey.bind({}, "f12", createAndOpenMarkdownFile)

    alert.show("Hammerspoon, at your service.")
end

init()
