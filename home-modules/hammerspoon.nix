{
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf pkgs.stdenv.isDarwin {
    home.file.".hammerspoon/init.lua".text = ''
      local hyper = {"cmd", "alt"}

      local function centerWindowObject(win, widthRatio, heightRatio)
        if not win then return end

        local screen = win:screen()
        if not screen then return end

        local frame = screen:frame()
        local w = frame.w * widthRatio
        local h = frame.h * heightRatio

        win:setFrame({
          x = frame.x + (frame.w - w) / 2,
          y = frame.y + (frame.h - h) / 2,
          w = w,
          h = h
        }, 0)
      end

      local function centerFocusedWindow(widthRatio, heightRatio)
        centerWindowObject(hs.window.focusedWindow(), widthRatio, heightRatio)
      end

      local function fillFocusedWindow()
        local win = hs.window.focusedWindow()
        if not win then return end

        local screen = win:screen()
        if not screen then return end

        win:setFrame(screen:frame(), 0)
      end

      local cycleState = {}

      local function isStandardVisibleWindow(win)
        return win and win:isStandard() and win:isVisible() and win:title() ~= ""
      end

      local function windowBelongsToApp(win, app)
        return win and app and win:application() and win:application():pid() == app:pid()
      end

      local function orderedVisibleWindows(app)
        if not app then return {} end

        local windows = hs.fnutils.filter(hs.window.orderedWindows(), function(win)
          return isStandardVisibleWindow(win) and windowBelongsToApp(win, app)
        end)

        if #windows > 0 then return windows end

        windows = hs.fnutils.filter(app:allWindows(), function(win)
          return isStandardVisibleWindow(win)
        end)

        table.sort(windows, function(a, b)
          return a:id() < b:id()
        end)

        return windows
      end

      local function focusApp(appName)
        cycleState[appName] = nil
        hs.application.launchOrFocus(appName)
      end

      local function cycleAppWindow(appName)
        local app = hs.application.get(appName)

        if not app then
          focusApp(appName)
          return
        end

        local windows = orderedVisibleWindows(app)

        if #windows == 0 then
          focusApp(appName)
          return
        end

        local focused = hs.window.focusedWindow()

        if not windowBelongsToApp(focused, app) then
          cycleState[appName] = nil
          windows[1]:focus()
          return
        end

        local state = cycleState[appName]
        local nextIndex = 1

        if state and state.windows and state.index and state.windows[state.index] and state.windows[state.index]:id() == focused:id() then
          windows = state.windows
          nextIndex = (state.index % #windows) + 1
        else
          for i, win in ipairs(windows) do
            if win:id() == focused:id() then
              nextIndex = (i % #windows) + 1
              break
            end
          end
        end

        cycleState[appName] = {
          windows = windows,
          index = nextIndex,
        }

        windows[nextIndex]:focus()
      end

      hs.hotkey.bind(hyper, "S", function()
        centerFocusedWindow(0.60, 0.85)
      end)

      hs.hotkey.bind(hyper, "U", function()
        fillFocusedWindow()
      end)

      hs.hotkey.bind(hyper, "H", function()
        focusApp("Ghostty")
      end)

      hs.hotkey.bind(hyper, "N", function()
        focusApp("Music")
      end)

      hs.hotkey.bind(hyper, "O", function()
        focusApp("Obsidian")
      end)

      hs.hotkey.bind(hyper, "T", function()
        cycleAppWindow("Microsoft Edge")
      end)
    '';
  };
}
