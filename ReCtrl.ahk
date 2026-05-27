; ===== Utility: Window Info Hotkey =====
; how to run: double-press "Ctrl" key.
; displays active-window's info like exe-name, win-title, class-name, HWND

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
