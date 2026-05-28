; ===== ReCtrl - Entry Point =====
; Main orchestrator file that loads and initializes the application

; ===== Utility: Window Info Hotkey =====
; how to run: double-press "Ctrl" key.
; displays active-window's info like exe-name, win-title, class-name, HWND

/**
 * directive (should be at the top) so the interpreter fails ...
 * with a clear message if the user runs it with AutoHotkey v1, ...
 * avoiding the ambiguous syntax error
 */
#Requires AutoHotkey v2

; Include the main application file
#Include src\ReCtrl.ahk
