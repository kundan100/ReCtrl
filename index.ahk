; ===== ReCtrl - Entry Point =====
; Main orchestrator file that loads and initializes the application

; ===== Utility: ReCtrl launcher hotkey =====
; how to run: double-press "Ctrl" key.
; behavior: summon ReCtrl main app (show when hidden, focus when already visible)

/**
 * directive (should be at the top) so the interpreter fails ...
 * with a clear message if the user runs it with AutoHotkey v1, ...
 * avoiding the ambiguous syntax error
 */
#Requires AutoHotkey v2

; Ensure only one instance of the script runs; automatically replace any previous instance
#SingleInstance Force

; Include the main application file
#Include src\ReCtrl.ahk
