; ===== Utility: Window Info Hotkey =====
; how to run: double-press "Ctrl" key.
; displays active-window's info like exe-name, win-title, class-name, HWND

; directive (should be at the top) so the interpreter fails ...
; with a clear message if the user runs it with AutoHotkey v1, ...
; avoiding the ambiguous syntax error
#Requires AutoHotkey v2

; Set custom tray icon and custom tooltip.
; You can also compile this script to an EXE embedding the same ICO (see README instructions).
iconPath := A_ScriptDir "\assets\appIcon\favicon_io\favicon.ico"
if FileExist(iconPath) {
  ; MsgBox(iconPath)
  try {
    ; set app-icon in system-tray
    TraySetIcon(iconPath)
    ; set hover tooltip (for system-tray's app-icon)
    A_IconTip := "ReCtrl"
    MsgBox("iconPath: " iconPath)
  } catch {
    ; TBD (future): find a way to pass "e" and print e.Message
    MsgBox("Failed to set tray icon!")
  }
}

lastCtrlPress := 0
~Ctrl:: {
 global lastCtrlPress
 currentTime := A_TickCount
 
 if (lastCtrlPress > 0 && (currentTime - lastCtrlPress < 400)) {
        hwnd := WinExist("A") ; Explicitly get the active window handle
  if !hwnd {
   MsgBox("No active window detected.")
   return
  }

  className := WinGetClass(hwnd)
  title := WinGetTitle(hwnd)
  exeName := WinGetProcessName(hwnd)

  MsgBox("Exe: " exeName "`nClass: " className "`nTitle: " title "`nHWND: " hwnd)
    }
 
 lastCtrlPress := currentTime
 KeyWait("Ctrl")
}
