; ===== ReCtrl - Main Coordinator =====
; Coordinates all modules and initializes the application

#Requires AutoHotkey v2

/**
 * Include all modules.
 * The #Include essentially merges all the included files into one script at parse time
 * All functions and variables from included files become available in the global scope
 */
#Include sysTray\sysTraySetup.ahk
; #Include currentWin\currentWinInfo.ahk  ; Disconnected - keeping for future reference
; #Include mainSearchBox\mainSearchBox.ahk
#Include mainApp\mainApp.ahk

; setup system tray icon and tooltip
SetupTrayIcon()

; Initialize the main searchbox feature
; global mainSearchBoxInstance := MainSearchBox()
global mainAppInstance := MainApp()

/**
 * Helper function for #HotIf context
 * Returns true only if main searchbox edit control has focus
 */
; IsMainSearchBoxEditFocused() {
;     global mainSearchBoxInstance
;     try {
;         if !WinActive("ahk_id " mainSearchBoxInstance.gui.GetHwnd())
;             return false
;         ; Check if messagebox or other dialog is active
;         if WinActive("ahk_class #32770")  ; Standard dialog/messagebox class
;             return false
;         focusedControl := ControlGetFocus("A")
;         return (focusedControl != "")
;     }
;     return false
; }

/**
 * register hotkey (Double-press Ctrl).
 * Detects when Ctrl key is pressed twice within 400ms
 * Now shows the main searchbox instead of window info
 */
; Global variable to track the last Ctrl key press time
lastCtrlPress := 0
; ~Ctrl:: → Detects double Ctrl press within 400ms → Calls ShowMainSearchBox()
~Ctrl:: {
    global lastCtrlPress
    currentTime := A_TickCount

    if (lastCtrlPress > 0 && (currentTime - lastCtrlPress < 400)) {
        ShowMainApp()
        ; ShowMainSearchBox()  ; New main searchbox feature
        ; DisplayWindowInfo()  ; Old feature - disconnected but available
    }

    lastCtrlPress := currentTime
    KeyWait("Ctrl")
}

/**
 * Enter key handler for main searchbox
 * Only active when main searchbox edit control has focus (not messageboxes)
 */
; #HotIf IsMainSearchBoxEditFocused()
; Enter:: {
;     global mainSearchBoxInstance
;     mainSearchBoxInstance.ProcessSearch()
; }
; #HotIf
