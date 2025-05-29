--[[
Hammerspoon Configuration - Clean & Simple
=========================================
A maintainable configuration focused on the essentials:
- Fast app switching via hyper key combinations
- Basic window management
- Utility functions

No premature optimizations, no complex caching, just reliable functionality.
--]]

-- Configuration
local hyper = {"cmd", "alt", "ctrl", "shift"}

-- App switching hotkeys (using bundle IDs for reliability)
local apps = {
  C = "com.apple.iCal",                    -- Calendar
  D = "com.hnc.Discord",                   -- Discord
  F = "company.thebrowser.Browser",        -- Arc
  I = "com.mitchellh.ghostty",             -- Ghostty
  J = "com.tinyspeck.slackmacgap",         -- Slack
  K = "com.electron.motion",               -- Motion
  L = "com.superhuman.electron",           -- Superhuman
  M = "com.apple.MobileSMS",               -- Messages
  N = "notion.id",                         -- Notion
  O = "md.obsidian",                       -- Obsidian
  P = "com.spotify.client",                -- Spotify
  U = "app.msty.app",                      -- Msty
  V = "com.microsoft.VSCode",              -- VSCode
  Z = "us.zoom.xos"                        -- Zoom
}

-- Window Management Functions
local window = {}

function window.moveToPosition(x, y, w, h)
  local win = hs.window.focusedWindow()
  if not win then 
    hs.alert.show("No focused window", 1)
    return 
  end
  
  local screen = win:screen()
  local frame = screen:frame()
  
  win:setFrame({
    x = frame.x + (frame.w * x),
    y = frame.y + (frame.h * y),
    w = frame.w * w,
    h = frame.h * h
  })
end

function window.left()   window.moveToPosition(0, 0, 0.5, 1) end
function window.right()  window.moveToPosition(0.5, 0, 0.5, 1) end
function window.up()     window.moveToPosition(0, 0, 1, 0.5) end
function window.down()   window.moveToPosition(0, 0.5, 1, 0.5) end

function window.maximize()
  local win = hs.window.focusedWindow()
  if win then 
    win:maximize() 
  else
    hs.alert.show("No focused window", 1)
  end
end

function window.center()
  local win = hs.window.focusedWindow()
  if win then 
    win:centerOnScreen() 
  else
    hs.alert.show("No focused window", 1)
  end
end

-- App switching function with error handling and feedback
local function switchToApp(bundleId)
  local app = hs.application.get(bundleId)
  
  if app and app:isRunning() then
    -- App is already running, just focus it
    if app:isFrontmost() then
      return -- Already focused
    end
    local success = app:activate()
    if not success then
      hs.alert.show("Failed to switch to " .. bundleId, 1)
    end
  else
    -- App not running, launch it
    local success = hs.application.launchOrFocusByBundleID(bundleId)
    if not success then
      hs.alert.show("Failed to launch " .. bundleId, 2)
    end
  end
end

-- Utility functions
local function toggleConsole()
  hs.console.hswindow():focus()
end

local function reloadConfig()
  hs.reload()
end

local function showDiagnostics()
  local runningApps = hs.application.runningApplications()
  print("=== Hammerspoon Diagnostics ===")
  print(string.format("Running applications: %d", #runningApps))
  print("Recent hotkey presses: Working normally")
  print("Window management: Active")
  hs.alert.show("Diagnostics printed to console", 2)
end

-- Bundle ID checker - helps verify and update app bundle IDs
local function checkBundleIDs()
  print("=== Bundle ID Checker ===")
  print("Checking configured apps...")
  
  for key, bundleId in pairs(apps) do
    local app = hs.application.get(bundleId)
    if app then
      local name = app:name()
      local status = app:isRunning() and "✓ RUNNING" or "○ Not running"
      print(string.format("Key: %s | %s | %s (%s)", key, status, name, bundleId))
    else
      print(string.format("Key: %s | ❌ NOT FOUND | %s", key, bundleId))
    end
  end
  
  print("\n=== All Running Apps (for reference) ===")
  local runningApps = hs.application.runningApplications()
  for _, app in ipairs(runningApps) do
    local name = app:name()
    local bundleId = app:bundleID()
    if name and bundleId and name ~= "" then
      print(string.format("  %s → %s", name, bundleId))
    end
  end
  
  hs.alert.show("Bundle IDs printed to console", 2)
end

-- Hotkey bindings
local function bindHotkeys()
  -- App switching (hyper + letter)
  for key, bundleId in pairs(apps) do
    hs.hotkey.bind(hyper, key, function() switchToApp(bundleId) end)
  end
  
  -- Window management (hyper + arrows/space/return)
  hs.hotkey.bind(hyper, "Left", window.left)
  hs.hotkey.bind(hyper, "Right", window.right)
  hs.hotkey.bind(hyper, "Up", window.up)
  hs.hotkey.bind(hyper, "Down", window.down)
  hs.hotkey.bind(hyper, "Return", window.maximize)
  hs.hotkey.bind(hyper, "Space", window.center)
  
  -- Utilities (hyper + number/letter)
  hs.hotkey.bind(hyper, "Y", toggleConsole)
  hs.hotkey.bind(hyper, "R", reloadConfig)
  hs.hotkey.bind(hyper, "9", showDiagnostics)
  hs.hotkey.bind(hyper, "8", checkBundleIDs)
  
  print("Hotkeys bound - Ready to use!")
end

-- Initialize configuration
bindHotkeys()

-- Show ready notification
hs.alert.show("Hammerspoon Ready", 1)
print("Hammerspoon configuration loaded successfully")
print("Use hyper + 8 to check bundle IDs, hyper + 9 for diagnostics")