; ===== ReCtrl - Main Coordinator =====
; Coordinates all modules and initializes the application

#Requires AutoHotkey v2

/**
 * Include all modules.
 * The #Include essentially merges all the included files into one script at parse time
 * All functions and variables from included files become available in the global scope
 */
#Include sysTraySetup.ahk
#Include currentWinInfo.ahk

; setup system tray icon and tooltip
SetupTrayIcon()


/**
 * register hotkey (Double-press Ctrl).
 * Detects when Ctrl key is pressed twice within 400ms
 */
; Global variable to track the last Ctrl key press time
lastCtrlPress := 0
~Ctrl:: {
    global lastCtrlPress
    currentTime := A_TickCount

    if (lastCtrlPress > 0 && (currentTime - lastCtrlPress < 400)) {
        DisplayWindowInfo()
    }

    lastCtrlPress := currentTime
    KeyWait("Ctrl")
}
