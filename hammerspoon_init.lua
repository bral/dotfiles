--[[
Hammerspoon Configuration (Extreme Performance + Path Apps)
==========================================================
This configuration is optimized for speed by using local references,
pre-caching running apps, reducing closures, limiting watchers, etc.

Modules:
- FFI: Low-level C function bindings for performance
- Config: User configuration settings
- Utils: Utility functions (logging, etc.)
- AppManagement: Application switching and tracking
- WindowManagement: Window positioning and manipulation
- Init: Initialization and hotkey binding
--]]

------------------------------
-- Local References for Speed
------------------------------
local hsApp      = hs.application
local hsWin      = hs.window
local hsHotkey   = hs.hotkey
local hsTimer    = hs.timer
local hsAlert    = hs.alert
local hsConsole  = hs.console
local hsReload   = hs.reload
local hsWatcher  = hs.application.watcher
local hsScreenWatcher = hs.screen.watcher
local strFmt     = string.format
local tblInsert  = table.insert
local printFn    = print
local collectG   = collectgarbage
local pairs      = pairs
local ipairs     = ipairs

-- Use built-in Lua 5.3+ bitwise operations (no library needed)
-- Note: Hammerspoon uses Lua 5.4 which has these operators built-in
-- band is &, bor is |, rshift is >>, lshift is <<
local floor = math.floor

------------------------------
-- Config Module
------------------------------
local Config = {}

Config.hyper = {"cmd", "alt", "ctrl", "shift"}

Config.debug = {
  enabled = false,         -- Switch to false for max speed (no logs/metrics)
  logLevel = "error",      -- "info", "debug", "warning", "error"
  performanceProfiling = false  -- Disable detailed timing logs
}

-- Removed mouse centering option
Config.throttleTime = 0.001  -- Reduced from 0.01 to improve responsiveness
Config.debounceTime = 0.02  -- Reduced for rapid switching (was 0.08)

Config.appHotkeys = {
  { key = "C", app = "Calendar" },
  { key = "D", app = "Discord" },
  { key = "F", app = "company.thebrowser.Browser" }, -- Arc
  { key = "I", app = "Ghostty" },
  { key = "J", app = "Slack" },
  { key = "K", app = "Motion" },
  { key = "L", app = "Superhuman" },
  { key = "M", app = "com.apple.MobileSMS" }, -- Messages
  { key = "N", app = "Notion" },
  { key = "O", app = "Obsidian" },
  { key = "P", app = "Spotify" },
  { key = "U", app = "Msty" },
  -- { key = "V", app = "com.todesktop.230313mzl4w4u92" }, -- Cursor
  { key = "V", app = "com.microsoft.VSCode" }, -- VsCode
  { key = "Z", app = "zoom.us" }
}

-- Optimize LuaJIT performance through aggressive garbage collection tuning
-- These settings optimize for minimum pause time with incremental GC
collectG("setpause", 140)   -- More aggressive than default (100)
collectG("setstepmul", 200) -- Less aggressive than default (200)

-- Print FFI status at startup with more details
hs.timer.doAfter(1, function()
  print("============= FFI WINDOW MANAGEMENT STATUS =============")
  print("- FFI loaded: " .. tostring(FFI and FFI.ffi ~= nil))
  print("- FFI window management available: " .. tostring(FFI and FFI.windowManagementAvailable))

  -- Test window management functionality (if available)
  if FFI and FFI.windowManagementAvailable then
    print("  Window management FFI is available")
  else
    print("  Window management FFI is not available - using standard hs.window methods")
  end
  print("========================================================")
end)

-- Advanced LuaJIT optimizations if jit.* API is available
local jit = package.preload.jit and require("jit")
if jit then
  -- Enable JIT for all Lua code, even when using FFI
  jit.on()
  -- Focus on optimizing the code paths that run most frequently
  jit.opt.start("hotloop=10", "hotexit=2", "maxside=100", "maxmcode=4096")
  jit.flush() -- Clear any existing compiled code
end

-- Table reutilization pool for frequently created/destroyed tables
local TablePool = {
  pool = {},
  maxSize = 20,
  size = 0
}

function TablePool.get()
  if TablePool.size > 0 then
    TablePool.size = TablePool.size - 1
    local tbl = TablePool.pool[TablePool.size + 1]
    TablePool.pool[TablePool.size + 1] = nil
    return tbl
  end
  return {}
end

function TablePool.recycle(tbl)
  -- Clear the table
  for k in pairs(tbl) do tbl[k] = nil end
  -- Add to pool if not full
  if TablePool.size < TablePool.maxSize then
    TablePool.size = TablePool.size + 1
    TablePool.pool[TablePool.size] = tbl
  end
end

------------------------------
-- Utils Module
------------------------------
local Utils = {}

-- Metrics tracking
Utils.metrics = {
  windowOps = { count = 0, totalTime = 0 },
  appSwitches = { count = 0, totalTime = 0, lastTime = 0 },
  cacheHits = 0,
  cacheMisses = 0,
  cacheCorruptions = 0,
  instantFocusHits = 0,
  instantFocusMisses = 0,
  debounceSkips = 0,
  validationCalls = 0,
  validationTime = 0
}

-- Logging
Utils.logLevels = {
  debug = 1,
  info = 2,
  warning = 3,
  error = 4
}

-- Pre-compute log level strings for performance
Utils.levelStrings = {
  debug = "DEBUG: ",
  info = "INFO: ",
  warning = "WARNING: ",
  error = "ERROR: "
}

-- Cache frequently-accessed configuration values
Utils.debugEnabled = Config.debug.enabled
Utils.configuredLogLevel = Utils.logLevels[Config.debug.logLevel] or 2

-- Cache config values that are checked frequently
-- Using Utils table instead of local for centralized access
Utils.WIN_DEBOUNCE_NS = (Config.debounceTime or 0.08) * 1000000000

-- Create direct references for performance in hot paths
local WIN_DEBOUNCE_NS = Utils.WIN_DEBOUNCE_NS

-- Function to update cached config if values change at runtime
function Utils.updateCachedConfig()
  -- Update module level variables first
  Utils.WIN_DEBOUNCE_NS = (Config.debounceTime or 0.08) * 1000000000

  -- Then update local references
  WIN_DEBOUNCE_NS = Utils.WIN_DEBOUNCE_NS

  -- Log update if debugging is enabled
  if Utils.debugEnabled then
    Utils.log("debug", "Updated cached config values")
  end
end

function Utils.log(level, message)
  -- If debug is disabled, skip everything for maximum speed
  if not Utils.debugEnabled then return end

  local messageLevel = Utils.logLevels[level] or 2
  if messageLevel < Utils.configuredLogLevel then return end

  -- Use pre-computed level string
  printFn(Utils.levelStrings[level] .. message)
end

------------------------------
-- FFI Module
------------------------------
local FFI = {}

FFI.ffi = package.preload.ffi and require("ffi")
FFI.windowManagementAvailable = false -- Will be set true on successful FFI setup
local ffiWin = false   -- Local cache for FFI.windowManagementAvailable

if FFI.ffi then

  -- FFI Window Management Setup
  success, err = pcall(function()
    FFI.ffi.cdef[[
      // Additional window management functions for specific window elements
      AXUIElementRef AXUIElementCopyAttributeValue(AXUIElementRef element, CFStringRef attribute, AXUIElementRef *value);
      /* CoreGraphics & Accessibility C Definitions for FFI */

      // Forward declarations for CoreGraphics structures
      typedef struct CGPoint CGPoint;
      typedef struct CGSize CGSize;
      typedef struct CGRect CGRect;

      // Structure representing width and height values.
      struct CGSize {
        double width;
        double height;
      };

      // Structure representing a rectangle (origin point + size).
      struct CGRect {
        CGPoint origin; // The coordinates of the rectangle's origin (typically top-left).
        CGSize size;    // The width and height of the rectangle.
      };

      // Opaque type representing an accessibility UI element (e.g., application, window).
      typedef void* AXUIElementRef;
      // Opaque type representing a Core Foundation string reference.
      typedef void* CFStringRef;
      // Opaque type representing a Core Foundation object reference (used for CFRelease).
      typedef void* CFTypeRef;
      // Process identifier type.
      typedef int pid_t;

      // Creates an accessibility object for the application with the specified process ID.
      AXUIElementRef AXUIElementCreateApplication(pid_t pid);

      // Sets the value of an accessibility attribute for a UI element.
      // Used here to set AXPosition and AXSize. Returns 0 on success.
      // Note: The 'value' type depends on the attribute (e.g., CGPoint for AXPosition, CGSize for AXSize).
      // We pass CGRect here, but the underlying functions expect specific types.
      // This seems to work due to how FFI handles struct passing, but is technically imprecise.
      // A more correct approach might involve separate calls with CGPoint and CGSize.
      int AXUIElementSetAttributeValue(AXUIElementRef element, CFStringRef attribute, CFTypeRef value);

      // Decrements the reference count of a Core Foundation object.
      // Crucial for preventing memory leaks with CF objects created/retained by API calls.
      void CFRelease(CFTypeRef cf);

      // Creates a CoreGraphics rectangle structure.
      CGRect CGRectMake(double x, double y, double width, double height);

      // Creates a CoreFoundation string from a C string.
      CFStringRef CFStringCreateWithCString(CFTypeRef allocator, const char *cStr, int encoding);
    ]]

    -- Pre-cache commonly used values
    -- Cache for AXUIElementRef objects, keyed by hs.window objects.
    -- Weak keys/values allow Lua GC to collect entries when the hs.window object is gone,
    -- but CFRelease is still needed for the AXUIElementRef itself (handled by timer/shutdown).
    FFI.axElementCache = setmetatable({}, {
      __mode = "kv",
      -- Add a __gc metamethod for automatic cleanup
      __gc = function(cache)
        if Utils.debugEnabled then
          Utils.log("debug", "AX element cache garbage collected")
        end
        -- CFRelease is handled separately by FFI.shutdown
      end
    })

    -- Pre-create CoreFoundation strings for Accessibility attribute names.
    -- This avoids string creation overhead during hotkey execution.
    -- Requires CFRelease on shutdown.
    if FFI.ffi.C.CFStringCreateWithCString then
      -- Note: Using FFI.CoreGraphics assumes CoreGraphics was loaded successfully earlier.
      -- A more robust check might be needed if CoreGraphics loading can fail independently.
      -- The last argument '0' corresponds to kCFStringEncodingMacRoman, a common default.
      FFI.axPositionAttr = FFI.ffi.C.CFStringCreateWithCString(nil, "AXPosition", 0)
      FFI.axSizeAttr = FFI.ffi.C.CFStringCreateWithCString(nil, "AXSize", 0)
      FFI.windowAttr = FFI.ffi.C.CFStringCreateWithCString(nil, "AXFocusedWindow", 0)
    else
      error("FFI function CFStringCreateWithCString not found. FFI setup incomplete.")
    end

    -- Pre-allocate CGPoint and CGSize structs for window management to avoid allocation in hot path
    FFI.cachedWinOrigin = FFI.ffi.new("CGPoint")
    FFI.cachedWinSize = FFI.ffi.new("CGSize")
    FFI.windowRef = FFI.ffi.new("AXUIElementRef[1]") -- For window element copy operations

    -- Retrieves or creates the AXUIElementRef for a given hs.window's application.
    FFI.getAXUIElement = function(win)
      if not win or not win:isValid() then return nil end

      -- Check cache first (using direct table access for speed)
      local cached = FFI.axElementCache[win]
      if cached then
        if Utils.debugEnabled then
          Utils.metrics.cacheHits = Utils.metrics.cacheHits + 1
        end
        return cached
      end

      -- Get process ID from the window
      local pid = win:pid()
      if not pid then return nil end

      -- Create the AX element for the application PID
      -- Note: This creates an element for the *application*, not the specific window.
      -- Setting AXPosition/AXSize on the app element often affects the main/focused window.
      local element = FFI.ffi.C.AXUIElementCreateApplication(pid)
      if element == nil then return nil end -- Creation failed

      -- Store in cache (weak reference)
      FFI.axElementCache[win] = element

      if Utils.debugEnabled then
        Utils.metrics.cacheMisses = Utils.metrics.cacheMisses + 1
        Utils.log("debug", string.format("Created AX element for window %d (PID: %d)", win:id(), pid))
      end

      return element
    end

    -- Gets the window element from the application element
    FFI.getWindowElement = function(win)
      -- First check if the window is valid to avoid errors
      local isValid = false
      pcall(function()
        isValid = win and win.isValid and win:isValid()
      end)
      if not isValid then return nil end

      local appElement = FFI.getAXUIElement(win)
      if not appElement then return nil end

      -- Get the focused window from the application
      local windowRef = FFI.windowRef -- Use pre-allocated array
      if FFI.ffi.C.AXUIElementCopyAttributeValue(appElement,
         FFI.windowAttr, windowRef) == 0 then
         return windowRef[0]
      end
      return nil
    end

    -- Sets the window frame (position and size) using FFI Accessibility calls.
    FFI.setWindowFrame = function(win, x, y, w, h)
      if not win or not win:isValid() then return false end

      -- First try to get the specific window element
      local windowElement = FFI.getWindowElement(win)
      -- If no specific window found, fall back to application element
      local element = windowElement or FFI.getAXUIElement(win)
      if not element then return false end

      -- Use pre-allocated CGPoint and CGSize structures for performance
      local origin = FFI.cachedWinOrigin
      local size = FFI.cachedWinSize
      origin.x, origin.y = x, y
      size.width, size.height = w, h

      local success = true
      -- Set the AXPosition attribute using the pre-allocated CGPoint
      if FFI.ffi.C.AXUIElementSetAttributeValue(element, FFI.axPositionAttr, origin) ~= 0 then
        success = false
        if Utils.debugEnabled then Utils.log("warning", "FFI: Failed to set AXPosition") end
      end
      -- Set the AXSize attribute using the pre-allocated CGSize
      if FFI.ffi.C.AXUIElementSetAttributeValue(element, FFI.axSizeAttr, size) ~= 0 then
        success = false
        if Utils.debugEnabled then Utils.log("warning", "FFI: Failed to set AXSize") end
      end

      -- Release window element if we got one, but not app element (which is cached)
      if windowElement and windowElement ~= element then
        FFI.ffi.C.CFRelease(windowElement)
      end

      return success
    end

    -- Add cleanup function to release cached elements when windows are destroyed
    FFI.cleanupAXElements = function()
      local cache = FFI.axElementCache -- Cache table locally
      local cfRelease = FFI.ffi.C.CFRelease -- Cache FFI function locally
      for win, element in pairs(cache) do
        if not win:isValid() then
          cfRelease(element) -- Use local cache
          cache[win] = nil
        end
      end

      if Utils.debugEnabled then
        Utils.log("debug", "Cleaned up invalid AX elements from cache")
      end
    end

    -- Set up timer for periodic cleanup to prevent memory leaks
    FFI.cleanupTimer = hsTimer.new(30, FFI.cleanupAXElements):start()

    -- This timer was removed since we now have a dedicated cleanup timer initialized earlier

    FFI.windowManagementAvailable = success -- Use actual success value
    ffiWin = success -- Update local cache
    return success
  end)

  if not success and Utils.debugEnabled then
    Utils.log("error", "FFI window management setup failed: " .. tostring(err))
  end

  -- Add shutdown cleanup function
  FFI.shutdown = function()
    if not FFI.ffi then return end

    -- Clean up AX elements
    for win, element in pairs(FFI.axElementCache or {}) do
      FFI.ffi.C.CFRelease(element)
    end

    -- Release CF strings
    if FFI.axPositionAttr then FFI.ffi.C.CFRelease(FFI.axPositionAttr) end
    if FFI.axSizeAttr then FFI.ffi.C.CFRelease(FFI.axSizeAttr) end
    if FFI.windowAttr then FFI.ffi.C.CFRelease(FFI.windowAttr) end

    if Utils.debugEnabled then
      Utils.log("info", "FFI shutdown: Released all CoreFoundation objects")
    end
  end

  -- Window management FFI functions initialized below if available

  -- Enhanced hot path caching for window management
  if FFI.windowManagementAvailable then
    -- Cache all FFI functions directly to locals for fastest possible access
    -- This eliminates table lookups in the critical path
    local AXUIElementSetAttributeValue = FFI.ffi.C.AXUIElementSetAttributeValue
    local axPositionAttr = FFI.axPositionAttr
    local axSizeAttr = FFI.axSizeAttr
    local cachedWinOrigin = FFI.cachedWinOrigin
    local cachedWinSize = FFI.cachedWinSize

    -- Pre-compute the most common window positions and sizes
    -- Cache matrix of common operations to avoid calculations
    FFI.frameCache = {}

    -- Enhanced position cache with element-specific results
    FFI.elementFrameCache = {} -- Cache per element address
    FFI.frameCache = {} -- Existing cache for dimensions only
    FFI.cacheHits = 0
    FFI.cacheMisses = 0

    -- Ultra-optimized window position setter with multi-level caching strategy
    FFI.directWindowSet = function(element, x, y, w, h)
      -- Element-position combo cache check (fastest path)
      local elementAddr = tostring(element):match("0x%x+")
      if elementAddr then
        local elemCacheKey = elementAddr..","..x..","..y..","..w..","..h
        if FFI.elementFrameCache[elemCacheKey] ~= nil then
          FFI.cacheHits = FFI.cacheHits + 1
          return FFI.elementFrameCache[elemCacheKey]
        end
      end

      -- Dimensions-only cache check
      local cacheKey = x..","..y..","..w..","..h
      local posResult, sizeResult = 0, 0

      if FFI.frameCache[cacheKey] then
        -- Use pre-computed values from cache
        posResult = FFI.frameCache[cacheKey][1]
        sizeResult = FFI.frameCache[cacheKey][2]
      else
        -- Fast path - set values directly with no temporary tables
        cachedWinOrigin.x, cachedWinOrigin.y = x, y
        cachedWinSize.width, cachedWinSize.height = w, h

        -- Direct FFI calls with no function overhead
        posResult = AXUIElementSetAttributeValue(element, axPositionAttr, cachedWinOrigin)
        sizeResult = AXUIElementSetAttributeValue(element, axSizeAttr, cachedWinSize)

        -- Store results in frame cache
        if #FFI.frameCache < 30 then -- Increased cache size
          FFI.frameCache[cacheKey] = {posResult, sizeResult}
        end
      end

      local success = posResult == 0 and sizeResult == 0

      -- Store in element-specific cache for fastest lookup next time
      if elementAddr and #FFI.elementFrameCache < 50 then
        FFI.elementFrameCache[elementAddr..","..x..","..y..","..w..","..h] = success
      end

      FFI.cacheMisses = FFI.cacheMisses + 1
      return success
    end
  end
end

------------------------------
-- Window Management Module
------------------------------
local WindowManagement = {}

-- Initialize windowLayout based on FFI availability (using cached local 'ffiWin')
if ffiWin then
  WindowManagement.layout = {
    left = function(max, win)
      local element = FFI.getAXUIElement(win)
      if element then
        -- Use standard division instead of bit shift to ensure correct sizing
        return FFI.directWindowSet(element, max.x, max.y, max.w / 2, max.h)
      end
      return false
    end,
    right = function(max, win)
      local element = FFI.getAXUIElement(win)
      if element then
        -- Use standard division instead of bit shift to ensure correct sizing
        local halfW = max.w / 2
        return FFI.directWindowSet(element, max.x + halfW, max.y, halfW, max.h)
      end
      return false
    end,
    up = function(max, win)
      local element = FFI.getAXUIElement(win)
      if element then
        -- Use standard division instead of bit shift to ensure correct sizing
        return FFI.directWindowSet(element, max.x, max.y, max.w, max.h / 2)
      end
      return false
    end,
    down = function(max, win)
      local element = FFI.getAXUIElement(win)
      if element then
        -- Use standard division instead of bit shift to ensure correct sizing
        local halfH = max.h / 2
        return FFI.directWindowSet(element, max.x, max.y + halfH, max.w, halfH)
      end
      return false
    end,
    max = function(max, win)
      local element = FFI.getAXUIElement(win)
      if element then
        return FFI.directWindowSet(element, max.x, max.y, max.w, max.h)
      end
      return false
    end,
    center = function(max, win)
      local element = FFI.getAXUIElement(win)
      if element then
        -- Use bit shifts for division by 8 (0.125) and 4 (0.75 = 1 - 0.25)
        -- Division by 8 = shift right by 3
        -- Multiplication by 0.75 = subtract (shift right by 2) from original
        local w8 = max.w >> 3  -- max.w/8
        local h8 = max.h >> 3  -- max.h/8
        local w75 = max.w - (max.w >> 2)  -- max.w*0.75
        local h75 = max.h - (max.h >> 2)  -- max.h*0.75
        return FFI.directWindowSet(element, max.x + w8, max.y + h8, w75, h75)
      end
      return false
    end
  }
else
  WindowManagement.layout = {
    left   = function(max, win) win:setFrame({x = max.x, y = max.y, w = max.w >> 1, h = max.h}) end,
    right  = function(max, win)
      local halfW = max.w >> 1
      win:setFrame({x = max.x + halfW, y = max.y, w = halfW, h = max.h})
    end,
    up     = function(max, win) win:setFrame({x = max.x, y = max.y, w = max.w, h = max.h >> 1}) end,
    down   = function(max, win)
      local halfH = max.h >> 1
      win:setFrame({x = max.x, y = max.y + halfH, w = max.w, h = halfH})
    end,
    max    = function(max, win) win:setFrame({x = max.x, y = max.y, w = max.w, h = max.h}) end,
    center = function(max, win)
      -- Use bit shifts for division by 8 (0.125) and 4 (0.75 = 1 - 0.25)
      local w8 = max.w >> 3  -- max.w/8
      local h8 = max.h >> 3  -- max.h/8
      local w75 = max.w - (max.w >> 2)  -- max.w*0.75
      local h75 = max.h - (max.h >> 2)  -- max.h*0.75
      win:setFrame({x = max.x + w8, y = max.y + h8, w = w75, h = h75})
    end
  }
end

-- Enhanced window management with performance optimizations
local lastWindowOpTime = 0
-- WIN_DEBOUNCE_NS is now defined globally with other cached config values

-- App switching debouncing to prevent rapid switching overhead
local lastAppSwitchTime = 0
local APP_SWITCH_DEBOUNCE_NS = 50000000 -- 50ms in nanoseconds

-- Simplified screen frame caching with event-based invalidation
WindowManagement.screenFrameCache = {}
local commonScreenLayouts = {}
local screenWatcher = nil

function WindowManagement.getScreenFrame(screen)
  local screenID = screen:id()

  -- Check if we have a cached frame
  if WindowManagement.screenFrameCache[screenID] then
    return WindowManagement.screenFrameCache[screenID]
  end

  -- Get fresh frame and cache it
  local frame = screen:frame()
  WindowManagement.screenFrameCache[screenID] = frame

  -- If this is primary screen, cache all common window positions
  if screen == hs.screen.primaryScreen() then
    commonScreenLayouts.primary = frame
    
    -- Pre-compute all commonly used layouts for maximum performance
    commonScreenLayouts.leftHalf = {
      x = frame.x,
      y = frame.y,
      w = frame.w >> 1,
      h = frame.h
    }

    commonScreenLayouts.rightHalf = {
      x = frame.x + (frame.w >> 1),
      y = frame.y,
      w = frame.w >> 1,
      h = frame.h
    }

    commonScreenLayouts.topHalf = {
      x = frame.x,
      y = frame.y,
      w = frame.w,
      h = frame.h >> 1
    }

    commonScreenLayouts.bottomHalf = {
      x = frame.x,
      y = frame.y + (frame.h >> 1),
      w = frame.w,
      h = frame.h >> 1
    }

    commonScreenLayouts.center = {
      x = frame.x + (frame.w >> 3),
      y = frame.y + (frame.h >> 3),
      w = frame.w - (frame.w >> 2),
      h = frame.h - (frame.h >> 2)
    }

    commonScreenLayouts.max = frame
  end

  return frame
end

-- Function to invalidate screen caches when screens change
local function invalidateScreenCaches()
  WindowManagement.screenFrameCache = {}
  commonScreenLayouts = {}
  if Utils.debugEnabled then
    Utils.log("debug", "Screen caches invalidated due to screen configuration change")
  end
end

-- Direct accessor functions for common layouts (zero computation)
WindowManagement.getLeftHalfLayout = function()
  return commonScreenLayouts.leftHalf
end

WindowManagement.getRightHalfLayout = function()
  return commonScreenLayouts.rightHalf
end

WindowManagement.getTopHalfLayout = function()
  return commonScreenLayouts.topHalf
end

WindowManagement.getBottomHalfLayout = function()
  return commonScreenLayouts.bottomHalf
end

WindowManagement.getCenterLayout = function()
  return commonScreenLayouts.center
end

WindowManagement.getMaxLayout = function()
  return commonScreenLayouts.max
end

-- Fast path information for even more optimization
local lastDirection = nil
local lastWindow = nil
local lastSuccess = false
local useFrequentLayoutCache = true -- Set to false if problems

function WindowManagement.moveWindow(direction)
  local win = hsWin.focusedWindow()
  if not win then return end
  local scr = win:screen()
  if not scr then return end

  -- Ultra-fast path: If same window and same direction as last time, and it worked
  -- This completely skips all calculations and reuses the last frame directly
  if useFrequentLayoutCache and lastWindow == win and lastDirection == direction and lastSuccess then
    -- Debounce still applies
    local currentTime = hsTimer.absoluteTime()
    if (currentTime - lastWindowOpTime) < WIN_DEBOUNCE_NS then
      return -- Skip if called too frequently
    end
    lastWindowOpTime = currentTime

    -- Skip all calculations and reuse last successful operation
    if Utils.debugEnabled then
      Utils.log("debug", "Ultra-fast path: Reusing last successful window operation")
    end

    -- Reuse the exact same frame that worked last time
    win:setFrame(lastWindow:frame())
    return
  end

  -- Debounce rapid calls using nanosecond precision
  local currentTime = hsTimer.absoluteTime()
  if (currentTime - lastWindowOpTime) < WIN_DEBOUNCE_NS then
    return -- Skip if called too frequently
  end
  lastWindowOpTime = currentTime

  -- If debug is enabled, measure time
  local startTime = Utils.debugEnabled and hsTimer.secondsSinceEpoch()

  -- Check if we can use pre-computed layouts for primary screen
  local usePrimary = scr == hs.screen.primaryScreen()
  local frame
  local success = false

  if usePrimary then
    -- Ensure screen cache is populated first
    WindowManagement.getScreenFrame(scr)
    
    -- Now safely use pre-computed layouts
    if direction == "left" and WindowManagement.getLeftHalfLayout then
      frame = WindowManagement.getLeftHalfLayout()
      if frame then
        win:setFrame(frame)
        success = true
      end
    elseif direction == "right" and WindowManagement.getRightHalfLayout then
      frame = WindowManagement.getRightHalfLayout()
      if frame then
        win:setFrame(frame)
        success = true
      end
    elseif direction == "up" and WindowManagement.getTopHalfLayout then
      frame = WindowManagement.getTopHalfLayout()
      if frame then
        win:setFrame(frame)
        success = true
      end
    elseif direction == "down" and WindowManagement.getBottomHalfLayout then
      frame = WindowManagement.getBottomHalfLayout()
      if frame then
        win:setFrame(frame)
        success = true
      end
    elseif direction == "center" and WindowManagement.getCenterLayout then
      frame = WindowManagement.getCenterLayout()
      if frame then
        win:setFrame(frame)
        success = true
      end
    elseif direction == "max" and WindowManagement.getMaxLayout then
      frame = WindowManagement.getMaxLayout()
      if frame then
        win:setFrame(frame)
        success = true
      end
    end
  end
  
  -- Fall back to normal frame calculation and layout function if needed
  if not success then
    frame = WindowManagement.getScreenFrame(scr)
    local layout = WindowManagement.layout -- Cache layout table locally
    success = layout[direction](frame, win)
  end

  -- Remember for ultra-fast path
  lastWindow = win
  lastDirection = direction
  lastSuccess = success

  -- Update metrics if debug is enabled
  if Utils.debugEnabled then
    local endTime = hsTimer.secondsSinceEpoch()
    Utils.metrics.windowOps.count = Utils.metrics.windowOps.count + 1
    Utils.metrics.windowOps.totalTime = Utils.metrics.windowOps.totalTime + (endTime - startTime)
    if not success then
      Utils.log("warning", "Window operation failed for direction: " .. direction)
    end
  end
end

-- Dedicated functions for each direction to avoid anonymous closures
function WindowManagement.moveLeft()   WindowManagement.moveWindow("left")   end
function WindowManagement.moveRight()  WindowManagement.moveWindow("right")  end
function WindowManagement.moveUp()     WindowManagement.moveWindow("up")     end
function WindowManagement.moveDown()   WindowManagement.moveWindow("down")   end
function WindowManagement.moveMax()    WindowManagement.moveWindow("max")    end
function WindowManagement.moveCenter() WindowManagement.moveWindow("center") end

------------------------------
-- App Management Module
------------------------------
local AppManagement = {}

-- App cache with intelligent loading, weak references, and predictive preloading
AppManagement.appCache = setmetatable({}, {
  __mode = "kv", -- Both keys and values are weak references
  __index = function(self, key)
    if not key or key == "" then return nil end

    -- Check if we have a cached entry
    local cachedEntry = rawget(self, key)
    if cachedEntry then
      if Utils.debugEnabled then
        Utils.metrics.cacheHits = Utils.metrics.cacheHits + 1
      end
      return cachedEntry
    end

    -- Record access frequency for predictive loading
    AppManagement.frequencyCounter = AppManagement.frequencyCounter or {}
    local newCount = (AppManagement.frequencyCounter[key] or 0) + 1
    AppManagement.frequencyCounter[key] = newCount
    
    -- Update top apps list incrementally
    AppManagement.updateTopAppsList(key, newCount)

    local app = nil
    -- Determine lookup strategy based on key format
    if key:find("%.") then -- Looks like a bundle ID
      app = hsApp.get(key)
    elseif key:sub(1,1) == "/" then -- Looks like a path
      app = hsApp.get(key)
    else -- Assume it's an app name
      app = hsApp.get('^' .. key .. '$') or -- Try exact name match first
            hsApp.get(key)                   -- Fallback to fuzzy name match
    end

    -- If found and running, cache it under all relevant keys
    if app and app:isRunning() then
      local name, bundleID = app:name(), app:bundleID()
      
      local cacheEntry = {
        app = app,
        validated = hsTimer.absoluteTime()
      }

      -- Cache under all relevant keys
      if name then
        self[name] = cacheEntry
      end

      if bundleID then
        self[bundleID] = cacheEntry
      end

      -- Also cache under the original key if it wasn't the name or bundleID
      if key ~= name and key ~= bundleID then
         self[key] = cacheEntry
      end

      if Utils.debugEnabled then
        Utils.log("debug", strFmt("Cache miss for '%s', found '%s' (%s), now cached", key, name or "N/A", bundleID or "N/A"))
        Utils.metrics.cacheMisses = Utils.metrics.cacheMisses + 1
      end
      return cacheEntry
    end

    -- App not found or not running
    if Utils.debugEnabled then
      Utils.log("debug", strFmt("Cache miss for '%s', app not found or not running", key))
      -- Note: We don't increment cacheMisses here because the app wasn't successfully retrieved.
    end
    return nil
  end
})

-- Maintain sorted top apps list for efficient preloading
AppManagement.topAppsList = {}
AppManagement.topAppsSet = {} -- For O(1) membership checks

-- Cache of apps that respond well to instant activation (skip window operations)
AppManagement.instantFocusApps = {
  -- Common apps that work well with activate(true) only
  ["com.apple.Safari"] = true,
  ["com.microsoft.VSCode"] = true,
  ["com.apple.Terminal"] = true,
  ["com.googlecode.iterm2"] = true,
  ["com.apple.finder"] = true,
  ["com.apple.mail"] = true,
  ["com.apple.MobileSMS"] = true,
  ["com.spotify.client"] = true,
  ["com.google.Chrome"] = true,
  ["com.apple.Notes"] = true,
  ["com.apple.TextEdit"] = true,
  ["com.apple.ActivityMonitor"] = true,
  ["com.apple.SystemPreferences"] = false, -- These need window operations
  ["com.apple.Preferences"] = false,
}

-- Update the top apps list when frequency changes (global function)
function AppManagement.updateTopAppsList(appKey, newCount)
  local topApps = AppManagement.topAppsList
  local topSet = AppManagement.topAppsSet
  local maxTopApps = 10 -- Keep more in list than we preload for efficiency
  
  -- Remove app from current position if it exists
  if topSet[appKey] then
    for i = 1, #topApps do
      if topApps[i].app == appKey then
        table.remove(topApps, i)
        break
      end
    end
  end
  
  -- Insert app in correct position based on count
  local inserted = false
  for i = 1, #topApps do
    if newCount > topApps[i].count then
      tblInsert(topApps, i, {app = appKey, count = newCount})
      inserted = true
      break
    end
  end
  
  -- If not inserted and list isn't full, add to end
  if not inserted and #topApps < maxTopApps then
    tblInsert(topApps, {app = appKey, count = newCount})
  end
  
  -- Trim list to max size
  if #topApps > maxTopApps then
    topApps[maxTopApps + 1] = nil
  end
  
  -- Update membership set
  topSet = {}
  for i = 1, #topApps do
    topSet[topApps[i].app] = true
  end
  AppManagement.topAppsSet = topSet
end

-- Track most frequently used apps and preload them (optimized version)
function AppManagement.predictivePreload()
  if not AppManagement.topAppsList then return end

  -- Preload the top 5 apps from our maintained list
  for i = 1, math.min(5, #AppManagement.topAppsList) do
    local appKey = AppManagement.topAppsList[i].app
    -- Only preload if not already in cache
    if not AppManagement.appCache[appKey] then
      -- Check if app is running before attempting to cache
      local app
      if appKey:find("%.") then -- Looks like a bundle ID
        app = hsApp.get(appKey)
      else
        app = hsApp.get('^' .. appKey .. '$') or hsApp.get(appKey)
      end

      if app and app:isRunning() then
        local name, bundleID = app:name(), app:bundleID()
        local cacheEntry = {
          app = app,
          validated = hsTimer.absoluteTime()
        }
      
        if name then AppManagement.appCache[name] = cacheEntry end
        if bundleID then AppManagement.appCache[bundleID] = cacheEntry end

        if Utils.debugEnabled then
          Utils.log("debug", strFmt("Predictively preloaded '%s' (%s)", name or "N/A", bundleID or "N/A"))
        end
      end
    end
  end
end

-- Pre-warm frequently used app windows to keep them responsive
AppManagement.prewarmCounter = 0
function AppManagement.prewarmAppWindows()
  if not AppManagement.topAppsList then return end
  
  -- Only pre-warm every 3rd call (every ~4.5 minutes) to avoid overhead
  AppManagement.prewarmCounter = AppManagement.prewarmCounter + 1
  if AppManagement.prewarmCounter % 3 ~= 0 then return end
  
  local prewarmedCount = 0
  
  -- Pre-warm all instant focus cache apps first (highest priority)
  for bundleID, isInstant in pairs(AppManagement.instantFocusApps) do
    if isInstant == true and prewarmedCount < 5 then
      local cachedEntry = AppManagement.appCache[bundleID]
      if cachedEntry and cachedEntry.app then
        local app = cachedEntry.app
        local ok, isValid = pcall(function() return app:isValid() and app:isRunning() end)
        if ok and isValid then
          pcall(function()
            -- Light pre-warming for instant focus apps
            app:name() -- Keep app object active
            local win = app:mainWindow()
            if win then
              win:frame() -- Touch window to keep it warm
            end
          end)
          prewarmedCount = prewarmedCount + 1
        end
      end
    end
  end
  
  -- Pre-warm top frequency apps if we have room
  for i = 1, math.min(3, #AppManagement.topAppsList) do
    if prewarmedCount >= 5 then break end
    
    local appKey = AppManagement.topAppsList[i].app
    local cachedEntry = AppManagement.appCache[appKey]
    
    if cachedEntry and cachedEntry.app then
      local app = cachedEntry.app
      local bundleID = app:bundleID()
      
      -- Skip if already pre-warmed via instant focus cache
      if not (bundleID and AppManagement.instantFocusApps[bundleID] == true) then
        local ok, isValid = pcall(function() return app:isValid() and app:isRunning() end)
        if ok and isValid then
          pcall(function()
            local win = app:mainWindow()
            if win then
              win:frame() -- Touch window to keep it responsive
            end
          end)
          prewarmedCount = prewarmedCount + 1
        end
      end
    end
  end
  
  if Utils.debugEnabled then
    Utils.log("debug", strFmt("Pre-warmed %d app windows for responsiveness", prewarmedCount))
  end
end

function AppManagement.buildRegistry()
  local cache = AppManagement.appCache -- Local cache for performance

  -- Save top apps for frequency preservation
  local topAppObjects = {}
  for key, entry in pairs(cache) do
    if entry and entry.app and entry.app:isValid() and entry.app:isRunning() then
      topAppObjects[key] = entry.app
    end
  end

  -- Clear existing caches
  for k in pairs(cache) do cache[k] = nil end

  -- Reset frequency counter but preserve the top N apps
  local topApps = {}
  if AppManagement.frequencyCounter then
    for app, count in pairs(AppManagement.frequencyCounter) do
      tblInsert(topApps, {app = app, count = count})
    end
    table.sort(topApps, function(a, b) return a.count > b.count end)
  end

  AppManagement.frequencyCounter = {}
  
  -- Clear and reset top apps list  
  AppManagement.topAppsList = {}
  AppManagement.topAppsSet = {}
  
  -- Limit cache size to prevent memory bloat over time
  local cacheCount = 0
  for _ in pairs(cache) do cacheCount = cacheCount + 1 end
  if cacheCount > 100 then -- Clear excess entries beyond 100 apps
    local keysToRemove = {}
    local count = 0
    for key in pairs(cache) do
      count = count + 1
      if count > 80 then -- Keep top 80, remove rest
        table.insert(keysToRemove, key)
      end
    end
    for _, key in ipairs(keysToRemove) do
      cache[key] = nil
    end
  end

  -- Preserve frequency data for top 10 apps with reduced counts
  for i = 1, math.min(10, #topApps) do
    -- Reset to lower count but preserve ranking
    local newCount = 11 - i
    AppManagement.frequencyCounter[topApps[i].app] = newCount
    AppManagement.updateTopAppsList(topApps[i].app, newCount)
  end

  -- Restore saved top apps first (fastest path)
  for key, app in pairs(topAppObjects or {}) do
    if app:isValid() and app:isRunning() then
      cache[key] = {
        app = app,
        validated = hsTimer.absoluteTime()
      }
    end
  end

  -- Populate from currently running apps
  local allRunning = hsApp.runningApplications()
  for _, appObj in ipairs(allRunning) do
    local name, bundleID = appObj and appObj:name(), appObj and appObj:bundleID()
    if name then
      cache[name] = {
        app = appObj,
        validated = hsTimer.absoluteTime()
      }
    end
    if bundleID then
      cache[bundleID] = {
        app = appObj,
        validated = hsTimer.absoluteTime()
      }
    end
  end

  -- More aggressive preloading of all apps defined in hotkeys
  for _, hotkeyDef in ipairs(Config.appHotkeys) do
    local appKey = hotkeyDef.app
    if not cache[appKey] then
      local app

      -- Try to get info even if app isn't running
      if appKey:find("%.") then  -- Bundle ID
        app = hsApp.get(appKey)
      else  -- App name
        -- Try exact match first, then fuzzy match
        app = hsApp.get("^" .. appKey .. "$") or hsApp.get(appKey)
      end

      if app then
        local name, bundleID = app:name(), app:bundleID()
        if name then cache[name] = app end
        if bundleID then cache[bundleID] = app end
        if appKey ~= name and appKey ~= bundleID then
          cache[appKey] = app
        end

        if Utils.debugEnabled then
          Utils.log("debug", strFmt("Preloaded app info: %s", appKey))
        end
      end
    end
  end

  -- Special case for Messages app which can be problematic
  AppManagement.preloadMessagesApp()

  if Utils.debugEnabled then
    Utils.log("debug", strFmt("Built app registry with %d apps and %d cached entries",
                             #allRunning, AppManagement.countCacheEntries()))
  end
end

-- Helper to count cache entries
function AppManagement.countCacheEntries()
  local count = 0
  for _ in pairs(AppManagement.appCache) do count = count + 1 end
  return count
end

-- Unified app focusing function with optimization
function AppManagement.focusApp(app)
  if not app then return false end

  local focusStartTime = hsTimer.secondsSinceEpoch()
  
  -- Check if this app is in our instant focus cache
  local bundleID = app:bundleID()
  if bundleID and AppManagement.instantFocusApps[bundleID] == true then
    -- Ultra-fast path: just activate without any window operations
    Utils.metrics.instantFocusHits = Utils.metrics.instantFocusHits + 1
    if Utils.debugEnabled and Config.debug.performanceProfiling then
      Utils.log("debug", strFmt("INSTANT FOCUS: '%s'", bundleID))
    end
    local result = app:activate(true)
    if Utils.debugEnabled and Config.debug.performanceProfiling then
      local duration = (hsTimer.secondsSinceEpoch() - focusStartTime) * 1000
      Utils.log("debug", strFmt("INSTANT FOCUS DONE: %.3fms", duration))
    end
    return result
  elseif bundleID and AppManagement.instantFocusApps[bundleID] == false then
    Utils.metrics.instantFocusMisses = Utils.metrics.instantFocusMisses + 1
    -- Apps that need window operations - use slower but more reliable method
    local win = app:mainWindow()
    if win then
      win:focus()
      return true
    else
      local activationSuccess = app:activate(true)
      -- Try to get window after activation
      win = app:mainWindow()
      if not win then
        local allWindows = app:allWindows()
        if #allWindows > 0 then
          win = allWindows[1]
        end
      end
      if win then
        win:focus()
      end
      return activationSuccess
    end
  else
    -- Unknown app - use original logic and learn from it
    Utils.metrics.instantFocusMisses = Utils.metrics.instantFocusMisses + 1
    if Utils.debugEnabled and Config.debug.performanceProfiling then
      Utils.log("debug", strFmt("WINDOW FOCUS: '%s' (unknown app)", bundleID or "no-bundle"))
    end
    
    local windowStartTime = hsTimer.secondsSinceEpoch()
    local activationSuccess = false
    local win = app:mainWindow()

    if win then
      win:focus()
      activationSuccess = true
      if Utils.debugEnabled and Config.debug.performanceProfiling then
        Utils.log("debug", strFmt("MAIN WINDOW: found and focused"))
      end
    else
      local activateStartTime = hsTimer.secondsSinceEpoch()
      activationSuccess = app:activate(true)
      if Utils.debugEnabled and Config.debug.performanceProfiling then
        local activateDuration = (hsTimer.secondsSinceEpoch() - activateStartTime) * 1000
        Utils.log("debug", strFmt("APP ACTIVATE: %.3fms", activateDuration))
      end
      
      -- Try again to get window after activation
      if not win then
        local windowSearchStart = hsTimer.secondsSinceEpoch()
        win = app:mainWindow()
        if not win then
          local allWindows = app:allWindows()
          if #allWindows > 0 then
            win = allWindows[1]
          end
        end
        if win then
          win:focus()
        end
        if Utils.debugEnabled and Config.debug.performanceProfiling then
          local searchDuration = (hsTimer.secondsSinceEpoch() - windowSearchStart) * 1000
          Utils.log("debug", strFmt("WINDOW SEARCH: %.3fms", searchDuration))
        end
      end
    end

    -- Learn: if activation worked quickly, mark as instant-focus-friendly
    local totalFocusTime = (hsTimer.secondsSinceEpoch() - windowStartTime) * 1000
    if activationSuccess and bundleID and totalFocusTime < 100 then -- Less than 100ms = fast
      AppManagement.instantFocusApps[bundleID] = true
      if Utils.debugEnabled then
        Utils.log("debug", strFmt("LEARNED: '%s' works well with instant focus (%.1fms)", bundleID, totalFocusTime))
      end
    end

    return activationSuccess
  end
end

-- Add a function to preload Messages app specifically
function AppManagement.preloadMessagesApp()
  -- Preload Messages app info if not already in cache
  if not AppManagement.appCache["com.apple.MobileSMS"] then
    local app = hsApp.get("com.apple.MobileSMS")
    if app then
      local name, bundleID = app:name(), app:bundleID()
      if name then AppManagement.appCache[name] = app end
      if bundleID then AppManagement.appCache[bundleID] = app end

      if Utils.debugEnabled then
        Utils.log("debug", "Preloaded Messages app info")
      end
    end
  end
end

-- Schedule predictive preloading to run in background
function AppManagement.setupPredictivePreloading()
  -- Run predictive preloading every 30 seconds
  return hsTimer.doEvery(30, function()
    -- Run in a protected call to prevent errors from breaking the timer
    local success, err = pcall(AppManagement.predictivePreload)
    if not success and Utils.debugEnabled then
      Utils.log("error", "Predictive preloading error: " .. tostring(err))
    end
  end)
end

-- No mouse positioning throttling needed

-- Fast integer rounding using bitwise operations (uses built-in Lua 5.3+ operators)
local function fastRound(n)
  n = n + 0.5
  return n - (n & 0) -- Using & operator for bitwise AND
end

-- Helper function to check if a frame is valid
function AppManagement.isFrameValid(f)
  return f and f.w > 0 and f.h > 0
end

-- Helper function to observe application launch using callbacks
function AppManagement.observeAppLaunch(appKey, callback, timeout)
  local observer = nil
  local timer = nil
  timeout = timeout or 3  -- Default 3 seconds timeout
  if Utils.debugEnabled then Utils.log("debug", strFmt("observeAppLaunch: Starting for '%s' with timeout %ds", appKey, timeout)) end

  -- Set up observer for application launched notifications
  observer = hsWatcher.new(function(appName, eventType, appObj)
    if eventType == hsWatcher.launched then
      local bundleID = appObj and appObj:bundleID()
      local name = appObj and appObj:name()

      if (appKey:find("%.") and bundleID == appKey) or
         (not appKey:find("%.") and name == appKey) then
        -- App found, stop watching and call the callback
        if Utils.debugEnabled then Utils.log("debug", strFmt("observeAppLaunch: Watcher found matching app '%s' (%s)", name or "N/A", bundleID or "N/A")) end
        observer:stop()
        if timer then timer:stop() end
        callback(true, appObj)
      end
    end
  end)

  -- Set up timeout timer
  timer = hsTimer.doAfter(timeout, function()
    if Utils.debugEnabled then Utils.log("warning", strFmt("observeAppLaunch: Timed out waiting for '%s' after %ds", appKey, timeout)) end
    observer:stop()
    callback(false, nil)  -- Timed out
  end)

  observer:start()

  return {
    stop = function()
      observer:stop()
      if timer then timer:stop() end
    end
  }
  end

  -- Switches to the specified application.
  -- If the app is running, focuses it. If not, launches it and focuses.
  -- Uses a non-blocking observer for launches.
  -- @param appKey string The bundle ID, name, or path of the application.
  -- @param options table|nil Optional table. Can contain { timeout = number } for launch observation.
  function AppManagement.switchToApp(appKey, options)
    local overallStartTime = hsTimer.secondsSinceEpoch()
    
    options = options or {} -- Ensure options table exists
    if not appKey or appKey == "" then
      if Utils.debugEnabled then Utils.log("error", "Invalid app key provided to switchToApp") end
      return false
    end

    -- Track time since last app switch
    local timeSinceLastSwitch = Utils.metrics.appSwitches.lastTime > 0 
      and (overallStartTime - Utils.metrics.appSwitches.lastTime) * 1000 or 0
    Utils.metrics.appSwitches.lastTime = overallStartTime
    
    if Utils.debugEnabled and Config.debug.performanceProfiling then
      Utils.log("debug", strFmt("=== APP SWITCH START: '%s' (%.1fms since last) ===", appKey, timeSinceLastSwitch))
    end

  local startTime
  if Utils.debugEnabled then
    startTime = hsTimer.secondsSinceEpoch()
  end

  -- Simplified single-level cache access with defensive programming
  local cacheStartTime = hsTimer.secondsSinceEpoch()
  local cachedEntry = AppManagement.appCache[appKey]
  local app = nil
  local lastValidated = nil
  
  -- Handle both cache entry structures and direct app objects
  if cachedEntry then
    if type(cachedEntry) == "table" and cachedEntry.app then
      -- New cache entry structure
      app = cachedEntry.app
      lastValidated = cachedEntry.validated
      Utils.metrics.cacheHits = Utils.metrics.cacheHits + 1
      if Utils.debugEnabled and Config.debug.performanceProfiling then
        Utils.log("debug", strFmt("CACHE HIT: '%s' (%.3fms)", appKey, (hsTimer.secondsSinceEpoch() - cacheStartTime) * 1000))
      end
    elseif type(cachedEntry) == "userdata" then
      -- Legacy direct app object - convert to new structure
      app = cachedEntry
      lastValidated = nil -- Force validation since we don't have timestamp
      AppManagement.appCache[appKey] = {
        app = app,
        validated = hsTimer.absoluteTime()
      }
      Utils.metrics.cacheHits = Utils.metrics.cacheHits + 1
      if Utils.debugEnabled and Config.debug.performanceProfiling then
        Utils.log("debug", strFmt("CACHE HIT (LEGACY): '%s' (%.3fms)", appKey, (hsTimer.secondsSinceEpoch() - cacheStartTime) * 1000))
      end
    else
      -- Unknown cache entry type, clean it up
      AppManagement.appCache[appKey] = nil
      Utils.metrics.cacheCorruptions = Utils.metrics.cacheCorruptions + 1
      if Utils.debugEnabled then
        Utils.log("debug", strFmt("CORRUPTION: Cleaned up unknown cache entry type for '%s' (type: %s)", appKey, type(cachedEntry)))
      end
    end
  else
    Utils.metrics.cacheMisses = Utils.metrics.cacheMisses + 1
    if Utils.debugEnabled and Config.debug.performanceProfiling then
      Utils.log("debug", strFmt("CACHE MISS: '%s'", appKey))
    end
  end

  -- Debounce rapid app switching to prevent cache thrashing
  local currentTime = hsTimer.absoluteTime()
  if (currentTime - lastAppSwitchTime) < APP_SWITCH_DEBOUNCE_NS then
    -- Allow instant focus cache apps to bypass debouncing
    local bundleID = app and app:bundleID()
    if not (bundleID and AppManagement.instantFocusApps[bundleID] == true) then
      Utils.metrics.debounceSkips = Utils.metrics.debounceSkips + 1
      if Utils.debugEnabled and Config.debug.performanceProfiling then
        local debounceTime = (currentTime - lastAppSwitchTime) / 1000000
        Utils.log("debug", strFmt("DEBOUNCED: '%s' (%.1fms ago, skipping)", appKey, debounceTime))
      end
      return false -- Skip rapid switches for non-instant apps
    end
  end
  lastAppSwitchTime = currentTime
  local VALIDATION_INTERVAL = 15000000000 -- 15 seconds in nanoseconds (reduced frequency)

  -- Check validity only if we haven't validated recently and app exists
  if app and type(app) == "userdata" and (not lastValidated or (currentTime - lastValidated) > VALIDATION_INTERVAL) then
    local validationStartTime = hsTimer.secondsSinceEpoch()
    Utils.metrics.validationCalls = Utils.metrics.validationCalls + 1
    
    -- Use pcall to safely check validity
    local ok, isValid = pcall(function() return app:isValid() end)
    local validationDuration = (hsTimer.secondsSinceEpoch() - validationStartTime) * 1000
    Utils.metrics.validationTime = Utils.metrics.validationTime + validationDuration
    
    if ok and isValid then
      -- Update validation timestamp
      AppManagement.appCache[appKey].validated = currentTime
      if Utils.debugEnabled and Config.debug.performanceProfiling then
        Utils.log("debug", strFmt("VALIDATION: '%s' OK (%.3fms)", appKey, validationDuration))
      end
    else
      -- Clear invalid app from cache
      AppManagement.appCache[appKey] = nil
      app = nil
      if Utils.debugEnabled then
        local reason = not ok and "error during validation" or "app no longer valid"
        Utils.log("debug", strFmt("VALIDATION: '%s' FAILED - %s (%.3fms)", appKey, reason, validationDuration))
      end
    end
  end

  -- If found in cache (and now confirmed valid), focus synchronously
  if app then
    local focusStartTime = hsTimer.secondsSinceEpoch()
    local focusSuccess = AppManagement.focusApp(app)
    local focusEndTime = hsTimer.secondsSinceEpoch()
    local overallEndTime = hsTimer.secondsSinceEpoch()
    
    if Utils.debugEnabled then
      Utils.metrics.appSwitches.count = Utils.metrics.appSwitches.count + 1
      local totalTime = overallEndTime - startTime
      local focusTime = focusEndTime - focusStartTime
      Utils.metrics.appSwitches.totalTime = Utils.metrics.appSwitches.totalTime + totalTime
      
      if Config.debug.performanceProfiling then
        Utils.log("debug", strFmt("FOCUS: %.3fms, TOTAL: %.3fms", focusTime * 1000, totalTime * 1000))
        Utils.log("debug", strFmt("=== APP SWITCH END: '%s' %s ===", appKey, focusSuccess and "SUCCESS" or "FAILED"))
      elseif focusSuccess then
        Utils.log("debug", strFmt("Successfully switched to cached app '%s' in %.3f seconds", appKey, totalTime))
      else
        Utils.log("warning", strFmt("Found cached app '%s' but failed to focus it.", appKey))
      end
    end
    return focusSuccess -- Return actual focus success
  else
    -- Not in cache, launch and observe asynchronously
    if Utils.debugEnabled then
      Utils.log("debug", strFmt("App '%s' not in cache, attempting launch and observe...", appKey))
    end

    -- Launch (or focus if already running but not cached somehow)
    if appKey:find("%.") then -- Bundle ID
      hs.application.launchOrFocusByBundleID(appKey)
    else -- App Name or Path
      hs.application.launchOrFocus(appKey)
    end

    -- Observe for launch completion (non-blocking), passing custom timeout if provided
    local launchTimeout = options.timeout -- Use timeout from options, defaults to nil (-> 3s in observeAppLaunch)
    AppManagement.observeAppLaunch(appKey, function(success, launchedApp)
      local focusSuccessAsync = false
      if success and launchedApp then
        -- App launched successfully, now focus it
        focusSuccessAsync = AppManagement.focusApp(launchedApp)
        -- Note: Caching happens automatically via __index if focusApp->mainWindow works,
        -- or via the watcherCallback if needed.
      end

      -- Log results and update metrics if debugging (inside callback)
      if Utils.debugEnabled then
        local endTime = hsTimer.secondsSinceEpoch()
        -- Note: startTime is captured from the outer scope
        Utils.metrics.appSwitches.count = Utils.metrics.appSwitches.count + 1
        Utils.metrics.appSwitches.totalTime = Utils.metrics.appSwitches.totalTime + (endTime - startTime)

        if success and launchedApp and focusSuccessAsync then
           Utils.log("debug", strFmt("Successfully launched and switched to app '%s' in %.3f seconds", appKey, endTime - startTime))
        elseif success and launchedApp and not focusSuccessAsync then
           Utils.log("warning", strFmt("Launched app '%s' but failed to focus it.", appKey))
        else -- success is false or launchedApp is nil
           Utils.log("warning", strFmt("Failed to launch or find app '%s' after timeout.", appKey))
        end
      end
      -- The callback doesn't return anything meaningful here
    end, launchTimeout) -- Pass the timeout value here

    -- Return true optimistically, as the launch process has started
    return true
  end
end

-- This watcher updates our registry when apps launch/terminate
function AppManagement.watcherCallback(appName, eventType, appObj)
  if eventType == hsWatcher.launched then
    -- App launched, add to cache if not already there
    if appObj then
      local name, bundleID = appObj:name(), appObj:bundleID()
      local cacheEntry = {
        app = appObj,
        validated = hsTimer.absoluteTime()
      }
      if name then
        AppManagement.appCache[name] = cacheEntry
      end
      if bundleID then
        AppManagement.appCache[bundleID] = cacheEntry
      end

      -- Record new app in frequency counter for future preloading
      if AppManagement.frequencyCounter then
        local key = bundleID or name
        if key then 
          AppManagement.frequencyCounter[key] = 1
          AppManagement.updateTopAppsList(key, 1)
        end
      end
    end
  elseif eventType == hsWatcher.terminated then
    -- Clear all possible keys for this app from both caches
    if appObj then
      local name, bundleID = appObj:name(), appObj:bundleID()
      if name then
        AppManagement.appCache[name] = nil
      end
      if bundleID then
        AppManagement.appCache[bundleID] = nil
      end
    end
    AppManagement.appCache[appName] = nil
  end
end

-- Create (but don't start yet)
AppManagement.watcher = hsWatcher.new(AppManagement.watcherCallback)

------------------------------
-- Init Module
------------------------------
local Init = {}

-- Pre-bind hotkey.bind for performance
local bindHotkey = hsHotkey.bind

function Init.bindAppHotkeys()
  local appHotkeyFunctions = {}
  -- Cache function locally for loop performance
  local switchTo = AppManagement.switchToApp

  for _, hotkeyDef in ipairs(Config.appHotkeys) do
    -- Create closure that directly references app name
    local appName = hotkeyDef.app
    local key = hotkeyDef.key

    -- Special case for Messages app (inlined call to switchTo)
    if key == "M" then
      tblInsert(appHotkeyFunctions, {
        key = key,
        -- Pass longer timeout for Messages launch observation
        fn = function() switchTo("com.apple.MobileSMS", { timeout = 10 }) end
      })
    else
      tblInsert(appHotkeyFunctions, {
        key = key,
        fn = function() switchTo(appName) end -- Use local cache
      })
    end
  end

  -- Bind all app hotkeys
  for _, def in ipairs(appHotkeyFunctions) do
    bindHotkey(Config.hyper, def.key, def.fn)
  end
end

function Init.bindWindowHotkeys()
  -- Bind window management hotkeys
  bindHotkey(Config.hyper, "Left",   WindowManagement.moveLeft)
  bindHotkey(Config.hyper, "Right",  WindowManagement.moveRight)
  bindHotkey(Config.hyper, "Up",     WindowManagement.moveUp)
  bindHotkey(Config.hyper, "Down",   WindowManagement.moveDown)
  bindHotkey(Config.hyper, "Return", WindowManagement.moveMax)
  bindHotkey(Config.hyper, "Space",  WindowManagement.moveCenter)
end

function Init.bindUtilityHotkeys()
  -- Console (Y) and Reload (R) hotkeys
  local function toggleConsole()
    if Config.debug.enabled then
      hsConsole.clearConsole()
    end
    hsConsole.hswindow():focus() -- Minimizes overhead vs toggle
  end

  bindHotkey(Config.hyper, "Y", toggleConsole)
  bindHotkey(Config.hyper, "R", function()
    hsReload()
    hsAlert.show("Hammerspoon config reloaded!")
  end)
end

function Init.start()
  -- Ensure all cached config values are synchronized
  Utils.updateCachedConfig()

  if Utils.debugEnabled then
    Utils.log("debug", "Building running app registry...")
  end
  AppManagement.buildRegistry()

  -- Specifically preload Messages app
  AppManagement.preloadMessagesApp()

  if Utils.debugEnabled then
    Utils.log("debug", "Starting application watcher...")
  end
  AppManagement.watcher:start()

  -- Start screen watcher for cache invalidation
  screenWatcher = hsScreenWatcher.new(invalidateScreenCaches)
  screenWatcher:start()

  -- Bind all hotkeys
  Init.bindWindowHotkeys()
  Init.bindAppHotkeys()
  Init.bindUtilityHotkeys()

  if Utils.debugEnabled then
    Utils.log("debug", "Hammerspoon initialization complete")
  end
end

-- Register shutdown handler
hs.shutdownCallback = function()
  if Utils.debugEnabled then
    Utils.log("info", "Performing shutdown cleanup...")
  end

  AppManagement.watcher:stop()
  if screenWatcher then screenWatcher:stop() end
  if FFI.shutdown then FFI.shutdown() end
  collectG("collect")
end

-- Start the configuration
Init.start()

-- Apply additional OS-level performance optimizations
function ApplyPerformanceOptimizations()
  -- Schedule consolidated maintenance tasks (reduced frequency for better performance)
  hsTimer.doEvery(90, function()
    -- Run in protected call to prevent errors from breaking the timer
    pcall(function()
      -- Predictive app preloading
      if AppManagement.predictivePreload then
        AppManagement.predictivePreload()
      end
      
      -- Pre-warm frequently used app windows
      if AppManagement.prewarmAppWindows then
        AppManagement.prewarmAppWindows()
      end
      
      -- Optional light memory cleanup (much less frequent)
      if Utils.debugEnabled then
        local before = collectG("count")
        collectG("collect")
        local after = collectG("count")
        Utils.log("debug", string.format("Maintenance GC: %0.2f KB -> %0.2f KB", before, after))
      end
    end)
  end)

  -- Let LuaJIT optimize naturally without forced parameters
  -- Note: Removed aggressive JIT settings that were counterproductive
  -- Reasoning:
  --   - jit.flush() destroys the JIT cache we want to build up
  --   - Forced hotloop/hotexit parameters interfere with adaptive optimization
  --   - LuaJIT's built-in heuristics are well-tuned for most workloads
  
  -- Use conservative GC tuning - more responsive but not aggressive
  -- These settings balance memory usage with UI responsiveness
  if collectG then
    collectG("setpause", 100)   -- Default is 200, this runs GC more frequently
    collectG("setstepmul", 120) -- Default is 200, this uses smaller GC steps
    -- Result: More frequent but smaller GC pauses = smoother performance
  end

  -- Disable macOS animations for instant app switching
  pcall(function()
    hs.execute("defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false")
    hs.execute("defaults write NSGlobalDomain NSWindowResizeTime -float 0.001")
    hs.execute("defaults write com.apple.dock expose-animation-duration -float 0.1")
    hs.execute("defaults write com.apple.dock autohide-time-modifier -float 0")
    hs.execute("defaults write com.apple.dock autohide-delay -float 0")
    
    if Utils.debugEnabled then
      Utils.log("info", "Disabled macOS animations for faster app switching")
    end
  end)



  if Utils.debugEnabled then
    Utils.log("info", "Applied OS-level performance optimizations")
  end
end

-- Call optimizations after a short delay to ensure init is complete
hsTimer.doAfter(1, ApplyPerformanceOptimizations)

-- Debug hotkeys for mouse centering removed

-- Add reload configuration hotkey
hsHotkey.bind({"cmd", "alt", "ctrl"}, "R", function()
  hsAlert.show("Reloading Hammerspoon configuration...")
  hsTimer.doAfter(0.5, function()
    hsReload()
  end)
end)
