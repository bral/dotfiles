-- Hammerspoon Configuration
-- Author: Brannon Lucas
-- Updated: 2024-11-24
-- Features: Hyper-key app switching with window cycling, window tiling

-- === Config =================================================================

local appmod, winmod, timermod = hs.application, hs.window, hs.timer
local hyper = {"cmd", "alt", "ctrl", "shift"}

-- Timing constants
local ALERT_DURATION = 0.6
local ALERT_DURATION_ERROR = 0.8
local ACTIVATION_TIMEOUT = 0.5
local LAUNCH_FOCUS_DELAY = 0.25

-- Performance settings
hs.window.animationDuration = 0
hs.application.enableSpotlightForNameSearches(false)


-- Bundle IDs (Hyper + key to switch/launch)
local apps = {
  C = "com.apple.iCal",              -- Calendar
  D = "com.hnc.Discord",             -- Discord
  F = "company.thebrowser.dia",      -- Dia
  I = "com.mitchellh.ghostty",       -- Ghostty
  J = "com.tinyspeck.slackmacgap",   -- Slack
  K = "com.electron.motion",         -- Motion
  L = "com.superhuman.electron",     -- Superhuman
  M = "com.apple.MobileSMS",         -- Messages
  N = "com.apple.Notes",             -- Notes
  O = "md.obsidian",                 -- Obsidian
  P = "com.spotify.client",          -- Spotify
  U = "app.msty.app",                -- Msty
  V = "com.microsoft.VSCode",        -- VSCode
  Z = "us.zoom.xos",                 -- Zoom
}

-- === Window ops =============================================================

local function getFocusedWindow()
  local w = winmod.focusedWindow()
  if not w then hs.alert.show("No focused window", ALERT_DURATION) end
  return w
end

local window = {}

function window.left()
  local w = getFocusedWindow()
  if w then w:moveToUnit({0, 0, 0.5, 1}) end
end

function window.right()
  local w = getFocusedWindow()
  if w then w:moveToUnit({0.5, 0, 0.5, 1}) end
end

function window.up()
  local w = getFocusedWindow()
  if w then w:moveToUnit({0, 0, 1, 0.5}) end
end

function window.down()
  local w = getFocusedWindow()
  if w then w:moveToUnit({0, 0.5, 1, 0.5}) end
end

function window.maximize()
  local w = getFocusedWindow()
  if w then w:maximize() end
end

function window.center()
  local w = getFocusedWindow()
  if w then w:centerOnScreen() end
end

-- === App switcher (fly) =====================================================

-- persistent cycling index per app (keeps order predictable)
local cycleIndex = {}

-- Event-driven activation watcher (eliminates 120ms blind wait)
local function waitForActivation(app, callback, timeout)
  -- Fast-path: if already frontmost, skip event system entirely
  if app:isFrontmost() then
    callback()
    return
  end

  -- Set up application watcher for activation events
  local watcher, timer
  local completed = false  -- Guard against double callback (race condition fix)

  watcher = hs.application.watcher.new(function(appName, eventType, appObject)
    -- Only respond to OUR app's activation event
    if appObject == app and eventType == hs.application.watcher.activated then
      if completed then return end
      completed = true
      if timer then timer:stop() end
      watcher:stop()
      callback()
    end
  end)

  watcher:start()

  -- Safety timeout: if activation never happens, try anyway after timeout
  -- This is a fallback - normal path is event-driven (fires at 50-150ms)
  timer = timermod.doAfter(timeout or ACTIVATION_TIMEOUT, function()
    if completed then return end
    completed = true
    watcher:stop()
    callback()  -- Try anyway - partial success better than silent failure
  end)
end

local function collectWindows(app)
  -- Fast filter: standard OR visible, not minimized, has a title
  local wins, n = {}, 0
  for _, w in ipairs(app:allWindows()) do
    if (w:isStandard() or (w:isVisible() and not w:isMinimized()))
       and w:title() ~= "" then
      n = n + 1
      wins[n] = w
    end
  end
  if n <= 1 then return wins end
  -- Sort by id for stability; cheap and deterministic
  table.sort(wins, function(a, b) return a:id() < b:id() end)
  return wins
end

local function focusWindow(w)
  if not w then return false end
  if w:isMinimized() then w:unminimize() end
  local app = w:application()
  if app and app:isHidden() then app:unhide() end
  local success = w:focus()

  -- Move mouse to center of focused window
  if success then
    local frame = w:frame()
    local center = hs.geometry.point(frame.x + frame.w / 2, frame.y + frame.h / 2)
    hs.mouse.absolutePosition(center)
  end

  return success
end

local function cycleAppWindows(app)
  if not app then return false end
  local wins = collectWindows(app)
  local n = #wins
  if n == 0 then return app:activate(true) end
  if n == 1 then return focusWindow(wins[1]) end

  -- if current focused belongs to app, advance from it; else use persisted index
  local f = winmod.focusedWindow()
  if f and f:application() == app then
    for i, w in ipairs(wins) do
      if w == f then
        local nextW = wins[(i % n) + 1]
        return focusWindow(nextW)
      end
    end
  end

  local idx = (cycleIndex[app:bundleID()] or 0) % n + 1
  cycleIndex[app:bundleID()] = idx
  return focusWindow(wins[idx])
end

local function switchToApp(bundleId)
  -- Fast path: running app
  local app = appmod.get(bundleId)
  if app and app:isRunning() then
    if app:isFrontmost() then
      return cycleAppWindows(app)
    else
      -- OPTIMIZED: Event-driven focus (eliminates 120ms blind wait)
      if not app:activate(true) then return false end

      -- Try immediate focus BEFORE setting up event watcher
      -- For running apps, windows exist and are ready (fast path: ~45ms avg)
      local wins = collectWindows(app)
      if #wins > 0 then
        return focusWindow(wins[1])
      end

      -- Fallback: wait for activation event if no windows found immediately
      -- This is rare for running apps, suggests windows in weird state
      waitForActivation(app, function()
        local w = app:mainWindow()
        if w then
          focusWindow(w)
        else
          -- Still no mainWindow - get first available window
          local wins = collectWindows(app)
          if #wins > 0 then focusWindow(wins[1]) end
        end
      end, ACTIVATION_TIMEOUT)
      return true
    end
  end

  -- Launch path: non-blocking nudge to focus a window after spawn
  local launched = appmod.launchOrFocusByBundleID(bundleId)
  if not launched then
    hs.alert.show("Launch failed: " .. (bundleId or "?"), ALERT_DURATION_ERROR)
    return false
  end
  timermod.doAfter(LAUNCH_FOCUS_DELAY, function()
    local a = appmod.get(bundleId)
    if not a then return end
    local wins = collectWindows(a)
    focusWindow(wins[1] or a:mainWindow())
  end)
  return true
end

-- === Utilities ==============================================================

local function toggleConsole()
  local cw = hs.console.hswindow()
  if cw then cw:focus() else hs.openConsole() end
end

local function reloadConfig() hs.reload() end

local function showDiagnostics()
  local running = appmod.runningApplications()
  local front = appmod.frontmostApplication()
  print("=== Hammerspoon Diagnostics ===")
  print(string.format("Running applications: %d", #running))
  print("Frontmost app: " .. (front and front:name() or "none"))
  print("Hotkeys active.")
  hs.alert.show("Diagnostics -> Console", ALERT_DURATION)
end

local function checkBundleIDs()
  print("=== Bundle ID Checker ===")
  for key, bundleId in pairs(apps) do
    local app = appmod.get(bundleId)
    if app then
      local status = app:isRunning() and "✓ RUNNING" or "○ Not running"
      print(string.format("[%s] %s  %s (%s)", key, status, app:name(), bundleId))
    else
      print(string.format("[%s] ❌ NOT FOUND  (%s)", key, bundleId))
    end
  end
  print("\n=== Running Apps (name → bundleID) ===")
  for _, a in ipairs(appmod.runningApplications()) do
    if a:name() and a:bundleID() then
      print("  " .. a:name() .. " → " .. a:bundleID())
    end
  end
  hs.alert.show("Bundle IDs -> Console", ALERT_DURATION)
end

-- === Hotkeys (no dupes on reload, repeat to cycle) ==========================

local activeHotkeys = {}

local function unbindHotkeys()
  for _, hk in ipairs(activeHotkeys) do
    hk:disable(); hk:delete()
  end
  activeHotkeys = {}
end

local function bindHotkeys()
  unbindHotkeys()

  -- App switching: press to activate/focus, hold to rapid-cycle windows
  for key, bundleId in pairs(apps) do
    local hk = hs.hotkey.bind(hyper, key,
      function() switchToApp(bundleId) end,     -- pressed
      nil,                                      -- released
      function()                                -- repeat (while held)
        local app = appmod.get(bundleId)
        if app and app:isFrontmost() then cycleAppWindows(app) end
      end
    )
    table.insert(activeHotkeys, hk)
  end

  -- Window management
  table.insert(activeHotkeys, hs.hotkey.bind(hyper, "Left",   nil, window.left))
  table.insert(activeHotkeys, hs.hotkey.bind(hyper, "Right",  nil, window.right))
  table.insert(activeHotkeys, hs.hotkey.bind(hyper, "Up",     nil, window.up))
  table.insert(activeHotkeys, hs.hotkey.bind(hyper, "Down",   nil, window.down))
  table.insert(activeHotkeys, hs.hotkey.bind(hyper, "Return", nil, window.maximize))
  table.insert(activeHotkeys, hs.hotkey.bind(hyper, "Space",  nil, window.center))

  -- Utilities
  table.insert(activeHotkeys, hs.hotkey.bind(hyper, "Y", nil, toggleConsole))
  table.insert(activeHotkeys, hs.hotkey.bind(hyper, "R", nil, reloadConfig))
  table.insert(activeHotkeys, hs.hotkey.bind(hyper, "9", nil, showDiagnostics))
  table.insert(activeHotkeys, hs.hotkey.bind(hyper, "8", nil, checkBundleIDs))

  print("Hotkeys bound.")
end

-- === Init ===================================================================

bindHotkeys()
hs.alert.show("Hammerspoon Ready", ALERT_DURATION)
print("Loaded. Hyper+8: Bundle IDs. Hyper+9: Diagnostics.")
