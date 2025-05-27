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
  logLevel = "error"      -- "info", "debug", "warning", "error"
}

-- Removed mouse centering option
Config.throttleTime = 0.001  -- Reduced from 0.01 to improve responsiveness
Config.debounceTime = 0.08  -- Seconds to debounce window operations

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
  appSwitches = { count = 0, totalTime = 0 },
  cacheHits = 0,
  cacheMisses = 0
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

-- Enhanced screen frame caching with per-screen expiry
WindowManagement.screenFrameCache = {}
local screenExpiryCache = {} -- Per-screen expiry timestamps
local SCREEN_CACHE_TTL_NS = 5000000000 -- 5 seconds in nanoseconds

-- Cache most common screen layouts to avoid even lookups
local commonScreenLayouts = {}
local screenLayoutsExpiry = 0

function WindowManagement.getScreenFrame(screen)
  local currentTime = hsTimer.absoluteTime()
  local screenID = screen:id()

  -- Aggressively cache primary screen, it's used most often
  -- Check if this is the primary screen by comparing with hs.screen.primaryScreen()
  if screen == hs.screen.primaryScreen() then
    -- Try common layouts first (ultra fast)
    if currentTime - screenLayoutsExpiry < SCREEN_CACHE_TTL_NS and
       commonScreenLayouts.primary then
      return commonScreenLayouts.primary
    end
  end

  -- Check if we have a valid cached frame with per-screen expiry
  if WindowManagement.screenFrameCache[screenID] and
     screenExpiryCache[screenID] and
     currentTime - screenExpiryCache[screenID] < SCREEN_CACHE_TTL_NS then
    return WindowManagement.screenFrameCache[screenID]
  end

  -- Get fresh frame and cache it with its own timestamp
  local frame = screen:frame()
  WindowManagement.screenFrameCache[screenID] = frame
  screenExpiryCache[screenID] = currentTime

  -- If this is primary screen, cache in common layouts too
  if screen == hs.screen.primaryScreen() then
    commonScreenLayouts.primary = frame
    screenLayoutsExpiry = currentTime

    -- Pre-compute and cache common window positions
    -- This avoids thousands of calculations during window operations
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
  end

  return frame
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
  -- This completely skips layout calculations for repeated operations
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

    -- Execute same operation again
    -- Always get a valid frame for the screen to avoid nil errors
    local frame = WindowManagement.getScreenFrame(scr)
    local layout = WindowManagement.layout -- Cache layout table locally
    layout[direction](frame, win, true) -- Pass frame and true to indicate reuse
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

  if usePrimary and direction == "left" and WindowManagement.getLeftHalfLayout then
    frame = WindowManagement.getLeftHalfLayout()
  elseif usePrimary and direction == "right" and WindowManagement.getRightHalfLayout then
    frame = WindowManagement.getRightHalfLayout()
  elseif usePrimary and direction == "up" and WindowManagement.getTopHalfLayout then
    frame = WindowManagement.getTopHalfLayout()
  elseif usePrimary and direction == "down" and WindowManagement.getBottomHalfLayout then
    frame = WindowManagement.getBottomHalfLayout()
  elseif usePrimary and direction == "center" and WindowManagement.getCenterLayout then
    frame = WindowManagement.getCenterLayout()
  else
    -- Fall back to normal frame calculation
    frame = WindowManagement.getScreenFrame(scr)
  end

  -- Apply window layout with cached layout table
  local layout = WindowManagement.layout -- Cache layout table locally
  local success = layout[direction](frame, win)

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

-- Fast direct lookup table (no metatable overhead)
-- Used for most frequent app lookups
AppManagement.fastCache = {}

-- App cache with intelligent loading, weak references, and predictive preloading
AppManagement.appCache = setmetatable({}, {
  __mode = "kv", -- Both keys and values are weak references
  __index = function(self, key)
    if not key or key == "" then return nil end

    -- First check ultra-fast direct lookup cache
    local fastResult = AppManagement.fastCache[key]
    if fastResult ~= nil then
      if Utils.debugEnabled then
        Utils.metrics.cacheHits = Utils.metrics.cacheHits + 1
      end
      return fastResult
    end

    -- Record access frequency for predictive loading
    AppManagement.frequencyCounter = AppManagement.frequencyCounter or {}
    AppManagement.frequencyCounter[key] = (AppManagement.frequencyCounter[key] or 0) + 1

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

      -- Update both caches - regular weak cache and fast direct lookup
      if name then
        self[name] = app
        AppManagement.fastCache[name] = app
      end

      if bundleID then
        self[bundleID] = app
        AppManagement.fastCache[bundleID] = app
      end

      -- Also cache under the original key if it wasn't the name or bundleID
      if key ~= name and key ~= bundleID then
         self[key] = app
         AppManagement.fastCache[key] = app
      end

      if Utils.debugEnabled then
        Utils.log("debug", strFmt("Cache miss for '%s', found '%s' (%s), now cached", key, name or "N/A", bundleID or "N/A"))
        Utils.metrics.cacheMisses = Utils.metrics.cacheMisses + 1
      end
      return app
    end

    -- App not found or not running
    if Utils.debugEnabled then
      Utils.log("debug", strFmt("Cache miss for '%s', app not found or not running", key))
      -- Note: We don't increment cacheMisses here because the app wasn't successfully retrieved.
    end
    return nil
  end
})

-- Track most frequently used apps and preload them
function AppManagement.predictivePreload()
  if not AppManagement.frequencyCounter then return end

  -- Find top apps by usage frequency
  local topApps = {}
  for app, count in pairs(AppManagement.frequencyCounter) do
    tblInsert(topApps, {app = app, count = count})
  end

  -- Sort by frequency (descending)
  table.sort(topApps, function(a, b) return a.count > b.count end)

  -- Preload the top N apps (limit to 5 for performance)
  for i = 1, math.min(5, #topApps) do
    local appKey = topApps[i].app
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
        if name then AppManagement.appCache[name] = app end
        if bundleID then AppManagement.appCache[bundleID] = app end

        if Utils.debugEnabled then
          Utils.log("debug", strFmt("Predictively preloaded '%s' (%s)", name or "N/A", bundleID or "N/A"))
        end
      end
    end
  end
end

function AppManagement.buildRegistry()
  local cache = AppManagement.appCache -- Local cache for performance
  local fastCache = AppManagement.fastCache or {} -- Fast direct cache

  -- Save top apps for frequency preservation
  local topAppObjects = {}
  if fastCache then
    for key, app in pairs(fastCache) do
      if app:isValid() and app:isRunning() then
        topAppObjects[key] = app
      end
    end
  end

  -- Clear existing caches
  for k in pairs(cache) do cache[k] = nil end
  AppManagement.fastCache = {}

  -- Reset frequency counter but preserve the top N apps
  local topApps = {}
  if AppManagement.frequencyCounter then
    for app, count in pairs(AppManagement.frequencyCounter) do
      tblInsert(topApps, {app = app, count = count})
    end
    table.sort(topApps, function(a, b) return a.count > b.count end)
  end

  AppManagement.frequencyCounter = {}

  -- Preserve frequency data for top 10 apps with reduced counts
  for i = 1, math.min(10, #topApps) do
    -- Reset to lower count but preserve ranking
    AppManagement.frequencyCounter[topApps[i].app] = 11 - i
  end

  -- Restore saved top apps first (fastest path)
  for key, app in pairs(topAppObjects or {}) do
    if app:isValid() and app:isRunning() then
      cache[key] = app
      AppManagement.fastCache[key] = app
    end
  end

  -- Populate from currently running apps
  local allRunning = hsApp.runningApplications()
  for _, appObj in ipairs(allRunning) do
    local name, bundleID = appObj and appObj:name(), appObj and appObj:bundleID()
    if name then
      cache[name] = appObj
      AppManagement.fastCache[name] = appObj
    end
    if bundleID then
      cache[bundleID] = appObj
      AppManagement.fastCache[bundleID] = appObj
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

  -- Use direct activation with timeout protection
  local activationSuccess = false

  -- First try to get main window before activation (fastest common case)
  local win = app:mainWindow()

  -- If we have a valid window, focus it directly
  if win then
    win:focus()
    activationSuccess = true
  else
    -- Otherwise, activate the app
    activationSuccess = app:activate()
  end

  -- Try again to get window after activation
  if not win then
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
  end

  return activationSuccess
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
    options = options or {} -- Ensure options table exists
    if not appKey or appKey == "" then
      if Utils.debugEnabled then Utils.log("error", "Invalid app key provided to switchToApp") end
      return false
    end

  local startTime
  if Utils.debugEnabled then
    startTime = hsTimer.secondsSinceEpoch()
  end

  -- Fast-path access for most frequent apps
  -- Direct table access with no metatable or function call overhead
  local app = AppManagement.fastCache and AppManagement.fastCache[appKey]

  -- Skip validity check for apps we just verified (massive performance win)
  local lastAppKey = AppManagement._lastVerifiedApp and AppManagement._lastVerifiedApp.key
  local lastAppTimestamp = AppManagement._lastVerifiedApp and AppManagement._lastVerifiedApp.time
  local currentTime = hsTimer.absoluteTime()
  local FAST_VERIFY_WINDOW = 1000000000 -- 1 second in nanoseconds

  -- Ultra-fast path - app verified within last second
  if app and lastAppKey == appKey and lastAppTimestamp and
     (currentTime - lastAppTimestamp) < FAST_VERIFY_WINDOW then

    if Utils.debugEnabled then
      Utils.metrics.cacheHits = Utils.metrics.cacheHits + 1
      Utils.log("debug", strFmt("Ultra-fast verification for '%s'", appKey))
    end

    -- Track for frequency-based optimization
    if AppManagement.frequencyCounter then
      AppManagement.frequencyCounter[appKey] = (AppManagement.frequencyCounter[appKey] or 0) + 2 -- Extra weight
    end

    -- Skip validation check completely - we just verified this
    goto focus_app
  end

  -- If not in fast cache, check regular cache
  if not app then
    app = AppManagement.appCache[appKey]

    -- If found in regular cache, promote to fast cache for next time
    if app then
      if not AppManagement.fastCache then AppManagement.fastCache = {} end
      AppManagement.fastCache[appKey] = app
    end
  end

  -- Check if the cached app object is still valid (app might have been terminated)
  if app then
    -- Debugging: Inspect the cached object before checking validity
    if Utils.debugEnabled then
      print(strFmt("switchToApp: Cache hit for '%s'. Type: %s", appKey, type(app)))
      -- Use pcall for inspect in case the object is truly strange
      pcall(function() hs.inspect(app) end)
    end

    local ok, valid = pcall(function() return app:isValid() end)
    if not ok or not valid then
      if Utils.debugEnabled then
        -- Log the error from pcall if it failed, or just that it's invalid
        local reason = not ok and tostring(valid) or "isValid returned false"
        Utils.log("debug", strFmt("switchToApp: Found stale/invalid app '%s' in cache (%s), forcing relaunch.", appKey, reason))
      end
      app = nil -- Treat as cache miss
      AppManagement.appCache[appKey] = nil -- Explicitly clear stale entry
      AppManagement.fastCache[appKey] = nil -- Clear from fast cache too
    else
      -- Add to recently verified list for ultra-fast path
      if not AppManagement._lastVerifiedApp then
        AppManagement._lastVerifiedApp = {}
      end
      AppManagement._lastVerifiedApp.key = appKey
      AppManagement._lastVerifiedApp.time = hsTimer.absoluteTime()
    end
  end

  ::focus_app:: -- Target for skipping verification

  -- If found in cache (and now confirmed valid), focus synchronously
  if app then
    local focusSuccess = AppManagement.focusApp(app)
    if Utils.debugEnabled then
      local endTime = hsTimer.secondsSinceEpoch()
      Utils.metrics.appSwitches.count = Utils.metrics.appSwitches.count + 1
      Utils.metrics.appSwitches.totalTime = Utils.metrics.appSwitches.totalTime + (endTime - startTime)
      if focusSuccess then
        Utils.log("debug", strFmt("Successfully switched to cached app '%s' in %.3f seconds", appKey, endTime - startTime))
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
  -- Ensure fast cache exists
  if not AppManagement.fastCache then AppManagement.fastCache = {} end

  if eventType == hsWatcher.launched then
    -- App launched, add to both caches if not already there
    if appObj then
      local name, bundleID = appObj:name(), appObj:bundleID()
      if name then
        AppManagement.appCache[name] = appObj
        AppManagement.fastCache[name] = appObj
      end
      if bundleID then
        AppManagement.appCache[bundleID] = appObj
        AppManagement.fastCache[bundleID] = appObj
      end

      -- Record new app in frequency counter for future preloading
      if AppManagement.frequencyCounter then
        local key = bundleID or name
        if key then AppManagement.frequencyCounter[key] = 1 end
      end
    end
  elseif eventType == hsWatcher.terminated then
    -- Clear all possible keys for this app from both caches
    if appObj then
      local name, bundleID = appObj:name(), appObj:bundleID()
      if name then
        AppManagement.appCache[name] = nil
        AppManagement.fastCache[name] = nil
      end
      if bundleID then
        AppManagement.appCache[bundleID] = nil
        AppManagement.fastCache[bundleID] = nil
      end
    end
    AppManagement.appCache[appName] = nil
    AppManagement.fastCache[appName] = nil
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
      
      -- Optional light memory cleanup (much less frequent)
      if Utils.debugEnabled then
        local before = collectG("count")
        collectG("collect")
        local after = collectG("count")
        Utils.log("debug", string.format("Maintenance GC: %0.2f KB -> %0.2f KB", before, after))
      end
    end)
  end)

  -- Flush JIT cache and optimize after initialization
  if package.preload.jit then
    local jit = require("jit")
    jit.opt.start("hotloop=10", "hotexit=2")
    jit.flush()
  end

  -- Optimize garbage collector for UI responsiveness
  if collectG then
    collectG("setpause", 140)
    collectG("setstepmul", 200)
  end



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
