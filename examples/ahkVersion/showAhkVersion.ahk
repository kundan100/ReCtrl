; ===== Info =====
; quick run (this file): powershell command (& "D:\kk\zeb_codes\__kk_Utils\__kkUtilsForAHK\AutoHotkey_2.0.19\AutoHotkey64.exe" "D:\kk\zeb_codes\__kk_Utils\__kk100github_readOnly\ReCtrl\examples\ahkVersion\showAhkVersion.ahk")
; how to run: double-press "Ctrl" key.
; displays active-window's info like exe-name, win-title, class-name, HWND

/**
 * directive (should be at the top) so the interpreter fails ...
 * with a clear message if the user runs it with AutoHotkey v1, ...
 * avoiding the ambiguous syntax error
 */
#Requires AutoHotkey v2

; show ahk version
MsgBox(A_AhkVersion)
